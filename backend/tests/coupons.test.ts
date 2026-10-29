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
const sequelize = require("../dist/config/database").default;
const Coupon = require("../dist/models/coupon").default;
const CouponRedemption = require("../dist/models/coupon-redemption").default;
const authService = require("../dist/modules/auth/auth.service");

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
const adminAuth = { Authorization: "Bearer admin-token" };

const buildCoupon = (overrides: Record<string, unknown> = {}) => ({
    couponId: 701,
    code: "SUMMER10",
    title: "Khuyến mãi mùa hè 10%",
    description: "Giảm 10% cho kỳ nghỉ hè",
    type: "percent",
    discountValue: 10,
    maxDiscountAmount: 500000,
    minOrderValue: 1000000,
    startDate: new Date("2026-05-01T00:00:00.000Z"),
    endDate: new Date("2026-08-31T23:59:59.000Z"),
    totalLimit: 100,
    usedCount: 5,
    limitPerUser: 1,
    isActive: true,
    deletedAt: null,
    createdAt: new Date("2026-05-01T00:00:00.000Z"),
    updatedAt: new Date("2026-05-01T00:00:00.000Z"),
    set(payload: Record<string, unknown>) {
        Object.assign(this, payload);
        return this;
    },
    async save() {
        return this;
    },
    ...overrides,
});

