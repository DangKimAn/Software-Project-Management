import {
    Op,
    QueryTypes,
    type Transaction,
    type WhereOptions,
} from "sequelize";
import { getEnv } from "../../config/env";
import {
    createBookingDateLocks,
    releaseBookingDateLocksForBooking,
} from "../../services/booking-date-lock.service";
import {
    expirePendingPaymentBooking,
    expirePendingPaymentBookingInTransaction,
    expirePendingPaymentBookings,
} from "../../services/booking-expiration.service";
import { ApiError } from "../../common/api-error";
import { buildActiveBookingStatusWhere, buildBookingDateOverlapWhere } from "../../common/booking-availability";
import {
    cancellationReasons,
    getBookingDisplayStatus,
    getPaymentExpiresAt,
    getPaymentStartedAt,
    normalizeCancellationReason,
} from "../../common/booking-display-status";
import { getListingImagesForListing } from "../../common/listing-relations";
import { getCoverImage, serializeListingImage } from "../../common/listing-mappers";
import { sanitizeNullableSingleLineText } from "../../common/sanitization";
import sequelize from "../../config/database";
import { logger } from "../../config/logger";
import AuditLog from "../../models/audit-log";
import AvailabilityCalendar from "../../models/availability-calendar";
import Booking, { BookingDocument, BookingStatus } from "../../models/booking";
import BookingDateLock from "../../models/booking-date-lock";
import BookingStatusHistory from "../../models/booking-status-history";
import HostPayoutBatch from "../../models/host-payout-batch";
import HostPayoutBookingItem from "../../models/host-payout-booking-item";
import Listing, { CancellationPolicy, ListingDocument } from "../../models/listing";
import NotificationLog from "../../models/notification-log";
import Payment from "../../models/payment";
import Refund from "../../models/refund";
import Review from "../../models/review";
import User from "../../models/user";
import type { AuthenticatedUser } from "../auth/auth.service";
import { writeAuditLog } from "../../services/audit-log-service";
import {
    assertBookingStatusTransition,
    type BookingStateActor,
    transitionBookingStatus,
} from "./booking-state-machine";
import {
    calculateBookingPricing,
    type BookingPriceBreakdown,
} from "./booking-pricing.service";
import {
    notifyBookingCancelled,
    notifyBookingConfirmed,
    notifyBookingCreated,
    notifyRefundCreated,
} from "../notifications/notification.service";

export type CreateBookingInput = {
    listingId: number;
    checkInDate: string;
    checkOutDate: string;
    guestCount: number;
    couponCode?: string;
};

export type CreateBulkBookingInput = {
    items: CreateBookingInput[];
};

export type ListBookingsQuery = {
    status?: BookingStatus | ApiBookingStatus;
    page?: number;
    limit?: number;
};

export type CancelBookingInput = {
    reason?: string;
};

export type ApiBookingStatus =
    | "pending"
    | "pending_payment"
    | "payment_expired"
    | "pending_host"
    | "pending_host_confirmation"
    | "confirmed"
    | "paid"
    | "checked_in"
    | "checked_out"
    | "completed"
    | "cancelled"
    | "cancelled_by_guest"
    | "cancelled_by_host"
    | "cancelled_by_admin"
    | "host_cancelled"
    | "expired"
    | "rejected";

type CancellationActor = "guest" | "host";
type PreparedBookingCreate = {
    index: number;
    input: CreateBookingInput;
    listing: ListingDocument;
    reservedDates: string[];
    calendarByDate: Awaited<ReturnType<typeof getCalendarMapForDates>>;
    pricing: Awaited<ReturnType<typeof calculateBookingPricing>>;
};

const maxPageLimit = 100;
const millisecondsPerDay = 24 * 60 * 60 * 1000;
const apiStatusToInternalStatuses: Record<ApiBookingStatus, BookingStatus[]> = {
    pending: ["pending_payment"],
    pending_payment: ["pending_payment"],
    payment_expired: ["payment_expired"],
    pending_host: ["paid"],
    pending_host_confirmation: ["paid"],
    confirmed: ["confirmed"],
    paid: ["paid"],
    checked_in: ["checked_in"],
    checked_out: ["checked_out"],
    completed: ["completed"],
    cancelled: ["cancelled_by_guest", "cancelled_by_host", "cancelled_by_admin"],
    cancelled_by_guest: ["cancelled_by_guest"],
    cancelled_by_host: ["cancelled_by_host"],
    cancelled_by_admin: ["cancelled_by_admin"],
    host_cancelled: ["cancelled_by_host"],
    expired: ["payment_expired"],
    rejected: ["rejected"],
};

const toNumber = (value: unknown) => Number(value ?? 0);

const toDateAtUtcMidnight = (date: string) => new Date(`${date}T00:00:00.000Z`);

