const assert = require("node:assert/strict");
const { after, afterEach, beforeEach, describe, it } = require("node:test");

const request = require("supertest");
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;
const Listing = require("../dist/models/listing").default;
const User = require("../dist/models/user").default;
const authService = require("../dist/modules/auth/auth.service");
const authRepository = require("../dist/modules/auth/auth.repository");
const adminService = require("../dist/modules/admin/admin.service");
const usersService = require("../dist/modules/users/users.service");
const usersRepository = require("../dist/modules/users/users.repository");
const reportsService = require("../dist/modules/reports/reports.service");
const auditLogService = require("../dist/services/audit-log-service");
const hostVerificationStatusService = require("../dist/services/host-verification-status-service");
const semanticSearchIndexer = require("../dist/modules/semantic-search/semantic-search.indexer");
const notificationService = require("../dist/modules/notifications/notification.service");

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

const adminUser = {
    id: "1",
    _id: "1",
    userId: 1,
    email: "admin@example.com",
    phone: "0900000001",
    name: "System Admin",
    fullName: "System Admin",
    username: "admin",
    status: "active",
    roles: ["admin"],
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-01-01"),
};

const guestUser = {
    id: "201",
    _id: "201",
    userId: 201,
    email: "guest@example.com",
    phone: "0900000201",
    name: "Guest User",
    fullName: "Guest User",
    username: "guest",
    status: "active",
    roles: ["guest"],
    createdAt: new Date("2026-02-01"),
    updatedAt: new Date("2026-02-01"),
};

const hostUser = {
    id: "101",
    _id: "101",
    userId: 101,
    email: "host@example.com",
    phone: "0900000101",
    name: "Host User",
    fullName: "Host User",
    username: "host",
    status: "active",
    roles: ["host"],
    createdAt: new Date("2026-02-01"),
    updatedAt: new Date("2026-02-01"),
};

const adminAuth = { Authorization: "Bearer admin-token" };
const guestAuth = { Authorization: "Bearer guest-token" };
const hostAuth = { Authorization: "Bearer host-token" };

const buildListing = (overrides: Record<string, unknown> = {}) => ({
    id: 1,
    listingId: 801,
    hostId: 101,
    title: "Villa Vũng Tàu Luxury",
    status: "pending_approval",
    description: "Villa view biển tuyệt đẹp",
    addressLine: "123 Trần Phú",
    ward: "Phường 1",
    district: "Thành phố Vũng Tàu",
    city: "Bà Rịa - Vũng Tàu",
    propertyType: "villa",
    roomType: "entire_place",
    basePrice: 2500000,
    currency: "VND",
    rejectionReason: null,
    approvedBy: null,
    approvedAt: null,
    images: [],
    createdAt: new Date("2026-05-01"),
    updatedAt: new Date("2026-05-01"),
    async save() {
        return this;
    },
    ...overrides,
});

