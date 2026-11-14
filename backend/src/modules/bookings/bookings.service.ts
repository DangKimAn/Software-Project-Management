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
} from "./booking-date-lock.service";
import {
    expirePendingPaymentBooking,
    expirePendingPaymentBookingInTransaction,
    expirePendingPaymentBookings,
} from "./booking-expiration.service";
import { ApiError } from "../../common/api-error";
import { buildActiveBookingStatusWhere, buildBookingDateOverlapWhere } from "./booking-availability";
import {
    cancellationReasons,
    getBookingDisplayStatus,
    getPaymentExpiresAt,
    getPaymentStartedAt,
    normalizeCancellationReason,
} from "./booking-display-status";
import { getListingImagesForListing } from "../listings/listing-relations";
import { getCoverImage, serializeListingImage } from "../listings/listing-mappers";
import { sanitizeNullableSingleLineText, sanitizeText } from "../../common/sanitization";
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
import { writeAuditLog } from "../../services/audit-log.service";
import {
    enqueueHostSheetSyncJobSafe,
    isHostSheetSyncRuntimeActive,
    verifySheetAvailabilityBeforeBooking,
} from "../host-sheet-sync/host-sheet-sync.service";
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
    bookingNote?: string | null;
    specialRequests?: string | null;
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
    bankName?: string;
    accountNumber?: string;
    accountName?: string;
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

/**
 * Giải thuật ép kiểu an toàn giá trị bất kỳ sang `number`, mặc định trả về `0` khi gặp `null` hoặc `undefined`.
 */
const toNumber = (value: unknown) => Number(value ?? 0);

/**
 * Giải thuật chuyển đổi chuỗi ngày lịch `YYYY-MM-DD` sang đối tượng `Date` cố định tại mốc nửa đêm UTC (`00:00:00.000Z`).
 */
const toDateAtUtcMidnight = (date: string) => new Date(`${date}T00:00:00.000Z`);

/**
 * Giải thuật xác định chuỗi ngày hiện tại `YYYY-MM-DD` theo múi giờ Việt Nam (`UTC+7`).
 */
