const assert = require("node:assert/strict");
const { after, afterEach, beforeEach, describe, it } = require("node:test");

const request = require("supertest");
import type { PatchEntry, Rejectable } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default;
const Booking = require("../dist/models/booking").default;
const Listing = require("../dist/models/listing").default;
const Review = require("../dist/models/review").default;
const authService = require("../dist/modules/auth/auth.service");
const reviewsService = require("../dist/modules/reviews/reviews.service");
const publicListingsService = require("../dist/modules/listings/listings.service");

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

after(async () => {
    try {
        await sequelize.close();
    } catch {
        // ignore
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

const otherGuestUser = {
    ...guestUser,
    id: "202",
    email: "other@example.com",
    username: "other_guest",
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
    id: "102",
    email: "otherhost@example.com",
};

const adminUser = {
    id: "1",
    email: "admin@example.com",
    phone: "0900000001",
    name: "Admin User",
    username: "admin",
    status: "active",
    roles: ["admin"],
};

const guestAuth = { Authorization: "Bearer guest-token" };
const otherGuestAuth = { Authorization: "Bearer other-guest-token" };
const hostAuth = { Authorization: "Bearer host-token" };
const otherHostAuth = { Authorization: "Bearer other-host-token" };
const adminAuth = { Authorization: "Bearer admin-token" };

const assertRejectsApiError = async (fn: Rejectable, statusCode: number, messageMatch?: RegExp | string): Promise<void> => {
    await assert.rejects(fn, (error: unknown) => {
        assert.equal(error instanceof ApiError, true);
        assert.equal((error as { statusCode: number }).statusCode, statusCode);
        if (messageMatch) {
            if (typeof messageMatch === "string") {
                assert.ok((error as Error).message.includes(messageMatch));
            } else {
                assert.match((error as Error).message, messageMatch);
            }
        }
        return true;
    });
};

const buildReview = (overrides: Record<string, unknown> = {}) => ({
    reviewId: 501,
    bookingId: 9001,
    listingId: 801,
    reviewerUserId: 201,
    reviewerName: "Guest User",
    rating: 5,
    comment: "Kỳ nghỉ tuyệt vời!",
    hostReply: null,
    isVisible: true,
    deletedAt: null,
    createdAt: new Date("2026-05-15T10:00:00.000Z"),
    updatedAt: new Date("2026-05-15T10:00:00.000Z"),
    async save() {
        return this;
    },
    ...overrides,
});

describe("Module reviews (RV-01 to RV-15)", () => {
    let app: any;

    beforeEach(() => {
        app = require("../dist/app").default;

        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "guest-token") return { userId: "201", role: "guest" };
            if (token === "other-guest-token") return { userId: "202", role: "guest" };
            if (token === "host-token") return { userId: "101", role: "host" };
            if (token === "other-host-token") return { userId: "102", role: "host" };
            if (token === "admin-token") return { userId: "1", role: "admin" };
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
            ["201", guestUser],
            ["202", otherGuestUser],
            ["101", hostUser],
            ["102", otherHostUser],
            ["1", adminUser],
        ]);

        const User = require("../dist/models/user").default;
        patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findOne", async ({ where }: any) => {
            if (where?.id || where?.userId) {
                return usersMap.get(String(where.id || where.userId)) ?? null;
            }
            return null;
        });

        const counter = require("../dist/models/counter");
        patch(counter, "getNextSequence", async () => 501);

        const notificationService = require("../dist/modules/notifications/notification.service");
        patch(notificationService, "notifyReviewCreated", async () => {});

        patch(sequelize, "transaction", async (arg1: any, arg2?: any) => {
            const callback = typeof arg1 === "function" ? arg1 : arg2;
            return callback ? callback({}) : {};
        });
    });

    it("RV-01: Guest đã hoàn tất kỳ nghỉ (completed/checked_out) tạo đánh giá 5 sao thành công (HTTP 201)", async () => {
        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            listingId: 801,
            status: "completed",
            checkedOutAt: new Date("2026-05-14T12:00:00.000Z"),
        }));

        patch(Review, "findOne", async () => null);

        patch(Listing, "findOne", async () => ({
            listingId: 801,
            hostId: 101,
            deletedAt: null,
        }));

        let savedReview: any = null;
        patch(Review.prototype, "save", async function (this: any) {
            savedReview = this;
            this.reviewId = 501;
            return this;
        });

        const res = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9001,
                rating: 5,
                comment: "Villa sạch sẽ, view biển rất đẹp!",
            });

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.reviewId, 501);
        assert.ok(savedReview);
        assert.equal(savedReview.rating, 5);
        assert.equal(savedReview.reviewerUserId, 201);
    });

    it("RV-02: Từ chối đánh giá khi đơn phòng chưa hoàn tất (đang confirmed, chưa check-out) (HTTP 409)", async () => {
        patch(Booking, "findOne", async () => ({
            bookingId: 9002,
            guestUserId: 201,
            listingId: 801,
            status: "confirmed",
            checkedOutAt: null,
        }));

        const res = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9002,
                rating: 5,
                comment: "Chưa ở xong nhưng muốn đánh giá trước",
            });

        assert.equal(res.status, 409);
        assert.equal(res.body.success, false);
        assert.match(res.body.message, /must be completed before review/i);
    });

    it("RV-03: Chặn user đánh giá đơn phòng không thuộc về mình (IDOR) (HTTP 403)", async () => {
        patch(Booking, "findOne", async () => ({
            bookingId: 9003,
            guestUserId: 202, // Đơn của user 202
            listingId: 801,
            status: "completed",
            checkedOutAt: new Date(),
        }));

        const res = await request(app)
            .post("/api/reviews")
            .set(guestAuth) // User 201 gọi
            .send({
                bookingId: 9003,
                rating: 5,
                comment: "Đánh giá trộm đơn người khác",
            });

        assert.equal(res.status, 403);
        assert.equal(res.body.success, false);
    });

    it("RV-04: Chặn đánh giá trùng cho cùng một đơn phòng (HTTP 409)", async () => {
        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            listingId: 801,
            status: "completed",
            checkedOutAt: new Date(),
        }));

        // Đã có review trước đó
        patch(Review, "findOne", async () => buildReview({ reviewId: 501, bookingId: 9001 }));

        const res = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9001,
                rating: 4,
                comment: "Đánh giá lần 2",
            });

        assert.equal(res.status, 409);
        assert.equal(res.body.success, false);
        assert.match(res.body.message, /already been reviewed/i);
    });

    it("RV-05: Từ chối số sao không hợp lệ (rating = 0, 6 hoặc âm) với lỗi 422", async () => {
        const resZero = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9001,
                rating: 0,
            });
        assert.equal(resZero.status, 422);

        const resOver = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9001,
                rating: 6,
            });
        assert.equal(resOver.status, 422);
    });

    it("RV-06: Khử mã độc XSS trong nội dung đánh giá của khách", async () => {
        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            listingId: 801,
            status: "completed",
            checkedOutAt: new Date(),
        }));
        patch(Review, "findOne", async () => null);
        patch(Listing, "findOne", async () => ({ listingId: 801, hostId: 101 }));

        let savedComment = "";
        patch(Review.prototype, "save", async function (this: any) {
            savedComment = this.comment;
            this.reviewId = 502;
            return this;
        });

        const res = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9001,
                rating: 5,
                comment: "Villa rat tot <script>alert('xss')</script><img src=x onerror=alert(1)>",
            });

        assert.equal(res.status, 201);
        assert.ok(!savedComment.includes("<script>"));
        assert.ok(!savedComment.includes("onerror="));
    });

    it("RV-07: Cho phép đánh giá chỉ có số sao, không bắt buộc nội dung comment (HTTP 201)", async () => {
        patch(Booking, "findOne", async () => ({
            bookingId: 9001,
            guestUserId: 201,
            listingId: 801,
            status: "completed",
            checkedOutAt: new Date(),
        }));
        patch(Review, "findOne", async () => null);
        patch(Listing, "findOne", async () => ({ listingId: 801, hostId: 101 }));

        let savedReview: any = null;
        patch(Review.prototype, "save", async function (this: any) {
            savedReview = this;
            this.reviewId = 503;
            return this;
        });

        const res = await request(app)
            .post("/api/reviews")
            .set(guestAuth)
            .send({
                bookingId: 9001,
                rating: 4,
            });

        assert.equal(res.status, 201);
        assert.equal(res.body.data.reviewId, 503);
        assert.equal(savedReview.rating, 4);
        assert.equal(savedReview.comment, "");
    });

    it("RV-08: Host của listing phản hồi đánh giá thành công (HTTP 201)", async () => {
        const mockReview = buildReview({ reviewId: 501, listingId: 801, hostReply: null });
        patch(Review, "findOne", async () => mockReview);
        patch(Listing, "findOne", async () => ({ listingId: 801, hostId: 101 }));

        const res = await request(app)
            .post("/api/reviews/501/reply")
            .set(hostAuth) // Host 101 sở hữu listing 801
            .send({
                reply: "Cảm ơn quý khách đã ghé thăm và ủng hộ villa!",
            });

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(mockReview.hostReply, "Cảm ơn quý khách đã ghé thăm và ủng hộ villa!");
    });

    it("RV-09: Chặn Host khác (không phải chủ listing) phản hồi review (HTTP 403)", async () => {
        const mockReview = buildReview({ reviewId: 501, listingId: 801, hostReply: null });
        patch(Review, "findOne", async () => mockReview);
        patch(Listing, "findOne", async () => ({ listingId: 801, hostId: 101 }));

        const res = await request(app)
            .post("/api/reviews/501/reply")
            .set(otherHostAuth) // Host 102 không phải chủ listing 801
            .send({
                reply: "Phản hồi trái phép",
            });

        assert.equal(res.status, 403);
        assert.equal(res.body.success, false);
    });

    it("RV-10: Chặn phản hồi lần 2 khi review đã có hostReply (HTTP 409)", async () => {
        const mockReview = buildReview({
            reviewId: 501,
            listingId: 801,
            hostReply: "Đã phản hồi trước đó",
        });
        patch(Review, "findOne", async () => mockReview);

        const res = await request(app)
            .post("/api/reviews/501/reply")
            .set(hostAuth)
            .send({
                reply: "Phản hồi đè lần nữa",
            });

        assert.equal(res.status, 409);
        assert.match(res.body.message, /already has a reply/i);
    });

    it("RV-11: Lấy danh sách review của listing có phân trang (HTTP 200)", async () => {
        patch(Listing, "findOne", async () => ({ listingId: 801, status: "active", deletedAt: null }));

        const mockList = [
            buildReview({ reviewId: 502, rating: 5, comment: "Tuyệt vời" }),
            buildReview({ reviewId: 501, rating: 4, comment: "Rất tốt" }),
        ];

        patch(Review, "find", () => ({
            sort() {
                return this;
            },
            lean: async () => mockList,
        }));

        const res = await request(app)
            .get("/api/listings/801/reviews?page=1&limit=10");

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.ok(Array.isArray(res.body.data.items));
        assert.equal(res.body.data.items.length, 2);
        assert.equal(res.body.data.summary.reviewCount, 2);
    });

    it("RV-12: Tính đúng điểm trung bình rating và số lượt review", async () => {
        patch(Listing, "findOne", async () => ({ listingId: 801, status: "active", deletedAt: null }));

        const mockList = [
            buildReview({ reviewId: 501, rating: 5 }),
            buildReview({ reviewId: 502, rating: 4 }),
            buildReview({ reviewId: 503, rating: 4 }),
        ];

        patch(Review, "find", () => ({
            sort() {
                return this;
            },
            lean: async () => mockList,
        }));

        const res = await request(app).get("/api/listings/801/reviews");

        assert.equal(res.status, 200);
        // (5 + 4 + 4) / 3 = 4.333... -> 4.3
        assert.equal(res.body.data.summary.avgRating, 4.3);
        assert.equal(res.body.data.summary.reviewCount, 3);
    });

    it("RV-13: Khách có thể cập nhật và xóa review của chính mình (HTTP 200)", async () => {
        const mockReview = buildReview({ reviewId: 501, reviewerUserId: 201 });
        patch(Review, "findOne", async () => mockReview);

        // Update
        const patchRes = await request(app)
            .patch("/api/reviews/501")
            .set(guestAuth)
            .send({
                rating: 4,
                comment: "Sửa lại comment sau khi trải nghiệm",
            });

        assert.equal(patchRes.status, 200);
        assert.equal(mockReview.rating, 4);
        assert.equal(mockReview.comment, "Sửa lại comment sau khi trải nghiệm");

        // Delete
        const deleteRes = await request(app)
            .delete("/api/reviews/501")
            .set(guestAuth);

        assert.equal(deleteRes.status, 200);
        assert.equal(mockReview.isVisible, false);
        assert.ok(mockReview.deletedAt !== null);
    });

    it("RV-14: Chặn khách sửa hoặc xóa review của người khác (HTTP 403)", async () => {
        const mockReview = buildReview({ reviewId: 501, reviewerUserId: 202 }); // Của user 202
        patch(Review, "findOne", async () => mockReview);

        const patchRes = await request(app)
            .patch("/api/reviews/501")
            .set(guestAuth) // User 201 gọi
            .send({ rating: 1 });

        assert.equal(patchRes.status, 403);

        const deleteRes = await request(app)
            .delete("/api/reviews/501")
            .set(guestAuth);

        assert.equal(deleteRes.status, 403);
    });

    it("RV-15: Chặn thao tác sửa/xóa trên review đã bị ẩn hoặc xóa (HTTP 409)", async () => {
        const mockReview = buildReview({
            reviewId: 501,
            reviewerUserId: 201,
            isVisible: false,
            deletedAt: new Date("2026-05-16T00:00:00.000Z"),
        });
        patch(Review, "findOne", async () => mockReview);

        const patchRes = await request(app)
            .patch("/api/reviews/501")
            .set(guestAuth)
            .send({ rating: 5 });

        assert.equal(patchRes.status, 409);
        assert.match(patchRes.body.message, /has been deleted/i);

        const deleteRes = await request(app)
            .delete("/api/reviews/501")
            .set(guestAuth);

        assert.equal(deleteRes.status, 409);
    });
});
