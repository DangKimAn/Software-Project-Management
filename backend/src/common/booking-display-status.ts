import { getEnv } from "../config/env";

export type BookingDisplayStatusCode =
    | "pending_payment"
    | "payment_expired"
    | "paid"
    | "confirmed"
    | "checked_in"
    | "checked_out"
    | "completed"
    | "cancelled_by_guest"
    | "cancelled_by_host"
    | "cancelled_by_admin"
    | "rejected"
    | "unknown";

export type BookingDisplayStatusTone = "warning" | "danger" | "success" | "info" | "muted";

export type BookingDisplayStatus = {
    code: BookingDisplayStatusCode;
    normalizedStatus: BookingDisplayStatusCode;
    label: string;
    tone: BookingDisplayStatusTone;
    reason: string | null;
    isTerminal: boolean;
    canHostConfirm: boolean;
    canHostCancel: boolean;
};

export type BookingDisplayStatusSource = {
    status?: string | null;
    paymentStatus?: string | null;
    createdAt?: Date | string | null;
    paymentStartedAt?: Date | string | null;
    paymentExpiresAt?: Date | string | null;
    lockedUntil?: Date | string | null;
    checkInDate?: string | null;
    checkOutDate?: string | null;
    cancellationReason?: string | null;
    cancelledAt?: Date | string | null;
    paidAt?: Date | string | null;
};

export const cancellationReasons = {
    customerCancelled: "CUSTOMER_CANCELLED",
    hostRejected: "HOST_REJECTED",
    adminCancelled: "ADMIN_CANCELLED",
    paymentExpired: "PAYMENT_EXPIRED",
} as const;

export type CancellationReasonCode = (typeof cancellationReasons)[keyof typeof cancellationReasons];

const paidInternalStatuses = new Set(["paid", "confirmed", "checked_in", "checked_out", "completed"]);
const terminalStatuses = new Set([
    "payment_expired",
    "completed",
    "cancelled_by_guest",
    "cancelled_by_host",
    "cancelled_by_admin",
    "rejected",
]);

