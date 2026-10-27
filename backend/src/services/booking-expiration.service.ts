import { Op, Transaction } from "sequelize";
import { sequelize } from "../config/database";
import { getEnv } from "../config/env";
import Booking, { type BookingDocument } from "../models/booking";
import Payment, { type PaymentDocument } from "../models/payment";
import Refund from "../models/refund";
import { releaseBookingDateLocksForBooking } from "./booking-date-lock.service";
import { logger } from "../config/logger";
import {
    cancellationReasons,
} from "../common/booking-display-status";
import { transitionBookingStatus } from "../modules/bookings/booking-state-machine";
import {
    notifyPaymentExpired,
    notifyPaymentSuccess,
    notifyRefundCreated,
} from "../modules/notifications/notification.service";

let sweepTimer: NodeJS.Timeout | null = null;
let sweepRunning = false;

const isPaymentPaidBeforeHoldExpired = (params: {
    paidAt: Date | null;
    lockedUntil: Date | null;
}) => {
    if (!params.lockedUntil || !params.paidAt) {
        return true;
    }

    return params.paidAt.getTime() <= params.lockedUntil.getTime();
};

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

export function stopPaymentExpirationSweep(): void {
    if (!sweepTimer) {
        return;
    }

    clearInterval(sweepTimer);
    sweepTimer = null;
    sweepRunning = false;

    logger.info("Payment expiration sweep stopped");
}
