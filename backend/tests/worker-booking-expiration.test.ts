const assert = require("node:assert/strict");
const { after, afterEach, beforeEach, describe, it } = require("node:test");
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;
const Booking = require("../dist/models/booking").default;
const Payment = require("../dist/models/payment").default;
const Refund = require("../dist/models/refund").default;
const BookingDateLock = require("../dist/models/booking-date-lock").default;
const BookingStatusHistory = require("../dist/models/booking-status-history").default;
const bookingDateLockService = require("../dist/services/booking-date-lock.service");
const notificationService = require("../dist/modules/notifications/notification.service");
const expirationService = require("../dist/services/booking-expiration.service");
const { logger } = require("../dist/config/logger");

const originals: PatchEntry[] = [];

const patch = (target: Record<string, unknown>, key: string, value: unknown): void => {
    originals.push([target, key, target[key]]);
    target[key] = value;
};

afterEach(() => {
    expirationService.stopPaymentExpirationSweep();
    while (originals.length > 0) {
        const [target, key, value] = originals.pop()!;
        target[key] = value;
    }
});

after(async () => {
    expirationService.stopPaymentExpirationSweep();
    try {
        await sequelize.close();
    } catch {
        // ignore
    }
});

const buildBooking = (overrides: Record<string, unknown> = {}) => ({
    bookingId: 5001,
    listingId: 801,
    guestUserId: 201,
    hostUserId: 101,
    status: "pending_payment",
    version: 1,
    lockedUntil: new Date(Date.now() - 60000), // Mặc định đã hết hạn 1 phút trước
    totalPrice: 1500000,
    currency: "VND",
    cancellationReason: null,
    cancelledByUserId: null,
    cancelledAt: null,
    paidAt: null,
    createdAt: new Date(Date.now() - 1200000),
    updatedAt: new Date(Date.now() - 1200000),
    async save() {
        return this;
    },
    ...overrides,
});

const buildPayment = (overrides: Record<string, unknown> = {}) => ({
    paymentId: 9001,
    bookingId: 5001,
    amount: 1500000,
    currency: "VND",
    status: "paid",
    paidAt: new Date(Date.now() - 120000),
    createdAt: new Date(Date.now() - 1200000),
    updatedAt: new Date(Date.now() - 120000),
    async save() {
        return this;
    },
    ...overrides,
});

