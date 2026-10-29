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
const Listing = require("../dist/models/listing").default;
const ListingImage = require("../dist/models/listing-image").default;
const Wishlist = require("../dist/models/wishlist").default;
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

const userAAuth = { Authorization: "Bearer user-a-token" };
const userBAuth = { Authorization: "Bearer user-b-token" };

const buildListing = (overrides: Record<string, unknown> = {}) => ({
    listingId: 801,
    title: "Luxury Beachfront Villa",
    description: "Villa tuyệt đẹp cạnh biển",
    basePrice: 2500000,
    addressLine: "12 Tran Phu",
    ward: "Phuong 1",
    district: "TP Vung Tau",
    city: "Vung Tau",
    propertyType: "villa",
    roomType: "entire_place",
    maxGuests: 8,
    bedrooms: 4,
    beds: 5,
    bathrooms: 3,
    currency: "VND",
    status: "active",
    deletedAt: null,
    images: [],
    ...overrides,
});

const buildWishlist = (overrides: Record<string, unknown> = {}) => ({
    wishlistId: 1001,
    userId: 201,
    listingId: 801,
    createdAt: new Date("2026-05-10T12:00:00.000Z"),
    updatedAt: new Date("2026-05-10T12:00:00.000Z"),
    ...overrides,
});

describe("Module wishlist (WL-01 to WL-10)", () => {
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
        ]);

        const User = require("../dist/models/user").default;
        patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(ListingImage, "findAll", async () => []);
    });

    it("WL-01: Thêm villa hợp lệ vào wishlist thành công (HTTP 201)", async () => {
        const mockListing = buildListing({ listingId: 801 });
        patch(Listing, "findOne", async () => mockListing);

        const mockWishlistItem = buildWishlist({ wishlistId: 1001, userId: 201, listingId: 801 });
        patch(Wishlist, "findOrCreate", async () => [mockWishlistItem, true]);

        const res = await request(app)
            .post("/api/wishlist/801")
            .set(userAAuth);

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.listingId, 801);
        assert.equal(res.body.data.userId, 201);
        assert.ok(res.body.data.listing);
        assert.equal(res.body.data.listing.title, "Luxury Beachfront Villa");
    });

    it("WL-02: Thêm trùng villa đã có trong wishlist xử lý idempotent thành công (HTTP 201)", async () => {
        const mockListing = buildListing({ listingId: 801 });
        patch(Listing, "findOne", async () => mockListing);

        // findOrCreate trả về item cũ với created = false
        const existingItem = buildWishlist({ wishlistId: 1001, userId: 201, listingId: 801 });
        patch(Wishlist, "findOrCreate", async () => [existingItem, false]);

        const res = await request(app)
            .post("/api/wishlist/801")
            .set(userAAuth);

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.wishlistId, 1001);
    });

    it("WL-03: Thêm listing không tồn tại hoặc bị ẩn/xóa trả về lỗi 404", async () => {
        patch(Listing, "findOne", async () => null);

        const res = await request(app)
            .post("/api/wishlist/99999")
            .set(userAAuth);

        assert.equal(res.status, 404);
        assert.equal(res.body.success, false);
        assert.match(res.body.message, /Listing not found/i);
    });

    it("WL-04: Từ chối truy cập wishlist khi chưa xác thực (thiếu token) với mã 401", async () => {
        const res = await request(app).get("/api/wishlist");
        assert.equal(res.status, 401);

        const postRes = await request(app).post("/api/wishlist/801");
        assert.equal(postRes.status, 401);
    });

    it("WL-05: Xóa villa khỏi wishlist thành công khi có trong danh sách (HTTP 200, removed: true)", async () => {
        patch(Wishlist, "destroy", async () => 1);

        const res = await request(app)
            .delete("/api/wishlist/801")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.listingId, 801);
        assert.equal(res.body.data.removed, true);
    });

    it("WL-06: Xóa mục không có trong wishlist trả về idempotent 200 với removed: false", async () => {
        patch(Wishlist, "destroy", async () => 0);

        const res = await request(app)
            .delete("/api/wishlist/801")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.removed, false);
    });

    it("WL-07: Xem danh sách wishlist của chính user hiện tại (HTTP 200)", async () => {
        const userAWishlists = [
            buildWishlist({ wishlistId: 1001, userId: 201, listingId: 801 }),
            buildWishlist({ wishlistId: 1002, userId: 201, listingId: 802 }),
        ];

        patch(Wishlist, "findAll", async ({ where }: any) => {
            assert.equal(where.userId, 201);
            return userAWishlists;
        });

        const listings = [
            buildListing({ listingId: 801, title: "Villa A" }),
            buildListing({ listingId: 802, title: "Villa B" }),
        ];

        patch(Listing, "findAll", async () => listings);

        const res = await request(app)
            .get("/api/wishlist")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.deepEqual(res.body.data.listingIds, [801, 802]);
        assert.equal(res.body.data.items.length, 2);
        assert.equal(res.body.data.invalidListingIds.length, 0);
    });

    it("WL-08: Tự động phân loại listing đã bị ẩn/xóa vào invalidListingIds và loại khỏi items hợp lệ", async () => {
        const userAWishlists = [
            buildWishlist({ wishlistId: 1001, userId: 201, listingId: 801 }),
            buildWishlist({ wishlistId: 1002, userId: 201, listingId: 802 }), // Listing 802 đã bị xóa
        ];

        patch(Wishlist, "findAll", async () => userAWishlists);

        // Chỉ có listing 801 là active
        patch(Listing, "findAll", async () => [
            buildListing({ listingId: 801, title: "Villa A", status: "active" }),
        ]);

        const res = await request(app)
            .get("/api/wishlist")
            .set(userAAuth);

        assert.equal(res.status, 200);
        assert.deepEqual(res.body.data.listingIds, [801]);
        assert.deepEqual(res.body.data.invalidListingIds, [802]);
        assert.equal(res.body.data.items.length, 1);
        assert.equal(res.body.data.items[0].listingId, 801);
    });

    it("WL-09: Đảm bảo cách ly dữ liệu giữa các user (User B không xem được wishlist User A)", async () => {
        let queriedUserId: number | null = null;

        patch(Wishlist, "findAll", async ({ where }: any) => {
            queriedUserId = where.userId;
            if (where.userId === 202) {
                return [buildWishlist({ wishlistId: 2001, userId: 202, listingId: 803 })];
            }
            return [];
        });

        patch(Listing, "findAll", async () => [buildListing({ listingId: 803, title: "Villa C" })]);

        const res = await request(app)
            .get("/api/wishlist")
            .set(userBAuth);

        assert.equal(res.status, 200);
        assert.equal(queriedUserId, 202); // Luôn truy vấn theo token của User B
        assert.deepEqual(res.body.data.listingIds, [803]);
    });

    it("WL-10: Từ chối tham số listingId không hợp lệ (chuỗi không phải số hoặc số âm) với mã 422", async () => {
        const resAlpha = await request(app)
            .post("/api/wishlist/abc")
            .set(userAAuth);
        assert.equal(resAlpha.status, 422);

        const resNegative = await request(app)
            .delete("/api/wishlist/-5")
            .set(userAAuth);
        assert.equal(resNegative.status, 422);
    });
});
