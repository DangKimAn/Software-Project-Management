const assert = require("node:assert/strict");
const { afterEach, describe, it } = require("node:test");

const { Op, UniqueConstraintError } = require("sequelize");
import type { PatchEntry, Rejectable, TransactionCallback } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default;
const AvailabilityCalendar = require("../dist/models/availability-calendar").default;
const AuditLog = require("../dist/models/audit-log").default;
const Booking = require("../dist/models/booking").default;
const BookingDateLock = require("../dist/models/booking-date-lock").default;
const BookingStatusHistory = require("../dist/models/booking-status-history").default;
const Coupon = require("../dist/models/coupon").default;
const CouponRedemption = require("../dist/models/coupon-redemption").default;
const Listing = require("../dist/models/listing").default;
const ListingImage = require("../dist/models/listing-image").default;
const NotificationLog = require("../dist/models/notification-log").default;
const Payment = require("../dist/models/payment").default;
const Refund = require("../dist/models/refund").default;
const bookingExpirationService = require("../dist/services/booking-expiration.service");
const bookingsService = require("../dist/modules/bookings/bookings.service");
const notificationService = require("../dist/modules/notifications/notification.service");
const { assertBookingStatusTransition } = require("../dist/modules/bookings/booking-state-machine");

type QueryOptions = {
    type?: unknown;
    where?: {
        listingId?: number;
    };
};
type SequelizeWhere = Record<PropertyKey, unknown>;

const originals: PatchEntry[] = [];

const patch = (target: Record<string, unknown>, key: string, value: unknown): void => {
    originals.push([target, key, target[key]]);
    target[key] = value;
};

afterEach(() => {
    while (originals.length > 0) {
        const [target, key, value] = originals.pop()!;
        target[key] = value;
    }
});

const guestUser = {
    id: "201",
    email: "guest@example.com",
    phone: "0900000201",
    name: "Guest User",
    username: "guest",
    status: "active",
    roles: ["guest"],
};

const hostUser = {
    id: "101",
    email: "host@example.com",
    phone: "0900000101",
    name: "Host User",
    username: "host",
    status: "active",
    roles: ["host"],
};

const otherHostUser = {
    ...hostUser,
    id: "999",
};

const buildListing = (overrides: Record<string, unknown> = {}) => ({
    listingId: 801,
    hostId: 101,
    status: "active",
    deletedAt: null,
    title: "Seaside villa",
    city: "Vung Tau",
    district: "Ward 1",
    addressLine: "123 Tran Phu",
    maxGuests: 4,
    basePrice: 1000000,
    weekendPrice: null,
    cleaningFee: 100000,
    serviceFeePct: 10,
    currency: "VND",
    minNights: 1,
    maxNights: 10,
    instantBookEnabled: true,
    cancellationPolicy: "moderate",
    images: [],
    availabilityCalendar: [],
    ...overrides,
});

const buildBooking = (overrides: Record<string, unknown> = {}) => ({
    bookingId: 9001,
    listingId: 801,
    guestUserId: 201,
    hostUserId: 101,
    checkInDate: "2026-06-20",
    checkOutDate: "2026-06-22",
    guestCount: 2,
    nights: 2,
    totalNights: 2,
    status: "confirmed",
    version: 0,
    lockedUntil: null,
    currency: "VND",
    couponId: null,
    subtotalAmount: 2000000,
    cleaningFeeAmount: 100000,
    serviceFeeAmount: 200000,
    discountAmount: 0,
    totalAmount: 2300000,
    priceBreakdown: null,
    bookingNote: null,
    cancellationReason: null,
    cancelledByUserId: null,
    cancelledAt: null,
    checkedInAt: null,
    checkedOutAt: null,
    paidAt: null,
    createdAt: new Date("2026-05-10T00:00:00.000Z"),
    updatedAt: new Date("2026-05-10T00:00:00.000Z"),
    async save() {
        return this;
    },
    ...overrides,
});
type BookingStub = ReturnType<typeof buildBooking>;