const getTodayInVietnam = () => new Date(Date.now() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

/**
 * Giải thuật tính tổng số đêm lưu trú nguyên giữa hai mốc ngày `checkInDate` và `checkOutDate` trên trục nửa đêm UTC.
 */
const getNightCount = (checkInDate: string, checkOutDate: string) =>
    Math.round((toDateAtUtcMidnight(checkOutDate).getTime() - toDateAtUtcMidnight(checkInDate).getTime()) / millisecondsPerDay);

const MAX_BOOKING_STAY_NIGHTS = 365;
const MAX_ACTIVE_PENDING_BOOKINGS_PER_GUEST = 10;

/**
 * Giải thuật liệt kê danh sách các ngày đêm lưu trú thuộc khoảng nửa mở `[checkInDate, checkOutDate)` có chặn trần an toàn `MAX_BOOKING_STAY_NIGHTS`.
 */
const listReservedDates = (checkInDate: string, checkOutDate: string) => {
    const dates: string[] = [];
    const cursor = toDateAtUtcMidnight(checkInDate);
    const end = toDateAtUtcMidnight(checkOutDate);

    while (cursor < end && dates.length <= MAX_BOOKING_STAY_NIGHTS) {
        dates.push(cursor.toISOString().slice(0, 10));
        cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    return dates;
};

/**
 * Giải thuật chuẩn hóa tham số phân trang danh sách đơn đặt phòng trong miền hợp lệ `page >= 1` và `1 <= limit <= maxPageLimit`.
 */
const parsePagination = (query: ListBookingsQuery) => ({
    page: Math.max(1, query.page ?? 1),
    limit: Math.min(maxPageLimit, Math.max(1, query.limit ?? 10)),
});

/**
 * Giải thuật sinh khóa tuần tự nguyên tử (`bookingId`) thông qua bảng bộ đếm `counters` trong giao dịch ACID:
 * 1. Thực thi lệnh nguyên tử `INSERT INTO counters ... ON DUPLICATE KEY UPDATE value = value + 1` để tăng bộ đếm khóa `'booking'`.
 * 2. Đọc lại giá trị hiện hành bằng khóa bi quan `SELECT ... FOR UPDATE` trong cùng `transaction`,
 *    đảm bảo cấp phát định danh duy nhất, tuần tự và loại bỏ hoàn toàn xung đột khóa chính dưới tải đồng thời cao.
 */
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

/**
 * Giải thuật kiểm định các bất biến cơ bản của khoảng ngày đặt phòng:
 * - Bất biến thứ tự: `checkInDate < checkOutDate`.
 * - Bất biến hiện tại/tương lai: `checkInDate >= todayVN` (theo múi giờ Việt Nam `UTC+7`).
 * - Bất biến độ dài kỳ nghỉ: số đêm lưu trú không vượt quá `MAX_BOOKING_STAY_NIGHTS` (365 đêm).
 */
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

    if (getNightCount(input.checkInDate, input.checkOutDate) > MAX_BOOKING_STAY_NIGHTS) {
        throw new ApiError(422, "Validation error", [
            {
                path: "checkOutDate",
                msg: `Booking duration cannot exceed ${MAX_BOOKING_STAY_NIGHTS} nights`,
            },
        ]);
    }
};

/**
 * Giải thuật kiểm tra giao cắt giữa hai khoảng ngày lưu trú nửa mở `[checkInDate, checkOutDate)`
 * theo bất đẳng thức `left.checkInDate < right.checkOutDate && left.checkOutDate > right.checkInDate`.
 */
const isDateRangeOverlapping = (
    left: Pick<CreateBookingInput, "checkInDate" | "checkOutDate">,
    right: Pick<CreateBookingInput, "checkInDate" | "checkOutDate">,
) => left.checkInDate < right.checkOutDate && left.checkOutDate > right.checkInDate;

/**
 * Giải thuật đối chiếu chéo từng cặp mục đặt phòng $O(N^2)$ trong cùng một yêu cầu đặt nhiều căn hộ (`bulk booking`):
 * phát hiện và từ chối sớm (`409 Conflict`) nếu tồn tại hai mục nhắm tới cùng `listingId` có khoảng ngày lưu trú giao cắt nhau.
 */
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

/**
 * Giải thuật định dạng đường dẫn trường lỗi gắn chỉ số phần tử `items[index]` cho phản hồi lỗi đặt phòng hàng loạt.
 */
const toBulkItemPath = (index: number, path?: string) => {
    if (!path) {
        return `items[${index}]`;
    }

    return `items[${index}].${path}`;
};

/**
 * Giải thuật chuẩn hóa và ném lại ngoại lệ gắn ngữ cảnh chỉ mục phần tử `items[index]` khi một chặng trong lô đặt phòng thất bại.
 */
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

/**
 * Giải thuật bọc thực thi bất đồng bộ cho từng mục trong lô đặt phòng nhằm tự động ánh xạ mọi lỗi phát sinh về đúng `items[index]`.
 */
const withBulkItemError = async <T>(index: number, action: () => Promise<T>) => {
    try {
        return await action();
    } catch (error) {
        return throwBulkItemError(index, error);
    }
};

/**
 * Giải thuật kiểm tra quy tắc số đêm lưu trú tối thiểu (`minNights`, ưu tiên `checkInCalendarMinNights` ghi đè tại ngày nhận phòng)
 * và trần số đêm tối đa (`listing.maxNights`) của căn hộ.
 */
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

/**
 * Giải thuật truy vấn căn hộ mở bán công khai kèm khóa bi quan mức dòng (`SELECT ... FOR UPDATE`) trong giao dịch ACID:
 * tuần tự hóa toàn bộ các yêu cầu đặt phòng cạnh tranh trên cùng một `listingId` và đảm bảo căn hộ đang ở trạng thái `active`.
 */
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

/**
 * Giải thuật hợp nhất bản đồ lịch khả dụng (`AvailabilityCalendar`) cho các đêm lưu trú dự kiến với khóa bi quan `FOR UPDATE`
 * nhằm đọc nhất quán trạng thái đóng/mở lịch, giá ghi đè (`priceOverride`) và số đêm tối thiểu ghi đè (`minNightsOverride`).
 */
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
            isBlockedByAdmin: Boolean(row.isBlockedByAdmin),
            priceOverride: row.priceOverride ?? null,
            minNightsOverride: row.minNightsOverride ?? null,
            notes: row.notes ?? null,
        });
    }

    return calendarByDate;
};

/**
 * Giải thuật kiểm định tính khả dụng trên lịch chủ nhà và quản trị cho toàn bộ danh sách đêm lưu trú `dates`;
 * ném lỗi `409 Conflict` kèm danh sách ngày cụ thể nếu có bất kỳ đêm nào bị chủ nhà/admin chặn (`isBlockedByHost || isBlockedByAdmin`) hoặc đóng bán (`!isAvailable`).
 */
const assertCalendarAvailability = (
    dates: string[],
    calendarByDate: Map<string, { isAvailable: boolean; isBlockedByHost: boolean; isBlockedByAdmin?: boolean }>,
) => {
    const unavailableDates = dates.filter((date) => {
        const day = calendarByDate.get(date);
        return day ? day.isBlockedByHost || Boolean(day.isBlockedByAdmin) || !day.isAvailable : false;
    });

    if (unavailableDates.length > 0) {
        throw new ApiError(
            409,
            "Listing is not available for the selected dates",
            [
                {
                    path: "checkInDate",
                    msg: `Unavailable dates: ${unavailableDates.join(", ")}`,
                },
            ],
            { code: "DATES_UNAVAILABLE" },
        );
    }
};

