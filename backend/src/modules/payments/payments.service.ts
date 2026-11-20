import { Op, UniqueConstraintError, type Transaction } from "sequelize";
import { releaseBookingDateLocksForBooking } from "../bookings/booking-date-lock.service";
import { expirePendingPaymentBookingInTransaction } from "../bookings/booking-expiration.service";
import { ApiError } from "../../common/api-error";
import { cancellationReasons } from "../bookings/booking-display-status";
import sequelize from "../../config/database";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import type { AuthenticatedUser } from "../auth/auth.service";
import Booking, { BookingDocument, BookingStatus } from "../../models/booking";
import { getNextSequence } from "../../models/counter";
import Coupon from "../../models/coupon";
import CouponRedemption from "../../models/coupon-redemption";
import Payment, { PaymentDocument, PaymentMethod, PaymentStatus } from "../../models/payment";
import PaymentTransaction, { type PaymentTransactionStatus } from "../../models/payment-transaction";
import Refund from "../../models/refund";
import { toVnpayAmount } from "../../common/money";
import { writeAuditLog } from "../../services/audit-log.service";
import {
    buildVnpayPaymentUrl,
    normalizeVnpayPayload,
    verifyVnpayPayload,
    VnpayPayload,
} from "./vnpay.service";
import {
    buildMomoPaymentUrl,
    isMomoAmountMatching,
    MomoPayload,
    normalizeMomoPayload,
    verifyMomoPayload,
    getMomoAvailability,
} from "./momo.service";
import { transitionBookingStatus } from "../bookings/booking-state-machine";
import {
    notifyPaymentExpired,
    notifyPaymentPending,
    notifyPaymentSuccess,
    notifyRefundCreated,
} from "../notifications/notification.service";

export type CreatePaymentInput = {
    bookingId: number;
    method: PaymentMethod;
};

export type ListPaymentsQuery = {
    status?: PaymentStatus;
    page?: number;
    limit?: number;
};

export type PaymentMethodAvailability = {
    method: PaymentMethod;
    label: string;
    available: boolean;
    unavailableReason?: string;
    missingConfigKeys?: string[];
};

export type VnpayWebhookResult = {
    RspCode: string;
    Message: string;
};
export type MomoWebhookResult = {
    resultCode: number;
    message: string;
};
type PaymentCallbackContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};
type NotificationSideEffect = {
    label: string;
    metadata?: Record<string, unknown>;
    fn: () => Promise<void>;
};

const payableBookingStatuses: BookingStatus[] = ["pending_payment"];
const reusablePaymentStatuses: PaymentStatus[] = ["pending", "paid"];
const finalTransactionStatuses = new Set<PaymentTransactionStatus>(["succeeded", "failed", "cancelled"]);


/**
 * Kiểm tra người dùng hiện tại có vai trò quản trị viên (`admin`) hay không.
 */
const isAdmin = (user: AuthenticatedUser) => user.roles.includes("admin");
/**
 * Kiểm tra người dùng hiện tại có vai trò chủ nhà (`host`) hay không.
 */
const isHost = (user: AuthenticatedUser) => user.roles.includes("host");
/**
 * Ép kiểu giá trị số tiền/số lượng từ DB (DECIMAL/string/null) sang kiểu `number` mặc định `0`.
 */
const toNumber = (value: unknown) => Number(value ?? 0);

/**
 * Tuần tự hóa đối tượng lỗi khi gửi thông báo thành cấu trúc JSON an toàn để ghi log chẩn đoán.
 */
const serializeNotificationError = (error: unknown) => {
    if (error instanceof Error) {
        return {
            name: error.name,
            message: error.message,
            stack: error.stack,
        };
    }

    return {
        message: String(error),
    };
};

/**
 * Giải thuật cô lập lỗi tác vụ phụ thông báo (Fault-Isolated Side Effect):
 * - Thực thi hàm gửi thông báo bất đồng bộ và bắt mọi ngoại lệ để ghi cảnh báo, đảm bảo lỗi kênh
 *   Email/Push/Socket không bao giờ làm hỏng kết quả giao dịch thanh toán đã commit trong DB.
 */
const safeNotify = async (
    label: string,
    fn: () => Promise<void>,
    metadata: Record<string, unknown> = {},
) => {
    try {
        await fn();
    } catch (error) {
        logger.warn("Payment notification side-effect failed", {
            label,
            ...metadata,
            error: serializeNotificationError(error),
        });
    }
};

/**
 * Giải thuật trì hoãn tác vụ thông báo ra sau thời điểm commit giao dịch (Deferred Post-Commit Outbox In-Memory):
 * - Đẩy hàm gửi thông báo vào hàng đợi tạm trong phạm vi giao dịch DB để chỉ kích hoạt đúng một lần
 *   sau khi transaction đã commit thành công, ngăn gửi thông báo giả nếu transaction bị rollback.
 */
const enqueueNotification = (
    notifications: NotificationSideEffect[],
    label: string,
    fn: () => Promise<void>,
    metadata: Record<string, unknown> = {},
) => {
    notifications.push({
        label,
        metadata,
        fn,
    });
};

/**
 * Thực thi tuần tự danh sách các tác vụ thông báo đã xếp hàng sau khi giao dịch thanh toán commit thành công.
 */
const runNotificationSideEffects = async (notifications: NotificationSideEffect[]) => {
    for (const notification of notifications) {
        await safeNotify(notification.label, notification.fn, notification.metadata);
    }
};

/**
 * Giải thuật xác định thời điểm hết hạn thanh toán của đơn đặt phòng:
 * - Ưu tiên mốc khóa lịch giữ chỗ `booking.lockedUntil`, dự phòng cộng `paymentHoldMinutes` từ thời điểm hiện tại.
 */
function getBookingPaymentExpiresAt(booking: BookingDocument): Date {
    const env = getEnv();

    return booking.lockedUntil ?? new Date(Date.now() + env.paymentHoldMinutes * 60 * 1000);
}

/**
 * Giải thuật kiểm tra điều kiện tiên quyết về trạng thái và thời hạn giữ chỗ trước khi khởi tạo giao dịch:
 * - Từ chối bằng lỗi `409 Conflict` nếu booking đã sang trạng thái kết thúc/hủy/quá hạn hoặc `lockedUntil <= now`.
 */
function assertBookingCanCreatePayment(booking: BookingDocument): void {
    const now = Date.now();

    if (
        [
            "payment_expired",
            "cancelled_by_guest",
            "cancelled_by_host",
            "cancelled_by_admin",
            "rejected",
            "checked_out",
            "completed",
        ].includes(booking.status)
    ) {
        throw new ApiError(409, "Phiên giữ chỗ đã hết hạn hoặc booking đã bị hủy.");
    }

    if (
        booking.status === "pending_payment" &&
        booking.lockedUntil &&
        booking.lockedUntil.getTime() <= now
    ) {
        throw new ApiError(409, "Phiên giữ chỗ đã hết hạn, vui lòng đặt lại.");
    }
}

/**
 * Giải thuật xác định số tiền thanh toán tin cậy phía máy chủ (Server-Authoritative Pricing):
 * - Luôn đọc trực tiếp từ `booking.totalAmount` trong DB thay vì tin dữ liệu phía client truyền lên,
 *   ràng buộc giá trị hữu hạn dương để chống tấn công sửa số tiền thanh toán.
 */
const getTrustedBookingPaymentAmount = (booking: BookingDocument) => {
    const amount = toNumber(booking.totalAmount);

    if (!Number.isFinite(amount) || amount <= 0) {
        throw new ApiError(409, "Booking amount is invalid");
    }

    return amount;
};

/**
 * Tổng hợp trạng thái sẵn sàng của các cổng thanh toán tích hợp (`vnpay`, `momo`) dựa trên cấu hình môi trường hiện hành.
 */
export const getPaymentMethodAvailability = () => {
    const env = getEnv();
    const isVnpayAvailable = Boolean(env.vnpayTmnCode && env.vnpayHashSecret && env.vnpayReturnUrl);
    const momoAvailability = getMomoAvailability();
    const methods: PaymentMethodAvailability[] = [
        {
            method: "vnpay",
            label: "VNPay",
            available: isVnpayAvailable,
            unavailableReason: isVnpayAvailable ? undefined : "VNPay payment is not configured",
        },
        {
            method: "momo",
            label: "MoMo",
            available: momoAvailability.available,
            unavailableReason: momoAvailability.available ? undefined : "MoMo payment is not configured",
            missingConfigKeys: momoAvailability.missingKeys,
        },
    ];

    return {
        items: methods,
    };
};

/**
 * Kiểm tra phân quyền sở hữu và trạng thái hợp lệ để thanh toán đơn đặt phòng:
 * - Chỉ chính khách đặt phòng (`booking.guestUserId === user.id`) mới được phép tạo giao dịch và
 *   booking bắt buộc đang ở trạng thái `"pending_payment"`.
 */
