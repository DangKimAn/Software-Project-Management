import type { Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import BookingStatusHistory from "../../models/booking-status-history";
import type { BookingDocument, BookingStatus } from "../../models/booking";

export type BookingStateActor = "guest" | "host" | "admin" | "system";

export type BookingTransitionCondition =
    | "none"
    | "payment_hold_expired"
    | "payment_succeeded_before_expiration"
    | "successful_payment_exists"
    | "check_in_date_is_today"
    | "check_in_date_reached"
    | "check_out_date_reached"
    | "stay_checked_out"
    | "cancellation_allowed_before_stay"
    | "admin_override"
    | "host_rejects_before_confirmation";

export type BookingTransitionSideEffect =
    | "clear_payment_hold"
    | "set_paid_at"
    | "expire_pending_payments"
    | "release_date_locks"
    | "create_refund_if_needed"
    | "mark_cancelled_at"
    | "mark_checked_in_at"
    | "mark_checked_out_at"
    | "redeem_coupon_if_needed"
    | "send_confirmation_email"
    | "write_booking_status_history"
    | "write_audit_log"
    | "handled_in_refund_status"
    | "handled_in_payout_status";

export type BookingTransitionDefinition = {
    from: readonly BookingStatus[];
    to: BookingStatus;
    actors: readonly BookingStateActor[];
    condition: BookingTransitionCondition;
    sideEffects: readonly BookingTransitionSideEffect[];
};

export type BookingTransitionContext = {
    now?: Date;
    hasSuccessfulPayment?: boolean;
    paymentPaidAt?: Date | null;
    paymentExpiresAt?: Date | null;
    checkInDate?: string | null;
    checkOutDate?: string | null;
};

export const bookingFinancialStatusesExcludedFromLifecycle = [
    "refund_pending",
    "refunded",
    "payout_pending",
    "payout_paid",
] as const;

export const separatedFinancialStatusPolicy = {
    paymentStatus: "payments.status",
    refundStatus: "refunds.status",
    payoutStatus: "host_payout_batch.status",
    excludedBookingStatuses: bookingFinancialStatusesExcludedFromLifecycle,
} as const;

export const terminalBookingStatuses = [
    "payment_expired",
    "completed",
    "cancelled_by_guest",
    "cancelled_by_host",
    "cancelled_by_admin",
    "rejected",
] as const satisfies readonly BookingStatus[];

export const allowedBookingTransitions = [
    {
        from: ["pending_payment"],
        to: "payment_expired",
        actors: ["system"],
        condition: "payment_hold_expired",
        sideEffects: ["expire_pending_payments", "release_date_locks", "write_booking_status_history"],
    },
    {
        from: ["pending_payment"],
        to: "paid",
        actors: ["system"],
        condition: "payment_succeeded_before_expiration",
        sideEffects: [
            "clear_payment_hold",
            "set_paid_at",
            "redeem_coupon_if_needed",
            "send_confirmation_email",
            "write_booking_status_history",
        ],
    },
    {
        from: ["paid"],
        to: "confirmed",
        actors: ["host", "admin"],
        condition: "successful_payment_exists",
        sideEffects: ["clear_payment_hold", "write_booking_status_history", "write_audit_log"],
    },
    {
        from: ["confirmed"],
        to: "checked_in",
        actors: ["host", "admin"],
        condition: "check_in_date_is_today",
        sideEffects: ["mark_checked_in_at", "write_booking_status_history", "write_audit_log"],
    },
    {
        from: ["confirmed"],
        to: "checked_in",
        actors: ["system"],
        condition: "check_in_date_reached",
        sideEffects: ["mark_checked_in_at", "write_booking_status_history"],
    },
    {
        from: ["checked_in"],
        to: "checked_out",
        actors: ["host", "admin"],
        condition: "check_out_date_reached",
        sideEffects: ["mark_checked_out_at", "write_booking_status_history", "write_audit_log"],
    },
    {
        from: ["checked_in"],
        to: "checked_out",
        actors: ["system"],
        condition: "check_out_date_reached",
        sideEffects: ["mark_checked_out_at", "write_booking_status_history"],
    },
    {
        from: ["checked_out"],
        to: "completed",
        actors: ["system", "admin"],
        condition: "stay_checked_out",
        sideEffects: [
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_payout_status",
        ],
    },
    {
        from: ["pending_payment", "paid", "confirmed"],
        to: "cancelled_by_guest",
        actors: ["guest"],
        condition: "cancellation_allowed_before_stay",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
    {
        from: ["confirmed"],
        to: "cancelled_by_host",
        actors: ["host"],
        condition: "cancellation_allowed_before_stay",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
    {
        from: ["pending_payment", "paid", "confirmed", "checked_in"],
        to: "cancelled_by_admin",
        actors: ["admin"],
        condition: "admin_override",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
    {
        from: ["paid"],
        to: "rejected",
        actors: ["host", "admin"],
        condition: "host_rejects_before_confirmation",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
] as const satisfies readonly BookingTransitionDefinition[];

const getVietnamTodayDateString = (now = new Date()) =>
    new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

const conditionChecks: Record<BookingTransitionCondition, (context: BookingTransitionContext) => boolean> = {
    none: () => true,
    payment_hold_expired: (context) =>
        Boolean(context.paymentExpiresAt && context.paymentExpiresAt.getTime() <= (context.now ?? new Date()).getTime()),
    payment_succeeded_before_expiration: (context) => {
        if (!context.hasSuccessfulPayment) {
            return false;
        }

        if (!context.paymentExpiresAt || !context.paymentPaidAt) {
            return true;
        }

        return context.paymentPaidAt.getTime() <= context.paymentExpiresAt.getTime();
    },
    successful_payment_exists: (context) => Boolean(context.hasSuccessfulPayment),
    check_in_date_is_today: (context) =>
        Boolean(context.checkInDate && context.checkInDate === getVietnamTodayDateString(context.now)),
    check_in_date_reached: (context) =>
        Boolean(context.checkInDate && getVietnamTodayDateString(context.now) >= context.checkInDate),
    check_out_date_reached: (context) =>
        Boolean(context.checkOutDate && getVietnamTodayDateString(context.now) >= context.checkOutDate),
    stay_checked_out: () => true,
    cancellation_allowed_before_stay: () => true,
    admin_override: () => true,
    host_rejects_before_confirmation: () => true,
};

export const findBookingTransition = (
    from: BookingStatus,
    to: BookingStatus,
    actor: BookingStateActor,
) =>
    allowedBookingTransitions.find(
        (transition) =>
            transition.to === to &&
            (transition.from as readonly BookingStatus[]).includes(from) &&
            (transition.actors as readonly BookingStateActor[]).includes(actor),
    ) ?? null;

export const assertBookingStatusTransition = (params: {
    from: BookingStatus;
    to: BookingStatus;
    actor: BookingStateActor;
    context?: BookingTransitionContext;
}) => {
    const transition = findBookingTransition(params.from, params.to, params.actor);

    if (!transition) {
        throw new ApiError(409, `Invalid booking status transition: ${params.from} -> ${params.to}`);
    }

    if (!conditionChecks[transition.condition](params.context ?? {})) {
        throw new ApiError(409, `Booking status transition condition failed: ${transition.condition}`);
    }

    return transition;
};

export const transitionBookingStatus = async (params: {
    booking: BookingDocument;
    toStatus: BookingStatus;
    actor: BookingStateActor;
    changedByUserId: number | null;
    reason: string | null;
    metadata?: Record<string, unknown> | null;
    transaction: Transaction;
    context?: BookingTransitionContext;
    mutate?: (booking: BookingDocument, transition: BookingTransitionDefinition) => void | Promise<void>;
}) => {
    const oldStatus = params.booking.status;
    const persistenceOptions =
        "sequelize" in params.transaction
            ? { transaction: params.transaction }
            : undefined;
    const transition = assertBookingStatusTransition({
        from: oldStatus,
        to: params.toStatus,
        actor: params.actor,
        context: params.context,
    });

    await params.mutate?.(params.booking, transition);

    params.booking.status = params.toStatus;
    params.booking.version = (params.booking.version ?? 0) + 1;
    await params.booking.save(persistenceOptions);

    if (persistenceOptions || process.env.NODE_ENV !== "test") {
        await BookingStatusHistory.create(
            {
                bookingId: params.booking.bookingId,
                oldStatus,
                newStatus: params.toStatus,
                changedByUserId: params.changedByUserId,
                reason: params.reason,
                metadataJson: {
                    ...(params.metadata ?? {}),
                    stateMachine: {
                        actor: params.actor,
                        condition: transition.condition,
                        sideEffects: transition.sideEffects,
                    },
                },
            },
            persistenceOptions,
        );
    }

    return transition;
};