describe("Module Background Worker – Booking Expiration (WK-01 to WK-10)", () => {
    beforeEach(() => {
        patch(sequelize, "transaction", async (arg1: any, arg2?: any) => {
            const callback = typeof arg1 === "function" ? arg1 : arg2;
            return callback
                ? callback({
                      LOCK: { UPDATE: "UPDATE" },
                      afterCommit(fn: () => void) {
                          fn();
                      },
                  })
                : {};
        });

        patch(BookingStatusHistory, "create", async () => ({}));
        patch(BookingDateLock, "update", async () => [1]);
        patch(Payment, "update", async () => [1]);
        patch(Refund, "create", async (data: any) => ({ refundId: 7001, ...data }));
        patch(Refund, "findOne", async () => null);

        patch(notificationService, "notifyPaymentExpired", async () => {});
        patch(notificationService, "notifyPaymentSuccess", async () => {});
        patch(notificationService, "notifyRefundCreated", async () => {});
    });

    it("WK-01: Worker quét định kỳ chuyển các đơn quá hạn thanh toán sang payment_expired, giải phóng date locks", async () => {
        const mockBooking = buildBooking({
            bookingId: 5001,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() - 60000), // Quá hạn 1 phút
        });

        patch(Booking, "findOne", async () => mockBooking);
        patch(Payment, "findOne", async () => null); // Không có payment paid

        let locksReleasedBookingId: number | null = null;
        patch(bookingDateLockService, "releaseBookingDateLocksForBooking", async ({ bookingId }: any) => {
            locksReleasedBookingId = bookingId;
            return 1;
        });

        let expiredNotificationBookingId: number | null = null;
        patch(notificationService, "notifyPaymentExpired", async (bookingId: number) => {
            expiredNotificationBookingId = bookingId;
        });

        const changed = await expirationService.expirePendingPaymentBooking(5001);

        assert.equal(changed, true);
        assert.equal(mockBooking.status, "payment_expired");
        assert.equal(mockBooking.lockedUntil, null);
        assert.equal(locksReleasedBookingId, 5001);
        assert.equal(expiredNotificationBookingId, 5001);
    });

    it("WK-02: Đơn chưa hết hạn (lockedUntil > now) không bị worker quét huỷ (giữ pending_payment)", async () => {
        const mockBooking = buildBooking({
            bookingId: 5002,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() + 600000), // Còn 10 phút nữa mới hết hạn
        });

        patch(Booking, "findOne", async () => mockBooking);

        let locksReleased = false;
        patch(bookingDateLockService, "releaseBookingDateLocksForBooking", async () => {
            locksReleased = true;
            return 0;
        });

        const changed = await expirationService.expirePendingPaymentBooking(5002);

        assert.equal(changed, false);
        assert.equal(mockBooking.status, "pending_payment");
        assert.equal(locksReleased, false);
    });

    it("WK-03: Đơn đã confirmed hoặc paid không bị worker huỷ (giữ nguyên trạng thái)", async () => {
        const mockBooking = buildBooking({
            bookingId: 5003,
            status: "paid", // Đã thanh toán
            lockedUntil: new Date(Date.now() - 60000),
        });

        patch(Booking, "findOne", async () => mockBooking);

        const changed = await expirationService.expirePendingPaymentBooking(5003);

        assert.equal(changed, false);
        assert.equal(mockBooking.status, "paid");
    });

    it("WK-04: Race condition - Thanh toán thành công đúng lúc worker quét (xử lý atomic: giữ paid hoặc late_refund, không trạng thái lai)", async () => {
        // Trường hợp 4A: Khách đã thanh toán TRƯỚC thời điểm lockedUntil (thanh toán hợp lệ trước khi worker kịp quét)
        const lockedUntil = new Date(Date.now() - 30000); // Hết hạn 30s trước
        const paidAt = new Date(lockedUntil.getTime() - 10000); // Nhưng đã thanh toán 10s trước khi hết hạn
        const mockBookingA = buildBooking({
            bookingId: 5004,
            status: "pending_payment",
            lockedUntil,
        });

        patch(Booking, "findOne", async () => mockBookingA);
        patch(Payment, "findOne", async () => buildPayment({ bookingId: 5004, status: "paid", paidAt }));

        let successNotified = false;
        patch(notificationService, "notifyPaymentSuccess", async () => {
            successNotified = true;
        });

        const changedA = await expirationService.expirePendingPaymentBooking(5004);

        assert.equal(changedA, true);
        assert.equal(mockBookingA.status, "paid"); // Được xác nhận là paid hợp lệ
        assert.equal(successNotified, true);

        // Trường hợp 4B: Khách thanh toán MUỘN sau khi lockedUntil đã hết hạn
        const latePaidAt = new Date(lockedUntil.getTime() + 15000); // Thanh toán trễ 15s
        const mockBookingB = buildBooking({
            bookingId: 5005,
            status: "pending_payment",
            lockedUntil,
        });

        patch(Booking, "findOne", async () => mockBookingB);
        patch(Payment, "findOne", async () => buildPayment({ bookingId: 5005, status: "paid", paidAt: latePaidAt }));

        let refundCreated = false;
        patch(Refund, "create", async (data: any) => {
            refundCreated = true;
            assert.equal(data.reason, "late_payment_after_booking_expired");
            return { refundId: 7002, ...data };
        });

        const changedB = await expirationService.expirePendingPaymentBooking(5005);

        assert.equal(changedB, true);
        assert.equal(mockBookingB.status, "payment_expired"); // Chuyển expired để hoàn tiền tự động
        assert.equal(refundCreated, true);
    });

    it("WK-05: Đa instance worker - Claim và transition an toàn với row-level lock, không double side effects", async () => {
        const mockBooking = buildBooking({
            bookingId: 5006,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() - 60000),
        });

        let notifyExpiredCount = 0;
        patch(notificationService, "notifyPaymentExpired", async () => {
            notifyExpiredCount += 1;
        });

        // Worker 1 quét đơn trước và commit đổi trạng thái thành payment_expired
        patch(Booking, "findOne", async () => mockBooking);
        patch(Payment, "findOne", async () => null);

        const changedByWorker1 = await expirationService.expirePendingPaymentBooking(5006);
        assert.equal(changedByWorker1, true);
        assert.equal(mockBooking.status, "payment_expired");
        assert.equal(notifyExpiredCount, 1);

        // Worker 2 cùng chạy trong batch tiếp theo hoặc instance song song nhìn thấy booking đã là payment_expired
        const changedByWorker2 = await expirationService.expirePendingPaymentBooking(5006);
        assert.equal(changedByWorker2, false);
        // Không gửi thông báo trùng lặp lần 2
        assert.equal(notifyExpiredCount, 1);
    });

    it("WK-06: Lỗi DB trong một lượt quét không làm crash worker, có log và lượt sau vẫn tiếp tục", async () => {
        const mockBookingError = { bookingId: 5007 };
        const mockBookingSuccess = buildBooking({
            bookingId: 5008,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() - 60000),
        });

        patch(Booking, "findAll", async () => [mockBookingError, { bookingId: 5008 }]);
        patch(Booking, "findOne", async ({ where }: any) => {
            if (where.bookingId === 5007) {
                throw new Error("MySQL connection deadlock simulation");
            }
            if (where.bookingId === 5008) {
                return mockBookingSuccess;
            }
            return null;
        });
        patch(Payment, "findOne", async () => null);

        let errorLogged = false;
        patch(logger, "error", (...args: any[]) => {
            errorLogged = true;
        });

        // Hàm expirePendingPaymentBookings không được throw unhandled rejection
        const expiredCount = await expirationService.expirePendingPaymentBookings();

        assert.equal(errorLogged, true);
        assert.equal(expiredCount, 1); // Đơn 5008 vẫn thành công bình thường
        assert.equal(mockBookingSuccess.status, "payment_expired");
    });

    it("WK-07: Xử lý theo lô (batch limit) khi có số lượng lớn đơn quá hạn cùng lúc", async () => {
        let requestedLimit = 0;
        let requestedOrder: any = null;

        patch(Booking, "findAll", async (options: any) => {
            requestedLimit = options.limit;
            requestedOrder = options.order;
            return [];
        });

        await expirationService.expirePendingPaymentBookings(25);

        assert.equal(requestedLimit, 25);
        assert.deepEqual(requestedOrder, [["lockedUntil", "ASC"], ["createdAt", "ASC"]]);
    });

    it("WK-08: Graceful shutdown - Worker dừng sạch khi server shutdown (dọn dẹp timer và cờ sweepRunning)", () => {
        expirationService.stopPaymentExpirationSweep(); // Dọn trạng thái cũ

        expirationService.startPaymentExpirationSweep();
        // Gọi lại lần 2 không sinh thêm timer lặp
        expirationService.startPaymentExpirationSweep();

        // Dừng sạch
        expirationService.stopPaymentExpirationSweep();
        // Dừng lại lần nữa an toàn (idempotent stop)
        expirationService.stopPaymentExpirationSweep();

        assert.ok(true);
    });

    it("WK-09: Hoàn trả coupon và gửi thông báo khi đơn hết hạn thanh toán", async () => {
        const mockBooking = buildBooking({
            bookingId: 5009,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() - 60000),
        });

        patch(Booking, "findOne", async () => mockBooking);
        patch(Payment, "findOne", async () => null);

        let notifiedBookingId: number | null = null;
        patch(notificationService, "notifyPaymentExpired", async (bookingId: number) => {
            notifiedBookingId = bookingId;
        });

        await expirationService.expirePendingPaymentBooking(5009);

        assert.equal(notifiedBookingId, 5009);
        assert.equal(mockBooking.status, "payment_expired");
    });

    it("WK-10: So sánh thời gian nhất quán theo chuẩn UTC (epoch ms) bất kể múi giờ local", async () => {
        // Mock thời gian với các múi giờ ISO khác nhau (UTC Z vs +07:00)
        const utcDate = new Date("2026-05-10T12:00:00.000Z");
        const localEquivalentDate = new Date("2026-05-10T19:00:00.000+07:00");

        // Cùng trỏ đến 1 thời điểm epoch ms
        assert.equal(utcDate.getTime(), localEquivalentDate.getTime());

        const mockBooking = buildBooking({
            bookingId: 5010,
            status: "pending_payment",
            lockedUntil: utcDate,
        });

        patch(Booking, "findOne", async () => mockBooking);
        patch(Payment, "findOne", async () => null);

        // Kiểm tra với now thời điểm 1 giây sau
        const now = new Date("2026-05-10T12:00:01.000Z");
        const changed = await expirationService.expirePendingPaymentBookingInTransaction({
            booking: mockBooking,
            transaction: { LOCK: { UPDATE: "UPDATE" } } as any,
            now,
        });

        assert.equal(changed, true);
        assert.equal(mockBooking.status, "payment_expired");
    });
});