describe("Module coupons (CP-01 to CP-18)", () => {
    let app: any;

    beforeEach(() => {
        app = require("../dist/app").default;

        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "guest-token") return { userId: "201", role: "guest" };
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
            ["1", adminUser],
        ]);

        const User = require("../dist/models/user").default;
        patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);

        const auditLogService = require("../dist/services/audit-log-service");
        patch(auditLogService, "writeAuditLog", async () => {});

        patch(sequelize, "transaction", async (arg1: any, arg2?: any) => {
            const callback = typeof arg1 === "function" ? arg1 : arg2;
            return callback ? callback({}) : {};
        });
    });

    it("CP-01: Admin tạo coupon % hợp lệ thành công (HTTP 201)", async () => {
        patch(Coupon, "findOne", async () => null); // Không trùng code

        let savedCoupon: any = null;
        patch(Coupon.prototype, "save", async function (this: any) {
            savedCoupon = this;
            this.couponId = 701;
            return this;
        });

        const res = await request(app)
            .post("/api/admin/coupons")
            .set(adminAuth)
            .send({
                code: "SUMMER10",
                title: "Giảm 10% mùa hè",
                type: "percent",
                discountValue: "10",
                maxDiscountAmount: "500000",
                minOrderValue: "1000000",
                startDate: "2026-06-01T00:00:00.000Z",
                endDate: "2026-08-31T23:59:59.000Z",
                totalLimit: 100,
                limitPerUser: 1,
            });

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.code, "SUMMER10");
        assert.equal(res.body.data.type, "percent");
    });

    it("CP-02: Từ chối tạo coupon khi mã code đã tồn tại (HTTP 409)", async () => {
        patch(Coupon, "findOne", async () => buildCoupon({ code: "SUMMER10" }));

        const res = await request(app)
            .post("/api/admin/coupons")
            .set(adminAuth)
            .send({
                code: "SUMMER10",
                title: "Trùng mã",
                type: "percent",
                discountValue: "10",
                startDate: "2026-06-01T00:00:00.000Z",
                endDate: "2026-08-31T23:59:59.000Z",
            });

        assert.equal(res.status, 409);
        assert.equal(res.body.success, false);
        assert.match(res.body.message, /already exists/i);
    });

    it("CP-03: Từ chối coupon % có discountValue ngoài khoảng 0 - 100 với mã 422", async () => {
        const resOver = await request(app)
            .post("/api/admin/coupons")
            .set(adminAuth)
            .send({
                code: "OVER100",
                title: "Vượt 100%",
                type: "percent",
                discountValue: "150",
                startDate: "2026-06-01T00:00:00.000Z",
                endDate: "2026-08-31T23:59:59.000Z",
            });

        assert.equal(resOver.status, 422);

        const resZero = await request(app)
            .post("/api/admin/coupons")
            .set(adminAuth)
            .send({
                code: "ZERO0",
                title: "0%",
                type: "percent",
                discountValue: "0",
                startDate: "2026-06-01T00:00:00.000Z",
                endDate: "2026-08-31T23:59:59.000Z",
            });

        assert.equal(resZero.status, 422);
    });

    it("CP-04: Từ chối khi ngày kết thúc trước hoặc bằng ngày bắt đầu (endDate <= startDate) với mã 422", async () => {
        const res = await request(app)
            .post("/api/admin/coupons")
            .set(adminAuth)
            .send({
                code: "INVALDDATE",
                title: "Ngày sai",
                type: "percent",
                discountValue: "10",
                startDate: "2026-08-01T00:00:00.000Z",
                endDate: "2026-07-01T00:00:00.000Z", // endDate < startDate
            });

        assert.equal(res.status, 422);
    });

    it("CP-05: Áp mã coupon hợp lệ tính đúng số tiền giảm và giá cuối (HTTP 200, valid: true)", async () => {
        // Đơn 2,000,000 VND, giảm 10% = 200,000 VND -> final = 1,800,000 VND
        const mockCoupon = buildCoupon({
            type: "percent",
            discountValue: 10,
            maxDiscountAmount: 500000,
            minOrderValue: 1000000,
            startDate: new Date(Date.now() - 86400000),
            endDate: new Date(Date.now() + 86400000),
            usedCount: 0,
            totalLimit: 100,
            limitPerUser: 2,
        });

        patch(Coupon, "findOne", async () => mockCoupon);
        patch(CouponRedemption, "count", async () => 0); // User chưa dùng

        const res = await request(app)
            .get("/api/coupons/validate?code=SUMMER10&bookingAmount=2000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.valid, true);
        assert.equal(res.body.data.discountAmount, 200000);
        assert.equal(res.body.data.finalAmount, 1800000);
    });

    it("CP-06: Báo lỗi mã không tồn tại hoặc bị xóa mềm (valid: false, Coupon is invalid)", async () => {
        patch(Coupon, "findOne", async () => null);

        const res = await request(app)
            .get("/api/coupons/validate?code=NOTFOUND&bookingAmount=1000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, false);
        assert.match(res.body.data.reason, /invalid/i);
    });

    it("CP-07: Báo lỗi khi mã đã hết hạn (endDate < now) (valid: false)", async () => {
        const expiredCoupon = buildCoupon({
            startDate: new Date(Date.now() - 10000000),
            endDate: new Date(Date.now() - 1000), // Đã hết hạn
        });
        patch(Coupon, "findOne", async () => expiredCoupon);

        const res = await request(app)
            .get("/api/coupons/validate?code=EXPIRED&bookingAmount=2000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, false);
        assert.match(res.body.data.reason, /expired or not active/i);
    });

    it("CP-08: Báo lỗi khi mã chưa đến thời gian bắt đầu (startDate > now) (valid: false)", async () => {
        const futureCoupon = buildCoupon({
            startDate: new Date(Date.now() + 1000000), // Trong tương lai
            endDate: new Date(Date.now() + 2000000),
        });
        patch(Coupon, "findOne", async () => futureCoupon);

        const res = await request(app)
            .get("/api/coupons/validate?code=FUTURE&bookingAmount=2000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, false);
        assert.match(res.body.data.reason, /expired or not active/i);
    });

    it("CP-09: Báo lỗi khi mã đã đạt giới hạn lượt dùng tổng (usedCount >= totalLimit) (valid: false)", async () => {
        const exhaustedCoupon = buildCoupon({
            totalLimit: 10,
            usedCount: 10, // Đã hết lượt dùng
            startDate: new Date(Date.now() - 86400000),
            endDate: new Date(Date.now() + 86400000),
        });
        patch(Coupon, "findOne", async () => exhaustedCoupon);

        const res = await request(app)
            .get("/api/coupons/validate?code=EXHAUSTED&bookingAmount=2000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, false);
        assert.match(res.body.data.reason, /usage limit has been reached/i);
    });

    it("CP-10: Báo lỗi khi giá trị đơn chưa đạt mức tối thiểu minOrderValue (valid: false)", async () => {
        const minOrderCoupon = buildCoupon({
            minOrderValue: 2000000, // Tối thiểu 2 triệu
            startDate: new Date(Date.now() - 86400000),
            endDate: new Date(Date.now() + 86400000),
        });
        patch(Coupon, "findOne", async () => minOrderCoupon);

        const res = await request(app)
            .get("/api/coupons/validate?code=MINORDER&bookingAmount=1500000") // Chỉ 1.5 triệu
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, false);
        assert.match(res.body.data.reason, /does not meet coupon minimum/i);
    });

    it("CP-11: Báo lỗi khi user đã dùng hết số lượt cho phép của tài khoản (valid: false)", async () => {
        const userLimitCoupon = buildCoupon({
            limitPerUser: 1, // Mỗi user dùng 1 lần
            startDate: new Date(Date.now() - 86400000),
            endDate: new Date(Date.now() + 86400000),
        });
        patch(Coupon, "findOne", async () => userLimitCoupon);
        patch(CouponRedemption, "count", async () => 1); // User đã dùng 1 lần

        const res = await request(app)
            .get("/api/coupons/validate?code=ONCE&bookingAmount=2000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, false);
        assert.match(res.body.data.reason, /usage limit has been reached/i);
    });

    it("CP-12: Mức giảm không được vượt qua giới hạn trần maxDiscountAmount", async () => {
        // Đơn 10,000,000 VND, giảm 20% = 2,000,000 VND, nhưng maxDiscountAmount = 500,000 VND
        const cappedCoupon = buildCoupon({
            type: "percent",
            discountValue: 20,
            maxDiscountAmount: 500000,
            startDate: new Date(Date.now() - 86400000),
            endDate: new Date(Date.now() + 86400000),
        });
        patch(Coupon, "findOne", async () => cappedCoupon);
        patch(CouponRedemption, "count", async () => 0);

        const res = await request(app)
            .get("/api/coupons/validate?code=CAP20&bookingAmount=10000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, true);
        assert.equal(res.body.data.discountAmount, 500000); // Bị chặn ở trần 500,000đ
        assert.equal(res.body.data.finalAmount, 9500000);
    });

    it("CP-13: Giảm cố định fixed_amount lớn hơn tổng tiền thì finalAmount bằng 0, không âm", async () => {
        // Đơn 500,000 VND, mã giảm 1,000,000 VND -> final = 0
        const fixedCoupon = buildCoupon({
            type: "fixed_amount",
            discountValue: 1000000,
            maxDiscountAmount: null,
            minOrderValue: null,
            startDate: new Date(Date.now() - 86400000),
            endDate: new Date(Date.now() + 86400000),
        });
        patch(Coupon, "findOne", async () => fixedCoupon);
        patch(CouponRedemption, "count", async () => 0);

        const res = await request(app)
            .get("/api/coupons/validate?code=FIXED1M&bookingAmount=500000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.valid, true);
        assert.equal(res.body.data.discountAmount, 500000);
        assert.equal(res.body.data.finalAmount, 0);
    });

    it("CP-14: Mã coupon tự động chuẩn hóa uppercase, không phân biệt hoa/thường", async () => {
        let searchedCode = "";
        patch(Coupon, "findOne", async ({ where }: any) => {
            searchedCode = where.code;
            return buildCoupon({ code: "SUMMER10" });
        });
        patch(CouponRedemption, "count", async () => 0);

        const res = await request(app)
            .get("/api/coupons/validate?code=summer10&bookingAmount=2000000")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(searchedCode, "SUMMER10");
    });

    it("CP-15: Chặn Guest tạo coupon trên endpoint admin (HTTP 403 Forbidden)", async () => {
        const res = await request(app)
            .post("/api/admin/coupons")
            .set(guestAuth) // Token Guest
            .send({
                code: "HACKCOUPON",
                title: "Fake",
                type: "percent",
                discountValue: "50",
            });

        assert.equal(res.status, 403);
        assert.equal(res.body.success, false);
    });

    it("CP-16: Admin cập nhật thông tin coupon thành công (HTTP 200)", async () => {
        const mockCoupon = buildCoupon({ couponId: 701, title: "Tiêu đề cũ" });
        patch(Coupon, "findOne", async () => mockCoupon);

        const res = await request(app)
            .patch("/api/admin/coupons/701")
            .set(adminAuth)
            .send({
                title: "Tiêu đề mới đã sửa",
                isActive: false,
            });

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(mockCoupon.title, "Tiêu đề mới đã sửa");
        assert.equal(mockCoupon.isActive, false);
    });

    it("CP-17: Admin xóa mềm coupon thành công (HTTP 200)", async () => {
        const mockCoupon = buildCoupon({ couponId: 701, deletedAt: null });
        patch(Coupon, "findOne", async () => mockCoupon);

        const res = await request(app)
            .delete("/api/admin/coupons/701")
            .set(adminAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.ok(mockCoupon.deletedAt !== null);
    });

    it("CP-18: Chặn người dùng không phải Admin xóa hoặc sửa coupon (HTTP 403)", async () => {
        const patchRes = await request(app)
            .patch("/api/admin/coupons/701")
            .set(guestAuth)
            .send({ title: "Guest sửa" });

        assert.equal(patchRes.status, 403);

        const deleteRes = await request(app)
            .delete("/api/admin/coupons/701")
            .set(guestAuth);

        assert.equal(deleteRes.status, 403);
    });
});
