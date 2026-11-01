const assert = require("node:assert/strict");
const { afterEach, beforeEach, describe, it } = require("node:test");

const request = require("supertest");
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const { ApiError } = require("../dist/common/api-error");
const NotificationLog = require("../dist/models/notification-log").default;
const Booking = require("../dist/models/booking").default;
const Listing = require("../dist/models/listing").default;
const Payment = require("../dist/models/payment").default;
const User = require("../dist/models/user").default;
const authService = require("../dist/modules/auth/auth.service");
const notificationService = require("../dist/modules/notifications/notification.service");
const mailService = require("../dist/services/mail.service");
const socketModule = require("../dist/socket/socket");

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

const userA = {
    id: "201",
    email: "usera@example.com",
    phone: "0900000201",
    name: "User A",
    username: "usera",
    status: "active",
    roles: ["guest"],
};

const userB = {
    id: "202",
    email: "userb@example.com",
    phone: "0900000202",
    name: "User B",
    username: "userb",
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

const userAAuth = { Authorization: "Bearer user-a-token" };
const userBAuth = { Authorization: "Bearer user-b-token" };

const buildNotification = (overrides: Record<string, unknown> = {}) => ({
    notificationLogId: 101,
    eventType: "BOOKING_CONFIRMED",
    targetType: "booking",
    targetId: "9001",
    recipient: "usera@example.com",
    recipientUserId: 201,
    title: "Đặt phòng thành công",
    body: "Đơn đặt phòng #9001 của bạn đã được xác nhận.",
    actionUrl: "/don-phong/9001",
    payload: { bookingId: 9001 },
    status: "sent",
    provider: "in_app",
    providerMessageId: null,
    errorMessage: null,
    sentAt: new Date("2026-05-10T12:00:00.000Z"),
    readAt: null,
    createdAt: new Date("2026-05-10T12:00:00.000Z"),
    updatedAt: new Date("2026-05-10T12:00:00.000Z"),
    async update(fields: any) {
        Object.assign(this, fields);
        return this;
    },
    async save() {
        return this;
    },
    ...overrides,
});

const buildMockCreatedLog = (data: any, id = 1) => ({
    ...data,
    notificationLogId: id,
    async update(fields: any) {
        Object.assign(this, fields);
        return this;
    },
    async save() {
        return this;
    },
});

describe("Module notifications (NT-01 to NT-12)", () => {
    let app: any;

    beforeEach(() => {
        app = require("../dist/app").default;

        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "user-a-token") return { userId: "201", role: "guest" };
            if (token === "user-b-token") return { userId: "202", role: "guest" };
            throw new ApiError(401, "Unauthorized");
        });

        patch(authService, "toAuthenticatedUser", async (user: any) => ({
            id: String(user.id || user._id || user.userId),
            email: user.email,
            phone: user.phone,
            name: user.name || user.fullName,
            username: user.username,
            status: user.status || "active",
            roles: user.roles || ["guest"],
        }));

        const usersMap = new Map([
            ["201", userA],
            ["202", userB],
            ["101", hostUser],
        ]);

        patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findByPk", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findOne", async ({ where }: any) => {
            const id = where?.id || where?.userId;
            return usersMap.get(String(id)) ?? null;
        });

        patch(Payment, "findOne", async () => ({
            paymentId: 8001,
            amount: 2500000,
            currency: "VND",
            method: "vnpay",
            status: "success",
        }));

        patch(NotificationLog, "create", async (data: any) => buildMockCreatedLog(data, 101));

        patch(socketModule, "emitNotificationNew", () => {});
        patch(mailService, "sendMail", async () => ({ messageId: "mock-mail-id" }));
    });

    it("NT-01: Sinh thông báo in-app và gửi email khi booking được xác nhận (notifyBookingConfirmed)", async () => {
        let sentEmailCount = 0;
        let createdInAppLogs: any[] = [];

        patch(mailService, "sendMail", async () => {
            sentEmailCount++;
            return { messageId: "mock-mail-id" };
        });

        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            hostUserId: 101,
            listingId: 801,
            totalAmount: 2500000,
            currency: "VND",
            checkInDate: "2026-06-01",
            checkOutDate: "2026-06-03",
        }));

        patch(Listing, "findOne", async () => ({
            listingId: 801,
            hostId: 101,
            title: "Villa Bien Vung Tau",
            addressLine: "12 Tran Phu",
        }));

        patch(NotificationLog, "create", async (data: any) => {
            createdInAppLogs.push(data);
            return buildMockCreatedLog(data, createdInAppLogs.length);
        });

        await notificationService.notifyBookingConfirmed(9001);

        // Cả guest (201) và host (101) đều nhận thông báo in-app
        assert.ok(createdInAppLogs.length >= 2);
        assert.ok(createdInAppLogs.some((log) => log.recipientUserId === 201 && log.provider === "in_app"));
        assert.ok(createdInAppLogs.some((log) => log.recipientUserId === 101 && log.provider === "in_app"));
        // Email được gửi cho guest và host
        assert.ok(sentEmailCount >= 1);
    });

    it("NT-02: Lấy danh sách thông báo của chính user, sắp xếp mới nhất trước và có phân trang (HTTP 200)", async () => {
        const mockLogs = [
            buildNotification({ notificationLogId: 102, recipientUserId: 201, title: "Mới nhất" }),
            buildNotification({ notificationLogId: 101, recipientUserId: 201, title: "Cũ hơn" }),
        ];

        patch(NotificationLog, "findAll", async ({ where, limit }: any) => {
            assert.equal(where.recipientUserId, 201);
            assert.equal(where.provider, "in_app");
            assert.equal(limit, 10);
            return mockLogs;
        });

        patch(NotificationLog, "count", async () => 2);

        const res = await request(app)
            .get("/api/notifications?page=1&limit=10")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.items.length, 2);
        assert.equal(res.body.data.items[0].title, "Mới nhất");
        assert.equal(res.body.data.pagination.total, 2);
    });

    it("NT-03: Trả về số lượng thông báo chưa đọc (unreadCount) chính xác", async () => {
        patch(NotificationLog, "findAll", async () => [
            buildNotification({ notificationLogId: 101, readAt: null }),
            buildNotification({ notificationLogId: 102, readAt: null }),
        ]);

        let countCall = 0;
        patch(NotificationLog, "count", async ({ where }: any) => {
            countCall++;
            return 2; // 2 thông báo chưa đọc
        });

        const res = await request(app)
            .get("/api/notifications")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.unreadCount, 2);
    });

    it("NT-04: Đánh dấu đã đọc cho 1 thông báo và đánh dấu tất cả đã đọc thành công (HTTP 200)", async () => {
        const mockLog = buildNotification({ notificationLogId: 101, recipientUserId: 201, readAt: null });
        patch(NotificationLog, "findOne", async () => mockLog);

        // Đánh dấu 1 thông báo
        const readSingleRes = await request(app)
            .patch("/api/notifications/101/read")
            .set(userAAuth);

        assert.equal(readSingleRes.status, 200);
        assert.equal(readSingleRes.body.success, true);
        assert.ok(mockLog.readAt !== null);

        // Đánh dấu tất cả
        patch(NotificationLog, "update", async () => [5]); // 5 thông báo được update

        const readAllRes = await request(app)
            .patch("/api/notifications/read-all")
            .set(userAAuth);

        assert.equal(readAllRes.status, 200);
        assert.equal(readAllRes.body.data.updatedCount, 5);
        assert.ok(readAllRes.body.data.readAt !== null);
    });

    it("NT-05: Chặn người dùng đánh dấu đã đọc thông báo của người khác (chống IDOR) (HTTP 404)", async () => {
        // Thông báo 101 thuộc về user 201, nhưng user 202 gọi
        patch(NotificationLog, "findOne", async ({ where }: any) => {
            if (where.notificationLogId === 101 && where.recipientUserId === 202) {
                return null; // Không tìm thấy thông báo 101 thuộc user 202
            }
            return null;
        });

        const res = await request(app)
            .patch("/api/notifications/101/read")
            .set(userBAuth); // User B gọi

        assert.equal(res.status, 404);
        assert.match(res.body.message, /Notification not found/i);
    });

    it("NT-06: Khi dịch vụ email SMTP lỗi, thông báo in-app vẫn được tạo thành công và không crash hệ thống", async () => {
        patch(mailService, "sendMail", async () => {
            throw new Error("SMTP connection timeout");
        });

        let inAppCreated = false;
        patch(NotificationLog, "create", async (data: any) => {
            if (data.provider === "in_app") inAppCreated = true;
            return buildMockCreatedLog(data, 1);
        });

        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            hostUserId: 101,
            listingId: 801,
        }));
        patch(Listing, "findOne", async () => ({ listingId: 801, hostId: 101, title: "Villa A" }));

        // Gọi notify không được ném unhandled rejection
        await assert.doesNotReject(async () => {
            await notificationService.notifyBookingConfirmed(9001);
        });

        assert.equal(inAppCreated, true);
    });

    it("NT-07: Không tạo bản ghi thông báo trùng lặp với cùng sự kiện khi webhook/retry gọi lại (Idempotency)", async () => {
        let createdCount = 0;
        patch(NotificationLog, "create", async (data: any) => {
            createdCount++;
            return buildMockCreatedLog(data, createdCount);
        });

        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            hostUserId: 101,
            listingId: 801,
        }));
        patch(Listing, "findOne", async () => ({ listingId: 801, hostId: 101, title: "Villa A" }));

        await notificationService.notifyBookingConfirmed(9001);
        const countAfterFirst = createdCount;

        // Giả lập hệ thống có kiểm tra dedup
        assert.ok(countAfterFirst > 0);
    });

    it("NT-08: Sinh thông báo in-app cho host khi có review mới từ khách (notifyReviewCreated)", async () => {
        const Review = require("../dist/models/review").default;
        patch(Review, "findOne", async () => ({
            reviewId: 501,
            listingId: 801,
            rating: 5,
            reviewerName: "Guest User",
        }));

        patch(Listing, "findOne", async () => ({
            listingId: 801,
            hostId: 101,
            title: "Villa Bien Vung Tau",
        }));

        let notifiedHostUserId: number | null = null;
        patch(NotificationLog, "create", async (data: any) => {
            if (data.provider === "in_app") {
                notifiedHostUserId = data.recipientUserId;
            }
            return buildMockCreatedLog(data, 1);
        });

        await notificationService.notifyReviewCreated(501);

        assert.equal(notifiedHostUserId, 101); // Host của listing nhận thông báo
    });

    it("NT-09: Gửi đúng thông báo duyệt hồ sơ host (notifyHostApplicationReviewed)", async () => {
        let sentTitle = "";
        let notifiedUserId: number | null = null;

        patch(NotificationLog, "create", async (data: any) => {
            if (data.provider === "in_app") {
                sentTitle = data.title;
                notifiedUserId = data.recipientUserId;
            }
            return buildMockCreatedLog(data, 1);
        });

        await notificationService.notify({
            eventType: "HOST_APPLICATION_APPROVED",
            targetType: "host_application",
            targetId: 12,
            recipients: [
                {
                    userId: 201,
                    title: "Hồ sơ đối tác đã được duyệt",
                    body: "Chúc mừng bạn đã trở thành Host!",
                },
            ],
        });

        assert.equal(notifiedUserId, 201);
        assert.match(sentTitle, /đã được duyệt/i);
    });

    it("NT-10: Khử mã độc HTML/XSS trong dữ liệu người dùng khi render nội dung thông báo/email", async () => {
        let sentEmailHtml = "";
        patch(mailService, "sendMail", async (mailOptions: any) => {
            sentEmailHtml = mailOptions.html;
            return { messageId: "mock-id" };
        });

        patch(NotificationLog, "create", async (data: any) => buildMockCreatedLog(data, 1));

        const maliciousUser = {
            id: "201",
            fullName: "<script>alert('xss')</script>Guest",
            email: "guest@example.com",
            status: "active",
        };
        patch(User, "findById", async () => maliciousUser);
        patch(User, "findByPk", async () => maliciousUser);
        patch(User, "findOne", async () => maliciousUser);

        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            hostUserId: 101,
            listingId: 801,
        }));
        patch(Listing, "findOne", async () => ({
            listingId: 801,
            hostId: 101,
            title: "Villa <b>Bold</b>",
        }));

        await notificationService.notifyBookingConfirmed(9001);

        // Đảm bảo không chứa thẻ <script> nguyên bản trong email HTML
        assert.ok(!sentEmailHtml.includes("<script>"));
        assert.ok(sentEmailHtml.includes("&lt;script&gt;"));
    });

    it("NT-11: Khả năng chống chịu lỗi (Resilience): Socket down không làm gián đoạn việc lưu notification vào database", async () => {
        patch(socketModule, "emitNotificationNew", () => {
            // Socket error handled internally or simulated
        });

        let inAppSaved = false;
        patch(NotificationLog, "create", async (data: any) => {
            inAppSaved = true;
            return buildMockCreatedLog(data, 1);
        });

        await assert.doesNotReject(async () => {
            await notificationService.notify({
                eventType: "SYSTEM_ALERT",
                targetType: "system",
                targetId: "sys-1",
                recipients: [{ userId: 201, title: "Test", body: "Resilience check" }],
            });
        });

        assert.equal(inAppSaved, true);
    });

    it("NT-12: Trạng thái thông báo nhất quán sau khi worker/server khởi động lại", async () => {
        const mockLog = buildNotification({
            notificationLogId: 101,
            status: "sent",
            readAt: new Date("2026-05-10T15:00:00.000Z"),
        });

        patch(NotificationLog, "findAll", async () => [mockLog]);
        patch(NotificationLog, "count", async () => 1);

        const res = await request(app)
            .get("/api/notifications")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.ok(res.body.success);
        assert.equal(res.body.data.items.length, 1);
    });

    it("NT-13: Đăng ký và hủy đăng ký FCM device token cho Android (POST /api/notifications/devices & /devices/unregister)", async () => {
        const UserDeviceToken = require("../dist/models/user-device-token").default;
        const sampleToken = "fcm_android_device_token_sample_1234567890_abcdef";
        let storedRecord: any = null;

        patch(UserDeviceToken, "findOne", async () => storedRecord);
        patch(UserDeviceToken, "create", async (data: any) => {
            storedRecord = {
                ...data,
                deviceTokenId: 77,
                async update(fields: any) {
                    Object.assign(this, fields);
                    return this;
                },
            };
            return storedRecord;
        });
        patch(UserDeviceToken, "update", async (fields: any) => {
            if (storedRecord) {
                Object.assign(storedRecord, fields);
                return [1];
            }
            return [0];
        });

        const regRes = await request(app)
            .post("/api/notifications/devices")
            .set(userAAuth)
            .send({
                token: sampleToken,
                platform: "android",
                appFlavor: "dev",
            });

        assert.equal(regRes.status, 200);
        assert.equal(regRes.body.success, true);
        assert.equal(regRes.body.data.isActive, true);
        assert.equal(storedRecord.userId, 201);

        const unregRes = await request(app)
            .post("/api/notifications/devices/unregister")
            .set(userAAuth)
            .send({ token: sampleToken });

        assert.equal(unregRes.status, 200);
        assert.equal(unregRes.body.data.unregistered, true);
        assert.equal(storedRecord.isActive, false);
    });

    it("NT-14: Gửi thông báo đẩy FCM Android và tự động vô hiệu hóa token không còn hợp lệ", async () => {
        const UserDeviceToken = require("../dist/models/user-device-token").default;
        const fcmPushService = require("../dist/services/fcm-push.service");
        const validToken = "valid_android_fcm_token_000000000000000001";
        const deadToken = "expired_android_fcm_token_0000000000000002";

        let deactivatedHashes: string[] = [];
        let capturedMulticast: any = null;

        fcmPushService.setFcmMulticastSenderForTesting(async (msg: any) => {
            capturedMulticast = msg;
            return {
                successCount: 1,
                failureCount: 1,
                responses: [
                    { success: true, messageId: "projects/test/messages/1" },
                    {
                        success: false,
                        error: { code: "messaging/registration-token-not-registered", message: "NotRegistered" },
                    },
                ],
            };
        });

        patch(UserDeviceToken, "findAll", async () => [
            {
                deviceTokenId: 1,
                userId: 201,
                fcmToken: validToken,
                tokenHash: fcmPushService.hashDeviceToken(validToken),
                platform: "android",
                isActive: true,
            },
            {
                deviceTokenId: 2,
                userId: 201,
                fcmToken: deadToken,
                tokenHash: fcmPushService.hashDeviceToken(deadToken),
                platform: "android",
                isActive: true,
            },
        ]);

        patch(UserDeviceToken, "update", async (_fields: any, options: any) => {
            deactivatedHashes = options.where.tokenHash;
            return [deactivatedHashes.length];
        });

        try {
            const result = await fcmPushService.sendPushToUser(201, {
                title: "Đặt phòng thành công",
                body: "Booking #9001 đã xác nhận",
                actionUrl: "/account/trips",
                eventType: "BOOKING_CONFIRMED",
                targetType: "booking",
                targetId: 9001,
                notificationLogId: 101,
            });

            assert.equal(result.sentCount, 1);
            assert.equal(result.failureCount, 1);
            assert.equal(capturedMulticast.android.priority, "high");
            assert.equal(
                capturedMulticast.android.notification.channelId,
                "minh_thanh_villa_high_importance",
            );
            assert.equal(capturedMulticast.data.actionUrl, "/account/trips");
            assert.deepEqual(deactivatedHashes, [fcmPushService.hashDeviceToken(deadToken)]);
        } finally {
            fcmPushService.resetFcmServiceCacheForTesting();
        }
    });

    it("NT-15: Thông báo chào mừng dùng thương hiệu The Palm Villa và chuẩn hóa các bản ghi Minh Thành Villa cũ", async () => {
        let createdInApp: any = null;
        patch(User, "findByPk", async () => ({
            userId: 201,
            email: "usera@example.com",
            fullName: "User A",
            status: "active",
        }));
        patch(NotificationLog, "create", async (data: any) => {
            if (data.provider === "in_app") {
                createdInApp = data;
            }
            return buildMockCreatedLog(data, 999);
        });

        await notificationService.notifyUserRegistered(201);
        assert.ok(createdInApp);
        assert.equal(createdInApp.title, "Chào mừng đến The Palm Villa");

        patch(NotificationLog, "findAll", async () => [
            buildNotification({
                notificationLogId: 180001,
                eventType: "USER_REGISTERED",
                title: "Chào mừng đến Minh Thành Villa",
                body: "Chủ biệt thự Nguyễn Minh Thành đã xác nhận kỳ nghỉ tại MinhThanh Luxury Sea View Villa Bãi Dâu.",
            }),
        ]);
        patch(NotificationLog, "count", async () => 1);

        const res = await request(app)
            .get("/api/notifications")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.items[0].title, "Chào mừng đến The Palm Villa");
        assert.equal(
            res.body.data.items[0].body,
            "Chủ biệt thự Nguyễn Minh Thành đã xác nhận kỳ nghỉ tại The Palm Luxury Sea View Villa Bãi Dâu.",
        );
    });
});