const assertBookingCanBePaidByUser = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (String(booking.guestUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }

    if (!payableBookingStatuses.includes(booking.status)) {
        throw new ApiError(409, "Booking is not payable");
    }
};

/**
 * Kiểm tra quyền truy cập chi tiết giao dịch thanh toán (RBAC + Ownership):
 * - Chỉ cho phép khách đặt phòng của đơn đó, chủ nhà sở hữu chỗ ở của đơn đó, hoặc quản trị viên (`admin`).
 */
const assertCanViewPayment = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (
        String(booking.guestUserId) === user.id ||
        (isHost(user) && String(booking.hostUserId) === user.id) ||
        isAdmin(user)
    ) {
        return;
    }

    throw new ApiError(403, "Forbidden");
};

/**
 * Giải thuật suy diễn trạng thái kết quả đối soát của giao dịch thanh toán muộn (Late Payment Resolution):
 * - Phát hiện cờ `latePaymentAfterBookingExpired` trong `providerPayload` khi tiền về sau lúc phiên giữ chỗ đã hết hạn.
 * - Ánh xạ sang `"refunded"` nếu yêu cầu hoàn tiền đã hoàn tất (`refundStatus === "succeeded"`),
 *   ngược lại trả về `"refund_pending"` để giao diện không hiển thị nhầm đơn đã được xác nhận phòng.
 */
const getLatePaymentPayload = (payment: PaymentDocument) => {
    const providerPayload = payment.providerPayload ?? {};
    const isLatePayment = providerPayload.latePaymentAfterBookingExpired === true;

    if (!isLatePayment) {
        return {
            isLatePayment: false,
            requiresRefund: false,
            refundStatus: null,
            latePaymentReason: null,
            paymentResultStatus: payment.status,
        };
    }

    const refundStatus =
        typeof providerPayload.refundStatus === "string" && providerPayload.refundStatus
            ? providerPayload.refundStatus
            : "pending";

    // Giải thuật xác định trạng thái kết quả của giao dịch thanh toán muộn (late payment):
    // Giao dịch đến sau khi hết thời gian giữ chỗ bắt buộc phải hoàn tiền:
    // trả về 'refunded' khi đã hoàn tất hoàn tiền ('succeeded'), ngược lại trả về 'refund_pending'.
    // CONFLICT-RESOLVED: Không trả về payment.status ('paid') khi refundStatus === 'succeeded' gây hiển thị nhầm "Thanh toán thành công".
    return {
        isLatePayment: true,
        requiresRefund: refundStatus !== "succeeded",
        refundStatus,
        latePaymentReason:
            typeof providerPayload.latePaymentReason === "string"
                ? providerPayload.latePaymentReason
                : "late_payment_after_booking_expired",
        paymentResultStatus: refundStatus === "succeeded" ? "refunded" : "refund_pending",
    };
};

/**
 * Chuẩn hóa đối tượng `PaymentDocument` sang DTO phản hồi API, tích hợp trạng thái đối soát hoàn tiền thanh toán muộn.
 */
const serializePayment = (payment: PaymentDocument, paymentUrl?: string | null) => {
    const latePayment = getLatePaymentPayload(payment);

    return {
        paymentId: payment.paymentId,
        bookingId: payment.bookingId,
        method: payment.method,
        paymentStatus: payment.status,
        paymentResultStatus: latePayment.paymentResultStatus,
        amount: payment.amount,
        currency: payment.currency,
        paymentUrl: paymentUrl ?? null,
        provider: payment.provider,
        providerTxnRef: payment.providerTxnRef,
        providerTransactionNo: payment.providerTransactionNo,
        providerTransactionId: payment.providerTransactionNo,
        providerResponseCode: payment.providerResponseCode,
        paidAt: payment.paidAt ?? null,
        requiresRefund: latePayment.requiresRefund,
        refundStatus: latePayment.refundStatus,
        latePaymentReason: latePayment.latePaymentReason,
        createdAt: payment.createdAt,
        updatedAt: payment.updatedAt,
    };
};

/**
 * Truy vấn bản ghi `Booking` gắn với giao dịch thanh toán; ném `ApiError(404)` nếu không tìm thấy.
 */
const getPaymentBooking = async (payment: PaymentDocument) => {
    const booking = await Booking.findOne({ bookingId: payment.bookingId });

    if (!booking) {
        throw new ApiError(404, "Booking not found");
    }

    return booking;
};

/**
 * Trích xuất địa chỉ IP đầu tiên của client từ chuỗi `X-Forwarded-For` hoặc trả về `127.0.0.1` mặc định.
 */
const getClientIp = (value?: string | null) => {
    const firstForwardedIp = value?.split(",")[0]?.trim();
    return firstForwardedIp || "127.0.0.1";
};

/**
 * Giải thuật tái dựng có điều kiện URL thanh toán VNPay cho giao dịch đang chờ (`pending`),
 * đồng bộ lại `providerTxnRef` nếu chưa được lưu.
 */
const maybeBuildVnpayUrl = async (
    booking: BookingDocument,
    payment: PaymentDocument,
    ipAddress: string,
) => {
    if (payment.method !== "vnpay" || payment.status !== "pending") {
        return null;
    }

    const result = buildVnpayPaymentUrl({
        booking,
        payment,
        ipAddress,
        createdAt: payment.createdAt,
    });

    if (payment.providerTxnRef !== result.txnRef) {
        payment.provider = "vnpay";
        payment.providerTxnRef = result.txnRef;
        await payment.save();
    }

    return result.paymentUrl;
};

/**
 * Kiểm tra giao dịch thanh toán đang chờ (`pending`) còn thời hạn hiệu lực (`expiresAt > now`)
 * để tái sử dụng bất biến (Idempotent Reuse) thay vì phát sinh bản ghi giao dịch mới trùng lặp.
 */
const isPendingPaymentReusable = (payment: PaymentDocument) => {
    if (payment.status !== "pending") {
        return false;
    }

    if (!payment.expiresAt) {
        return false;
    }

    return payment.expiresAt.getTime() > Date.now();
};

/**
 * Giải thuật hủy hiệu lực giao dịch thanh toán đang chờ cũ khi khởi tạo phiên thanh toán thay thế:
 * - Chuyển trạng thái `Payment` sang `"expired"` và đánh dấu các bản ghi `PaymentTransaction` tương ứng
 *   sang `"cancelled"` nguyên tử trong cùng giao dịch DB.
 */
const expirePendingPayment = async (payment: PaymentDocument, transaction: Transaction) => {
    if (payment.status !== "pending") {
        return;
    }

    const expiredAt = new Date();
    payment.status = "expired";
    payment.failedAt = payment.failedAt ?? expiredAt;
    payment.expiredAt = payment.expiredAt ?? expiredAt;
    await payment.save({ transaction });

    if (payment.providerTxnRef) {
        await PaymentTransaction.update(
            {
                status: "cancelled",
                processedAt: payment.failedAt,
            },
            {
                where: {
                    providerTxnRef: payment.providerTxnRef,
                },
                transaction,
            },
        );
    }
};

/**
 * Giải thuật kiểm tra đối khớp số tiền thực thu từ VNPay bằng số nguyên chính xác tuyệt đối:
 * - Ràng buộc `vnp_Amount` chỉ gồm các chữ số và đối chiếu qua `BigInt(payload.vnp_Amount) === toVnpayAmount(payment.amount)`
 *   (đơn vị VND * 100), triệt tiêu hoàn toàn sai số số thực dấu phẩy động và chống sửa số tiền thanh toán.
 */
const isVnpayAmountMatching = (payload: VnpayPayload, payment: PaymentDocument) => {
    if (!payload.vnp_Amount || !/^\d+$/.test(payload.vnp_Amount)) {
        return false;
    }

    try {
        return BigInt(payload.vnp_Amount) === toVnpayAmount(payment.amount);
    } catch {
        return false;
    }
};

/**
 * Giải thuật phân tích chuỗi thời điểm thanh toán `vnp_PayDate` (`yyyyMMddHHmmss` múi giờ GMT+7)
 * sang đối tượng `Date` chuẩn UTC.
 */
const parseVnpayPayDate = (value?: string | null) => {
    if (!value || !/^\d{14}$/.test(value)) {
        return null;
    }

    const year = Number(value.slice(0, 4));
    const month = Number(value.slice(4, 6)) - 1;
    const day = Number(value.slice(6, 8));
    const hour = Number(value.slice(8, 10));
    const minute = Number(value.slice(10, 12));
    const second = Number(value.slice(12, 14));

    return new Date(Date.UTC(year, month, day, hour - 7, minute, second));
};

/**
 * Giải thuật chuyển đổi dấu thời gian `responseTime` (epoch milliseconds) từ callback MoMo sang đối tượng `Date`.
 */
const parseMomoResponseTime = (value?: string | null) => {
    if (!value || !/^\d+$/.test(value)) {
        return null;
    }

    const timestamp = Number(value);

    if (!Number.isFinite(timestamp) || timestamp <= 0) {
        return null;
    }

    return new Date(timestamp);
};

