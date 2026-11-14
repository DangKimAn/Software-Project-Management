// CONFLICT-RESOLVED: Chuyển tiến trình quét hết hạn giữ chỗ từ `src/services/booking-expiration.service.ts` về `src/modules/bookings/`.
import { Op, Transaction } from "sequelize";
import { sequelize } from "../../config/database";
import { getEnv } from "../../config/env";
import Booking, { type BookingDocument } from "../../models/booking";
import Payment, { type PaymentDocument } from "../../models/payment";
import Refund from "../../models/refund";
import { releaseBookingDateLocksForBooking } from "./booking-date-lock.service";
import { logger } from "../../config/logger";
import {
    cancellationReasons,
} from "./booking-display-status";
import { transitionBookingStatus } from "./booking-state-machine";
import {
    notifyPaymentExpired,
    notifyPaymentSuccess,
    notifyRefundCreated,
} from "../notifications/notification.service";

let sweepTimer: NodeJS.Timeout | null = null;
let sweepRunning = false;

/**
 * Giải thuật kiểm tra bất biến thời hạn thanh toán so với hạn giữ chỗ (`paidAt <= lockedUntil`):
 * - Xác định giao dịch thanh toán được ghi nhận trước hoặc đúng thời điểm khóa tạm thời hết hiệu lực.
 * - Trường hợp bản ghi thiếu một trong hai mốc thời gian thì mặc định coi là hợp lệ nhằm bảo vệ quyền lợi khách đã trả tiền.
 */
const isPaymentPaidBeforeHoldExpired = (params: {
    paidAt: Date | null;
    lockedUntil: Date | null;
}) => {
    if (!params.lockedUntil || !params.paidAt) {
        return true;
    }

    return params.paidAt.getTime() <= params.lockedUntil.getTime();
};

/**
 * Giải thuật khởi tạo yêu cầu hoàn tiền lũy đẳng (idempotent) cho khoản thanh toán đến muộn sau khi giữ chỗ đã hết hạn:
 * - Sử dụng khóa bi quan `SELECT ... FOR UPDATE` trên bảng `refunds` theo bộ khóa `(bookingId, paymentId, reason)` trong cùng `transaction`.
 * - Nếu chưa tồn tại phiếu hoàn tiền tương ứng thì tạo mới bản ghi `Refund` ở trạng thái `pending` với toàn bộ số tiền đã thu.
 */
const createLatePaymentRefundIfMissing = async (params: {
    booking: BookingDocument;
    payment: PaymentDocument;
    transaction: Transaction;
}) => {
    const existingRefund = await Refund.findOne({
        where: {
            bookingId: params.booking.bookingId,
            paymentId: params.payment.paymentId,
            reason: "late_payment_after_booking_expired",
        },
        transaction: params.transaction,
        lock: params.transaction.LOCK.UPDATE,
    });

    if (existingRefund) {
        return null;
    }

    return Refund.create(
        {
            bookingId: params.booking.bookingId,
            paymentId: params.payment.paymentId,
            requestedByUserId: params.booking.guestUserId,
            amount: params.payment.amount,
            currency: params.payment.currency,
            status: "pending",
            reason: "late_payment_after_booking_expired",
            providerRef: null,
            processedByUserId: null,
            processedAt: null,
        },
        { transaction: params.transaction },
    );
};