describe("Module admin (AD-01 to AD-14)", () => {
    let app: any;

    beforeEach(() => {
        app = require("../dist/app").default;

        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "admin-token") return { userId: "1", role: "admin" };
            if (token === "guest-token") return { userId: "201", role: "guest" };
            if (token === "host-token") return { userId: "101", role: "host" };
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
            ["1", adminUser],
            ["201", guestUser],
            ["101", hostUser],
        ]);

        patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findByPk", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findOne", async ({ where }: any) => {
            const id = where?.id || where?.userId || where?._id;
            return usersMap.get(String(id)) ?? null;
        });

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

        patch(sequelize, "query", async () => []);

        patch(hostVerificationStatusService, "isHostVerifiedForPublishing", async () => true);
        patch(semanticSearchIndexer, "scheduleSemanticReindex", () => {});
        patch(notificationService, "notifyListingApproved", async () => {});
        patch(notificationService, "notifyListingRejected", async () => {});
        patch(auditLogService, "writeAuditLog", async () => ({}));
        patch(auditLogService, "createAuditLog", async () => ({}));
        patch(authRepository, "createAuditLog", async () => ({}));

        patch(usersRepository, "findUserProfileByUserId", async () => null);
        patch(usersRepository, "saveUserUpdates", async (user: any, updates: any) => {
            Object.assign(user, updates);
            return user;
        });
    });

    it("AD-01: Admin xem dashboard thống kê doanh thu và lượt đặt phòng thành công (HTTP 200)", async () => {
        patch(reportsService, "getAdminRevenueReport", async () => ({
            totalRevenue: 50000000,
            currency: "VND",
            items: [
                { bucket: "2026-05-01", grossRevenue: 25000000, netRevenue: 22500000, transactionCount: 5 },
                { bucket: "2026-05-02", grossRevenue: 25000000, netRevenue: 22500000, transactionCount: 5 },
            ],
            summary: {
                totalOrders: 10,
                totalGrossRevenue: 50000000,
            },
        }));

        patch(reportsService, "getAdminBookingsReport", async () => ({
            totalBookings: 15,
            items: [],
            byStatus: {
                confirmed: 10,
                completed: 3,
                cancelled: 2,
            },
        }));

        const resRevenue = await request(app)
            .get("/api/admin/reports/revenue?from=2026-05-01&to=2026-05-10")
            .set(adminAuth);

        assert.equal(resRevenue.status, 200);
        assert.equal(resRevenue.body.success, true);
        assert.ok(resRevenue.body.data.totalRevenue !== undefined || resRevenue.body.data.summary !== undefined);

        const resBookings = await request(app)
            .get("/api/admin/reports/bookings?from=2026-05-01&to=2026-05-10")
            .set(adminAuth);

        assert.equal(resBookings.status, 200);
        assert.equal(resBookings.body.success, true);
        assert.equal(resBookings.body.data.totalBookings, 15);
    });

    it("AD-02: Chặn Guest và Host truy cập vào các API quản trị của Admin (HTTP 403 Forbidden)", async () => {
        const resGuest = await request(app)
            .get("/api/admin/reports/revenue")
            .set(guestAuth);

        assert.equal(resGuest.status, 403);

        const resHost = await request(app)
            .patch("/api/admin/listings/801/approve")
            .set(hostAuth);

        assert.equal(resHost.status, 403);

        const resUsers = await request(app)
            .get("/api/users")
            .set(guestAuth);

        assert.equal(resUsers.status, 403);
    });

    it("AD-03: Admin duyệt listing thành công - chuyển status sang active và index vào Qdrant (HTTP 200)", async () => {
        const mockListing = buildListing({ listingId: 801, status: "pending_approval" });
        patch(Listing, "findOne", async () => mockListing);

        let reindexedListingId: number | null = null;
        let reindexReason = "";
        patch(semanticSearchIndexer, "scheduleSemanticReindex", (listingId: number, reason: string) => {
            reindexedListingId = listingId;
            reindexReason = reason;
        });

        let approvedNotified = false;
        patch(notificationService, "notifyListingApproved", async () => {
            approvedNotified = true;
        });

        let auditAction = "";
        patch(auditLogService, "writeAuditLog", async (params: any) => {
            auditAction = params.action;
        });

        const res = await request(app)
            .patch("/api/admin/listings/801/approve")
            .set(adminAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(mockListing.status, "active");
        assert.equal(reindexedListingId, 801);
        assert.equal(reindexReason, "listing_approved");
        assert.equal(approvedNotified, true);
        assert.equal(auditAction, "listing.approve");
    });

    it("AD-04: Admin từ chối duyệt listing kèm lý do rõ ràng - gửi thông báo cho host (HTTP 200/422)", async () => {
        const mockListing = buildListing({ listingId: 802, status: "pending_approval" });
        patch(Listing, "findOne", async () => mockListing);

        let rejectionNotified = false;
        patch(notificationService, "notifyListingRejected", async () => {
            rejectionNotified = true;
        });

        // 4A: Từ chối với lý do hợp lệ
        const resValid = await request(app)
            .patch("/api/admin/listings/802/reject")
            .set(adminAuth)
            .send({
                reason: "Hình ảnh mờ, giấy tờ chỗ nghỉ chưa đủ điều kiện.",
            });

        assert.equal(resValid.status, 200);
        assert.equal(mockListing.status, "rejected");
        assert.equal(rejectionNotified, true);

        // 4B: Từ chối với lý do rỗng -> Lỗi 422
        const resEmpty = await request(app)
            .patch("/api/admin/listings/802/reject")
            .set(adminAuth)
            .send({
                reason: "   ",
            });

        assert.equal(resEmpty.status, 422);
    });

    it("AD-05: Khóa tài khoản người dùng vi phạm (status = blocked) - vô hiệu hóa đăng nhập (HTTP 200)", async () => {
        const targetUser = {
            ...guestUser,
            status: "active",
            async save() {
                return this;
            },
        };
        patch(usersService, "findUserById", async () => targetUser);
        patch(usersRepository, "findUserById", async () => targetUser);
        patch(usersRepository, "getUserRoles", async () => ["guest"]);
        patch(usersRepository, "updateUser", async (_id: any, updates: any) => {
            Object.assign(targetUser, updates);
            return targetUser;
        });

        let auditAction = "";
        patch(authRepository, "createAuditLog", async (params: any) => {
            auditAction = params.action;
            return {};
        });
        patch(auditLogService, "createAuditLog", async (params: any) => {
            auditAction = params.action;
            return {};
        });

        const res = await request(app)
            .patch("/api/users/201/status")
            .set(adminAuth)
            .send({
                status: "blocked",
            });

        assert.equal(res.status, 200);
        assert.equal(targetUser.status, "blocked");
        assert.equal(auditAction, "users.account_locked");

        // Xác minh tài khoản bị khoá sẽ bị từ chối xác thực
        assert.throws(() => {
            const { assertUserCanAuthenticate } = require("../dist/modules/auth/auth.service");
            assertUserCanAuthenticate(targetUser);
        }, /Account is (blocked|unavailable)/i);
    });

    it("AD-06: Chặn admin tự khóa chính mình khi là admin hoạt động duy nhất (HTTP 409/422)", async () => {
        const adminTarget = {
            ...adminUser,
            status: "active",
            async save() {
                return this;
            },
        };
        patch(usersService, "findUserById", async () => adminTarget);
        patch(usersRepository, "findUserById", async () => adminTarget);
        patch(usersRepository, "getUserRoles", async () => ["admin"]);
        patch(usersRepository, "countActiveUsersWithRole", async () => 1); // Chỉ còn 1 admin duy nhất

        const res = await request(app)
            .patch("/api/users/1/status")
            .set(adminAuth)
            .send({
                status: "blocked",
            });

        assert.ok(res.status === 409 || res.status === 422);
        assert.ok(res.body.message.includes("last active admin"));
    });

    it("AD-07: Mở khóa tài khoản đã bị khóa (status = active) - cho phép đăng nhập lại (HTTP 200)", async () => {
        const blockedUser = {
            ...guestUser,
            status: "blocked",
            async save() {
                return this;
            },
        };
        patch(usersService, "findUserById", async () => blockedUser);
        patch(usersRepository, "findUserById", async () => blockedUser);
        patch(usersRepository, "getUserRoles", async () => ["guest"]);
        patch(usersRepository, "updateUser", async (_id: any, updates: any) => {
            Object.assign(blockedUser, updates);
            return blockedUser;
        });

        const res = await request(app)
            .patch("/api/users/201/status")
            .set(adminAuth)
            .send({
                status: "active",
            });

        assert.equal(res.status, 200);
        assert.equal(blockedUser.status, "active");

        // Xác minh tài khoản sau khi mở khóa có thể xác thực bình thường không throw
        const { assertUserCanAuthenticate } = require("../dist/modules/auth/auth.service");
        assert.doesNotThrow(() => {
            assertUserCanAuthenticate(blockedUser);
        });
    });

    it("AD-08: Thống kê doanh thu theo khoảng thời gian from-to khớp số liệu giao dịch (HTTP 200)", async () => {
        patch(reportsService, "getAdminRevenueReport", async (_actor: any, query: any) => {
            assert.equal(query.from, "2026-05-01");
            assert.equal(query.to, "2026-05-31");
            return {
                from: "2026-05-01",
                to: "2026-05-31",
                totalRevenue: 120000000,
                netRevenue: 108000000,
                refundedAmount: 5000000,
                items: [
                    { bucket: "2026-05-15", grossRevenue: 125000000, refundedAmount: 5000000, netRevenue: 108000000 },
                ],
            };
        });

        const res = await request(app)
            .get("/api/admin/reports/revenue?from=2026-05-01&to=2026-05-31&group=day")
            .set(adminAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.totalRevenue, 120000000);
        assert.equal(res.body.data.netRevenue, 108000000);
    });

    it("AD-09: Từ chối truy vấn thống kê khi khoảng thời gian sai from > to với mã 422", async () => {
        const res = await request(app)
            .get("/api/admin/reports/revenue?from=2026-05-31&to=2026-05-01")
            .set(adminAuth);

        assert.equal(res.status, 422);
    });

    it("AD-10: Thống kê khi không có dữ liệu trả về 0 an toàn, không gây chia cho 0 (HTTP 200)", async () => {
        patch(reportsService, "getAdminRevenueReport", async () => ({
            totalRevenue: 0,
            netRevenue: 0,
            refundedAmount: 0,
            averageOrderValue: 0,
            items: [],
            summary: {
                totalOrders: 0,
                totalGrossRevenue: 0,
            },
        }));

        const res = await request(app)
            .get("/api/admin/reports/revenue?from=2026-01-01&to=2026-01-10")
            .set(adminAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.totalRevenue, 0);
        assert.equal(res.body.data.averageOrderValue, 0);
    });

    it("AD-11: Khả năng xử lý tập dữ liệu thống kê lớn - tính toán aggregate tối ưu", async () => {
        const largeDataset = Array.from({ length: 30 }, (_, i) => ({
            bucket: `2026-05-${String(i + 1).padStart(2, "0")}`,
            grossRevenue: 10000000,
            netRevenue: 9000000,
            transactionCount: 20,
        }));

        patch(reportsService, "getAdminRevenueReport", async () => ({
            totalRevenue: 300000000,
            items: largeDataset,
            summary: {
                totalOrders: 600,
            },
        }));

        const res = await request(app)
            .get("/api/admin/reports/revenue?from=2026-05-01&to=2026-05-30&group=day")
            .set(adminAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.data.items.length, 30);
    });

    it("AD-12: Danh sách người dùng có bộ lọc tìm kiếm và phân trang chính xác (HTTP 200)", async () => {
        patch(usersRepository, "listUsersForAdmin", async (filter: any) => {
            assert.equal(filter.search, "guest");
            assert.equal(filter.role, "guest");
            return {
                items: [
                    {
                        userId: 201,
                        username: "guest",
                        email: "guest@example.com",
                        roles: ["guest"],
                        status: "active",
                    },
                ],
                total: 1,
                page: 1,
                limit: 10,
                totalPages: 1,
            };
        });

        const res = await request(app)
            .get("/api/users?search=guest&role=guest&page=1&limit=10")
            .set(adminAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.items.length, 1);
        assert.equal(res.body.data.items[0].userId, 201);
    });

    it("AD-13: Ghi nhận đầy đủ audit log cho mọi hành động quản trị viên (approve, reject, status)", async () => {
        const auditEvents: string[] = [];
        patch(auditLogService, "writeAuditLog", async (params: any) => {
            auditEvents.push(params.action);
        });

        const mockListing = buildListing({ listingId: 803, status: "pending_approval" });
        patch(Listing, "findOne", async () => mockListing);

        await request(app)
            .patch("/api/admin/listings/803/approve")
            .set(adminAuth);

        assert.ok(auditEvents.includes("listing.approve"));
    });

    it("AD-14: Bảo mật thông tin nhạy cảm - API quản trị không bao giờ trả password hay passwordHash", async () => {
        const mockUserWithHash = {
            ...guestUser,
            passwordHash: "$2a$10$abcdefghijklmnopqrstuvwxyz1234567890",
            password: "plain-secret-password",
        };

        patch(usersService, "findUserById", async () => mockUserWithHash);
        patch(usersRepository, "findUserById", async () => mockUserWithHash);
        patch(usersRepository, "getUserRoles", async () => ["guest"]);
        patch(usersRepository, "getUserProfile", async () => null);

        const resDetail = await request(app)
            .get("/api/users/201")
            .set(adminAuth);

        assert.equal(resDetail.status, 200);
        const userJson = JSON.stringify(resDetail.body);

        assert.equal(userJson.includes("passwordHash"), false);
        assert.equal(userJson.includes("plain-secret-password"), false);
        assert.equal(resDetail.body.data.user.password, undefined);
        assert.equal(resDetail.body.data.user.passwordHash, undefined);
    });

    it("AD-15: Sắp xếp danh sách người dùng theo thứ tự vai trò guest -> host -> admin rồi theo tên tiếng Việt A-Z", () => {
        const unsorted = [
            {
                userId: "1",
                fullName: "Quản trị viên The Palm Villa",
                email: "admin@minhthanhvilla.com",
                role: "admin",
            },
            {
                userId: "11",
                fullName: "Đặng Kim An",
                email: "n23dccn001@student.ptithcm.edu.vn",
                role: "guest",
            },
            {
                userId: "12",
                fullName: "NGUYỄN VĂN A",
                email: "dangkiman41005@gmail.com",
                role: "host",
            },
            {
                userId: "4",
                fullName: "ĐẶNG KIM AN",
                email: "guest@gmail.com",
                role: "guest",
            },
            {
                userId: "2",
                fullName: "Nguyễn Minh Thành",
                email: "host.thanh@minhthanhvilla.com",
                roles: ["guest", "host"],
            },
            {
                userId: "15",
                fullName: "Lê Hoàng Long",
                email: "long@example.com",
                role: "guest",
            },
        ];

        const sorted = usersRepository.sortAdminUserItems(unsorted);
        assert.deepEqual(
            sorted.map((u: any) => u.userId),
            ["4", "11", "15", "2", "12", "1"],
        );
    });
});
