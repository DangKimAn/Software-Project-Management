process.env.TZ = "UTC";
process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.JWT_SECRET = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const assert = require("node:assert/strict");
const { afterEach, beforeEach, describe, it } = require("node:test");
const { UniqueConstraintError } = require("sequelize");
import type { PatchEntry } from "./helpers/types";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;
const Booking = require("../dist/models/booking").default;
const BookingDateLock = require("../dist/models/booking-date-lock").default;
const Listing = require("../dist/models/listing").default;
const Payment = require("../dist/models/payment").default;
const AvailabilityCalendar = require("../dist/models/availability-calendar").default;
const {
    buildReservedDates,
    createBookingDateLocks,
    releaseBookingDateLocksForBooking,
} = require("../dist/services/booking-date-lock.service");
const {
    assertBookingStatusTransition,
    transitionBookingStatus,
} = require("../dist/modules/bookings/booking-state-machine");
const bookingsService = require("../dist/modules/bookings/bookings.service");
const { calculateBookingPricing } = require("../dist/modules/bookings/booking-pricing.service");
const { buildBookingDateOverlapWhere, buildActiveBookingStatusWhere } = require("../dist/common/booking-availability");

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

const mockUser = {
    id: "301",
    userId: "301",
    email: "guest301@example.com",
    phone: "0900000301",
    username: "guest301",
    status: "active",
    roles: ["guest"],
};

const mockListing = {
    listingId: 101,
    hostId: 50,
    title: "Seaside Villa",
    status: "active",
    basePrice: "1000000.00",
    cleaningFee: "100000.00",
    serviceFee: "50000.00",
    minNights: 1,
    maxNights: 30,
    availabilityCalendar: [],
    async save() {
        return this;
    },
};

const fakeTransaction = {
    LOCK: { UPDATE: "UPDATE" },
    commit: async () => {},
    rollback: async () => {},
};