/**
 * Giải thuật thu hồi giữ chỗ đơn đặt phòng quá hạn thanh toán trong giao dịch ACID:
 * 1. Kiểm tra bất biến đầu vào: chỉ xử lý đơn ở trạng thái `pending_payment` đã chạm hoặc vượt mốc hết hạn (`paymentExpiresAt <= now`).
 * 2. Khóa bi quan `FOR UPDATE` bản ghi thanh toán `paid` (nếu có) để phân giải xung đột đồng thời với webhook cổng thanh toán:
 *    - Nếu khách đã thanh toán kịp hạn (`paidAt <= paymentExpiresAt`): chuyển trạng thái đơn sang `paid` qua FSM, xóa `lockedUntil` và thông báo thành công.
 *    - Nếu khách thanh toán trễ hạn (`paidAt > paymentExpiresAt`): lập phiếu hoàn tiền tự động (`late_payment_after_booking_expired`) và vẫn thu hồi đơn để tránh xung đột lịch.
 * 3. Hủy toàn bộ phiên thanh toán đang chờ (`pending -> expired`), nhả toàn bộ khóa ngày trong `booking_date_locks`, chuyển đơn sang `payment_expired`
 *    (qua đó tự động hoàn trả lượt giữ tạm thời hạn mức coupon của đơn `pending_payment`) và phát thông báo hết hạn trong cùng một giao dịch ACID.
 */