const getOpValue = <T>(value: unknown, op: symbol): T | undefined => {
    if (!value || typeof value !== "object") {
        return undefined;
    }

    return (value as Record<PropertyKey, T>)[op];
};

const matchesDateRangeWhere = (booking: BookingStub, where: SequelizeWhere) => {
    const checkInBefore = getOpValue<string>(where.checkInDate, Op.lt);
    const checkOutAfter = getOpValue<string>(where.checkOutDate, Op.gt);

    return (
        (!checkInBefore || booking.checkInDate < checkInBefore) &&
        (!checkOutAfter || booking.checkOutDate > checkOutAfter)
    );
};

const matchesPendingPaymentClause = (booking: BookingStub, clause: SequelizeWhere) => {
    const lockedAfter = getOpValue<Date>(clause.lockedUntil, Op.gt);
    const bookingLockedUntil = booking.lockedUntil as unknown;

    return bookingLockedUntil instanceof Date && lockedAfter instanceof Date && bookingLockedUntil > lockedAfter;
};

const matchesActiveStatusClause = (booking: BookingStub, clause: SequelizeWhere) => {
    const status = clause.status;

    if (status === "pending_payment") {
        return booking.status === "pending_payment" && matchesPendingPaymentClause(booking, clause);
    }

    if (status === "checked_out") {
        const checkOutAfter = getOpValue<string>(clause.checkOutDate, Op.gt);

        return booking.status === "checked_out" && (!checkOutAfter || booking.checkOutDate > checkOutAfter);
    }

    const blockingStatuses = getOpValue<string[]>(status, Op.in);

    return Boolean(blockingStatuses?.includes(String(booking.status)));
};

const matchesActiveOverlappingBookingWhere = (booking: BookingStub, where: SequelizeWhere) => {
    if (where.listingId !== undefined && booking.listingId !== where.listingId) {
        return false;
    }

    if (!matchesDateRangeWhere(booking, where)) {
        return false;
    }

    const statusClauses = (where[Op.or] as SequelizeWhere[] | undefined) ?? [];

    return statusClauses.some((clause) => matchesActiveStatusClause(booking, clause));
};

const patchExistingBookings = (existingBookings: BookingStub[]) => {
    patch(Booking, "findOne", async (options: { where?: SequelizeWhere } = {}) =>
        existingBookings.find((booking) => matchesActiveOverlappingBookingWhere(booking, options.where ?? {})) ?? null,
    );
};

const patchTransaction = () => {
    patch(sequelize, "transaction", async (callback: TransactionCallback) =>
        callback({
            LOCK: {
                UPDATE: "UPDATE",
            },
        }),
    );
    patch(sequelize, "query", async (_sql: string, options: QueryOptions = {}) => {
        if (options.type) {
            return [{ value: 9001 }];
        }

        return [];
    });
};

const patchNotification = () => {
    patch(notificationService, "notifyBookingCreated", async () => { });
    patch(notificationService, "notifyPaymentPending", async () => { });
    patch(notificationService, "notifyPaymentSuccess", async () => { });
    patch(notificationService, "notifyPaymentExpired", async () => { });
    patch(notificationService, "notifyBookingConfirmed", async () => { });
    patch(notificationService, "notifyBookingCancelled", async () => { });
};

const patchSerialization = (listing = buildListing()) => {
    patchNotification();
    patch(Payment, "findOne", async () => null);
    patch(Refund, "findOne", async () => null);
    patch(ListingImage, "findAll", async () => []);
    patch(AuditLog, "create", async () => ({}));
    patch(BookingStatusHistory, "create", async () => ({}));
    patch(NotificationLog, "create", async () => ({}));
    patch(Listing, "findOne", async (options: QueryOptions = {}) => {
        if (options.where?.listingId === listing.listingId) {
            return listing;
        }

        return null;
    });
};