const parseDateTime = (value?: Date | string | null) => {
    if (!value) {
        return null;
    }

    if (value instanceof Date) {
        return Number.isNaN(value.getTime()) ? null : value;
    }

    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const normalizeStatus = (value?: string | null) => String(value ?? "").trim().toLowerCase();

export const normalizeCancellationReason = (value?: string | null) => {
    const normalized = String(value ?? "").trim().toUpperCase();
    return normalized || null;
};

export const getVietnamTodayDateString = (now = new Date()) =>
    new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

export const getPaymentStartedAt = (booking: BookingDisplayStatusSource) =>
    parseDateTime(booking.paymentStartedAt) ?? parseDateTime(booking.createdAt);

export const getPaymentExpiresAt = (booking: BookingDisplayStatusSource) => {
    const explicitDeadline = parseDateTime(booking.paymentExpiresAt) ?? parseDateTime(booking.lockedUntil);

    if (explicitDeadline) {
        return explicitDeadline;
    }

    const startedAt = getPaymentStartedAt(booking);

    if (!startedAt) {
        return null;
    }

    return new Date(startedAt.getTime() + getEnv().paymentHoldMinutes * 60 * 1000);
};

export const isBookingPaid = (booking: BookingDisplayStatusSource) => {
    const status = normalizeStatus(booking.status);
    const paymentStatus = normalizeStatus(booking.paymentStatus);

    return paymentStatus === "paid" || Boolean(parseDateTime(booking.paidAt)) || paidInternalStatuses.has(status);
};

const makeDisplayStatus = (
    code: BookingDisplayStatusCode,
    label: string,
    tone: BookingDisplayStatusTone,
    reason: string | null,
    options: Partial<Pick<BookingDisplayStatus, "isTerminal" | "canHostConfirm" | "canHostCancel">> = {},
): BookingDisplayStatus => ({
    code,
    normalizedStatus: code,
    label,
    tone,
    reason,
    isTerminal: options.isTerminal ?? terminalStatuses.has(code),
    canHostConfirm: options.canHostConfirm ?? false,
    canHostCancel: options.canHostCancel ?? false,
});

const getCancellationStatusFromLegacyReason = (reason: string | null): BookingDisplayStatusCode => {
    switch (reason) {
        case cancellationReasons.adminCancelled:
            return "cancelled_by_admin";
        case cancellationReasons.hostRejected:
            return "rejected";
        case cancellationReasons.customerCancelled:
        default:
            return "cancelled_by_guest";
    }
};

const getCancellationLabel = (status: BookingDisplayStatusCode) => {
    switch (status) {
        case "cancelled_by_guest":
            return "Da huy - Khach huy";
        case "cancelled_by_host":
            return "Da huy - Host huy";
        case "cancelled_by_admin":
            return "Da huy - Admin huy";
        case "rejected":
            return "Da huy - Host tu choi";
        default:
            return "Da huy";
    }
};

export function getBookingDisplayStatus(
    booking: BookingDisplayStatusSource,
    now = new Date(),
): BookingDisplayStatus {
    const status = normalizeStatus(booking.status);
    const cancellationReason = normalizeCancellationReason(booking.cancellationReason);
    const paid = isBookingPaid(booking);

    if (
        status === "payment_expired" ||
        status === "expired" ||
        cancellationReason === cancellationReasons.paymentExpired
    ) {
        return makeDisplayStatus("payment_expired", "Qua han thanh toan", "danger", cancellationReason, {
            isTerminal: true,
        });
    }

    if (
        status === "cancelled_by_guest" ||
        status === "cancelled_by_host" ||
        status === "cancelled_by_admin" ||
        status === "rejected" ||
        status === "cancelled"
    ) {
        const cancellationStatus =
            status === "cancelled"
                ? getCancellationStatusFromLegacyReason(cancellationReason)
                : (status as BookingDisplayStatusCode);

        return makeDisplayStatus(
            cancellationStatus,
            getCancellationLabel(cancellationStatus),
            cancellationStatus === "cancelled_by_guest" ? "muted" : "danger",
            cancellationReason,
            { isTerminal: true },
        );
    }

    if (!paid && ["pending", "pending_host", "pending_host_confirmation", "pending_payment"].includes(status)) {
        const paymentExpiresAt = getPaymentExpiresAt(booking);

        if (paymentExpiresAt && paymentExpiresAt.getTime() <= now.getTime()) {
            return makeDisplayStatus("payment_expired", "Qua han thanh toan", "danger", cancellationReasons.paymentExpired, {
                isTerminal: true,
            });
        }

        return makeDisplayStatus("pending_payment", "Cho thanh toan", "warning", null);
    }

    if (status === "paid" || status === "pending_host" || status === "pending_host_confirmation") {
        return makeDisplayStatus("paid", "Thanh toan thanh cong", "success", null, {
            canHostConfirm: true,
            canHostCancel: true,
        });
    }

    if (status === "confirmed") {
        return makeDisplayStatus("confirmed", "Da xac nhan", "success", null, {
            canHostCancel: true,
        });
    }

    if (status === "checked_in") {
        return makeDisplayStatus("checked_in", "Dang luu tru", "info", null);
    }

    if (status === "checked_out") {
        return makeDisplayStatus("checked_out", "Da tra phong", "info", null);
    }

    if (status === "completed") {
        return makeDisplayStatus("completed", "Hoan tat", "success", null, {
            isTerminal: true,
        });
    }

    if (paid) {
        return makeDisplayStatus("paid", "Thanh toan thanh cong", "success", null, {
            canHostConfirm: true,
            canHostCancel: true,
        });
    }

    return makeDisplayStatus("unknown", booking.status || "Khong ro", "muted", cancellationReason);
}