export async function expirePendingPaymentBookingInTransaction(params: {
    booking: BookingDocument;
    transaction: Transaction;
    now?: Date;
}): Promise<boolean> {
    const { booking, transaction } = params;
    const now = params.now ?? new Date();

    if (booking.status !== "pending_payment") {
        return false;
    }

    const paymentExpiresAt = booking.lockedUntil ?? now;

    if (!paymentExpiresAt || paymentExpiresAt.getTime() > now.getTime()) {
        return false;
    }

    const paidPayment = await Payment.findOne({
        where: {
            bookingId: booking.bookingId,
            status: "paid",
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (
        paidPayment &&
        (!booking.lockedUntil ||
            isPaymentPaidBeforeHoldExpired({
                paidAt: paidPayment.paidAt,
                lockedUntil: paymentExpiresAt,
            }))
    ) {
        await transitionBookingStatus({
            booking,
            toStatus: "paid",
            actor: "system",
            changedByUserId: null,
            reason: "payment_paid_before_expiration_sweep",
            metadata: {
                paymentId: paidPayment.paymentId,
            },
            transaction,
            context: {
                hasSuccessfulPayment: true,
                paymentPaidAt: paidPayment.paidAt,
                paymentExpiresAt,
            },
            mutate: (currentBooking) => {
                currentBooking.lockedUntil = null;
                currentBooking.paidAt = paidPayment.paidAt ?? now;
            },
        });
        await notifyPaymentSuccess(paidPayment.paymentId, transaction);

        return true;
    }

    if (paidPayment) {
        const refund = await createLatePaymentRefundIfMissing({
            booking,
            payment: paidPayment,
            transaction,
        });

        if (refund) {
            await notifyRefundCreated(refund.refundId, transaction);
        }

        logger.warn("Late paid payment found after booking hold expired; booking moved to payment_expired for manual review", {
            bookingId: booking.bookingId,
            paymentId: paidPayment.paymentId,
            paidAt: paidPayment.paidAt,
            lockedUntil: paymentExpiresAt,
        });
    }

    await Payment.update(
        {
            status: "expired",
            expiredAt: now,
            failedAt: now,
        },
        {
            where: {
                bookingId: booking.bookingId,
                status: "pending",
            },
            transaction,
        },
    );

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
        metadata: paidPayment
            ? {
                paymentId: paidPayment.paymentId,
                latePaidAt: paidPayment.paidAt?.toISOString() ?? null,
            }
            : null,
        transaction,
        context: {
            paymentExpiresAt,
            now,
        },
        mutate: (currentBooking) => {
            currentBooking.cancellationReason = cancellationReasons.paymentExpired;
            currentBooking.cancelledByUserId = null;
            currentBooking.cancelledAt = null;
            currentBooking.lockedUntil = null;
        },
    });

    await notifyPaymentExpired(booking.bookingId, transaction);

    return true;
}

/**
 * Giải thuật thu hồi giữ chỗ cho một đơn đặt phòng đơn lẻ theo khóa bi quan (`SELECT ... FOR UPDATE`):
 * - Khởi tạo giao dịch cơ sở dữ liệu độc lập và khóa dòng `Booking` theo `bookingId` để tuần tự hóa với các luồng thanh toán hoặc hủy đơn đồng thời,
 *   sau đó ủy quyền xử lý nguyên tử cho `expirePendingPaymentBookingInTransaction`.
 */
export async function expirePendingPaymentBooking(bookingId: number): Promise<boolean> {
    return sequelize.transaction(async (transaction) => {
        const now = new Date();

        const booking = await Booking.findOne({
            where: {
                bookingId,
            },
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!booking) {
            return false;
        }

        return expirePendingPaymentBookingInTransaction({
            booking,
            transaction,
            now,
        });
    });
}

/**
 * Giải thuật quét và thu hồi hàng loạt các đơn đặt phòng quá hạn thanh toán theo lô (`limit`):
 * 1. Truy vấn danh sách `bookingId` ở trạng thái `pending_payment` có `lockedUntil <= now`, hoặc thiếu `lockedUntil` nhưng đã quá hạn tính từ `createdAt`,
 *    sắp xếp ưu tiên đơn hết hạn sớm nhất (`lockedUntil ASC, createdAt ASC`).
 * 2. Thực thi thu hồi từng đơn trong giao dịch tách biệt kèm bẫy lỗi độc lập (fault isolation), đảm bảo sự cố ở một bản ghi không làm hỏng toàn bộ lô quét.
 */
export async function expirePendingPaymentBookings(limit = 100): Promise<number> {
    const now = new Date();
    const createdAtCutoff = new Date(now.getTime() - getEnv().paymentHoldMinutes * 60 * 1000);

    const bookings = await Booking.findAll({
        where: {
            status: "pending_payment",
            [Op.or]: [
                {
                    lockedUntil: {
                        [Op.lte]: now,
                    },
                },
                {
                    lockedUntil: {
                        [Op.is]: null,
                    },
                    createdAt: {
                        [Op.lte]: createdAtCutoff,
                    },
                },
            ],
        },
        attributes: ["bookingId"],
        limit,
        order: [["lockedUntil", "ASC"], ["createdAt", "ASC"]],
    });

    let expiredCount = 0;

    for (const booking of bookings) {
        try {
            const changed = await expirePendingPaymentBooking(booking.bookingId);
            if (changed) {
                expiredCount += 1;
            }
        } catch (error) {
            logger.error("Failed to expire pending payment booking", error, {
                bookingId: booking.bookingId,
            });
        }
    }

    return expiredCount;
}

/**
 * Giải thuật khởi chạy tiến trình nền quét thu hồi giữ chỗ định kỳ chống chồng lấn (`non-reentrant interval`):
 * - Sử dụng biến khóa trạng thái `sweepRunning` để ngăn hai chu kỳ quét chạy song song khi tải cơ sở dữ liệu cao.
 * - Gọi `sweepTimer.unref()` để bộ định thời không giữ tiến trình Node.js sống khi ứng dụng thực hiện đóng kết nối (graceful shutdown).
 */
export function startPaymentExpirationSweep(): void {
    if (sweepTimer) {
        return;
    }

    const env = getEnv();
    const intervalMs = env.paymentExpirationSweepIntervalSeconds * 1000;

    sweepTimer = setInterval(() => {
        if (sweepRunning) {
            return;
        }

        sweepRunning = true;

        expirePendingPaymentBookings()
            .catch((error) => {
                logger.error("Payment expiration sweep failed", error);
            })
            .finally(() => {
                sweepRunning = false;
            });
    }, intervalMs);

    sweepTimer.unref?.();

    logger.info("Payment expiration sweep started", {
        intervalSeconds: env.paymentExpirationSweepIntervalSeconds,
    });
}

/**
 * Giải thuật hủy đăng ký bộ định thời quét thu hồi giữ chỗ và khôi phục trạng thái cờ điều phối về mặc định an toàn.
 */
export function stopPaymentExpirationSweep(): void {
    if (!sweepTimer) {
        return;
    }

    clearInterval(sweepTimer);
    sweepTimer = null;
    sweepRunning = false;

    logger.info("Payment expiration sweep stopped");
}
