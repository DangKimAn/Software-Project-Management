import { Op, UniqueConstraintError, type Transaction } from "sequelize";
import { releaseBookingDateLocksForBooking } from "../../services/booking-date-lock.service";
import { expirePendingPaymentBookingInTransaction } from "../../services/booking-expiration.service";
import { ApiError } from "../../common/api-error";
import { cancellationReasons } from "../../common/booking-display-status";
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
import { toVnpayAmount } from "../../utils/money";
import { writeAuditLog } from "../../services/audit-log-service";
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


const isAdmin = (user: AuthenticatedUser) => user.roles.includes("admin");
const isHost = (user: AuthenticatedUser) => user.roles.includes("host");
const toNumber = (value: unknown) => Number(value ?? 0);

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

const runNotificationSideEffects = async (notifications: NotificationSideEffect[]) => {
    for (const notification of notifications) {
        await safeNotify(notification.label, notification.fn, notification.metadata);
    }
};

function getBookingPaymentExpiresAt(booking: BookingDocument): Date {
    const env = getEnv();

    return booking.lockedUntil ?? new Date(Date.now() + env.paymentHoldMinutes * 60 * 1000);
}

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

const getTrustedBookingPaymentAmount = (booking: BookingDocument) => {
    const amount = toNumber(booking.totalAmount);

    if (!Number.isFinite(amount) || amount <= 0) {
        throw new ApiError(409, "Booking amount is invalid");
    }

    return amount;
};

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

const assertBookingCanBePaidByUser = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (String(booking.guestUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }

    if (!payableBookingStatuses.includes(booking.status)) {
        throw new ApiError(409, "Booking is not payable");
    }
};

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

    return {
        isLatePayment: true,
        requiresRefund: refundStatus !== "succeeded",
        refundStatus,
        latePaymentReason:
            typeof providerPayload.latePaymentReason === "string"
                ? providerPayload.latePaymentReason
                : "late_payment_after_booking_expired",
        paymentResultStatus: refundStatus === "succeeded" ? payment.status : "refund_pending",
    };
};

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

const getPaymentBooking = async (payment: PaymentDocument) => {
    const booking = await Booking.findOne({ bookingId: payment.bookingId });

    if (!booking) {
        throw new ApiError(404, "Booking not found");
    }

    return booking;
};

const getClientIp = (value?: string | null) => {
    const firstForwardedIp = value?.split(",")[0]?.trim();
    return firstForwardedIp || "127.0.0.1";
};

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

const isPendingPaymentReusable = (payment: PaymentDocument) => {
    if (payment.status !== "pending") {
        return false;
    }

    if (!payment.expiresAt) {
        return false;
    }

    return payment.expiresAt.getTime() > Date.now();
};

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

const sanitizeVnpayPayloadForStorage = (payload: VnpayPayload) => ({
    vnp_TxnRef: payload.vnp_TxnRef ?? null,
    vnp_Amount: payload.vnp_Amount ?? null,
    vnp_ResponseCode: payload.vnp_ResponseCode ?? null,
    vnp_TransactionStatus: payload.vnp_TransactionStatus ?? null,
    vnp_TransactionNo: payload.vnp_TransactionNo ?? null,
    vnp_PayDate: payload.vnp_PayDate ?? null,
    vnp_BankCode: payload.vnp_BankCode ?? null,
});

const getFailedVnpayStatus = (payload: VnpayPayload): PaymentStatus => {
    if (payload.vnp_ResponseCode === "24") {
        return "cancelled";
    }

    if (payload.vnp_ResponseCode === "11" || payload.vnp_TransactionStatus === "02") {
        return "expired";
    }

    return "failed";
};

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

export const getPaymentDetail = async (user: AuthenticatedUser, paymentId: number) => {
    const payment = await Payment.findOne({ paymentId });

    if (!payment) {
        throw new ApiError(404, "Payment not found");
    }

    const booking = await getPaymentBooking(payment);
    assertCanViewPayment(booking, user);

    return serializePayment(payment);
};

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

const isSuccessfulVnpayPayload = (payload: VnpayPayload) =>
    payload.vnp_ResponseCode === "00" &&
    (payload.vnp_TransactionStatus === undefined || payload.vnp_TransactionStatus === "00");

const findPaymentByVnpayPayload = async (payload: VnpayPayload) => {
    const txnRef = payload.vnp_TxnRef;

    if (!txnRef) {
        return null;
    }

    return Payment.findOne({ providerTxnRef: txnRef });
};

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

const buildVnpayAuditMetadata = (payload: VnpayPayload, outcome: string) => ({
    provider: "vnpay",
    outcome,
    txnRef: payload.vnp_TxnRef ?? null,
    responseCode: payload.vnp_ResponseCode ?? null,
    transactionStatus: payload.vnp_TransactionStatus ?? null,
    providerTransactionNo: payload.vnp_TransactionNo ?? null,
    amount: payload.vnp_Amount ?? null,
});

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

const isSuccessfulMomoPayload = (payload: MomoPayload) => payload.resultCode === "0";

const getFailedMomoStatus = (payload: MomoPayload): PaymentStatus => {
    if (payload.resultCode === "1006") {
        return "cancelled";
    }

    if (payload.resultCode === "7000" || payload.resultCode === "7002") {
        return "pending";
    }

    return "failed";
};

const findPaymentByMomoPayload = async (payload: MomoPayload) => {
    const orderId = payload.orderId;

    if (!orderId) {
        return null;
    }

    return Payment.findOne({ providerTxnRef: orderId });
};

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