const patchCreateBookingHappyPath = (listing = buildListing()) => {
    patchTransaction();
    patchSerialization(listing);
    patch(AvailabilityCalendar, "findAll", async () => []);
    patch(Booking, "findAll", async () => []);
    patch(Booking, "findOne", async () => null);
    patch(Booking, "create", async (payload: Record<string, unknown>) => buildBooking(payload));
    patch(BookingDateLock, "bulkCreate", async () => []);
    patch(Coupon, "findOne", async () => null);
    patch(Coupon, "increment", async () => { });
    patch(CouponRedemption, "count", async () => 0);
    patch(CouponRedemption, "create", async () => ({}));
};

const assertRejectsApiError = async (fn: Rejectable, statusCode: number): Promise<void> => {
    await assert.rejects(fn, (error: unknown) => {
        assert.equal(error instanceof ApiError, true);
        assert.equal((error as { statusCode: number }).statusCode, statusCode);
        return true;
    });
};

describe("Bookings service transaction-safe business rules", () => {
    it("creates a booking from trusted listing pricing, not client totals", async () => {
        patchCreateBookingHappyPath();

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            guestCount: 2,
        });

        assert.equal(result.bookingId, 9001);
        assert.equal(result.status, "pending_payment");
        assert.equal(result.subtotalAmount, 2000000);
        assert.equal(result.cleaningFeeAmount, 100000);
        assert.equal(result.serviceFeeAmount, 200000);
        assert.equal(result.totalPrice, 2300000);
        assert.equal(result.totalNights, 2);
        assert.equal(result.priceBreakdown.subtotalAmount, 2000000);
    });

    it("bulk creates two valid bookings", async () => {
        patchCreateBookingHappyPath();
        let nextBookingId = 9000;
        const createdBookingIds: number[] = [];

        patch(sequelize, "query", async (_sql: string, options: QueryOptions = {}) => {
            if (options.type) {
                nextBookingId += 1;
                return [{ value: nextBookingId }];
            }

            return [];
        });
        patch(Booking, "create", async (payload: Record<string, unknown>) => {
            createdBookingIds.push(Number(payload.bookingId));
            return buildBooking(payload);
        });

        const result = await bookingsService.createBulkBookings(guestUser, {
            items: [
                {
                    listingId: 801,
                    checkInDate: "2026-06-20",
                    checkOutDate: "2026-06-22",
                    guestCount: 2,
                },
                {
                    listingId: 801,
                    checkInDate: "2026-06-24",
                    checkOutDate: "2026-06-26",
                    guestCount: 2,
                },
            ],
        });

        assert.equal(result.items.length, 2);
        assert.deepEqual(createdBookingIds, [9001, 9002]);
        assert.equal(result.items[0].status, "pending_payment");
        assert.equal(result.items[1].status, "pending_payment");
    });

    it("rejects the whole bulk booking when a later item overlaps an active booking", async () => {
        patchCreateBookingHappyPath();
        let createCount = 0;

        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "confirmed",
                checkInDate: "2026-07-01",
                checkOutDate: "2026-07-03",
            }),
        ]);
        patch(Booking, "create", async (payload: Record<string, unknown>) => {
            createCount += 1;
            return buildBooking(payload);
        });

        await assertRejectsApiError(
            () =>
                bookingsService.createBulkBookings(guestUser, {
                    items: [
                        {
                            listingId: 801,
                            checkInDate: "2026-06-20",
                            checkOutDate: "2026-06-22",
                            guestCount: 2,
                        },
                        {
                            listingId: 801,
                            checkInDate: "2026-07-02",
                            checkOutDate: "2026-07-04",
                            guestCount: 2,
                        },
                    ],
                }),
            409,
        );
        assert.equal(createCount, 0);
    });

    it("compensates the first bulk booking when a later create fails", async () => {
        patchCreateBookingHappyPath();
        let nextBookingId = 9000;
        let createCount = 0;
        const activePendingBookings = new Set<number>();
        const destroyedBookingIds: number[] = [];

        patch(sequelize, "query", async (_sql: string, options: QueryOptions = {}) => {
            if (options.type) {
                nextBookingId += 1;
                return [{ value: nextBookingId }];
            }

            return [];
        });
        patch(Booking, "create", async (payload: Record<string, unknown>) => {
            createCount += 1;

            if (createCount === 2) {
                throw new Error("Simulated booking insert failure");
            }

            activePendingBookings.add(Number(payload.bookingId));
            return buildBooking(payload);
        });
        patch(BookingDateLock, "destroy", async () => 2);
        patch(BookingStatusHistory, "destroy", async () => 1);
        patch(Booking, "destroy", async (options: { where?: { bookingId?: Record<PropertyKey, number[]> } } = {}) => {
            const ids = getOpValue<number[]>(options.where?.bookingId, Op.in) ?? [];

            ids.forEach((bookingId) => {
                activePendingBookings.delete(bookingId);
                destroyedBookingIds.push(bookingId);
            });
            return ids.length;
        });

        await assertRejectsApiError(
            () =>
                bookingsService.createBulkBookings(guestUser, {
                    items: [
                        {
                            listingId: 801,
                            checkInDate: "2026-06-20",
                            checkOutDate: "2026-06-22",
                            guestCount: 2,
                        },
                        {
                            listingId: 801,
                            checkInDate: "2026-06-24",
                            checkOutDate: "2026-06-26",
                            guestCount: 2,
                        },
                    ],
                }),
            500,
        );
        assert.equal(createCount, 2);
        assert.deepEqual(destroyedBookingIds, [9001]);
        assert.equal(activePendingBookings.size, 0);
    });

    it("prices weekday nights from listing base price", async () => {
        patchCreateBookingHappyPath(buildListing({
            basePrice: 1000000,
            weekendPrice: 1800000,
            cleaningFee: 100000,
            serviceFeePct: 10,
        }));

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-22",
            checkOutDate: "2026-06-24",
            guestCount: 2,
        });

        assert.equal(result.priceBreakdown.weekdayNights, 2);
        assert.equal(result.priceBreakdown.weekendNights, 0);
        assert.equal(result.subtotalAmount, 2000000);
        assert.equal(result.serviceFeeAmount, 200000);
        assert.equal(result.totalAmount, 2300000);
    });

    it("prices weekend nights from listing weekend price", async () => {
        patchCreateBookingHappyPath(buildListing({
            basePrice: 1000000,
            weekendPrice: 1800000,
            cleaningFee: 100000,
            serviceFeePct: 10,
        }));

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            guestCount: 2,
        });

        assert.equal(result.priceBreakdown.weekdayNights, 0);
        assert.equal(result.priceBreakdown.weekendNights, 2);
        assert.equal(result.subtotalAmount, 3600000);
        assert.equal(result.serviceFeeAmount, 360000);
        assert.equal(result.totalAmount, 4060000);
    });

    it("uses calendar price overrides before listing base or weekend price", async () => {
        patchCreateBookingHappyPath(buildListing({
            basePrice: 1000000,
            weekendPrice: 1800000,
            cleaningFee: 0,
            serviceFeePct: 0,
        }));
        patch(AvailabilityCalendar, "findAll", async () => [
            {
                date: "2026-06-20",
                isAvailable: true,
                isBlockedByHost: false,
                priceOverride: 2500000,
                minNightsOverride: null,
                notes: null,
            },
        ]);

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-21",
            guestCount: 2,
        });

        assert.equal(result.subtotalAmount, 2500000);
        assert.equal(result.totalAmount, 2500000);
        assert.equal(result.priceBreakdown.nightlyPrices[0].source, "calendar");
    });

    it("applies coupon discount to the backend-calculated total", async () => {
        patchCreateBookingHappyPath(buildListing({
            basePrice: 1000000,
            weekendPrice: null,
            cleaningFee: 100000,
            serviceFeePct: 10,
        }));
        let redemptionCreated = 0;
        let couponUsageIncremented = 0;

        patch(Coupon, "findOne", async () => ({
            couponId: 7,
            code: "SUMMER10",
            type: "percent",
            discountValue: 10,
            maxDiscountAmount: null,
            minOrderValue: null,
            startDate: new Date("2026-01-01T00:00:00.000Z"),
            endDate: new Date("2027-01-01T00:00:00.000Z"),
            totalLimit: 100,
            usedCount: 0,
            limitPerUser: null,
            isActive: true,
            deletedAt: null,
        }));
        patch(CouponRedemption, "create", async () => {
            redemptionCreated += 1;
            return {};
        });
        patch(Coupon, "increment", async () => {
            couponUsageIncremented += 1;
        });

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-22",
            checkOutDate: "2026-06-24",
            guestCount: 2,
            couponCode: "summer10",
        });

        assert.equal(result.discountAmount, 230000);
        assert.equal(result.totalAmount, 2070000);
        assert.equal(result.couponId, 7);
        assert.equal(result.priceBreakdown.couponCode, "SUMMER10");
        assert.equal(redemptionCreated, 0);
        assert.equal(couponUsageIncremented, 0);
    });

    it("does not count an expired unpaid booking against coupon usage", async () => {
        patchCreateBookingHappyPath(buildListing({
            basePrice: 1000000,
            weekendPrice: null,
            cleaningFee: 100000,
            serviceFeePct: 10,
        }));
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "payment_expired",
                couponId: 7,
                discountAmount: 230000,
                lockedUntil: null,
            }),
        ]);
        patch(Coupon, "findOne", async () => ({
            couponId: 7,
            code: "SUMMER10",
            type: "percent",
            discountValue: 10,
            maxDiscountAmount: null,
            minOrderValue: null,
            startDate: new Date("2026-01-01T00:00:00.000Z"),
            endDate: new Date("2027-01-01T00:00:00.000Z"),
            totalLimit: 1,
            usedCount: 0,
            limitPerUser: 1,
            isActive: true,
            deletedAt: null,
        }));
        patch(CouponRedemption, "count", async () => 0);

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-22",
            checkOutDate: "2026-06-24",
            guestCount: 2,
            couponCode: "summer10",
        });

        assert.equal(result.status, "pending_payment");
        assert.equal(result.couponId, 7);
        assert.equal(result.discountAmount, 230000);
    });

    it("adds extra guest fee when guest count exceeds included guests", async () => {
        patchCreateBookingHappyPath(buildListing({
            basePrice: 1000000,
            weekendPrice: null,
            cleaningFee: 0,
            serviceFeePct: 10,
            maxGuests: 6,
            includedGuests: 2,
            extraGuestFee: 100000,
        }));

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-22",
            checkOutDate: "2026-06-24",
            guestCount: 4,
        });

        assert.equal(result.subtotalAmount, 2000000);
        assert.equal(result.extraGuestFeeAmount, 400000);
        assert.equal(result.serviceFeeAmount, 240000);
        assert.equal(result.totalAmount, 2640000);
        assert.deepEqual(result.priceBreakdown.extraGuest, {
            includedGuests: 2,
            extraGuests: 2,
            feePerGuestPerNight: 100000,
        });
    });

    it("keeps booking total unchanged when host changes listing price after booking", async () => {
        const listing = buildListing({
            basePrice: 1000000,
            weekendPrice: null,
            cleaningFee: 0,
            serviceFeePct: 0,
        });
        let createdBooking: BookingStub | null = null;

        patchCreateBookingHappyPath(listing);
        patch(Booking, "create", async (payload: Record<string, unknown>) => {
            createdBooking = buildBooking(payload);
            return createdBooking;
        });

        const created = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-22",
            checkOutDate: "2026-06-24",
            guestCount: 2,
        });

        listing.basePrice = 9000000;
        patch(Booking, "findOne", async () => createdBooking);

        const detail = await bookingsService.getGuestBookingDetail(guestUser, created.bookingId);

        assert.equal(created.totalAmount, 2000000);
        assert.equal(detail.totalAmount, 2000000);
        assert.equal(detail.priceBreakdown.nightlyPrice, 1000000);
    });

    it("returns 409 when date lock insertion detects a double booking", async () => {
        patchCreateBookingHappyPath();
        patch(BookingDateLock, "bulkCreate", async () => {
            throw new UniqueConstraintError({ errors: [] });
        });

        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-06-20",
                    checkOutDate: "2026-06-22",
                    guestCount: 2,
                }),
            409,
        );
    });

    it("blocks dates while a pending payment booking is still within its hold", async () => {
        patchCreateBookingHappyPath();
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "pending_payment",
                lockedUntil: new Date(Date.now() + 10 * 60 * 1000),
            }),
        ]);

        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-06-20",
                    checkOutDate: "2026-06-22",
                    guestCount: 2,
                }),
            409,
        );
    });

    it("allows a booking to check in on the previous booking's checkout date", async () => {
        patchCreateBookingHappyPath();
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "confirmed",
                checkInDate: "2026-07-01",
                checkOutDate: "2026-07-03",
            }),
        ]);

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-07-03",
            checkOutDate: "2026-07-05",
            guestCount: 2,
        });

        assert.equal(result.status, "pending_payment");
    });

    it("blocks a booking that overlaps an existing stay", async () => {
        patchCreateBookingHappyPath();
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "confirmed",
                checkInDate: "2026-07-01",
                checkOutDate: "2026-07-03",
            }),
        ]);

        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-07-02",
                    checkOutDate: "2026-07-04",
                    guestCount: 2,
                }),
            409,
        );
    });

    it("blocks booking dates manually closed by the host calendar", async () => {
        patchCreateBookingHappyPath(buildListing({
            availabilityCalendar: [
                {
                    date: "2026-07-02",
                    isAvailable: false,
                    isBlockedByHost: true,
                    priceOverride: null,
                    minNightsOverride: null,
                    notes: "Owner block",
                },
            ],
        }));

        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-07-01",
                    checkOutDate: "2026-07-03",
                    guestCount: 2,
                }),
            409,
        );
    });

    it("allows only one concurrent booking to hold the same reserved dates", async () => {
        patchCreateBookingHappyPath();
        const activeLocks = new Set<string>();
        let nextBookingId = 9000;

        patch(sequelize, "query", async (_sql: string, options: QueryOptions = {}) => {
            if (options.type) {
                nextBookingId += 1;
                return [{ value: nextBookingId }];
            }

            return [];
        });
        patch(BookingDateLock, "bulkCreate", async (rows: Array<{ listingId: number; reservedDate: string }>) => {
            await new Promise((resolve) => setImmediate(resolve));

            const keys = rows.map((row) => `${row.listingId}:${row.reservedDate}`);

            if (keys.some((key) => activeLocks.has(key))) {
                throw new UniqueConstraintError({ errors: [] });
            }

            keys.forEach((key) => activeLocks.add(key));
            return rows;
        });

        const results = await Promise.allSettled([
            bookingsService.createBooking(guestUser, {
                listingId: 801,
                checkInDate: "2026-07-01",
                checkOutDate: "2026-07-03",
                guestCount: 2,
            }),
            bookingsService.createBooking(guestUser, {
                listingId: 801,
                checkInDate: "2026-07-01",
                checkOutDate: "2026-07-03",
                guestCount: 2,
            }),
        ]);

        const fulfilled = results.filter((result) => result.status === "fulfilled");
        const rejected = results.filter((result) => result.status === "rejected") as PromiseRejectedResult[];

        assert.equal(fulfilled.length, 1);
        assert.equal(rejected.length, 1);
        assert.equal(rejected[0].reason instanceof ApiError, true);
        assert.equal((rejected[0].reason as { statusCode: number }).statusCode, 409);
    });

    it("blocks checked_out bookings while the stay has not reached checkout date", async () => {
        patchCreateBookingHappyPath();
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "checked_out",
                checkInDate: "2026-06-20",
                checkOutDate: "2026-06-22",
            }),
        ]);

        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-06-20",
                    checkOutDate: "2026-06-22",
                    guestCount: 2,
                }),
            409,
        );
    });

    it("allows dates held by payment_expired bookings to be booked again", async () => {
        patchCreateBookingHappyPath();
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "payment_expired",
                lockedUntil: null,
            }),
        ]);

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            guestCount: 2,
        });

        assert.equal(result.status, "pending_payment");
    });

    it("expires stale pending payment holds and opens the dates again", async () => {
        patchCreateBookingHappyPath();
        const staleBooking = buildBooking({
            bookingId: 9002,
            status: "pending_payment",
            checkInDate: "2026-07-01",
            checkOutDate: "2026-07-03",
            lockedUntil: new Date(Date.now() - 60 * 1000),
            cancellationReason: null,
        });
        let releasedLocks = false;

        patch(Booking, "findAll", async () => [staleBooking]);
        patch(Payment, "update", async () => [1]);
        patch(BookingDateLock, "update", async () => {
            releasedLocks = true;
            return [2];
        });

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-07-01",
            checkOutDate: "2026-07-03",
            guestCount: 2,
        });

        assert.equal(staleBooking.status, "payment_expired");
        assert.equal(staleBooking.lockedUntil, null);
        assert.equal(staleBooking.cancellationReason, "PAYMENT_EXPIRED");
        assert.equal(releasedLocks, true);
        assert.equal(result.status, "pending_payment");
    });

    it("allows a new booking to check in on another booking's checkout date", async () => {
        patchCreateBookingHappyPath();
        patchExistingBookings([
            buildBooking({
                bookingId: 9002,
                status: "confirmed",
                checkInDate: "2026-06-18",
                checkOutDate: "2026-06-20",
            }),
        ]);

        const result = await bookingsService.createBooking(guestUser, {
            listingId: 801,
            checkInDate: "2026-06-20",
            checkOutDate: "2026-06-22",
            guestCount: 2,
        });

        assert.equal(result.status, "pending_payment");
    });

    it("returns 422 when guestCount exceeds listing maxGuests", async () => {
        patchCreateBookingHappyPath(buildListing({ maxGuests: 2 }));

        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-06-20",
                    checkOutDate: "2026-06-22",
                    guestCount: 3,
                }),
            422,
        );
    });

    it("returns 422 when checkout is before checkin", async () => {
        await assertRejectsApiError(
            () =>
                bookingsService.createBooking(guestUser, {
                    listingId: 801,
                    checkInDate: "2026-06-22",
                    checkOutDate: "2026-06-20",
                    guestCount: 2,
                }),
            422,
        );
    });

    it("returns 403 when a guest tries to view or cancel another guest booking", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ guestUserId: 999 }));

        await assertRejectsApiError(() => bookingsService.getGuestBookingDetail(guestUser, 9001), 403);
        await assertRejectsApiError(() => bookingsService.cancelGuestBooking(guestUser, 9001, {}), 403);
    });

    it("returns 403 when a host confirms a booking outside their listings", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ hostUserId: 101, status: "pending" }));

        await assertRejectsApiError(() => bookingsService.confirmHostBooking(otherHostUser, 9001), 403);
    });

    it("returns 403 when a host views or cancels a booking outside their listings", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ hostUserId: 101, status: "confirmed" }));

        await assertRejectsApiError(() => bookingsService.getHostBookingDetail(otherHostUser, 9001), 403);
        await assertRejectsApiError(() => bookingsService.cancelHostBooking(otherHostUser, 9001, {}), 403);
    });

    it("returns 403 when a host checks in or checks out a booking outside their listings", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ hostUserId: 101, status: "confirmed" }));

        await assertRejectsApiError(() => bookingsService.checkInHostBooking(otherHostUser, 9001), 403);

        patch(Booking, "findOne", async () => buildBooking({ hostUserId: 101, status: "checked_in" }));

        await assertRejectsApiError(() => bookingsService.checkOutHostBooking(otherHostUser, 9001), 403);
    });

    it("returns 409 when cancelling an invalid status", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ status: "completed" }));

        await assertRejectsApiError(() => bookingsService.cancelGuestBooking(guestUser, 9001, {}), 409);
    });

    it("returns 409 when check-in is requested for the wrong status", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ status: "pending" }));

        await assertRejectsApiError(() => bookingsService.checkInHostBooking(hostUser, 9001), 409);
    });

    it("returns 409 when check-out is requested before check-in", async () => {
        patchTransaction();
        patch(Booking, "findOne", async () => buildBooking({ status: "confirmed" }));

        await assertRejectsApiError(() => bookingsService.checkOutHostBooking(hostUser, 9001), 409);
    });

    it("releases date locks when a host rejects a paid booking", async () => {
        patchTransaction();
        patchSerialization();
        const booking = buildBooking({
            status: "paid",
            paidAt: new Date("2026-05-10T00:00:00.000Z"),
        });
        let releasedLocks = false;

        patch(Booking, "findOne", async () => booking);
        patch(Payment, "update", async () => [1]);
        patch(BookingDateLock, "update", async (payload: Record<string, unknown>) => {
            releasedLocks = payload.status === "released";
            return [2];
        });

        await bookingsService.cancelHostBooking(hostUser, 9001, { reason: "No longer available" });

        assert.equal(booking.status, "rejected");
        assert.equal(releasedLocks, true);
    });

    it("rejects invalid booking lifecycle jumps in the state machine", () => {
        assert.throws(
            () => assertBookingStatusTransition({ from: "pending_payment", to: "completed", actor: "system" }),
            /Invalid booking status transition/,
        );
        assert.throws(
            () => assertBookingStatusTransition({ from: "paid", to: "checked_in", actor: "host" }),
            /Invalid booking status transition/,
        );
        assert.throws(
            () => assertBookingStatusTransition({ from: "payment_expired", to: "confirmed", actor: "admin" }),
            /Invalid booking status transition/,
        );
    });

    it("expires pending payment bookings with payment_expired status and releases date locks", async () => {
        patchTransaction();
        patchNotification();
        const booking = buildBooking({
            status: "pending_payment",
            lockedUntil: new Date(Date.now() - 60 * 1000),
            cancellationReason: null,
            cancelledAt: null,
        });
        const capturedUpdates: {
            payment?: Record<string, unknown>;
            dateLock?: Record<string, unknown>;
        } = {};

        patch(Booking, "findOne", async () => booking);
        patch(Payment, "findOne", async () => null);
        patch(Payment, "update", async (payload: Record<string, unknown>) => {
            capturedUpdates.payment = payload;
            return [1];
        });
        patch(BookingDateLock, "update", async (payload: Record<string, unknown>) => {
            capturedUpdates.dateLock = payload;
            return [2];
        });

        const changed = await bookingExpirationService.expirePendingPaymentBooking(booking.bookingId);

        assert.equal(changed, true);
        assert.equal(booking.status, "payment_expired");
        assert.equal(booking.lockedUntil, null);
        assert.equal(booking.cancellationReason, "PAYMENT_EXPIRED");
        assert.equal(booking.cancelledAt, null);
        if (!capturedUpdates.payment || !capturedUpdates.dateLock) {
            throw new Error("Expected payment and date lock updates to be captured");
        }
        assert.equal(capturedUpdates.payment.status, "expired");
        assert.equal(capturedUpdates.dateLock.status, "released");
        assert.ok(capturedUpdates.dateLock.releasedAt instanceof Date);
    });
});

export { };