const getTodayInVietnam = () => new Date(Date.now() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

const getNightCount = (checkInDate: string, checkOutDate: string) =>
    Math.round((toDateAtUtcMidnight(checkOutDate).getTime() - toDateAtUtcMidnight(checkInDate).getTime()) / millisecondsPerDay);

const listReservedDates = (checkInDate: string, checkOutDate: string) => {
    const dates: string[] = [];
    const cursor = toDateAtUtcMidnight(checkInDate);
    const end = toDateAtUtcMidnight(checkOutDate);

    while (cursor < end) {
        dates.push(cursor.toISOString().slice(0, 10));
        cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    return dates;
};

const parsePagination = (query: ListBookingsQuery) => ({
    page: Math.max(1, query.page ?? 1),
    limit: Math.min(maxPageLimit, Math.max(1, query.limit ?? 10)),
});

const getNextBookingSequence = async (transaction: Transaction) => {
    await sequelize.query(
        `
        INSERT INTO counters (\`key\`, \`value\`)
        VALUES ('booking', 1)
        ON DUPLICATE KEY UPDATE \`value\` = \`value\` + 1
        `,
        { transaction },
    );

    const rows = await sequelize.query<{ value: number }>(
        "SELECT `value` FROM counters WHERE `key` = 'booking' LIMIT 1 FOR UPDATE",
        {
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    const nextValue = rows[0]?.value;

    if (!nextValue) {
        throw new ApiError(500, "Unable to allocate booking id");
    }

    return Number(nextValue);
};

const assertBookingDateRange = (input: Pick<CreateBookingInput, "checkInDate" | "checkOutDate">) => {
    if (input.checkInDate >= input.checkOutDate) {
        throw new ApiError(422, "Validation error", [
            {
                path: "checkOutDate",
                msg: "checkOutDate must be after checkInDate",
            },
        ]);
    }

    if (input.checkInDate < getTodayInVietnam()) {
        throw new ApiError(422, "Validation error", [
            {
                path: "checkInDate",
                msg: "checkInDate cannot be in the past",
            },
        ]);
    }
};

const isDateRangeOverlapping = (
    left: Pick<CreateBookingInput, "checkInDate" | "checkOutDate">,
    right: Pick<CreateBookingInput, "checkInDate" | "checkOutDate">,
) => left.checkInDate < right.checkOutDate && left.checkOutDate > right.checkInDate;

const assertNoOverlappingBulkItems = (items: CreateBookingInput[]) => {
    for (let index = 0; index < items.length; index += 1) {
        for (let previousIndex = 0; previousIndex < index; previousIndex += 1) {
            const currentItem = items[index];
            const previousItem = items[previousIndex];

            if (
                currentItem.listingId === previousItem.listingId &&
                isDateRangeOverlapping(currentItem, previousItem)
            ) {
                throw new ApiError(409, "Bulk booking validation failed", [
                    {
                        path: `items[${index}]`,
                        msg: `Booking item #${index + 1} overlaps item #${previousIndex + 1}`,
                    },
                ]);
            }
        }
    }
};

const toBulkItemPath = (index: number, path?: string) => {
    if (!path) {
        return `items[${index}]`;
    }

    return `items[${index}].${path}`;
};

const throwBulkItemError = (index: number, error: unknown): never => {
    if (error instanceof ApiError) {
        throw new ApiError(
            error.statusCode,
            "Bulk booking validation failed",
            error.errors?.length
                ? error.errors.map((detail) => ({
                    path: toBulkItemPath(index, detail.path),
                    msg: detail.msg,
                }))
                : [
                    {
                        path: `items[${index}]`,
                        msg: error.message,
                    },
                ],
        );
    }

    throw new ApiError(500, "Bulk booking failed", [
        {
            path: `items[${index}]`,
            msg: error instanceof Error ? error.message : "Unable to create booking",
        },
    ]);
};

const withBulkItemError = async <T>(index: number, action: () => Promise<T>) => {
    try {
        return await action();
    } catch (error) {
        return throwBulkItemError(index, error);
    }
};

const assertNightRules = (
    listing: ListingDocument,
    checkInCalendarMinNights: number | null,
    nights: number,
) => {
    const minNights = checkInCalendarMinNights ?? listing.minNights;

    if (nights < minNights) {
        throw new ApiError(422, "Validation error", [
            {
                path: "checkOutDate",
                msg: `Booking must be at least ${minNights} night(s)`,
            },
        ]);
    }

    if (listing.maxNights !== null && listing.maxNights !== undefined && nights > listing.maxNights) {
        throw new ApiError(422, "Validation error", [
            {
                path: "checkOutDate",
                msg: `Booking must be at most ${listing.maxNights} night(s)`,
            },
        ]);
    }
};

const getPublicListingForBooking = async (listingId: number, transaction: Transaction) => {
    const listing = await Listing.findOne({
        where: {
            listingId,
            deletedAt: null,
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (!listing || listing.status !== "active") {
        throw new ApiError(404, "Listing not found");
    }

    return listing;
};

const getCalendarMapForDates = async (
    listing: ListingDocument,
    dates: string[],
    transaction: Transaction,
) => {
    const calendarByDate = new Map(
        listing.availabilityCalendar.map((row) => [row.date, row] as const),
    );
    const rows = await AvailabilityCalendar.findAll({
        where: {
            listingId: listing.listingId,
            date: {
                [Op.in]: dates,
            },
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    for (const row of rows) {
        calendarByDate.set(row.date, {
            date: row.date,
            isAvailable: row.isAvailable,
            isBlockedByHost: row.isBlockedByHost,
            priceOverride: row.priceOverride ?? null,
            minNightsOverride: row.minNightsOverride ?? null,
            notes: row.notes ?? null,
        });
    }

    return calendarByDate;
};

const assertCalendarAvailability = (dates: string[], calendarByDate: Map<string, { isAvailable: boolean; isBlockedByHost: boolean }>) => {
    const unavailableDates = dates.filter((date) => {
        const day = calendarByDate.get(date);
        return day ? day.isBlockedByHost || !day.isAvailable : false;
    });

    if (unavailableDates.length > 0) {
        throw new ApiError(409, "Listing is not available for the selected dates", [
            {
                path: "checkInDate",
                msg: `Unavailable dates: ${unavailableDates.join(", ")}`,
            },
        ]);
    }
};

const assertNoActiveOverlappingBooking = async (
    listingId: number,
    checkInDate: string,
    checkOutDate: string,
    transaction: Transaction,
) => {
    const overlapping = await Booking.findOne({
        where: {
            listingId,
            ...buildActiveBookingStatusWhere(),
            ...buildBookingDateOverlapWhere(checkInDate, checkOutDate),
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (overlapping) {
        throw new ApiError(409, "Listing is already booked for the selected dates");
    }
};

const expireStaleOverlappingPendingPaymentBookings = async (
    listingId: number,
    checkInDate: string,
    checkOutDate: string,
    transaction: Transaction,
) => {
    const now = new Date();
    const staleBookings = await Booking.findAll({
        where: {
            listingId,
            status: "pending_payment",
            ...buildBookingDateOverlapWhere(checkInDate, checkOutDate),
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
                },
            ],
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    for (const staleBooking of staleBookings) {
        await expirePendingPaymentBookingInTransaction({
            booking: staleBooking,
            transaction,
            now,
        });
    }
};

const toApiBookingStatus = (booking: BookingDocument): ApiBookingStatus => {
    switch (booking.status) {
        case "pending_payment":
            return "pending_payment";
        case "payment_expired":
            return "payment_expired";
        case "paid":
            return "paid";
        case "confirmed":
            return "confirmed";
        case "checked_in":
            return "checked_in";
        case "checked_out":
            return "checked_out";
        case "completed":
            return "completed";
        case "cancelled_by_guest":
            return "cancelled_by_guest";
        case "cancelled_by_host":
            return "cancelled_by_host";
        case "cancelled_by_admin":
            return "cancelled_by_admin";
        case "rejected":
            return "rejected";
        default:
            return "pending_payment";
    }
};

const getLatestPaymentForBooking = async (bookingId: number) =>
    Payment.findOne({
        where: {
            bookingId,
        },
        order: [["createdAt", "DESC"]],
    });

const getLatestRefundForBooking = async (bookingId: number) =>
    Refund.findOne({
        where: {
            bookingId,
        },
        order: [["createdAt", "DESC"]],
    });

const getLatestPayoutStatusForBooking = async (bookingId: number) => {
    const payoutItem = await HostPayoutBookingItem.findOne({
        where: {
            bookingDetailId: bookingId,
        },
        order: [["createdAt", "DESC"]],
    });

    if (!payoutItem) {
        return null;
    }

    if (!payoutItem.payoutId) {
        return null;
    }

    const payout = await HostPayoutBatch.findOne({
        where: {
            payoutId: payoutItem.payoutId,
        },
    });

    return payout?.status ?? null;
};

const parseStoredPriceBreakdown = (value: unknown): Partial<BookingPriceBreakdown> | null => {
    if (!value) {
        return null;
    }

    if (typeof value === "string") {
        try {
            const parsed = JSON.parse(value) as unknown;
            return typeof parsed === "object" && parsed !== null
                ? parsed as Partial<BookingPriceBreakdown>
                : null;
        } catch {
            return null;
        }
    }

    return typeof value === "object" ? value as Partial<BookingPriceBreakdown> : null;
};

const buildBookingPriceBreakdownForResponse = (booking: BookingDocument): BookingPriceBreakdown => {
    const stored = parseStoredPriceBreakdown(booking.priceBreakdown);
    const totalNights = toNumber(
        stored?.totalNights ??
        booking.totalNights ??
        booking.nights ??
        getNightCount(booking.checkInDate, booking.checkOutDate),
    );
    const subtotalAmount = toNumber(stored?.subtotalAmount ?? stored?.subtotal ?? booking.subtotalAmount);
    const cleaningFeeAmount = toNumber(stored?.cleaningFeeAmount ?? stored?.cleaningFee ?? booking.cleaningFeeAmount);
    const surchargeAmount = toNumber(stored?.surchargeAmount);
    const serviceFeeAmount = toNumber(stored?.serviceFeeAmount ?? stored?.serviceFee ?? booking.serviceFeeAmount);
    const discountAmount = toNumber(stored?.discountAmount ?? stored?.discount ?? booking.discountAmount);
    const totalAmount = toNumber(stored?.totalAmount ?? booking.totalAmount);
    const extraGuestFeeAmount = toNumber(stored?.extraGuestFeeAmount ?? stored?.extraGuestFee);
    const nightlyPrices = Array.isArray(stored?.nightlyPrices) ? stored.nightlyPrices : [];
    const extraGuest = stored?.extraGuest ?? {
        includedGuests: booking.guestCount,
        extraGuests: 0,
        feePerGuestPerNight: 0,
    };

    return {
        totalNights,
        weekdayNights: toNumber(stored?.weekdayNights),
        weekendNights: toNumber(stored?.weekendNights),
        nightlyPrice: toNumber(stored?.nightlyPrice),
        weekendPrice: stored?.weekendPrice === null || stored?.weekendPrice === undefined
            ? null
            : toNumber(stored.weekendPrice),
        nightlyPrices,
        subtotalAmount,
        subtotal: subtotalAmount,
        cleaningFeeAmount,
        cleaningFee: cleaningFeeAmount,
        surchargeAmount,
        serviceFeeAmount,
        serviceFee: serviceFeeAmount,
        extraGuestFeeAmount,
        extraGuestFee: extraGuestFeeAmount,
        discountAmount,
        discount: discountAmount,
        totalAmount,
        couponId: stored?.couponId ?? booking.couponId ?? null,
        couponCode: stored?.couponCode ?? null,
        extraGuest: {
            includedGuests: toNumber(extraGuest.includedGuests),
            extraGuests: toNumber(extraGuest.extraGuests),
            feePerGuestPerNight: toNumber(extraGuest.feePerGuestPerNight),
        },
    };
};

const autoAdvanceBookingStatus = async (booking: BookingDocument): Promise<void> => {
    const today = getTodayInVietnam();

    // confirmed → checked_in (today >= checkInDate)
    if (booking.status === "confirmed" && today >= booking.checkInDate) {
        try {
            await sequelize.transaction(async (transaction) => {
                const fresh = await getBookingOrThrow(booking.bookingId, transaction, true);
                if (fresh.status !== "confirmed") return;

                await transitionBookingStatus({
                    booking: fresh,
                    toStatus: "checked_in",
                    actor: "system",
                    changedByUserId: null,
                    reason: "auto_advance_check_in",
                    transaction,
                    context: { checkInDate: fresh.checkInDate },
                    mutate: (b) => {
                        b.checkedInAt = b.checkedInAt ?? new Date();
                    },
                });

                booking.status = fresh.status;
                booking.checkedInAt = fresh.checkedInAt;
                booking.version = fresh.version;
            });
        } catch (error) {
            logger.warn("Auto-advance confirmed->checked_in failed", {
                bookingId: booking.bookingId,
                error: error instanceof Error ? error.message : String(error),
            });
        }
    }

    // checked_in → checked_out (today >= checkOutDate)
    if (booking.status === "checked_in" && today >= booking.checkOutDate) {
        try {
            await sequelize.transaction(async (transaction) => {
                const fresh = await getBookingOrThrow(booking.bookingId, transaction, true);
                if (fresh.status !== "checked_in") return;

                await transitionBookingStatus({
                    booking: fresh,
                    toStatus: "checked_out",
                    actor: "system",
                    changedByUserId: null,
                    reason: "auto_advance_check_out",
                    transaction,
                    context: { checkOutDate: fresh.checkOutDate },
                    mutate: (b) => {
                        b.checkedOutAt = b.checkedOutAt ?? new Date();
                    },
                });

                booking.status = fresh.status;
                booking.checkedOutAt = fresh.checkedOutAt;
                booking.version = fresh.version;
            });
        } catch (error) {
            logger.warn("Auto-advance checked_in->checked_out failed", {
                bookingId: booking.bookingId,
                error: error instanceof Error ? error.message : String(error),
            });
        }
    }

    // checked_out → completed
    if (booking.status === "checked_out") {
        try {
            await sequelize.transaction(async (transaction) => {
                const fresh = await getBookingOrThrow(booking.bookingId, transaction, true);
                if (fresh.status !== "checked_out") return;

                await transitionBookingStatus({
                    booking: fresh,
                    toStatus: "completed",
                    actor: "system",
                    changedByUserId: null,
                    reason: "auto_advance_completed",
                    transaction,
                });

                booking.status = fresh.status;
                booking.version = fresh.version;
            });
        } catch (error) {
            logger.warn("Auto-advance checked_out->completed failed", {
                bookingId: booking.bookingId,
                error: error instanceof Error ? error.message : String(error),
            });
        }
    }
};

const serializeBooking = async (booking: BookingDocument, includeImages = false) => {
    await autoAdvanceBookingStatus(booking);

    const [latestPayment, latestRefund, payoutStatus, listing, review, guestUser] = await Promise.all([
        getLatestPaymentForBooking(booking.bookingId),
        getLatestRefundForBooking(booking.bookingId),
        getLatestPayoutStatusForBooking(booking.bookingId),
        Listing.findOne({
            where: {
                listingId: booking.listingId,
            },
        }),
        Review.findOne({
            where: {
                bookingId: booking.bookingId,
            },
        }),
        User.findById(booking.guestUserId),
    ]);
    const images = listing ? await getListingImagesForListing(listing) : [];
    const coverImage = getCoverImage(images);
    const serializedCoverImage = coverImage ? serializeListingImage(coverImage) : null;
    const paymentStartedAt = getPaymentStartedAt({
        paymentStartedAt: latestPayment?.createdAt ?? null,
        createdAt: booking.createdAt,
    });
    const paymentExpiresAt = getPaymentExpiresAt({
        status: booking.status,
        paymentStatus: latestPayment?.status ?? null,
        createdAt: booking.createdAt,
        paymentStartedAt,
        paymentExpiresAt: latestPayment?.expiresAt ?? booking.lockedUntil,
        lockedUntil: booking.lockedUntil,
        checkInDate: booking.checkInDate,
        checkOutDate: booking.checkOutDate,
        cancellationReason: booking.cancellationReason,
        cancelledAt: booking.cancelledAt,
        paidAt: booking.paidAt,
    });
    const displayStatus = getBookingDisplayStatus({
        status: booking.status,
        paymentStatus: latestPayment?.status ?? null,
        createdAt: booking.createdAt,
        paymentStartedAt,
        paymentExpiresAt,
        lockedUntil: booking.lockedUntil,
        checkInDate: booking.checkInDate,
        checkOutDate: booking.checkOutDate,
        cancellationReason: booking.cancellationReason,
        cancelledAt: booking.cancelledAt,
        paidAt: booking.paidAt,
    });
    const remainingPaymentSeconds = paymentExpiresAt
        ? Math.max(
            0,
            Math.floor((new Date(paymentExpiresAt).getTime() - Date.now()) / 1000),
        )
        : 0;
    const priceBreakdown = buildBookingPriceBreakdownForResponse(booking);

    return {
        bookingId: booking.bookingId,
        listingId: booking.listingId,
        guestUserId: String(booking.guestUserId),
        hostUserId: String(booking.hostUserId),
        guestName: guestUser?.fullName ?? null,
        guestEmail: guestUser?.email ?? null,
        listingTitle: listing?.title ?? null,
        listing: listing
            ? {
                listingId: listing.listingId,
                title: listing.title,
                city: listing.city,
                district: listing.district,
                addressLine: listing.addressLine,
                imageUrl: coverImage?.url ?? null,
                coverImageUrl: coverImage?.url ?? null,
                coverImage: serializedCoverImage,
                images: includeImages ? images.map(serializeListingImage) : [],
            }
            : null,
        checkInDate: booking.checkInDate,
        checkOutDate: booking.checkOutDate,
        guests: booking.guestCount,
        guestCount: booking.guestCount,
        guestsCount: booking.guestCount,
        nights: priceBreakdown.totalNights,
        totalNights: priceBreakdown.totalNights,
        status: displayStatus.normalizedStatus,
        persistedStatus: toApiBookingStatus(booking),
        internalStatus: booking.status,
        displayStatus,
        hasReview: !!review,
        paymentStatus: latestPayment?.status ?? null,
        refundStatus: latestRefund?.status ?? null,
        payoutStatus,
        lockedUntil: booking.lockedUntil,
        paymentStartedAt,
        paymentExpiresAt,
        remainingPaymentSeconds,
        currency: booking.currency,
        subtotalAmount: toNumber(booking.subtotalAmount),
        cleaningFeeAmount: toNumber(booking.cleaningFeeAmount),
        serviceFeeAmount: toNumber(booking.serviceFeeAmount),
        extraGuestFeeAmount: priceBreakdown.extraGuestFeeAmount,
        discountAmount: toNumber(booking.discountAmount),
        totalAmount: toNumber(booking.totalAmount),
        totalPrice: toNumber(booking.totalAmount),
        priceBreakdown,
        couponId: booking.couponId ?? null,
        bookingNote: booking.bookingNote ?? null,
        cancellationReason: displayStatus.reason ?? booking.cancellationReason ?? null,
        cancelledByUserId: booking.cancelledByUserId ? String(booking.cancelledByUserId) : null,
        cancelledAt: booking.cancelledAt ?? null,
        checkedInAt: booking.checkedInAt ?? null,
        checkedOutAt: booking.checkedOutAt ?? null,
        paidAt: booking.paidAt ?? null,
        createdAt: booking.createdAt,
        updatedAt: booking.updatedAt,
    };
};

const writeBookingStatusHistory = async (
    booking: BookingDocument,
    oldStatus: string | null,
    newStatus: string,
    actorId: number | null,
    reason: string | null,
    metadata: Record<string, unknown> | null,
    transaction: Transaction,
) => {
    await BookingStatusHistory.create(
        {
            bookingId: booking.bookingId,
            oldStatus,
            newStatus,
            changedByUserId: actorId,
            reason,
            metadataJson: metadata,
        },
        { transaction },
    );
};

const buildStatusWhere = (status?: BookingStatus | ApiBookingStatus): WhereOptions<BookingDocument> | undefined => {
    if (!status) {
        return undefined;
    }

    const internalStatuses =
        status in apiStatusToInternalStatuses
            ? apiStatusToInternalStatuses[status as ApiBookingStatus]
            : [status as BookingStatus];

    return {
        status: {
            [Op.in]: internalStatuses,
        },
    } as WhereOptions<BookingDocument>;
};

type SerializedBooking = Awaited<ReturnType<typeof serializeBooking>>;

const matchesSerializedBookingStatus = (
    booking: SerializedBooking,
    status?: BookingStatus | ApiBookingStatus,
) => {
    if (!status) {
        return true;
    }

    const requestedStatus = String(status).toLowerCase();
    const displayStatus = String(booking.status).toLowerCase();
    const internalStatus = String(booking.internalStatus).toLowerCase();

    if (requestedStatus === "pending_host" || requestedStatus === "pending_host_confirmation") {
        return displayStatus === "paid";
    }

    if (requestedStatus === "cancelled_by_guest") {
        return internalStatus === "cancelled_by_guest" || displayStatus === "cancelled_by_guest";
    }

    if (requestedStatus === "cancelled_by_host" || requestedStatus === "host_cancelled") {
        return internalStatus === "cancelled_by_host" || displayStatus === "cancelled_by_host";
    }

    if (requestedStatus === "cancelled_by_admin") {
        return internalStatus === "cancelled_by_admin" || displayStatus === "cancelled_by_admin";
    }

    if (requestedStatus === "cancelled") {
        return displayStatus.startsWith("cancelled_by");
    }

    if (requestedStatus === "expired" || requestedStatus === "payment_expired") {
        return displayStatus === "payment_expired";
    }

    return displayStatus === requestedStatus;
};

const paginateSerializedBookings = (
    items: SerializedBooking[],
    page: number,
    limit: number,
) => {
    const totalItems = items.length;

    return {
        items: items.slice((page - 1) * limit, page * limit),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

const listBookingsForDisplayStatus = async (params: {
    where: WhereOptions<BookingDocument>;
    query: ListBookingsQuery;
    order: Array<[string, "ASC" | "DESC"]>;
}) => {
    const { page, limit } = parsePagination(params.query);

    if (params.query.status) {
        const allItems = await Booking.findAll({
            where: params.where,
            order: params.order,
        });
        const serializedItems = await Promise.all(allItems.map((booking) => serializeBooking(booking)));

        return paginateSerializedBookings(
            serializedItems.filter((booking) => matchesSerializedBookingStatus(booking, params.query.status)),
            page,
            limit,
        );
    }

    const [items, totalItems] = await Promise.all([
        Booking.findAll({
            where: params.where,
            order: params.order,
            offset: (page - 1) * limit,
            limit,
        }),
        Booking.count({ where: params.where }),
    ]);

    return {
        items: await Promise.all(items.map((booking) => serializeBooking(booking))),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

const assertGuestOwnsBooking = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (String(booking.guestUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }
};

const assertHostOwnsBooking = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (user.roles.includes("admin")) {
        return;
    }

    if (String(booking.hostUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }
};

const getBookingOrThrow = async (bookingId: number, transaction?: Transaction, lock = false) => {
    const booking = await Booking.findOne({
        where: {
            bookingId,
        },
        transaction,
        lock: lock && transaction ? transaction.LOCK.UPDATE : undefined,
    });

    if (!booking) {
        throw new ApiError(404, "Booking not found");
    }

    return booking;
};

const getListingCancellationPolicy = async (booking: BookingDocument, transaction: Transaction) => {
    const listing = await Listing.findOne({
        where: {
            listingId: booking.listingId,
        },
        transaction,
    });

    return listing?.cancellationPolicy ?? "strict";
};

const getHoursUntilCheckIn = (booking: BookingDocument) =>
    (toDateAtUtcMidnight(booking.checkInDate).getTime() - Date.now()) / (60 * 60 * 1000);

const calculateRefundAmount = (
    booking: BookingDocument,
    policy: CancellationPolicy,
    actor: CancellationActor,
) => {
    const totalAmount = toNumber(booking.totalAmount);

    if (actor === "host") {
        return totalAmount;
    }

    const hoursUntilCheckIn = getHoursUntilCheckIn(booking);

    if (policy === "flexible") {
        return hoursUntilCheckIn >= 24 ? totalAmount : 0;
    }

    if (policy === "moderate") {
        if (hoursUntilCheckIn >= 120) return totalAmount;
        if (hoursUntilCheckIn >= 24) return Math.round(totalAmount * 0.5);
        return 0;
    }

    return hoursUntilCheckIn >= 168 ? Math.round(totalAmount * 0.5) : 0;
};

const createRefundForPaidPaymentIfNeeded = async (
    booking: BookingDocument,
    policy: CancellationPolicy,
    actor: CancellationActor,
    requestedByUserId: number,
    reason: string | null,
    transaction: Transaction,
) => {
    const paidPayment = await Payment.findOne({
        where: {
            bookingId: booking.bookingId,
            status: "paid",
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (!paidPayment) {
        return null;
    }

    const refundAmount = calculateRefundAmount(booking, policy, actor);

    if (refundAmount <= 0) {
        return null;
    }

    return Refund.create(
        {
            paymentId: paidPayment.paymentId,
            bookingId: booking.bookingId,
            amount: refundAmount,
            currency: booking.currency,
            reason,
            status: "pending",
            providerRef: null,
            requestedByUserId,
            processedByUserId: null,
            processedAt: null,
        },
        { transaction },
    );
};

const knownCancellationReasons = new Set<string>(Object.values(cancellationReasons));

const resolveCancellationReason = (
    user: AuthenticatedUser,
    actor: CancellationActor,
    currentStatus: BookingStatus,
    inputReason?: string,
) => {
    const sanitizedReason = sanitizeNullableSingleLineText(inputReason);
    const normalizedReason = normalizeCancellationReason(sanitizedReason);

    if (normalizedReason && knownCancellationReasons.has(normalizedReason)) {
        return {
            reasonCode: normalizedReason,
            note: null,
        };
    }

    if (user.roles.includes("admin")) {
        return {
            reasonCode: cancellationReasons.adminCancelled,
            note: sanitizedReason,
        };
    }

    if (actor === "host") {
        return {
            reasonCode: cancellationReasons.hostRejected,
            note: sanitizedReason,
        };
    }

    return {
        reasonCode: cancellationReasons.customerCancelled,
        note: sanitizedReason,
    };
};

const getBookingStateActor = (user: AuthenticatedUser, actor: CancellationActor | "system"): BookingStateActor => {
    if (actor === "system") {
        return "system";
    }

    return user.roles.includes("admin") ? "admin" : actor;
};

const getCancellationTargetStatus = (
    stateActor: BookingStateActor,
    requestedActor: CancellationActor,
    currentStatus: BookingStatus,
): BookingStatus => {
    if (stateActor === "admin") {
        return "cancelled_by_admin";
    }

    if (requestedActor === "guest") {
        return "cancelled_by_guest";
    }

    return currentStatus === "paid" ? "rejected" : "cancelled_by_host";
};

const cancelBooking = async (
    user: AuthenticatedUser,
    bookingId: number,
    input: CancelBookingInput,
    actor: CancellationActor,
) => {
    const booking = await sequelize.transaction(async (transaction) => {
        const existingBooking = await getBookingOrThrow(bookingId, transaction, true);

        if (actor === "guest") {
            assertGuestOwnsBooking(existingBooking, user);
        } else {
            assertHostOwnsBooking(existingBooking, user);
        }

        const stateActor = getBookingStateActor(user, actor);
        const nextStatus = getCancellationTargetStatus(stateActor, actor, existingBooking.status);
        assertBookingStatusTransition({
            from: existingBooking.status,
            to: nextStatus,
            actor: stateActor,
        });
        const { reasonCode, note } = resolveCancellationReason(user, actor, existingBooking.status, input.reason);
        const policy = await getListingCancellationPolicy(existingBooking, transaction);
        const refund = await createRefundForPaidPaymentIfNeeded(
            existingBooking,
            policy,
            stateActor === "guest" ? "guest" : "host",
            Number(user.id),
            reasonCode,
            transaction,
        );

        const oldStatus = existingBooking.status;
        const cancelledAt = new Date();

        await transitionBookingStatus({
            booking: existingBooking,
            toStatus: nextStatus,
            actor: stateActor,
            changedByUserId: Number(user.id),
            reason: reasonCode,
            metadata: {
                cancellationPolicy: policy,
                refundId: refund?.refundId ?? null,
                refundAmount: refund ? toNumber(refund.amount) : 0,
                note,
            },
            transaction,
            mutate: (booking) => {
                booking.cancellationReason = reasonCode;
                booking.cancelledByUserId = Number(user.id);
                booking.cancelledAt = cancelledAt;
            },
        });
        await releaseBookingDateLocksForBooking({
            bookingId: existingBooking.bookingId,
            transaction,
        });
        await Payment.update(
            {
                status: "cancelled",
                failedAt: new Date(),
            },
            {
                where: {
                    bookingId: existingBooking.bookingId,
                    status: "pending",
                },
                transaction,
            },
        );
        await writeAuditLog({
            actorId: Number(user.id),
            action:
                stateActor === "admin"
                    ? "booking.cancel.admin"
                    : actor === "host"
                        ? "booking.cancel.host"
                        : "booking.cancel.guest",
            targetType: "booking",
            targetId: existingBooking.bookingId,
            metadata: {
                fromStatus: oldStatus,
                toStatus: nextStatus,
                reason: reasonCode,
                note,
                cancellationPolicy: policy,
            },
            transaction,
        });
        await notifyBookingCancelled(existingBooking.bookingId, transaction);

        if (refund) {
            await notifyRefundCreated(refund.refundId, transaction);
        }

        return existingBooking;
    });

    return serializeBooking(booking, true);
};

const prepareBookingCreate = async (
    user: AuthenticatedUser,
    input: CreateBookingInput,
    index: number,
    transaction: Transaction,
): Promise<PreparedBookingCreate> => {
    assertBookingDateRange(input);

    const listing = await getPublicListingForBooking(input.listingId, transaction);

    if (String(listing.hostId) === user.id) {
        throw new ApiError(403, "Hosts cannot book their own listing");
    }

    if (input.guestCount > listing.maxGuests) {
        throw new ApiError(422, "Validation error", [
            {
                path: "guestCount",
                msg: "guestCount exceeds listing maxGuests",
            },
        ]);
    }

    const reservedDates = listReservedDates(input.checkInDate, input.checkOutDate);
    const calendarByDate = await getCalendarMapForDates(listing, reservedDates, transaction);
    const checkInMinNights = calendarByDate.get(input.checkInDate)?.minNightsOverride ?? null;
    const nights = getNightCount(input.checkInDate, input.checkOutDate);

    assertNightRules(listing, checkInMinNights, nights);
    assertCalendarAvailability(reservedDates, calendarByDate);
    await expireStaleOverlappingPendingPaymentBookings(
        listing.listingId,
        input.checkInDate,
        input.checkOutDate,
        transaction,
    );
    await assertNoActiveOverlappingBooking(listing.listingId, input.checkInDate, input.checkOutDate, transaction);

    const pricing = await calculateBookingPricing({
        userId: Number(user.id),
        listing,
        dates: reservedDates,
        calendarByDate,
        guestCount: input.guestCount,
        couponCode: input.couponCode,
        transaction,
    });

    return {
        index,
        input,
        listing,
        reservedDates,
        calendarByDate,
        pricing,
    };
};

const createPreparedBooking = async (
    user: AuthenticatedUser,
    prepared: PreparedBookingCreate,
    transaction: Transaction,
    onCreated?: (booking: BookingDocument) => void,
) => {
    const { input, listing, pricing } = prepared;
    const env = getEnv();
    const lockedUntil = new Date(Date.now() + env.paymentHoldMinutes * 60 * 1000);
    const status: BookingStatus = "pending_payment";
    const createdBooking = await Booking.create(
        {
            bookingId: await getNextBookingSequence(transaction),
            listingId: listing.listingId,
            guestUserId: Number(user.id),
            hostUserId: Number(listing.hostId),
            checkInDate: input.checkInDate,
            checkOutDate: input.checkOutDate,
            guestCount: input.guestCount,
            nights: pricing.totalNights,
            totalNights: pricing.totalNights,
            status,
            version: 0,
            lockedUntil,
            currency: listing.currency,
            couponId: pricing.couponId,
            subtotalAmount: pricing.subtotalAmount,
            cleaningFeeAmount: pricing.cleaningFeeAmount,
            serviceFeeAmount: pricing.serviceFeeAmount,
            discountAmount: pricing.discountAmount,
            totalAmount: pricing.totalAmount,
            priceBreakdown: pricing.priceBreakdown as unknown as Record<string, unknown>,
            bookingNote: null,
            cancellationReason: null,
            cancelledByUserId: null,
            cancelledAt: null,
            checkedInAt: null,
            checkedOutAt: null,
            paidAt: null,
        },
        { transaction },
    );

    onCreated?.(createdBooking);

    await createBookingDateLocks({
        bookingId: createdBooking.bookingId,
        listingId: createdBooking.listingId,
        checkInDate: toDateAtUtcMidnight(createdBooking.checkInDate),
        checkOutDate: toDateAtUtcMidnight(createdBooking.checkOutDate),
        transaction,
    });

    await writeBookingStatusHistory(
        createdBooking,
        null,
        toApiBookingStatus(createdBooking),
        Number(user.id),
        null,
        {
            pricingSnapshot: pricing,
            instantBookEnabled: listing.instantBookEnabled,
        },
        transaction,
    );
    await writeAuditLog({
        actorId: Number(user.id),
        action: "booking.create",
        targetType: "booking",
        targetId: createdBooking.bookingId,
        metadata: {
            listingId: listing.listingId,
            status: toApiBookingStatus(createdBooking),
            totalAmount: pricing.totalAmount,
        },
        transaction,
    });
    await notifyBookingCreated(createdBooking.bookingId, transaction);

    return createdBooking;
};

const compensateBulkBookingCreation = async (createdBookings: BookingDocument[]) => {
    const bookingIds = [...new Set(createdBookings.map((booking) => Number(booking.bookingId)).filter(Number.isFinite))];

    if (bookingIds.length === 0) {
        return;
    }

    const bookingIdWhere = { bookingId: { [Op.in]: bookingIds } };

    try {
        await BookingDateLock.destroy({ where: bookingIdWhere });
    } catch (error) {
        logger.warn("Bulk booking compensation could not delete date locks", {
            bookingIds,
            error: error instanceof Error ? error.message : String(error),
        });
    }

    try {
        await BookingStatusHistory.destroy({ where: bookingIdWhere });
    } catch (error) {
        logger.warn("Bulk booking compensation could not delete status history", {
            bookingIds,
            error: error instanceof Error ? error.message : String(error),
        });
    }

    try {
        await AuditLog.destroy({
            where: {
                targetType: "booking",
                targetId: { [Op.in]: bookingIds },
            },
        });
    } catch (error) {
        logger.warn("Bulk booking compensation could not delete audit logs", {
            bookingIds,
            error: error instanceof Error ? error.message : String(error),
        });
    }

    try {
        await NotificationLog.destroy({
            where: {
                targetType: "booking",
                targetId: { [Op.in]: bookingIds.map(String) },
            },
        });
    } catch (error) {
        logger.warn("Bulk booking compensation could not delete notification logs", {
            bookingIds,
            error: error instanceof Error ? error.message : String(error),
        });
    }

    try {
        await Booking.destroy({ where: bookingIdWhere });
    } catch (error) {
        logger.warn("Bulk booking compensation could not delete bookings", {
            bookingIds,
            error: error instanceof Error ? error.message : String(error),
        });
    }
};

export const createBooking = async (user: AuthenticatedUser, input: CreateBookingInput) => {
    assertBookingDateRange(input);

    const booking = await sequelize.transaction(async (transaction) => {
        const prepared = await prepareBookingCreate(user, input, 0, transaction);

        return createPreparedBooking(user, prepared, transaction);
    });

    return serializeBooking(booking, true);
};

export const createBulkBookings = async (user: AuthenticatedUser, input: CreateBulkBookingInput) => {
    input.items.forEach((item, index) => {
        try {
            assertBookingDateRange(item);
        } catch (error) {
            throwBulkItemError(index, error);
        }
    });
    assertNoOverlappingBulkItems(input.items);

    const createdForCompensation: BookingDocument[] = [];
    let committedBookings: BookingDocument[];

    try {
        committedBookings = await sequelize.transaction(async (transaction) => {
            const preparedBookings: PreparedBookingCreate[] = [];

            for (const [index, item] of input.items.entries()) {
                preparedBookings.push(
                    await withBulkItemError(index, () => prepareBookingCreate(user, item, index, transaction)),
                );
            }

            const createdBookings: BookingDocument[] = [];

            for (const prepared of preparedBookings) {
                const createdBooking = await withBulkItemError(prepared.index, () =>
                    createPreparedBooking(user, prepared, transaction, (booking) => {
                        if (!createdForCompensation.some((created) => created.bookingId === booking.bookingId)) {
                            createdForCompensation.push(booking);
                        }
                    }),
                );

                createdBookings.push(createdBooking);
            }

            return createdBookings;
        });
    } catch (error) {
        await compensateBulkBookingCreation(createdForCompensation);
        throw error;
    }

    // Serialize OUTSIDE the compensation try/catch.
    // At this point the transaction has committed — bookings are valid.
    // If serialization fails we must NOT delete committed bookings.
    return {
        items: await Promise.all(committedBookings.map((booking) => serializeBooking(booking, true))),
    };
};

export const getMyBookings = async (user: AuthenticatedUser, query: ListBookingsQuery) => {
    await expirePendingPaymentBookings();

    const where: WhereOptions<BookingDocument> = {
        guestUserId: Number(user.id),
    };

    return listBookingsForDisplayStatus({
        where,
        query,
        order: [["createdAt", "DESC"], ["bookingId", "DESC"]],
    });
};

export const getGuestBookingDetail = async (user: AuthenticatedUser, bookingId: number) => {
    await expirePendingPaymentBooking(bookingId);
    const booking = await getBookingOrThrow(bookingId);
    assertGuestOwnsBooking(booking, user);
    return serializeBooking(booking, true);
};

export const cancelGuestBooking = async (
    user: AuthenticatedUser,
    bookingId: number,
    input: CancelBookingInput,
) => cancelBooking(user, bookingId, input, "guest");

export const getHostBookings = async (user: AuthenticatedUser, query: ListBookingsQuery) => {
    await expirePendingPaymentBookings();

    const where: WhereOptions<BookingDocument> = {
        ...(user.roles.includes("admin") ? {} : { hostUserId: Number(user.id) }),
    };

    return listBookingsForDisplayStatus({
        where,
        query,
        order: [["bookingId", "DESC"]],
    });
};

export const getHostBookingDetail = async (user: AuthenticatedUser, bookingId: number) => {
    await expirePendingPaymentBooking(bookingId);
    const booking = await getBookingOrThrow(bookingId);
    assertHostOwnsBooking(booking, user);
    return serializeBooking(booking, true);
};

export const confirmHostBooking = async (user: AuthenticatedUser, bookingId: number) => {
    const booking = await sequelize.transaction(async (transaction) => {
        const existingBooking = await getBookingOrThrow(bookingId, transaction, true);
        assertHostOwnsBooking(existingBooking, user);

        if (existingBooking.status !== "paid") {
            throw new ApiError(409, "Booking cannot be confirmed in its current status");
        }

        const paidPayment = existingBooking.paidAt
            ? null
            : await Payment.findOne({
                where: {
                    bookingId: existingBooking.bookingId,
                    status: "paid",
                },
                transaction,
                lock: transaction.LOCK.UPDATE,
            });

        if (!existingBooking.paidAt && !paidPayment) {
            throw new ApiError(409, "Host can only confirm a booking after successful payment");
        }

        const oldStatus = existingBooking.status;
        await transitionBookingStatus(
            {
                booking: existingBooking,
                toStatus: "confirmed",
                actor: getBookingStateActor(user, "host"),
                changedByUserId: Number(user.id),
                reason: null,
                transaction,
                context: {
                    hasSuccessfulPayment: Boolean(existingBooking.paidAt || paidPayment),
                },
                mutate: (booking) => {
                    booking.paidAt = booking.paidAt ?? paidPayment?.paidAt ?? null;
                    booking.lockedUntil = null;
                },
            },
        );
        await writeAuditLog({
            actorId: Number(user.id),
            action: "booking.confirm",
            targetType: "booking",
            targetId: existingBooking.bookingId,
            metadata: {
                fromStatus: oldStatus,
                toStatus: "confirmed",
            },
            transaction,
        });
        await notifyBookingConfirmed(existingBooking.bookingId, transaction);

        return existingBooking;
    });

    return serializeBooking(booking, true);
};

export const checkInHostBooking = async (user: AuthenticatedUser, bookingId: number) => {
    const booking = await sequelize.transaction(async (transaction) => {
        const existingBooking = await getBookingOrThrow(bookingId, transaction, true);
        assertHostOwnsBooking(existingBooking, user);

        if (existingBooking.status !== "confirmed") {
            throw new ApiError(409, "Booking cannot be checked in in its current status");
        }

        if (getTodayInVietnam() < existingBooking.checkInDate) {
            throw new ApiError(400, "Booking can only be checked in on or after the check-in date");
        }

        const oldStatus = existingBooking.status;
        await transitionBookingStatus(
            {
                booking: existingBooking,
                toStatus: "checked_in",
                actor: getBookingStateActor(user, "host"),
                changedByUserId: Number(user.id),
                reason: null,
                transaction,
                context: {
                    checkInDate: existingBooking.checkInDate,
                },
                mutate: (booking) => {
                    booking.checkedInAt = new Date();
                },
            },
        );
        await writeAuditLog({
            actorId: Number(user.id),
            action: "booking.check_in",
            targetType: "booking",
            targetId: existingBooking.bookingId,
            metadata: {
                fromStatus: oldStatus,
                toStatus: "checked_in",
            },
            transaction,
        });

        return existingBooking;
    });

    return serializeBooking(booking, true);
};

export const checkOutHostBooking = async (user: AuthenticatedUser, bookingId: number) => {
    const booking = await sequelize.transaction(async (transaction) => {
        const existingBooking = await getBookingOrThrow(bookingId, transaction, true);
        assertHostOwnsBooking(existingBooking, user);

        if (existingBooking.status !== "checked_in") {
            throw new ApiError(409, "Booking cannot be checked out in its current status");
        }

        if (getTodayInVietnam() < existingBooking.checkOutDate) {
            throw new ApiError(400, "Booking can only be checked out on or after the check-out date");
        }

        const oldStatus = existingBooking.status;
        await transitionBookingStatus(
            {
                booking: existingBooking,
                toStatus: "checked_out",
                actor: getBookingStateActor(user, "host"),
                changedByUserId: Number(user.id),
                reason: null,
                transaction,
                context: {
                    checkOutDate: existingBooking.checkOutDate,
                },
                mutate: (booking) => {
                    booking.checkedOutAt = new Date();
                },
            },
        );
        await writeAuditLog({
            actorId: Number(user.id),
            action: "booking.check_out",
            targetType: "booking",
            targetId: existingBooking.bookingId,
            metadata: {
                fromStatus: oldStatus,
                toStatus: "checked_out",
            },
            transaction,
        });

        return existingBooking;
    });

    return serializeBooking(booking, true);
};

export const cancelHostBooking = async (
    user: AuthenticatedUser,
    bookingId: number,
    input: CancelBookingInput,
) => cancelBooking(user, bookingId, input, "host");