/**
 * Giải thuật kiểm tra chống đặt trùng phòng bằng truy vấn khóa bi quan (`SELECT ... FOR UPDATE`) trên bảng `bookings`:
 * kết hợp bộ lọc trạng thái đang chiếm giữ lịch (`buildActiveBookingStatusWhere`) và bất đẳng thức giao cắt nửa mở (`buildBookingDateOverlapWhere`).
 */
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
        throw new ApiError(409, "Listing is already booked for the selected dates", undefined, {
            code: "DATES_UNAVAILABLE",
        });
    }
};

/**
 * Giải thuật thu hồi tức thì (lazy expiration) các đơn `pending_payment` đã hết hạn giữ chỗ đang chồng lấn khoảng ngày yêu cầu:
 * khóa bi quan `FOR UPDATE` các đơn quá hạn (`lockedUntil <= now` hoặc `lockedUntil IS NULL`) và gọi `expirePendingPaymentBookingInTransaction`
 * ngay trong cùng giao dịch đặt phòng mới để nhả khóa `booking_date_locks` kịp thời mà không bị trễ bởi chu kỳ quét nền.
 */
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

/**
 * Giải thuật ánh xạ mã trạng thái lưu trữ nội bộ (`BookingStatus`) sang mã trạng thái hợp đồng phản hồi API (`ApiBookingStatus`).
 */
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

/**
 * Giải thuật truy vấn giao dịch thanh toán mới nhất (`createdAt DESC`) gắn với một đơn đặt phòng.
 */
const getLatestPaymentForBooking = async (bookingId: number) =>
    Payment.findOne({
        where: {
            bookingId,
        },
        order: [["createdAt", "DESC"]],
    });

/**
 * Giải thuật truy vấn yêu cầu hoàn tiền mới nhất (`createdAt DESC`) gắn với một đơn đặt phòng.
 */
const getLatestRefundForBooking = async (bookingId: number) =>
    Refund.findOne({
        where: {
            bookingId,
        },
        order: [["createdAt", "DESC"]],
    });

/**
 * Giải thuật truy vấn trạng thái giải ngân mới nhất của đơn đặt phòng thông qua bảng liên kết `HostPayoutBookingItem` và lô `HostPayoutBatch`.
 */
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

/**
 * Giải thuật giải mã an toàn ảnh chụp cấu trúc giá (`priceBreakdown`) lưu ở định dạng chuỗi JSON hoặc đối tượng trong cơ sở dữ liệu.
 */
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

/**
 * Giải thuật tái tạo đầy đủ bảng kê chi tiết giá (`BookingPriceBreakdown`) cho phản hồi API,
 * tự động nội suy dự phòng từ các cột tổng trên bản ghi `Booking` đối với dữ liệu lịch sử chưa có ảnh chụp chi tiết.
 */
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

/**
 * Giải thuật tự động thăng cấp tuần tự trạng thái lưu trú theo mốc ngày hiện tại tại múi giờ Việt Nam (`UTC+7`):
 * - Đánh giá nối tiếp các chặng: `paid -> completed` (khi `today >= checkOutDate`), `confirmed -> checked_in` (khi `today >= checkInDate`),
 *   `checked_in -> checked_out` (khi `today >= checkOutDate`), và `checked_out -> completed`.
 * - Mỗi bước chuyển mở một giao dịch độc lập kèm khóa bi quan `SELECT ... FOR UPDATE` và đi qua máy trạng thái `transitionBookingStatus` (`actor = 'system'`).
 */
// Giải thuật quy đổi mốc giờ tiêu chuẩn nhận phòng (14:00) và trả phòng (12:00) theo múi giờ Việt Nam UTC+7 (TC-051, TC-053):
const toVietnamStandardCheckInMs = (dateStr: string) =>
    new Date(`${dateStr}T14:00:00+07:00`).getTime();

const toVietnamStandardCheckOutMs = (dateStr: string) =>
    new Date(`${dateStr}T12:00:00+07:00`).getTime();