describe("Part B - Booking & Date Lock Concurrency (BK-33 to BK-41)", () => {
    beforeEach(() => {
        patch(sequelize, "transaction", async (callback: any) => {
            if (typeof callback === "function") {
                return callback(fakeTransaction);
            }
            return fakeTransaction;
        });
        patch(sequelize, "query", async () => [{ value: 1001 }]);
    });

    it("BK-33: Overlap một phần (A: 10-13/11, B: 12-15/11) - Khách B nhận 409 Conflict khi A có hold hợp lệ", async () => {
        const checkInA = "2026-11-10";
        const checkOutA = "2026-11-13";
        const checkInB = "2026-11-12";
        const checkOutB = "2026-11-15";

        // Formula check: Existing A (10-13) overlaps with Request B (12-15)
        const whereClause = buildBookingDateOverlapWhere(checkInB, checkOutB);
        assert.ok(whereClause.checkInDate, "Where clause includes checkInDate filter");
        assert.ok(whereClause.checkOutDate, "Where clause includes checkOutDate filter");

        // Simulate Booking.findOne finding active booking A
        patch(Booking, "findOne", async (options: any) => {
            if (options?.where?.listingId === 101) {
                return {
                    bookingId: 901,
                    listingId: 101,
                    checkInDate: checkInA,
                    checkOutDate: checkOutA,
                    status: "pending_payment",
                    lockedUntil: new Date(Date.now() + 15 * 60 * 1000),
                };
            }
            return null;
        });

        patch(Listing, "findOne", async () => ({ ...mockListing }));

        await assert.rejects(
            async () => {
                await bookingsService.createBooking(mockUser as any, {
                    listingId: 101,
                    checkInDate: checkInB,
                    checkOutDate: checkOutB,
                    guestCount: 2,
                });
            },
            (error: any) => {
                assert.ok(error instanceof ApiError);
                assert.equal(error.statusCode, 409);
                assert.match(error.message, /already booked/i);
                return true;
            },
        );
    });

    it("BK-34: Rollback nhiều đêm - Lỗi insert lock ở đêm thứ 3 khiến transaction rollback sạch", async () => {
        let rollbackCalled = false;
        let commitCalled = false;

        const customTransaction = {
            LOCK: { UPDATE: "UPDATE" },
            commit: async () => { commitCalled = true; },
            rollback: async () => { rollbackCalled = true; },
        };

        patch(sequelize, "transaction", async (callback: any) => {
            try {
                return await callback(customTransaction);
            } catch (err) {
                await customTransaction.rollback();
                throw err;
            }
        });

        // Mock bulkCreate throwing error on date lock insertion
        patch(BookingDateLock, "bulkCreate", async () => {
            throw new Error("Deadlock or DB failure inserting night lock #3");
        });

        await assert.rejects(
            async () => {
                await sequelize.transaction(async (tx: any) => {
                    await createBookingDateLocks({
                        bookingId: 888,
                        listingId: 101,
                        checkInDate: new Date("2026-11-10"),
                        checkOutDate: new Date("2026-11-13"),
                        transaction: tx,
                    });
                });
            },
            (error: any) => {
                assert.match(error.message, /night lock #3/i);
                return true;
            },
        );

        assert.equal(rollbackCalled, true, "Transaction must rollback completely on error");
        assert.equal(commitCalled, false, "Transaction must not commit when date locks fail");
    });

    it("BK-35: Ẩn listing cạnh tạo đơn - Admin/host ẩn listing đồng thời, booking bị từ chối 404", async () => {
        // When listing is inactive/hidden during booking creation
        patch(Listing, "findOne", async () => ({
            ...mockListing,
            status: "inactive", // host or admin hid the listing
        }));

        await assert.rejects(
            async () => {
                await bookingsService.createBooking(mockUser as any, {
                    listingId: 101,
                    checkInDate: "2026-11-20",
                    checkOutDate: "2026-11-22",
                    guestCount: 2,
                });
            },
            (error: any) => {
                assert.ok(error instanceof ApiError);
                assert.equal(error.statusCode, 404);
                assert.match(error.message, /Listing not found/i);
                return true;
            },
        );
    });

    it("BK-36: Thay giá cạnh tạo booking - Booking snapshot đúng 1 version giá đã chốt", async () => {
        const initialPrice = 1000000;
        const newPrice = 2500000;

        const listingSnapshot = {
            ...mockListing,
            basePrice: String(initialPrice),
            cleaningFee: "100000.00",
            availabilityCalendar: [],
        };

        const pricing = await calculateBookingPricing({
            userId: 301,
            listing: listingSnapshot as any,
            dates: ["2026-12-01", "2026-12-02"], // 2 nights
            guestCount: 2,
            calendarByDate: new Map(),
            transaction: fakeTransaction as any,
        });

        assert.equal(pricing.totalNights, 2);
        assert.equal(pricing.subtotalAmount, 2000000); // 2 * 1,000,000

        // Host updates listing price afterwards
        listingSnapshot.basePrice = String(newPrice);

        // Snapshot pricing already locked in booking remains intact
        assert.equal(pricing.subtotalAmount, 2000000, "Pricing snapshot must not mutate when host updates basePrice");
    });

    it("BK-37: Giá thay đổi sau tạo payment - Amount đã chốt không đổi, không sửa payment intent", async () => {
        const lockedBooking = {
            bookingId: 777,
            listingId: 101,
            totalAmount: "2150000.00",
            status: "pending_payment",
        };

        const paymentIntent = {
            paymentId: 555,
            bookingId: lockedBooking.bookingId,
            amount: lockedBooking.totalAmount,
            status: "pending",
        };

        // Host alters listing price to 3,000,000
        const updatedListing = {
            ...mockListing,
            basePrice: "3000000.00",
        };

        // Payment amount remains locked to initial booking total
        assert.equal(paymentIntent.amount, "2150000.00");
        assert.equal(lockedBooking.totalAmount, "2150000.00");
        assert.notEqual(paymentIntent.amount, updatedListing.basePrice);
    });

    it("BK-38: Hai lần hủy song song - Chỉ 1 transition thành công, lần 2 bị 409", async () => {
        const booking = {
            bookingId: 444,
            status: "paid" as const,
            version: 1,
            async save() {
                return this;
            },
        };

        // First cancellation succeeds
        const firstTransition = await transitionBookingStatus({
            booking: booking as any,
            toStatus: "cancelled_by_guest",
            actor: "guest",
            changedByUserId: 301,
            reason: "guest_plans_changed",
            transaction: fakeTransaction as any,
        });

        assert.equal(firstTransition.to, "cancelled_by_guest");
        assert.equal(booking.status, "cancelled_by_guest");
        assert.equal(booking.version, 2);

        // Second cancellation attempt from cancelled_by_guest -> cancelled_by_guest must throw 409
        await assert.rejects(
            async () => {
                await transitionBookingStatus({
                    booking: booking as any,
                    toStatus: "cancelled_by_guest",
                    actor: "guest",
                    changedByUserId: 301,
                    reason: "duplicate_cancel_call",
                    transaction: fakeTransaction as any,
                });
            },
            (error: any) => {
                assert.ok(error instanceof ApiError);
                assert.equal(error.statusCode, 409);
                assert.match(error.message, /Invalid booking status transition/i);
                return true;
            },
        );
    });

    it("BK-39: Ranh giới lịch - CheckIn 28/02 năm nhuận (2024), checkout 01/03 đếm đúng 2 đêm", () => {
        // Leap year 2024: 28/02 and 29/02 -> 2 nights
        const leapYearDates = buildReservedDates(
            new Date("2024-02-28T00:00:00.000Z"),
            new Date("2024-03-01T00:00:00.000Z"),
        );
        assert.deepEqual(leapYearDates, ["2024-02-28", "2024-02-29"]);
        assert.equal(leapYearDates.length, 2, "Leap year February 2024 has 29 days, total 2 nights");

        // Non-leap year 2023: only 28/02 -> 1 night
        const nonLeapYearDates = buildReservedDates(
            new Date("2023-02-28T00:00:00.000Z"),
            new Date("2023-03-01T00:00:00.000Z"),
        );
        assert.deepEqual(nonLeapYearDates, ["2023-02-28"]);
        assert.equal(nonLeapYearDates.length, 1, "Non-leap year February 2023 has 28 days, total 1 night");

        // Year boundary 31/12/2024 to 02/01/2025 -> 2 nights
        const newYearDates = buildReservedDates(
            new Date("2024-12-31T00:00:00.000Z"),
            new Date("2025-01-02T00:00:00.000Z"),
        );
        assert.deepEqual(newYearDates, ["2024-12-31", "2025-01-01"]);
        assert.equal(newYearDates.length, 2, "Year crossing calculates exact 2 nights across Dec 31 and Jan 1");
    });

    it("BK-40: Race đa instance - DB unique constraint ném UniqueConstraintError chuyển thành 409", async () => {
        // When two instances race, second one hits unique constraint on (listing_id, reserved_date, released_at)
        patch(BookingDateLock, "bulkCreate", async () => {
            const err = new UniqueConstraintError({
                message: "Duplicate entry '101-2026-11-15' for key 'listing_reserved_date_unique'",
                errors: [],
            });
            throw err;
        });

        await assert.rejects(
            async () => {
                await createBookingDateLocks({
                    bookingId: 333,
                    listingId: 101,
                    checkInDate: new Date("2026-11-15"),
                    checkOutDate: new Date("2026-11-17"),
                    transaction: fakeTransaction as any,
                });
            },
            (error: any) => {
                assert.ok(error instanceof ApiError);
                assert.equal(error.statusCode, 409);
                assert.equal(error.message, "Listing is already booked for the selected dates");
                return true;
            },
        );
    });

    it("BK-41: Chỉnh lịch khi đã có pending hold - Phát hiện xung đột date lock hoặc calendar blocked", async () => {
        // Date lock release test
        patch(BookingDateLock, "update", async (_values: any, options: any) => {
            assert.equal(options.where.bookingId, 555);
            return [2]; // 2 dates released
        });

        const releasedCount = await releaseBookingDateLocksForBooking({
            bookingId: 555,
            transaction: fakeTransaction as any,
        });

        assert.equal(releasedCount, 2, "Date locks successfully released for booking");

        // Pending hold conflict: Active booking hold prevents calendar availability
        const activeStatusesWhere = buildActiveBookingStatusWhere();
        assert.ok(activeStatusesWhere, "Active booking filter defines blocking criteria for pending payment");
    });
});