/**
 * Lọc danh sách trắng các trường đối soát thiết yếu của VNPay trước khi lưu JSON vào DB,
 * loại bỏ trường chữ ký `vnp_SecureHash` và các tham số không cần thiết.
 */
const sanitizeVnpayPayloadForStorage = (payload: VnpayPayload) => ({
    vnp_TxnRef: payload.vnp_TxnRef ?? null,
    vnp_Amount: payload.vnp_Amount ?? null,
    vnp_ResponseCode: payload.vnp_ResponseCode ?? null,
    vnp_TransactionStatus: payload.vnp_TransactionStatus ?? null,
    vnp_TransactionNo: payload.vnp_TransactionNo ?? null,
    vnp_PayDate: payload.vnp_PayDate ?? null,
    vnp_BankCode: payload.vnp_BankCode ?? null,
});

/**
 * Giải thuật ánh xạ mã lỗi phản hồi VNPay (`vnp_ResponseCode`, `vnp_TransactionStatus`) sang trạng thái `PaymentStatus`:
 * - Mã `"24"` -> khách hủy giao dịch (`"cancelled"`); mã `"11"` hoặc trạng thái `"02"` -> hết hạn (`"expired"`);
 *   các mã khác -> thất bại (`"failed"`).
 */
const getFailedVnpayStatus = (payload: VnpayPayload): PaymentStatus => {
    if (payload.vnp_ResponseCode === "24") {
        return "cancelled";
    }

    if (payload.vnp_ResponseCode === "11" || payload.vnp_TransactionStatus === "02") {
        return "expired";
    }

    return "failed";
};

/**
 * Giải thuật ghi nhận sử dụng mã giảm giá bất biến (Idempotent Coupon Redemption) khi quyết toán thành công:
 * - Khóa bi quan mức dòng (`SELECT ... FOR UPDATE`) trên cả `CouponRedemption` và `Coupon` để chống Race Condition
 *   khi nhiều callback thanh toán đến đồng thời.
 * - Bắt ngoại lệ `UniqueConstraintError` làm chốt chặn Idempotency thứ hai ở tầng DB, đảm bảo mỗi `bookingId`
 *   chỉ tăng `Coupon.usedCount` đúng một lần duy nhất.
 */