const autoAdvanceBookingStatus = async (booking: BookingDocument): Promise<void> => {
    const nowMs = Date.now();
    const reachedCheckIn = nowMs >= toVietnamStandardCheckInMs(booking.checkInDate);
    const reachedCheckOut = nowMs >= toVietnamStandardCheckOutMs(booking.checkOutDate);

    // Giải thuật tự động chuyển tiếp đơn 'paid' đã quá hạn trả phòng (now >= checkOutDate 12:00 UTC+7):
    // Nếu khách đã thanh toán thành công, không bị hủy/từ chối và kỳ lưu trú đã kết thúc nhưng Host quên bấm xác nhận,
    // hệ thống tự chuyển sang 'completed' để đơn không bị treo vĩnh viễn ở tab "Sắp tới".
    if (booking.status === "paid" && reachedCheckOut) {
        try {
            await sequelize.transaction(async (transaction) => {
                const fresh = await getBookingOrThrow(booking.bookingId, transaction, true);
                if (fresh.status !== "paid") return;

                await transitionBookingStatus({
                    booking: fresh,
                    toStatus: "completed",
                    actor: "system",
                    changedByUserId: null,
                    reason: "auto_advance_paid_past_check_out",
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
            logger.warn("Auto-advance paid->completed failed", {
                bookingId: booking.bookingId,
                error: error instanceof Error ? error.message : String(error),
            });
        }
    }

    // confirmed -> checked_in (now >= checkInDate 14:00 UTC+7)
    if (booking.status === "confirmed" && reachedCheckIn) {
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

    // checked_in -> checked_out (now >= checkOutDate 12:00 UTC+7)
    if (booking.status === "checked_in" && reachedCheckOut) {
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

/**
 * Giải thuật hợp nhất và tuần tự hóa toàn diện thực thể `Booking`:
 * 1. Kích hoạt tự động thăng cấp trạng thái lưu trú (`autoAdvanceBookingStatus`).
 * 2. Tải song song (`Promise.all`) thông tin thanh toán, hoàn tiền, chi trả, căn hộ, đánh giá và hồ sơ Khách/Host.
 * 3. Tính thời gian giữ chỗ còn lại `remainingPaymentSeconds = max(0, floor((paymentExpiresAt - now) / 1000))` và suy diễn trạng thái hiển thị thời gian thực.
 */
const serializeBooking = async (booking: BookingDocument, includeImages = false) => {
    await autoAdvanceBookingStatus(booking);

    const [latestPayment, latestRefund, payoutStatus, listing, review, guestUser, hostUser] = await Promise.all([
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
        User.findById(booking.hostUserId),
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
        hostName: hostUser?.fullName ?? null,
        hostPhone: hostUser?.phone ?? null,
        host: hostUser
            ? {
                userId: hostUser.userId,
                fullName: hostUser.fullName,
                phone: hostUser.phone,
                email: hostUser.email,
            }
            : null,
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
        refundAmount: latestRefund ? toNumber(latestRefund.amount) : 0,
        cancellationPolicy: listing?.cancellationPolicy ?? "strict",
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
        cancellationReason: booking.cancellationReason ?? displayStatus.reason ?? null,
        cancellationReasonCode: displayStatus.reason ?? null,
        cancelledByUserId: booking.cancelledByUserId ? String(booking.cancelledByUserId) : null,
        cancelledAt: booking.cancelledAt ?? null,
        checkedInAt: booking.checkedInAt ?? null,
        checkedOutAt: booking.checkedOutAt ?? null,
        paidAt: booking.paidAt ?? null,
        createdAt: booking.createdAt,
        updatedAt: booking.updatedAt,
    };
};

/**
 * Giải thuật ghi nhận bản ghi lịch sử khởi tạo hoặc chuyển trạng thái đơn đặt phòng vào bảng `BookingStatusHistory` trong phạm vi `transaction`.
 */
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

/**
 * Giải thuật chuyển đổi tham số lọc `status` từ tầng API sang điều kiện `WHERE status IN (...)` của Sequelize dựa trên bảng ánh xạ `apiStatusToInternalStatuses`.
 */
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

/**
 * Giải thuật đối sánh trạng thái đơn đặt phòng đã tuần tự hóa với bộ lọc `status` của người dùng,
 * xử lý đồng bộ cả bí danh trạng thái cũ (`pending_host`, `cancelled`, `expired`) lẫn trạng thái suy diễn theo thời gian thực.
 */
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

/**
 * Giải thuật cắt lát phân trang trên mảng đơn đặt phòng đã tuần tự hóa và tính toán siêu dữ liệu `totalPages`.
 */
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

/**
 * Giải thuật truy vấn và phân trang danh sách đơn đặt phòng tương thích với trạng thái hiển thị suy diễn thời gian thực:
 * - Khi có bộ lọc `query.status`: tuần tự hóa và tự động thăng cấp trạng thái trước khi lọc chính xác qua `matchesSerializedBookingStatus`.
 * - Khi không lọc `status`: phân trang trực tiếp ở mức SQL (`LIMIT / OFFSET`) để tối ưu hiệu năng truy vấn.
 */
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

/**
 * Giải thuật kiểm tra quyền sở hữu đơn đặt phòng của phía khách lưu trú (`guestUserId === user.id`); ném lỗi `403 Forbidden` nếu không khớp.
 */
const assertGuestOwnsBooking = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (String(booking.guestUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật kiểm tra quyền quản lý đơn đặt phòng của phía chủ nhà (`hostUserId === user.id`) hoặc quyền đặc cách của quản trị viên (`admin`).
 */
const assertHostOwnsBooking = (booking: BookingDocument, user: AuthenticatedUser) => {
    if (user.roles.includes("admin")) {
        return;
    }

    if (String(booking.hostUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật tải bản ghi `Booking` theo định danh `bookingId`, hỗ trợ tùy chọn khóa bi quan mức dòng (`SELECT ... FOR UPDATE`) trong `transaction`;
 * ném lỗi `404 Not Found` nếu đơn không tồn tại.
 */
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

/**
 * Giải thuật truy xuất chính sách hủy phòng (`cancellationPolicy`) của căn hộ gắn với đơn trong `transaction`, mặc định dự phòng về `"strict"`.
 */
const getListingCancellationPolicy = async (booking: BookingDocument, transaction: Transaction) => {
    const listing = await Listing.findOne({
        where: {
            listingId: booking.listingId,
        },
        transaction,
    });

    return listing?.cancellationPolicy ?? "strict";
};

/**
 * Giải thuật tính khoảng cách thời gian còn lại (đơn vị giờ thực) từ thời điểm hiện tại tới mốc nhận phòng chuẩn `14:00:00+07:00` ngày `checkInDate`.
 */
const getHoursUntilCheckIn = (booking: BookingDocument) =>
    (toVietnamStandardCheckInMs(booking.checkInDate) - Date.now()) / (60 * 60 * 1000);

/**
 * Giải thuật tính số tiền hoàn trả theo chính sách hủy (`flexible` / `moderate` / `strict`), tác nhân hủy và số giờ còn lại trước `checkInDate`:
 * 1. Nếu hủy từ phía chủ nhà / quản trị (`actor === 'host'`): hoàn trả toàn bộ 100% `totalAmount` cho khách.
 * 2. Nếu khách tự hủy (`actor === 'guest'`):
 *    - Chính sách `flexible`: hoàn 100% nếu `hoursUntilCheckIn >= 24` (trước 1 ngày), ngược lại `0`.
 *    - Chính sách `moderate`: hoàn 100% nếu `hoursUntilCheckIn >= 120` (trước 5 ngày); hoàn 50% (`round(totalAmount * 0.5)`) nếu thuộc `[24, 120)`; ngược lại `0`.
 *    - Chính sách `strict`: hoàn 50% (`round(totalAmount * 0.5)`) nếu `hoursUntilCheckIn >= 168` (trước 7 ngày); ngược lại `0`.
 */
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

/**
 * Giải thuật khởi tạo phiếu hoàn tiền (`Refund` trạng thái `pending`) trong giao dịch ACID khi hủy đơn đã thu tiền:
 * khóa bi quan `FOR UPDATE` bản ghi `Payment` trạng thái `paid`, tính mức hoàn qua `calculateRefundAmount` và chỉ tạo bản ghi hoàn tiền khi `refundAmount > 0`.
 */
const createRefundForPaidPaymentIfNeeded = async (
    booking: BookingDocument,
    policy: CancellationPolicy,
    actor: CancellationActor,
    requestedByUserId: number,
    reason: string | null,
    transaction: Transaction,
    bankInfo?: {
        bankName?: string;
        accountNumber?: string;
        accountName?: string;
    },
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
            bankName: bankInfo?.bankName ? String(bankInfo.bankName).trim() : null,
            accountNumber: bankInfo?.accountNumber ? String(bankInfo.accountNumber).trim() : null,
            accountName: bankInfo?.accountName ? String(bankInfo.accountName).trim() : null,
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

/**
 * Giải thuật phân giải mã lý do hủy chuẩn hóa (`reasonCode`) và ghi chú tự do (`note`) đã làm sạch
 * dựa trên vai trò người dùng (`admin`, `host`, `guest`) và lý do đầu vào.
 */
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

/**
 * Giải thuật xác định tác nhân thực thi máy trạng thái (`BookingStateActor`), ưu tiên quyền `admin` nếu tài khoản có vai trò quản trị.
 */
const getBookingStateActor = (user: AuthenticatedUser, actor: CancellationActor | "system"): BookingStateActor => {
    if (actor === "system") {
        return "system";
    }

    return user.roles.includes("admin") ? "admin" : actor;
};

/**
 * Giải thuật suy diễn trạng thái hủy đích trên máy trạng thái FSM:
 * phân biệt rõ `cancelled_by_admin`, `cancelled_by_guest`, `rejected` (Host từ chối đơn `paid` trước khi xác nhận) và `cancelled_by_host` (Host hủy đơn đã `confirmed`).
 */
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

/**
 * Giải thuật hủy đơn đặt phòng nguyên tử trong giao dịch ACID:
 * 1. Khóa bi quan dòng `Booking` (`FOR UPDATE`), kiểm tra quyền sở hữu và xác thực cung chuyển FSM qua `assertBookingStatusTransition`.
 * 2. Tính toán và tạo phiếu hoàn tiền (nếu đơn đã thanh toán và đủ điều kiện hoàn theo chính sách hủy).
 * 3. Chuyển trạng thái đơn qua `transitionBookingStatus`, giải phóng toàn bộ khóa ngày `booking_date_locks`,
 *    hủy các phiên thanh toán `pending`, ghi nhật ký kiểm toán và gửi thông báo hủy/hoàn tiền trong cùng `transaction`.
 */
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
        const persistedReason = note ?? reasonCode;
        const policy = await getListingCancellationPolicy(existingBooking, transaction);
        const refund = await createRefundForPaidPaymentIfNeeded(
            existingBooking,
            policy,
            stateActor === "guest" ? "guest" : "host",
            Number(user.id),
            persistedReason,
            transaction,
            {
                bankName: input.bankName,
                accountNumber: input.accountNumber,
                accountName: input.accountName,
            },
        );

        const oldStatus = existingBooking.status;
        const cancelledAt = new Date();

        await transitionBookingStatus({
            booking: existingBooking,
            toStatus: nextStatus,
            actor: stateActor,
            changedByUserId: Number(user.id),
            reason: persistedReason,
            metadata: {
                cancellationPolicy: policy,
                refundId: refund?.refundId ?? null,
                refundAmount: refund ? toNumber(refund.amount) : 0,
                reasonCode,
                note,
            },
            transaction,
            mutate: (booking) => {
                booking.cancellationReason = persistedReason;
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

/**
 * Giải thuật chuẩn bị và kiểm định khóa ACID toàn diện trước khi khởi tạo đơn đặt phòng:
 * 1. Kiểm tra bất biến khoảng ngày và giới hạn số đơn giữ chỗ tối đa trên mỗi khách (`MAX_ACTIVE_PENDING_BOOKINGS_PER_GUEST = 10` chống đầu cơ giữ phòng).
 * 2. Khóa bi quan dòng `Listing` (`FOR UPDATE`), ngăn chủ nhà tự đặt phòng của chính mình, kiểm tra trần số khách `maxGuests`.
 * 3. Khóa bi quan lịch `AvailabilityCalendar` (`FOR UPDATE`), kiểm tra quy tắc số đêm tối thiểu/tối đa và trạng thái mở bán từng đêm.
 * 4. Thu hồi tức thì các đơn chờ quá hạn chồng lấn (`expireStaleOverlappingPendingPaymentBookings`), kiểm tra không còn đơn hiệu lực giao cắt ngày (`assertNoActiveOverlappingBooking`)
 *    và tính toán bảng giá chi tiết kèm khóa kiểm tra coupon (`calculateBookingPricing`).
 */
const prepareBookingCreate = async (
    user: AuthenticatedUser,
    input: CreateBookingInput,
    index: number,
    transaction: Transaction,
): Promise<PreparedBookingCreate> => {
    assertBookingDateRange(input);

    const canQueryBookingCount =
        Boolean((transaction as { commit?: unknown })?.commit) ||
        Object.prototype.hasOwnProperty.call(Booking, "count");

    if (canQueryBookingCount) {
        const activePendingCount = await Booking.count({
            where: {
                guestUserId: Number(user.id),
                status: "pending_payment",
                lockedUntil: {
                    [Op.gt]: new Date(),
                },
            },
            transaction,
        });

        if (activePendingCount + index >= MAX_ACTIVE_PENDING_BOOKINGS_PER_GUEST) {
            throw new ApiError(
                429,
                "Bạn đang có quá nhiều đơn đặt phòng chờ thanh toán. Vui lòng hoàn tất hoặc hủy đơn cũ trước.",
            );
        }
    }

    const listing = await getPublicListingForBooking(input.listingId, transaction);

    if (String(listing.hostId) === user.id) {
        throw new ApiError(403, "Chủ nhà không thể tự đặt phòng của chính mình.", undefined, {
            code: "SELF_BOOKING_FORBIDDEN",
        });
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

/**
 * Giải thuật ghi nhận bản ghi đơn đặt phòng mới và thiết lập khóa ngày ACID chống đặt trùng phòng:
 * 1. Cấp phát `bookingId` tuần tự nguyên tử qua `getNextBookingSequence(transaction)` và tính hạn giữ chỗ `lockedUntil = now + paymentHoldMinutes`.
 * 2. Khởi tạo bản ghi `Booking` trạng thái `pending_payment` (`version = 0`) lưu đầy đủ ảnh chụp `priceBreakdown`.
 * 3. Cấp phát khóa từng đêm `[checkInDate, checkOutDate)` trong bảng `booking_date_locks` (ràng buộc UNIQUE mức cơ sở dữ liệu triệt tiêu hoàn toàn race-condition double-booking).
 * 4. Ghi lịch sử trạng thái khởi tạo, nhật ký kiểm toán (`booking.create`) và thông báo trong cùng `transaction`.
 */
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
    const rawNote = input.bookingNote ?? input.specialRequests;
    const sanitizedBookingNote =
        typeof rawNote === "string" && sanitizeText(rawNote).length > 0 ? sanitizeText(rawNote) : null;
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
            bookingNote: sanitizedBookingNote,
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

/**
 * Giải thuật bù trừ Saga (Saga Compensation) dọn dẹp tài nguyên khi luồng đặt nhiều căn hộ đồng thời thất bại giữa chừng:
 * - Thực thi xóa ngược theo thứ tự phụ thuộc khóa ngoại (`BookingDateLock` -> `BookingStatusHistory` -> `AuditLog` -> `NotificationLog` -> `Booking`)
 *   cho tập `bookingIds` đã phát sinh trong phiên tạo lô.
 * - Mỗi bước dọn dẹp bọc trong khối `try/catch` cô lập lỗi để nỗ lực giải phóng tối đa khóa ngày và bản ghi mồi ngay cả khi một bảng phụ gặp sự cố.
 */
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

/**
 * Giải thuật tiền kiểm khả dụng chéo với Google Sheet của Host trước khi mở giao dịch cơ sở dữ liệu (khi runtime đồng bộ Sheet đang hoạt động),
 * tránh giữ khóa giao dịch DB trong thời gian chờ phản hồi mạng bên ngoài.
 */
const runPreBookingSheetVerifyIfActive = async (input: CreateBookingInput) => {
    if (!isHostSheetSyncRuntimeActive()) {
        return;
    }

    const listing = await Listing.findOne({
        where: {
            listingId: input.listingId,
            deletedAt: null,
        },
        attributes: ["listingId", "hostId", "status"],
    });

    if (!listing || listing.status !== "active") {
        return;
    }

    await verifySheetAvailabilityBeforeBooking({
        listingId: listing.listingId,
        hostUserId: Number(listing.hostId),
        checkInDate: input.checkInDate,
        checkOutDate: input.checkOutDate,
    });
};

/**
 * Giải thuật tạo đơn đặt phòng đơn lẻ chống đặt trùng (Anti-Double-Booking) bằng giao dịch ACID:
 * 1. Xác thực biên ngày và đối chiếu trước lịch Google Sheet ngoài giao dịch.
 * 2. Thực thi nguyên tử `prepareBookingCreate` + `createPreparedBooking` trong `sequelize.transaction` (kết hợp khóa bi quan `FOR UPDATE` và khóa UNIQUE `booking_date_locks`).
 * 3. Đẩy tác vụ đồng bộ ngược lên Google Sheet bất đồng bộ sau khi giao dịch đã commit thành công và trả về dữ liệu tuần tự hóa.
 */
export const createBooking = async (user: AuthenticatedUser, input: CreateBookingInput) => {
    assertBookingDateRange(input);
    await runPreBookingSheetVerifyIfActive(input);

    const booking = await sequelize.transaction(async (transaction) => {
        const prepared = await prepareBookingCreate(user, input, 0, transaction);

        return createPreparedBooking(user, prepared, transaction);
    });

    enqueueHostSheetSyncJobSafe({
        hostUserId: Number(booking.hostUserId),
        jobType: "booking_changed",
        listingId: booking.listingId,
        bookingId: booking.bookingId,
    });

    return serializeBooking(booking, true);
};

/**
 * Giải thuật đặt đồng thời nhiều căn hộ (Bulk Booking) kết hợp giao dịch ACID hai pha và cơ chế bù trừ Saga:
 * 1. Pha tiền kiểm ngoài giao dịch: kiểm định khoảng ngày từng mục, chống tự giao cắt chéo trong cùng lô (`assertNoOverlappingBulkItems`),
 *    và xác thực trước lịch trống trên Google Sheet cho toàn bộ mục.
 * 2. Pha giao dịch ACID hai bước: chuẩn bị và khóa kiểm định toàn bộ các mục (`prepareBookingCreate`) trước khi tuần tự ghi nhận (`createPreparedBooking`)
 *    kèm thu thập danh sách `createdForCompensation`.
 * 3. Pha bù trừ Saga khi lỗi: nếu bất kỳ mục nào thất bại hoặc giao dịch ném lỗi, kích hoạt `compensateBulkBookingCreation` để thu hồi triệt để khóa ngày và dữ liệu dở dang.
 * 4. Pha hậu cam kết: chỉ đẩy tác vụ đồng bộ Sheet và tuần tự hóa kết quả sau khi khối giao dịch đã commit an toàn (tách ngoài `try/catch` bù trừ để bảo toàn các đơn hợp lệ).
 */
export const createBulkBookings = async (user: AuthenticatedUser, input: CreateBulkBookingInput) => {
    input.items.forEach((item, index) => {
        try {
            assertBookingDateRange(item);
        } catch (error) {
            throwBulkItemError(index, error);
        }
    });
    assertNoOverlappingBulkItems(input.items);

    for (const [index, item] of input.items.entries()) {
        await withBulkItemError(index, () => runPreBookingSheetVerifyIfActive(item));
    }

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
    for (const committed of committedBookings) {
        enqueueHostSheetSyncJobSafe({
            hostUserId: Number(committed.hostUserId),
            jobType: "booking_changed",
            listingId: committed.listingId,
            bookingId: committed.bookingId,
        });
    }

    return {
        items: await Promise.all(committedBookings.map((booking) => serializeBooking(booking, true))),
    };
};

/**
 * Giải thuật truy vấn danh sách đơn đặt phòng của khách đang đăng nhập sau khi quét thu hồi các đơn chờ quá hạn (`expirePendingPaymentBookings`).
 */
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

/**
 * Giải thuật truy vấn chi tiết một đơn đặt phòng dành cho khách: kích hoạt thu hồi lười nếu đã quá hạn thanh toán, kiểm tra quyền sở hữu và tuần tự hóa kèm ảnh căn hộ.
 */
export const getGuestBookingDetail = async (user: AuthenticatedUser, bookingId: number) => {
    await expirePendingPaymentBooking(bookingId);
    const booking = await getBookingOrThrow(bookingId);
    assertGuestOwnsBooking(booking, user);
    return serializeBooking(booking, true);
};

/**
 * Giải thuật hủy đơn đặt phòng từ phía khách lưu trú, ủy quyền vào luồng hủy nguyên tử `cancelBooking` với tác nhân `"guest"`.
 */
export const cancelGuestBooking = async (
    user: AuthenticatedUser,
    bookingId: number,
    input: CancelBookingInput,
) => cancelBooking(user, bookingId, input, "guest");

/**
 * Giải thuật truy vấn danh sách đơn đặt phòng thuộc quyền quản lý của Host (hoặc toàn bộ đơn nếu là `admin`) sau khi thu hồi các đơn quá hạn giữ chỗ.
 */
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

/**
 * Giải thuật truy vấn chi tiết đơn đặt phòng dành cho Host hoặc Admin sau khi đồng bộ trạng thái quá hạn thanh toán.
 */
export const getHostBookingDetail = async (user: AuthenticatedUser, bookingId: number) => {
    await expirePendingPaymentBooking(bookingId);
    const booking = await getBookingOrThrow(bookingId);
    assertHostOwnsBooking(booking, user);
    return serializeBooking(booking, true);
};

/**
 * Giải thuật xác nhận đơn đặt phòng của Host (`paid -> confirmed`) trong giao dịch ACID:
 * khóa bi quan đơn `FOR UPDATE`, kiểm tra quyền Host/Admin, xác thực bắt buộc đã có giao dịch `Payment` trạng thái `paid`,
 * thực thi chuyển trạng thái qua FSM, xóa hạn giữ chỗ `lockedUntil = null`, ghi kiểm toán và gửi thông báo xác nhận.
 */
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

/**
 * Giải thuật ghi nhận khách nhận phòng (`confirmed -> checked_in`) trong giao dịch ACID:
 * khóa bi quan đơn `FOR UPDATE`, kiểm tra bất biến ngày hiện tại theo giờ Việt Nam đã chạm mốc `checkInDate` (`todayVN >= checkInDate`),
 * chuyển trạng thái qua máy trạng thái FSM (kiểm tra điều kiện của Host/Admin), đóng dấu `checkedInAt` và ghi nhật ký kiểm toán.
 */
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

/**
 * Giải thuật ghi nhận khách trả phòng (`checked_in -> checked_out`) trong giao dịch ACID:
 * khóa bi quan đơn `FOR UPDATE`, kiểm tra bất biến ngày hiện tại theo giờ Việt Nam đã chạm hoặc vượt mốc `checkOutDate` (`todayVN >= checkOutDate`),
 * chuyển trạng thái qua máy trạng thái FSM, đóng dấu `checkedOutAt` và ghi nhật ký kiểm toán.
 */
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

/**
 * Giải thuật hủy hoặc từ chối đơn đặt phòng từ phía Host/Admin, ủy quyền vào luồng hủy nguyên tử `cancelBooking` với tác nhân `"host"`.
 */
export const cancelHostBooking = async (
    user: AuthenticatedUser,
    bookingId: number,
    input: CancelBookingInput,
) => cancelBooking(user, bookingId, input, "host");