const redeemBookingCouponIfNeeded = async (booking: BookingDocument, transaction: Transaction) => {
    if (!booking.couponId || !booking.discountAmount || Number(booking.discountAmount) <= 0) {
        return;
    }

    const existingRedemption = await CouponRedemption.findOne({
        where: {
            couponId: booking.couponId,
            bookingId: booking.bookingId,
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (existingRedemption) {
        return;
    }

    const coupon = await Coupon.findOne({
        where: {
            couponId: booking.couponId,
            deletedAt: null,
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (!coupon) {
        return;
    }

    const now = new Date();
    if (
        coupon.isActive === false ||
        (coupon.endDate && new Date(coupon.endDate) < now) ||
        (coupon.totalLimit !== null &&
            coupon.totalLimit !== undefined &&
            Number(coupon.usedCount ?? 0) >= Number(coupon.totalLimit))
    ) {
        logger.warn("Coupon redeemed during payment settlement after expiry or limit threshold", {
            couponId: coupon.couponId,
            bookingId: booking.bookingId,
            usedCount: coupon.usedCount,
            totalLimit: coupon.totalLimit,
        });
    }

    try {
        await CouponRedemption.create(
            {
                couponId: booking.couponId,
                userId: booking.guestUserId,
                bookingId: booking.bookingId,
                discountAmount: booking.discountAmount,
            },
            { transaction },
        );
    } catch (error) {
        if (error instanceof UniqueConstraintError) {
            return;
        }

        throw error;
    }

    await Coupon.increment("usedCount", {
        by: 1,
        where: {
            couponId: booking.couponId,
        },
        transaction,
    });
};

/**
 * Giải thuật đối soát và giải phóng giữ chỗ khi giao dịch thất bại sau thời điểm hết hạn khóa lịch:
 * - Nếu booking đang `"pending_payment"` và `lockedUntil <= now`, giải phóng khóa lịch phòng (`releaseBookingDateLocksForBooking`),
 *   chuyển trạng thái máy hữu hạn sang `"payment_expired"` và xếp hàng thông báo hết hạn sau khi commit.
 */
const expireBookingAfterFailedPayment = async (
    booking: BookingDocument,
    transaction: Transaction,
    reason: string,
    notifications: NotificationSideEffect[] = [],
) => {
    if (booking.status !== "pending_payment") {
        return false;
    }

    const now = new Date();
    const paymentExpiresAt = booking.lockedUntil ?? now;

    if (paymentExpiresAt.getTime() > now.getTime()) {
        return false;
    }

    await releaseBookingDateLocksForBooking({
        bookingId: booking.bookingId,
        transaction,
    });

    await transitionBookingStatus({
        booking,
        toStatus: "payment_expired",
        actor: "system",
        changedByUserId: null,
        reason,
        transaction,
        context: {
            now,
            paymentExpiresAt,
        },
        mutate: (currentBooking) => {
            currentBooking.cancellationReason = reason;
            currentBooking.cancelledByUserId = null;
            currentBooking.lockedUntil = null;
        },
    });

    enqueueNotification(
        notifications,
        "notifyPaymentExpired",
        () => notifyPaymentExpired(booking.bookingId),
        { bookingId: booking.bookingId },
    );

    return true;
};

/**
 * Giải thuật phát hiện giao dịch thanh toán thành công muộn sau khi phiên giữ chỗ đã hết hiệu lực:
 * - Đánh dấu là thanh toán muộn nếu booking đã chuyển sang trạng thái hết hạn/hủy/từ chối, hoặc vẫn ở
 *   `"pending_payment"` nhưng thời điểm thanh toán thực tế `paidAt` vượt quá mốc khóa giữ chỗ (`lockedUntil` / `expiresAt`).
 */
const isLateSuccessfulPaymentForBooking = (
    booking: BookingDocument,
    payment: PaymentDocument,
    paidAt: Date,
): boolean =>
    booking.status === "payment_expired" ||
    booking.status === "cancelled_by_guest" ||
    booking.status === "cancelled_by_host" ||
    booking.status === "cancelled_by_admin" ||
    booking.status === "rejected" ||
    Boolean(
        booking.status === "pending_payment" &&
        (booking.lockedUntil ?? payment.expiresAt) &&
        (booking.lockedUntil ?? payment.expiresAt)!.getTime() < paidAt.getTime()
    );

/**
 * Giải thuật khởi tạo yêu cầu hoàn tiền bất biến (Idempotent Refund Creation) cho giao dịch thanh toán muộn:
 * - Truy vấn có khóa bi quan `FOR UPDATE` theo bộ khóa `(bookingId, paymentId, reason: "late_payment_after_booking_expired")`
 *   để đảm bảo các callback trùng lặp chỉ tạo tối đa một bản ghi `Refund` duy nhất.
 */
const createLatePaymentRefundIfMissing = async (
    booking: BookingDocument,
    payment: PaymentDocument,
    transaction: Transaction,
) => {
    const existingRefund = await Refund.findOne({
        where: {
            bookingId: booking.bookingId,
            paymentId: payment.paymentId,
            reason: "late_payment_after_booking_expired",
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (existingRefund) {
        return {
            refund: existingRefund,
            created: false,
        };
    }

    const refund = await Refund.create(
        {
            bookingId: booking.bookingId,
            paymentId: payment.paymentId,
            requestedByUserId: booking.guestUserId,
            amount: payment.amount,
            currency: payment.currency,
            status: "pending",
            reason: "late_payment_after_booking_expired",
            providerRef: null,
            processedByUserId: null,
            processedAt: null,
        },
        { transaction },
    );

    return {
        refund,
        created: true,
    };
};

/**
 * Giải thuật xử lý đối soát giao dịch thanh toán thành công muộn (Late Payment Reconciliation & Auto-Refund Queueing):
 * 1. Ghi nhận tiền đã thu (`payment.status = "paid"`) kèm cờ `latePaymentAfterBookingExpired` và `refundRequired = true`
 *    nhằm bảo toàn dấu vết dòng tiền thực tế mà không xác nhận nhầm phòng đã hết giữ chỗ.
 * 2. Nếu booking vẫn treo ở `"pending_payment"`, giải phóng khóa ngày đặt phòng và chuyển sang `"payment_expired"`.
 * 3. Khởi tạo bản ghi hoàn tiền bất biến (`createLatePaymentRefundIfMissing`), ghi nhật ký kiểm toán
 *    `"payment.late.refund_pending"` và đẩy thông báo hoàn tiền vào hàng đợi hậu commit.
 */
const markLateSuccessfulPaymentForManualReview = async (params: {
    booking: BookingDocument;
    payment: PaymentDocument;
    paidAt: Date;
    previousPaymentStatus: PaymentStatus;
    transaction: Transaction;
    provider: PaymentMethod;
    notifications: NotificationSideEffect[];
}): Promise<boolean> => {
    const { booking, payment, paidAt, previousPaymentStatus, transaction, provider, notifications } = params;
    let bookingStatusChanged = false;

    payment.status = "paid";
    payment.paidAt = paidAt;
    payment.failedAt = null;
    payment.providerPayload = {
        ...(payment.providerPayload ?? {}),
        latePaymentAfterBookingExpired: true,
        refundRequired: true,
        refundStatus: "pending",
        latePaymentReason: "late_payment_after_booking_expired",
        manualReviewReason: "payment_success_after_hold_expired",
    };

    if (booking.status === "pending_payment") {
        const paymentExpiresAt = booking.lockedUntil ?? paidAt;

        await releaseBookingDateLocksForBooking({
            bookingId: booking.bookingId,
            transaction,
        });

        await transitionBookingStatus({
            booking,
            toStatus: "payment_expired",
            actor: "system",
            changedByUserId: null,
            reason: cancellationReasons.paymentExpired,
            metadata: {
                paymentId: payment.paymentId,
                provider,
                paidAt: paidAt.toISOString(),
                manualReviewReason: "late_payment_after_booking_expired",
            },
            transaction,
            context: {
                now: paidAt,
                paymentExpiresAt,
            },
            mutate: (currentBooking) => {
                currentBooking.cancellationReason = cancellationReasons.paymentExpired;
                currentBooking.cancelledByUserId = null;
                currentBooking.lockedUntil = null;
            },
        });
        bookingStatusChanged = true;
    }

    const refundResult = await createLatePaymentRefundIfMissing(booking, payment, transaction);

    if (bookingStatusChanged) {
        enqueueNotification(
            notifications,
            "notifyPaymentExpired",
            () => notifyPaymentExpired(booking.bookingId),
            { bookingId: booking.bookingId },
        );
    }

    if (refundResult.created && refundResult.refund) {
        const refundId = refundResult.refund.refundId;

        enqueueNotification(
            notifications,
            "notifyRefundCreated",
            () => notifyRefundCreated(refundId),
            {
                bookingId: booking.bookingId,
                paymentId: payment.paymentId,
                refundId,
            },
        );
    }

    await writeAuditLog({
        action: "payment.late.refund_pending",
        targetType: "payment",
        targetId: payment.paymentId,
        metadata: {
            bookingId: booking.bookingId,
            provider,
            paymentId: payment.paymentId,
            paidAt: paidAt.toISOString(),
            previousPaymentStatus,
            refundId: refundResult.refund?.refundId ?? null,
            refundCreated: refundResult.created,
            reason: "late_payment_after_booking_expired",
        },
        transaction,
    });

    logger.warn("Late successful payment requires manual review", {
        bookingId: booking.bookingId,
        paymentId: payment.paymentId,
        provider,
        bookingStatus: booking.status,
        paidAt,
    });

    return bookingStatusChanged;
};

/**
 * Ánh xạ trạng thái tổng thể của `Payment` sang trạng thái chi tiết của bản ghi đối soát `PaymentTransaction`.
 */
const toPaymentTransactionStatus = (paymentStatus: PaymentStatus): PaymentTransactionStatus => {
    if (paymentStatus === "paid") {
        return "succeeded";
    }

    if (paymentStatus === "failed") {
        return "failed";
    }

    if (paymentStatus === "cancelled" || paymentStatus === "expired") {
        return "cancelled";
    }

    return "pending";
};

/**
 * Giải thuật định vị và khóa bi quan bản ghi `PaymentTransaction` phục vụ xử lý callback:
 * - Ưu tiên tra cứu theo khóa giao dịch phía cổng thanh toán `(provider, "payment", providerTransactionNo)` có `lock: true`
 *   (`SELECT ... FOR UPDATE`), nếu chưa có mới lùi về tra cứu theo mã tham chiếu nội bộ `providerTxnRef`.
 */
const findPaymentTransactionForCallback = async (params: {
    payment: PaymentDocument;
    provider: PaymentMethod;
    providerTransactionNo?: string | null;
    transaction: Transaction;
}) => {
    const { payment, provider, providerTransactionNo, transaction } = params;

    if (providerTransactionNo) {
        const providerTransaction = await PaymentTransaction.findOne({
            where: {
                provider,
                transactionType: "payment",
                providerTransactionNo,
            },
            transaction,
            lock: true,
        });

        if (providerTransaction) {
            return providerTransaction;
        }
    }

    if (!payment.providerTxnRef) {
        return null;
    }

    return PaymentTransaction.findOne({
        where: {
            providerTxnRef: payment.providerTxnRef,
            transactionType: "payment",
        },
        transaction,
        lock: true,
    });
};

/**
 * Giải thuật chống va chạm/gắn nhầm mã giao dịch cổng thanh toán giữa hai đơn thanh toán khác nhau:
 * - Đảm bảo `providerTransactionNo` nếu đã từng được ghi nhận thì bắt buộc thuộc về đúng `payment.paymentId` hiện tại,
 *   ném lỗi `409 Conflict` nếu phát hiện tái sử dụng mã giao dịch sang đơn khác.
 */
const assertProviderTransactionBelongsToPayment = (params: {
    existingTransaction: InstanceType<typeof PaymentTransaction> | null;
    payment: PaymentDocument;
    providerTransactionNo?: string | null;
}) => {
    if (!params.existingTransaction || !params.providerTransactionNo) {
        return;
    }

    if (Number(params.existingTransaction.paymentId) !== Number(params.payment.paymentId)) {
        throw new ApiError(409, "Provider transaction has already been processed for another payment");
    }
};

/**
 * Giải thuật kiểm tra bất biến Idempotency cho callback trùng lặp từ cổng thanh toán (Return URL & Webhook IPN):
 * - Xác nhận callback đã được áp dụng hoàn tất trước đó khi `existingTransaction` đã ở trạng thái kết thúc
 *   (`succeeded`, `failed`, `cancelled`) khớp với `expectedTransactionStatus` và trạng thái `Payment` hiện tại
 *   cũng đã hội tụ tương ứng, giúp bỏ qua an toàn mọi lần gọi lại mà không nhân đôi tác vụ phụ.
 */
const isCallbackAlreadyApplied = (params: {
    paymentStatus: PaymentStatus;
    existingTransaction: InstanceType<typeof PaymentTransaction> | null;
    expectedTransactionStatus: PaymentTransactionStatus;
}) => {
    const { paymentStatus, existingTransaction, expectedTransactionStatus } = params;

    if (!existingTransaction || !finalTransactionStatuses.has(existingTransaction.status)) {
        return false;
    }

    if (existingTransaction.status !== expectedTransactionStatus) {
        return false;
    }

    if (expectedTransactionStatus === "succeeded") {
        return paymentStatus === "paid";
    }

    if (expectedTransactionStatus === "failed") {
        return paymentStatus === "failed";
    }

    if (expectedTransactionStatus === "cancelled") {
        return paymentStatus === "cancelled" || paymentStatus === "expired";
    }

    return false;
};

/**
 * Giải thuật cập nhật hoặc thêm mới bất biến (Idempotent Upsert) bản ghi lịch sử giao dịch `PaymentTransaction`
 * từ dữ liệu callback đã xác thực trong cùng giao dịch cơ sở dữ liệu.
 */
const upsertPaymentTransactionFromCallback = async (params: {
    existingTransaction: InstanceType<typeof PaymentTransaction> | null;
    payment: PaymentDocument;
    booking: BookingDocument;
    provider: PaymentMethod;
    status: PaymentTransactionStatus;
    rawPayloadJson: Record<string, unknown>;
    transaction: Transaction;
}) => {
    const {
        existingTransaction,
        payment,
        booking,
        provider,
        status,
        rawPayloadJson,
        transaction,
    } = params;
    const processedAt = new Date();

    if (existingTransaction) {
        existingTransaction.provider = provider;
        existingTransaction.providerTxnRef = payment.providerTxnRef;
        existingTransaction.providerTransactionNo = payment.providerTransactionNo;
        existingTransaction.transactionType = "payment";
        existingTransaction.status = status;
        existingTransaction.amount = payment.amount;
        existingTransaction.currency = payment.currency;
        existingTransaction.rawPayloadJson = rawPayloadJson;
        existingTransaction.processedAt = processedAt;
        await existingTransaction.save({ transaction });
        return existingTransaction;
    }

    return PaymentTransaction.create(
        {
            paymentId: payment.paymentId,
            bookingId: booking.bookingId,
            provider,
            providerTxnRef: payment.providerTxnRef,
            providerTransactionNo: payment.providerTransactionNo,
            transactionType: "payment",
            status,
            amount: payment.amount,
            currency: payment.currency,
            rawPayloadJson,
            processedAt,
        },
        { transaction },
    );
};

/**
 * Giải thuật khởi tạo giao dịch thanh toán an toàn với khóa bi quan và tái sử dụng bất biến (Idempotent Payment Creation):
 * 1. Mở giao dịch DB và khóa bi quan bản ghi `Booking` (`SELECT ... FOR UPDATE` / `lock: true`) để chống hai yêu cầu
 *    tạo thanh toán chạy song song trên cùng một đơn đặt phòng.
 * 2. Kiểm tra quyền sở hữu của khách, đối soát tự động trạng thái hết hạn giữ chỗ và lấy số tiền tin cậy từ DB.
 * 3. Khóa và kiểm tra các bản ghi `Payment` hiện hữu của booking:
 *    - Nếu đã có giao dịch `"paid"`, trả về ngay kết quả hiện hữu (Idempotent).
 *    - Nếu đang có giao dịch `"pending"` cùng phương thức, còn hạn và khớp số tiền, tái sử dụng bản ghi đó để cấp lại URL cổng thanh toán.
 *    - Ngược lại, hủy hiệu lực toàn bộ các giao dịch `"pending"` cũ trước khi cấp mã `paymentId` mới, tạo URL ký số
 *      (VNPay/MoMo) và ghi đồng bộ cặp `Payment` + `PaymentTransaction`.
 * 4. Chỉ phát thông báo chờ thanh toán sau khi giao dịch DB đã commit thành công.
 */
export const createPayment = async (
    user: AuthenticatedUser,
    input: CreatePaymentInput,
    ipAddress?: string | null,
) => {
    const clientIp = getClientIp(ipAddress);

    const result = await sequelize.transaction(async (transaction) => {
        const notifications: NotificationSideEffect[] = [];
        const booking = await Booking.findOne({
            where: {
                bookingId: input.bookingId,
            },
            transaction,
            lock: true,
        });

        if (!booking) {
            throw new ApiError(404, "Booking not found");
        }

        assertBookingCanBePaidByUser(booking, user);

        if (booking.status === "pending_payment") {
            await expirePendingPaymentBookingInTransaction({
                booking,
                transaction,
            });

            if ((booking.status as BookingStatus) === "payment_expired") {
                throw new ApiError(409, "Phiên giữ chỗ đã hết hạn, vui lòng đặt lại.");
            }
        }

        assertBookingCanCreatePayment(booking);
        const bookingAmount = getTrustedBookingPaymentAmount(booking);

        const existingPayments = await Payment.findAll({
            where: {
                bookingId: booking.bookingId,
                status: {
                    [Op.in]: reusablePaymentStatuses,
                },
            },
            transaction,
            lock: true,
            order: [["createdAt", "DESC"], ["paymentId", "DESC"]],
        });

        const paidPayment = existingPayments.find((payment) => payment.status === "paid");
        if (paidPayment) {
            return {
                payment: serializePayment(paidPayment),
                notifications,
            };
        }

        if (booking.status === "paid") {
            throw new ApiError(409, "Booking has already been paid");
        }

        const pendingPayment = existingPayments.find(
            (payment) => payment.status === "pending" && payment.method === input.method,
        );

        if (
            pendingPayment &&
            isPendingPaymentReusable(pendingPayment) &&
            toNumber(pendingPayment.amount) === bookingAmount
        ) {
            let paymentUrl: string | null = null;
            let providerTxnRef = pendingPayment.providerTxnRef;
            let provider = pendingPayment.provider;

            if (pendingPayment.method === "vnpay") {
                const vnpayPayment = buildVnpayPaymentUrl({
                    booking,
                    payment: pendingPayment,
                    ipAddress: clientIp,
                    createdAt: pendingPayment.createdAt,
                });

                paymentUrl = vnpayPayment.paymentUrl;
                provider = "vnpay";
                providerTxnRef = vnpayPayment.txnRef;
            }

            if (pendingPayment.method === "momo") {
                const momoPayment = await buildMomoPaymentUrl({ booking, payment: pendingPayment });

                paymentUrl = momoPayment.paymentUrl;
                provider = "momo";
                providerTxnRef = momoPayment.txnRef;

                pendingPayment.providerPayload = {
                    createResponse: momoPayment.responsePayload,
                    requestId: momoPayment.requestId,
                };
            }

            if (provider && pendingPayment.provider !== provider) {
                pendingPayment.provider = provider;
            }

            if (providerTxnRef && pendingPayment.providerTxnRef !== providerTxnRef) {
                pendingPayment.providerTxnRef = providerTxnRef;
            }

            await pendingPayment.save({ transaction });

            await PaymentTransaction.update(
                {
                    provider: pendingPayment.provider,
                    providerTxnRef: pendingPayment.providerTxnRef,
                    rawPayloadJson: pendingPayment.providerPayload,
                },
                {
                    where: {
                        paymentId: pendingPayment.paymentId,
                        providerTxnRef: null,
                    },
                    transaction,
                },
            );

            enqueueNotification(
                notifications,
                "notifyPaymentPending",
                () => notifyPaymentPending(pendingPayment.paymentId),
                { paymentId: pendingPayment.paymentId, bookingId: pendingPayment.bookingId },
            );

            return {
                payment: serializePayment(pendingPayment, paymentUrl),
                notifications,
            };
        }

        for (const payment of existingPayments) {
            if (payment.status === "pending") {
                await expirePendingPayment(payment, transaction);
            }
        }

        const expiresAt = getBookingPaymentExpiresAt(booking);

        if (booking.status === "pending_payment" && !booking.lockedUntil) {
            booking.lockedUntil = expiresAt;
            await booking.save({ transaction });
        }

        const payment = new Payment({
            paymentId: await getNextSequence("payment", 890),
            bookingId: booking.bookingId,
            userId: booking.guestUserId,
            amount: bookingAmount,
            currency: booking.currency,
            method: input.method,
            status: "pending",
            provider: input.method === "vnpay" || input.method === "momo" ? input.method : null,
            providerTxnRef: null,
            providerTransactionNo: null,
            providerResponseCode: null,
            providerPayload: null,
            paidAt: null,
            failedAt: null,
            expiresAt,
            expiredAt: null,
        });

        let paymentUrl: string | null = null;

        if (input.method === "vnpay") {
            const vnpayPayment = buildVnpayPaymentUrl({ booking, payment, ipAddress: clientIp });
            payment.providerTxnRef = vnpayPayment.txnRef;
            paymentUrl = vnpayPayment.paymentUrl;
        }

        if (input.method === "momo") {
            const momoPayment = await buildMomoPaymentUrl({ booking, payment });

            payment.providerTxnRef = momoPayment.txnRef;
            payment.providerPayload = {
                createResponse: momoPayment.responsePayload,
                requestId: momoPayment.requestId,
            };
            paymentUrl = momoPayment.paymentUrl;
        }

        await payment.save({ transaction });

        await PaymentTransaction.create(
            {
                paymentId: payment.paymentId,
                bookingId: booking.bookingId,
                provider: payment.provider,
                providerTxnRef: payment.providerTxnRef,
                providerTransactionNo: payment.providerTransactionNo,
                transactionType: "payment",
                status: "pending",
                amount: payment.amount,
                currency: payment.currency,
                rawPayloadJson: payment.providerPayload,
                processedAt: null,
            },
            { transaction },
        );

        enqueueNotification(
            notifications,
            "notifyPaymentPending",
            () => notifyPaymentPending(payment.paymentId),
            { paymentId: payment.paymentId, bookingId: payment.bookingId },
        );

        return {
            payment: serializePayment(payment, paymentUrl),
            notifications,
        };
    });

    await runNotificationSideEffects(result.notifications);

    return result.payment;
};

/**
 * Truy vấn chi tiết một giao dịch thanh toán theo `paymentId` kèm kiểm tra phân quyền truy cập (`assertCanViewPayment`).
 */
export const getPaymentDetail = async (user: AuthenticatedUser, paymentId: number) => {
    const payment = await Payment.findOne({ paymentId });

    if (!payment) {
        throw new ApiError(404, "Payment not found");
    }

    const booking = await getPaymentBooking(payment);
    assertCanViewPayment(booking, user);

    return serializePayment(payment);
};

/**
 * Truy vấn phân trang danh sách lịch sử thanh toán của người dùng hiện tại, sắp xếp mới nhất trước.
 */
export const getMyPayments = async (user: AuthenticatedUser, query: ListPaymentsQuery) => {
    const page = query.page ?? 1;
    const limit = query.limit ?? 10;
    const filter: {
        userId: number;
        status?: PaymentStatus;
    } = {
        userId: Number(user.id),
    };

    if (query.status) {
        filter.status = query.status;
    }

    const [items, totalItems] = await Promise.all([
        Payment.find(filter)
            .sort({ createdAt: -1, paymentId: -1 })
            .skip((page - 1) * limit)
            .limit(limit),
        Payment.countDocuments(filter),
    ]);

    return {
        items: items.map((payment) => serializePayment(payment)),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

/**
 * Kiểm tra kết quả giao dịch VNPay thành công theo quy ước kép:
 * - Bắt buộc `vnp_ResponseCode === "00"` và `vnp_TransactionStatus` (nếu có mặt) cũng bằng `"00"`.
 */
const isSuccessfulVnpayPayload = (payload: VnpayPayload) =>
    payload.vnp_ResponseCode === "00" &&
    (payload.vnp_TransactionStatus === undefined || payload.vnp_TransactionStatus === "00");

/**
 * Tra cứu không khóa bản ghi `Payment` theo mã tham chiếu `vnp_TxnRef` phục vụ kiểm tra sơ bộ hoặc ghi audit lỗi.
 */
const findPaymentByVnpayPayload = async (payload: VnpayPayload) => {
    const txnRef = payload.vnp_TxnRef;

    if (!txnRef) {
        return null;
    }

    return Payment.findOne({ providerTxnRef: txnRef });
};

/**
 * Giải thuật quyết toán giao dịch VNPay bảo đảm bất biến Idempotency và chống Race Condition:
 * 1. Xác thực chữ ký `HMAC-SHA512` thời gian hằng định (`verifyVnpayPayload`) trước khi chạm cơ sở dữ liệu.
 * 2. Mở giao dịch DB và khóa bi quan mức dòng (`SELECT ... FOR UPDATE` / `lock: true`) theo thứ tự cố định
 *    `Payment` -> `Booking` -> `PaymentTransaction` để tuần tự hóa đồng thời Return URL và IPN Webhook, tránh Deadlock.
 * 3. Đối khớp chính xác số tiền thực thu bằng số nguyên `BigInt` (`isVnpayAmountMatching`) và kiểm tra tính sở hữu
 *    của `providerTransactionNo` (`assertProviderTransactionBelongsToPayment`).
 * 4. Đảm bảo bất biến Idempotency:
 *    - Chặn hạ cấp trạng thái nếu `payment.status === "paid"` nhưng sau đó nhận callback thất bại trễ.
 *    - Thoát sớm không tác dụng phụ nếu `isCallbackAlreadyApplied` xác nhận callback trùng lặp đã được áp dụng.
 * 5. Nếu thanh toán thành công: phân nhánh giữa thanh toán muộn sau khi hết giữ chỗ (`markLateSuccessfulPaymentForManualReview`
 *    để tạo hoàn tiền tự động) và thanh toán đúng hạn (chuyển `Booking` sang `"paid"`, tiêu thụ coupon một lần,
 *    chỉ bật `shouldSendConfirmationEmail` khi `previousPaymentStatus !== "paid"`).
 * 6. Chỉ thực thi hàng đợi thông báo sau khi giao dịch DB commit hoàn tất, đảm bảo thông báo và xác nhận đơn chỉ phát đúng một lần.
 */
const updatePaymentFromVnpayPayload = async (payload: VnpayPayload) => {
    if (!verifyVnpayPayload(payload)) {
        throw new ApiError(400, "Invalid VNPay signature");
    }

    const result = await sequelize.transaction(async (transaction) => {
        const notifications: NotificationSideEffect[] = [];
        const payment = await Payment.findOne({
            where: {
                providerTxnRef: payload.vnp_TxnRef,
            },
            transaction,
            lock: true,
        });

        if (!payment) {
            throw new ApiError(404, "Payment not found");
        }

        const booking = await Booking.findOne({
            where: {
                bookingId: payment.bookingId,
            },
            transaction,
            lock: true,
        });

        if (!booking) {
            throw new ApiError(404, "Booking not found");
        }

        if (!isVnpayAmountMatching(payload, payment)) {
            throw new ApiError(400, "Invalid VNPay amount");
        }

        const callbackSucceeded = isSuccessfulVnpayPayload(payload);
        const previousPaymentStatus = payment.status;
        const rawPayload = sanitizeVnpayPayloadForStorage(payload);
        const providerTransactionNo = payload.vnp_TransactionNo ?? payment.providerTransactionNo;
        const failedPaymentStatus = callbackSucceeded ? null : getFailedVnpayStatus(payload);
        const expectedTransactionStatus: PaymentTransactionStatus = callbackSucceeded
            ? "succeeded"
            : toPaymentTransactionStatus(failedPaymentStatus!);
        const existingTransaction = await findPaymentTransactionForCallback({
            payment,
            provider: "vnpay",
            providerTransactionNo,
            transaction,
        });

        assertProviderTransactionBelongsToPayment({
            existingTransaction,
            payment,
            providerTransactionNo,
        });

        if (payment.status === "paid" && !callbackSucceeded) {
            return {
                payment: serializePayment(payment),
                shouldSendConfirmationEmail: false,
                paymentId: payment.paymentId,
                bookingId: payment.bookingId,
                notifications,
            };
        }

        if (
            isCallbackAlreadyApplied({
                paymentStatus: payment.status,
                existingTransaction,
                expectedTransactionStatus,
            })
        ) {
            return {
                payment: serializePayment(payment),
                shouldSendConfirmationEmail: false,
                paymentId: payment.paymentId,
                bookingId: payment.bookingId,
                notifications,
            };
        }

        let shouldSendConfirmationEmail = false;
        let bookingStatusChanged = false;

        payment.provider = "vnpay";
        payment.providerPayload = rawPayload;
        payment.providerTransactionNo = providerTransactionNo;
        payment.providerResponseCode = payload.vnp_ResponseCode ?? payment.providerResponseCode;

        if (callbackSucceeded) {
            const paidAt = payment.paidAt ?? parseVnpayPayDate(payload.vnp_PayDate) ?? new Date();

            if (isLateSuccessfulPaymentForBooking(booking, payment, paidAt)) {
                bookingStatusChanged = await markLateSuccessfulPaymentForManualReview({
                    booking,
                    payment,
                    paidAt,
                    previousPaymentStatus,
                    transaction,
                    provider: "vnpay",
                    notifications,
                });
            } else {
                if (payment.status !== "paid") {
                    payment.status = "paid";
                    payment.paidAt = paidAt;
                    payment.failedAt = null;
                }

                if (booking.status === "pending_payment") {
                    await transitionBookingStatus({
                        booking,
                        toStatus: "paid",
                        actor: "system",
                        changedByUserId: null,
                        reason: "payment_success",
                        metadata: {
                            paymentId: payment.paymentId,
                            provider: "vnpay",
                        },
                        transaction,
                        context: {
                            hasSuccessfulPayment: true,
                            paymentPaidAt: paidAt,
                            paymentExpiresAt: booking.lockedUntil,
                        },
                        mutate: (currentBooking) => {
                            currentBooking.lockedUntil = null;
                            currentBooking.paidAt = paidAt;
                        },
                    });
                    bookingStatusChanged = true;
                }

                await redeemBookingCouponIfNeeded(booking, transaction);
                shouldSendConfirmationEmail = previousPaymentStatus !== "paid";
            }
        } else if (payment.status !== "paid") {
            payment.status = failedPaymentStatus!;
            const failedAt = new Date();
            payment.failedAt = failedAt;

            if (payment.status === "expired") {
                payment.expiredAt = payment.expiredAt ?? failedAt;
            }

            if (["failed", "cancelled", "expired"].includes(payment.status)) {
                bookingStatusChanged = await expireBookingAfterFailedPayment(
                    booking,
                    transaction,
                    cancellationReasons.paymentExpired,
                    notifications,
                );
            }
        }

        await payment.save({ transaction });
        if (!bookingStatusChanged) {
            await booking.save({ transaction });
        }
        await upsertPaymentTransactionFromCallback({
            existingTransaction,
            payment,
            booking,
            provider: "vnpay",
            status: toPaymentTransactionStatus(payment.status),
            rawPayloadJson: rawPayload,
            transaction,
        });

        if (shouldSendConfirmationEmail) {
            enqueueNotification(
                notifications,
                "notifyPaymentSuccess",
                () => notifyPaymentSuccess(payment.paymentId),
                { paymentId: payment.paymentId, bookingId: payment.bookingId },
            );
        }

        return {
            payment: serializePayment(payment),
            shouldSendConfirmationEmail,
            paymentId: payment.paymentId,
            bookingId: payment.bookingId,
            notifications,
        };
    });

    await runNotificationSideEffects(result.notifications);

    return result.payment;
};

/**
 * Trích xuất siêu dữ liệu đối soát an toàn của callback VNPay phục vụ ghi nhật ký kiểm toán (`audit_logs`).
 */
const buildVnpayAuditMetadata = (payload: VnpayPayload, outcome: string) => ({
    provider: "vnpay",
    outcome,
    txnRef: payload.vnp_TxnRef ?? null,
    responseCode: payload.vnp_ResponseCode ?? null,
    transactionStatus: payload.vnp_TransactionStatus ?? null,
    providerTransactionNo: payload.vnp_TransactionNo ?? null,
    amount: payload.vnp_Amount ?? null,
});

/**
 * Ghi nhật ký kiểm toán cho sự kiện Return URL hoặc Webhook IPN của VNPay kèm địa chỉ IP và User-Agent nguồn gọi.
 */
const writePaymentCallbackAudit = async (
    action: string,
    payload: VnpayPayload,
    outcome: string,
    context: PaymentCallbackContext,
    targetId?: number | null,
) => {
    await writeAuditLog({
        action,
        targetType: targetId ? "payment" : "payment_callback",
        targetId: targetId ?? null,
        metadata: buildVnpayAuditMetadata(payload, outcome),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
    });
};

/**
 * Phân loại mã kết quả thất bại chuẩn hóa từ ngoại lệ phát sinh trong quá trình xử lý callback VNPay.
 */
const getVnpayCallbackFailureOutcome = (error: unknown) => {
    if (!(error instanceof ApiError)) {
        return "error";
    }

    if (error.statusCode === 400 && /signature/i.test(error.message)) {
        return "invalid_signature";
    }

    if (error.statusCode === 400 && /amount/i.test(error.message)) {
        return "invalid_amount";
    }

    if (error.statusCode === 404) {
        return "order_not_found";
    }

    return `http_${error.statusCode}`;
};

/**
 * Giải thuật xử lý luồng chuyển hướng trình duyệt Return URL từ VNPay:
 * - Chuẩn hóa tham số `vnp_*`, ủy quyền quyết toán bất biến qua `updatePaymentFromVnpayPayload`
 *   (an toàn khi đua đồng thời với IPN Webhook) và luôn ghi nhật ký kiểm toán cho cả nhánh thành công lẫn thất bại.
 */
export const processVnpayReturn = async (
    input: Record<string, unknown>,
    context: PaymentCallbackContext = {},
) => {
    const payload = normalizeVnpayPayload(input);

    try {
        const result = await updatePaymentFromVnpayPayload(payload);

        await writePaymentCallbackAudit(
            "payment.callback.vnpay.return",
            payload,
            result.paymentStatus,
            context,
            result.paymentId,
        );

        return result;
    } catch (error) {
        const payment = await findPaymentByVnpayPayload(payload);

        await writePaymentCallbackAudit(
            "payment.callback.vnpay.return",
            payload,
            getVnpayCallbackFailureOutcome(error),
            context,
            payment?.paymentId ?? null,
        );

        throw error;
    }
};

/**
 * Giải thuật xử lý thông báo tức thời máy chủ-máy chủ (IPN Webhook) từ VNPay:
 * - Kiểm tra tuần tự chữ ký `HMAC-SHA512` (`RspCode: "97"`), sự tồn tại của đơn thanh toán (`RspCode: "01"`)
 *   và đối khớp số tiền nguyên VND (`RspCode: "04"`) theo đúng giao thức phản hồi chuẩn của VNPay.
 * - Thực thi quyết toán bất biến Idempotent qua `updatePaymentFromVnpayPayload` và trả `RspCode: "00"`
 *   kể cả khi VNPay gửi lại IPN trùng lặp, ngăn cổng thanh toán retry vô hạn.
 */
export const processVnpayWebhook = async (
    input: Record<string, unknown>,
    context: PaymentCallbackContext = {},
): Promise<VnpayWebhookResult> => {
    const payload = normalizeVnpayPayload(input);

    if (!verifyVnpayPayload(payload)) {
        await writePaymentCallbackAudit("payment.callback.vnpay.webhook", payload, "invalid_signature", context);

        return {
            RspCode: "97",
            Message: "Invalid signature",
        };
    }

    const payment = await findPaymentByVnpayPayload(payload);

    if (!payment) {
        await writePaymentCallbackAudit("payment.callback.vnpay.webhook", payload, "order_not_found", context);

        return {
            RspCode: "01",
            Message: "Order not found",
        };
    }

    if (!isVnpayAmountMatching(payload, payment)) {
        await writePaymentCallbackAudit(
            "payment.callback.vnpay.webhook",
            payload,
            "invalid_amount",
            context,
            payment.paymentId,
        );

        return {
            RspCode: "04",
            Message: "Invalid amount",
        };
    }

    await updatePaymentFromVnpayPayload(payload);
    await writePaymentCallbackAudit(
        "payment.callback.vnpay.webhook",
        payload,
        "confirmed",
        context,
        payment.paymentId,
    );

    return {
        RspCode: "00",
        Message: "Confirm Success",
    };
};

/**
 * Lọc danh sách trắng các trường đối soát của callback MoMo để lưu trữ JSON vào DB mà không lưu chữ ký thô.
 */
const sanitizeMomoPayloadForStorage = (payload: MomoPayload) => ({
    partnerCode: payload.partnerCode ?? null,
    orderId: payload.orderId ?? null,
    requestId: payload.requestId ?? null,
    amount: payload.amount ?? null,
    resultCode: payload.resultCode ?? null,
    message: payload.message ?? null,
    orderInfo: payload.orderInfo ?? null,
    orderType: payload.orderType ?? null,
    payType: payload.payType ?? null,
    transId: payload.transId ?? null,
    responseTime: payload.responseTime ?? null,
    extraData: payload.extraData ?? null,
});

/**
 * Kiểm tra giao dịch MoMo thành công dựa trên mã kết quả `resultCode === "0"`.
 */
const isSuccessfulMomoPayload = (payload: MomoPayload) => payload.resultCode === "0";

/**
 * Giải thuật ánh xạ mã `resultCode` khác 0 của MoMo sang trạng thái `PaymentStatus`:
 * - `"1006"` -> người dùng từ chối xác nhận thanh toán (`"cancelled"`).
 * - `"7000"` / `"7002"` -> giao dịch đang được xử lý bất đồng bộ (`"pending"`).
 * - Các mã lỗi còn lại -> thất bại (`"failed"`).
 */
const getFailedMomoStatus = (payload: MomoPayload): PaymentStatus => {
    if (payload.resultCode === "1006") {
        return "cancelled";
    }

    if (payload.resultCode === "7000" || payload.resultCode === "7002") {
        return "pending";
    }

    return "failed";
};

/**
 * Tra cứu không khóa bản ghi `Payment` theo mã tham chiếu `orderId` từ callback MoMo.
 */
const findPaymentByMomoPayload = async (payload: MomoPayload) => {
    const orderId = payload.orderId;

    if (!orderId) {
        return null;
    }

    return Payment.findOne({ providerTxnRef: orderId });
};

/**
 * Giải thuật quyết toán giao dịch MoMo bảo đảm bất biến Idempotency và chống Race Condition:
 * 1. Xác thực chữ ký `HMAC-SHA256` thời gian hằng định (`verifyMomoPayload`).
 * 2. Mở giao dịch DB và khóa bi quan mức dòng (`SELECT ... FOR UPDATE` / `lock: true`) theo thứ tự cố định
 *    `Payment` -> `Booking` -> `PaymentTransaction` nhằm tuần tự hóa các lời gọi Return URL và IPN chồng lấn.
 * 3. Kiểm tra khớp tuyệt đối số tiền nguyên dương VND (`isMomoAmountMatching`) và ràng buộc quyền sở hữu mã `transId`.
 * 4. Bảo toàn bất biến Idempotency: không cho phép ghi đè giao dịch đã `"paid"` bằng callback lỗi đến muộn,
 *    và trả về ngay kết quả hiện hữu nếu `isCallbackAlreadyApplied` phát hiện callback trùng lặp.
 * 5. Xử lý phân nhánh thanh toán đúng hạn (chuyển trạng thái `Booking` sang `"paid"`, tiêu thụ coupon một lần,
 *    đánh dấu gửi thông báo đúng một lần) hoặc thanh toán muộn sau khi hết hạn giữ chỗ (tạo yêu cầu hoàn tiền tự động).
 * 6. Chạy hàng đợi thông báo sau khi commit giao dịch DB thành công.
 */
const updatePaymentFromMomoPayload = async (payload: MomoPayload) => {
    if (!verifyMomoPayload(payload)) {
        throw new ApiError(400, "Invalid MoMo signature");
    }

    const result = await sequelize.transaction(async (transaction) => {
        const notifications: NotificationSideEffect[] = [];
        const payment = await Payment.findOne({
            where: {
                providerTxnRef: payload.orderId,
            },
            transaction,
            lock: true,
        });

        if (!payment) {
            throw new ApiError(404, "Payment not found");
        }

        const booking = await Booking.findOne({
            where: {
                bookingId: payment.bookingId,
            },
            transaction,
            lock: true,
        });

        if (!booking) {
            throw new ApiError(404, "Booking not found");
        }

        if (!isMomoAmountMatching(payload, payment)) {
            throw new ApiError(400, "Invalid MoMo amount");
        }

        const callbackSucceeded = isSuccessfulMomoPayload(payload);
        const previousPaymentStatus = payment.status;
        const rawPayload = sanitizeMomoPayloadForStorage(payload);
        const providerTransactionNo = payload.transId ?? payment.providerTransactionNo;
        const failedPaymentStatus = callbackSucceeded ? null : getFailedMomoStatus(payload);
        const expectedTransactionStatus: PaymentTransactionStatus = callbackSucceeded
            ? "succeeded"
            : toPaymentTransactionStatus(failedPaymentStatus!);
        const existingTransaction = await findPaymentTransactionForCallback({
            payment,
            provider: "momo",
            providerTransactionNo,
            transaction,
        });

        assertProviderTransactionBelongsToPayment({
            existingTransaction,
            payment,
            providerTransactionNo,
        });

        if (payment.status === "paid" && !callbackSucceeded) {
            return {
                payment: serializePayment(payment),
                shouldSendConfirmationEmail: false,
                paymentId: payment.paymentId,
                bookingId: payment.bookingId,
                notifications,
            };
        }

        if (
            isCallbackAlreadyApplied({
                paymentStatus: payment.status,
                existingTransaction,
                expectedTransactionStatus,
            })
        ) {
            return {
                payment: serializePayment(payment),
                shouldSendConfirmationEmail: false,
                paymentId: payment.paymentId,
                bookingId: payment.bookingId,
                notifications,
            };
        }

        let shouldSendConfirmationEmail = false;
        let bookingStatusChanged = false;

        payment.provider = "momo";
        payment.providerPayload = {
            ...(payment.providerPayload ?? {}),
            callback: rawPayload,
        };
        payment.providerTransactionNo = providerTransactionNo;
        payment.providerResponseCode = payload.resultCode ?? payment.providerResponseCode;

        if (callbackSucceeded) {
            const paidAt = payment.paidAt ?? parseMomoResponseTime(payload.responseTime) ?? new Date();

            if (isLateSuccessfulPaymentForBooking(booking, payment, paidAt)) {
                bookingStatusChanged = await markLateSuccessfulPaymentForManualReview({
                    booking,
                    payment,
                    paidAt,
                    previousPaymentStatus,
                    transaction,
                    provider: "momo",
                    notifications,
                });
            } else {
                if (payment.status !== "paid") {
                    payment.status = "paid";
                    payment.paidAt = paidAt;
                    payment.failedAt = null;
                }

                if (booking.status === "pending_payment") {
                    await transitionBookingStatus({
                        booking,
                        toStatus: "paid",
                        actor: "system",
                        changedByUserId: null,
                        reason: "payment_success",
                        metadata: {
                            paymentId: payment.paymentId,
                            provider: "momo",
                        },
                        transaction,
                        context: {
                            hasSuccessfulPayment: true,
                            paymentPaidAt: paidAt,
                            paymentExpiresAt: booking.lockedUntil,
                        },
                        mutate: (currentBooking) => {
                            currentBooking.lockedUntil = null;
                            currentBooking.paidAt = paidAt;
                        },
                    });
                    bookingStatusChanged = true;
                }

                await redeemBookingCouponIfNeeded(booking, transaction);
                shouldSendConfirmationEmail = previousPaymentStatus !== "paid";
            }
        } else if (payment.status !== "paid") {
            payment.status = failedPaymentStatus!;

            if (payment.status !== "pending") {
                const failedAt = new Date();
                payment.failedAt = failedAt;

                if (payment.status === "expired") {
                    payment.expiredAt = payment.expiredAt ?? failedAt;
                }
            }

            if (["failed", "cancelled", "expired"].includes(payment.status)) {
                bookingStatusChanged = await expireBookingAfterFailedPayment(
                    booking,
                    transaction,
                    cancellationReasons.paymentExpired,
                    notifications,
                );
            }
        }

        await payment.save({ transaction });
        if (!bookingStatusChanged) {
            await booking.save({ transaction });
        }

        await upsertPaymentTransactionFromCallback({
            existingTransaction,
            payment,
            booking,
            provider: "momo",
            status: toPaymentTransactionStatus(payment.status),
            rawPayloadJson: rawPayload,
            transaction,
        });

        if (shouldSendConfirmationEmail) {
            enqueueNotification(
                notifications,
                "notifyPaymentSuccess",
                () => notifyPaymentSuccess(payment.paymentId),
                { paymentId: payment.paymentId, bookingId: payment.bookingId },
            );
        }

        return {
            payment: serializePayment(payment),
            shouldSendConfirmationEmail,
            paymentId: payment.paymentId,
            bookingId: payment.bookingId,
            notifications,
        };
    });

    await runNotificationSideEffects(result.notifications);

    return result.payment;
};

/**
 * Đóng gói siêu dữ liệu đối soát callback MoMo phục vụ ghi nhận nhật ký kiểm toán (`audit_logs`).
 */
const buildMomoAuditMetadata = (payload: MomoPayload, outcome: string) => ({
    provider: "momo",
    outcome,
    orderId: payload.orderId ?? null,
    requestId: payload.requestId ?? null,
    resultCode: payload.resultCode ?? null,
    message: payload.message ?? null,
    transId: payload.transId ?? null,
    amount: payload.amount ?? null,
});

/**
 * Ghi nhật ký kiểm toán cho sự kiện Return URL hoặc IPN Webhook từ cổng thanh toán MoMo.
 */
const writeMomoPaymentCallbackAudit = async (
    action: string,
    payload: MomoPayload,
    outcome: string,
    context: PaymentCallbackContext,
    targetId?: number | null,
) => {
    await writeAuditLog({
        action,
        targetType: targetId ? "payment" : "payment_callback",
        targetId: targetId ?? null,
        metadata: buildMomoAuditMetadata(payload, outcome),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
    });
};

/**
 * Ánh xạ ngoại lệ xử lý callback MoMo sang nhãn kết quả chuẩn hóa phục vụ kiểm toán.
 */
const getMomoCallbackFailureOutcome = (error: unknown) => {
    if (!(error instanceof ApiError)) {
        return "error";
    }

    if (error.statusCode === 400 && /signature/i.test(error.message)) {
        return "invalid_signature";
    }

    if (error.statusCode === 400 && /amount/i.test(error.message)) {
        return "invalid_amount";
    }

    if (error.statusCode === 404) {
        return "order_not_found";
    }

    return `http_${error.statusCode}`;
};

/**
 * Giải thuật xử lý luồng chuyển hướng trình duyệt Return URL từ MoMo:
 * - Chuẩn hóa payload, gọi quyết toán bất biến `updatePaymentFromMomoPayload` và ghi nhận đầy đủ nhật ký kiểm toán.
 */
export const processMomoReturn = async (
    input: Record<string, unknown>,
    context: PaymentCallbackContext = {},
) => {
    const payload = normalizeMomoPayload(input);

    try {
        const result = await updatePaymentFromMomoPayload(payload);

        await writeMomoPaymentCallbackAudit(
            "payment.callback.momo.return",
            payload,
            result.paymentStatus,
            context,
            result.paymentId,
        );

        return result;
    } catch (error) {
        const payment = await findPaymentByMomoPayload(payload);

        await writeMomoPaymentCallbackAudit(
            "payment.callback.momo.return",
            payload,
            getMomoCallbackFailureOutcome(error),
            context,
            payment?.paymentId ?? null,
        );

        throw error;
    }
};

/**
 * Giải thuật xử lý thông báo tức thời máy chủ-máy chủ (IPN Webhook) từ MoMo:
 * - Xác thực chữ ký `HMAC-SHA256` (`resultCode: 97`), kiểm tra đơn hàng tồn tại (`resultCode: 1`) và đối khớp
 *   số tiền nguyên VND (`resultCode: 4`) trước khi thực thi quyết toán bất biến qua `updatePaymentFromMomoPayload`.
 * - Luôn phản hồi `resultCode: 0` sau khi xác nhận thành công (kể cả khi IPN gửi lặp lại) để hoàn tất chu trình đối soát với MoMo.
 */
export const processMomoWebhook = async (
    input: Record<string, unknown>,
    context: PaymentCallbackContext = {},
): Promise<MomoWebhookResult> => {
    const payload = normalizeMomoPayload(input);

    if (!verifyMomoPayload(payload)) {
        await writeMomoPaymentCallbackAudit("payment.callback.momo.webhook", payload, "invalid_signature", context);

        return {
            resultCode: 97,
            message: "Invalid signature",
        };
    }

    const payment = await findPaymentByMomoPayload(payload);

    if (!payment) {
        await writeMomoPaymentCallbackAudit("payment.callback.momo.webhook", payload, "order_not_found", context);

        return {
            resultCode: 1,
            message: "Order not found",
        };
    }

    if (!isMomoAmountMatching(payload, payment)) {
        await writeMomoPaymentCallbackAudit(
            "payment.callback.momo.webhook",
            payload,
            "invalid_amount",
            context,
            payment.paymentId,
        );

        return {
            resultCode: 4,
            message: "Invalid amount",
        };
    }

    await updatePaymentFromMomoPayload(payload);

    await writeMomoPaymentCallbackAudit(
        "payment.callback.momo.webhook",
        payload,
        "confirmed",
        context,
        payment.paymentId,
    );

    return {
        resultCode: 0,
        message: "Success",
    };
};
