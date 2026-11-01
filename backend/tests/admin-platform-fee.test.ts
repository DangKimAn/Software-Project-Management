const assert = require("node:assert/strict");
const { after, afterEach, beforeEach, describe, it } = require("node:test");
const request = require("supertest");
import { Op } from "sequelize";
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret-key-32-chars-long-here";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;
const { ApiError } = require("../dist/common/api-error");
const PlatformFeeSetting = require("../dist/models/platform-fee-setting").default;
const User = require("../dist/models/user").default;
const authService = require("../dist/modules/auth/auth.service");
const mailService = require("../dist/services/mail.service");
const notificationService = require("../dist/modules/notifications/notification.service");
const {
    cancelScheduledPlatformFee,
    getCurrentPlatformFeeStatus,
    invalidatePlatformFeeCache,
    schedulePlatformFeeChange,
    syncEffectivePlatformFee,
} = require("../dist/modules/admin/admin-fees.service");
const {
    calculateBookingPricing,
} = require("../dist/modules/bookings/booking-pricing.service");

const originals: PatchEntry[] = [];

const patch = (target: Record<string, unknown>, key: string, value: unknown): void => {
    originals.push([target, key, target[key]]);
    target[key] = value;
};

type MockFeeSetting = {
    id: number;
    feePct: number;
    status: "active" | "scheduled" | "superseded" | "cancelled";
    effectiveAt: Date;
    createdByAdminId: number;
    cancelledByAdminId: number | null;
    reason: string | null;
    notificationSentAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
    save: (options?: unknown) => Promise<MockFeeSetting>;
};

let feeSettings: MockFeeSetting[] = [];
let nextFeeId = 1;

const buildFeeSetting = (data: Partial<MockFeeSetting>): MockFeeSetting => {
    const item: MockFeeSetting = {
        id: data.id ?? nextFeeId++,
        feePct: data.feePct ?? 10,
        status: data.status ?? "scheduled",
        effectiveAt: data.effectiveAt ? new Date(data.effectiveAt) : new Date(),
        createdByAdminId: data.createdByAdminId ?? 1,
        cancelledByAdminId: data.cancelledByAdminId ?? null,
        reason: data.reason ?? null,
        notificationSentAt: data.notificationSentAt ? new Date(data.notificationSentAt) : null,
        createdAt: data.createdAt ? new Date(data.createdAt) : new Date(),
        updatedAt: data.updatedAt ? new Date(data.updatedAt) : new Date(),
        async save() {
            item.updatedAt = new Date();
            return item;
        },
    };
    return item;
};

const adminUser = {
    id: "1",
    _id: "1",
    userId: 1,
    email: "admin@test.com",
    name: "Admin User",
    roles: ["admin"],
    status: "active",
};

const guestUser = {
    id: "201",
    _id: "201",
    userId: 201,
    email: "guest@test.com",
    name: "Guest User",
    roles: ["guest"],
    status: "active",
};

const hostUser = {
    id: "101",
    _id: "101",
    userId: 101,
    email: "host@test.com",
    name: "Host User",
    roles: ["host"],
    status: "active",
};

const adminAuth = { Authorization: "Bearer admin-token" };
const guestAuth = { Authorization: "Bearer guest-token" };
const hostAuth = { Authorization: "Bearer host-token" };

describe("Admin Platform Fee Management (Unit & Integration Tests)", () => {
    beforeEach(() => {
        // Reset in-memory fixture state
        nextFeeId = 2;
        feeSettings = [
            buildFeeSetting({
                id: 1,
                feePct: 10,
                status: "active",
                effectiveAt: new Date(Date.now() - 3600 * 1000),
                createdByAdminId: 1,
                reason: "Initial default platform fee 10%",
                createdAt: new Date("2026-01-01T00:00:00Z"),
                updatedAt: new Date("2026-01-01T00:00:00Z"),
            }),
        ];
        invalidatePlatformFeeCache();

        // Patch PlatformFeeSetting Sequelize Model with in-memory store
        patch(PlatformFeeSetting, "findAll", async (options: Record<string, any> = {}) => {
            let result = [...feeSettings];
            if (options.where) {
                if (options.where.status) {
                    result = result.filter((item) => item.status === options.where.status);
                }
                if (options.where.effectiveAt) {
                    const lte = options.where.effectiveAt[Op.lte];
                    if (lte) {
                        result = result.filter((item) => item.effectiveAt.getTime() <= new Date(lte).getTime());
                    }
                    const gt = options.where.effectiveAt[Op.gt];
                    if (gt) {
                        result = result.filter((item) => item.effectiveAt.getTime() > new Date(gt).getTime());
                    }
                }
            }
            if (options.order) {
                for (const [col, dir] of options.order) {
                    result.sort((a: any, b: any) => {
                        const valA = a[col] instanceof Date ? a[col].getTime() : a[col];
                        const valB = b[col] instanceof Date ? b[col].getTime() : b[col];
                        return dir === "DESC" ? (valB > valA ? 1 : -1) : (valA > valB ? 1 : -1);
                    });
                }
            }
            if (options.limit) {
                result = result.slice(0, options.limit);
            }
            return result;
        });

        patch(PlatformFeeSetting, "findOne", async (options: Record<string, any> = {}) => {
            const list = await PlatformFeeSetting.findAll(options);
            return list[0] ?? null;
        });

        patch(PlatformFeeSetting, "create", async (data: Partial<MockFeeSetting>) => {
            const item = buildFeeSetting(data);
            feeSettings.push(item);
            return item;
        });

        patch(PlatformFeeSetting, "update", async (values: Partial<MockFeeSetting>, options: Record<string, any> = {}) => {
            let count = 0;
            for (const item of feeSettings) {
                if (!options.where || !options.where.status || item.status === options.where.status) {
                    Object.assign(item, values);
                    count++;
                }
            }
            return [count];
        });

        // Patch Sequelize query (total revenue and notification queries)
        patch(sequelize, "query", async () => {
            return [{ totalPlatformRevenue: 15000000 }];
        });

        // Stub mail & notification sending to keep tests deterministic and network-isolated
        patch(mailService, "sendMail", async () => ({ success: true, messageId: "mock-mail-id" }));
        patch(notificationService, "notifyAllHostsPlatformFeeScheduled", async () => {});
    });

    afterEach(() => {
        while (originals.length > 0) {
            const [target, key, value] = originals.pop()!;
            target[key] = value;
        }
    });

    // ── Suite 1: Service Domain Logic & Validation ──
    describe("Platform Fee Service Domain Logic", () => {
        it("should retrieve current platform fee status and return active fee", async () => {
            const status = await getCurrentPlatformFeeStatus();
            assert.ok(status.activeFee);
            assert.strictEqual(typeof status.activeFee.feePct, "number");
            assert.strictEqual(status.activeFee.feePct, 10);
            assert.strictEqual(status.activeFee.status, "active");
            assert.ok(Array.isArray(status.history));
            assert.strictEqual(typeof status.totalPlatformRevenue, "number");
        });

        it("should reject invalid fee percentage (< 0, > 100, NaN)", async () => {
            // Negative fee
            await assert.rejects(
                async () => {
                    await schedulePlatformFeeChange({
                        feePct: -5,
                        adminUserId: 1,
                    });
                },
                {
                    name: "ApiError",
                    statusCode: 400,
                },
            );

            // Fee > 100
            await assert.rejects(
                async () => {
                    await schedulePlatformFeeChange({
                        feePct: 105,
                        adminUserId: 1,
                    });
                },
                {
                    name: "ApiError",
                    statusCode: 400,
                },
            );

            // NaN fee
            await assert.rejects(
                async () => {
                    await schedulePlatformFeeChange({
                        feePct: Number.NaN,
                        adminUserId: 1,
                    });
                },
                {
                    name: "ApiError",
                    statusCode: 400,
                },
            );
        });

        it("should reject scheduling the same fee as current active fee", async () => {
            const currentFee = await syncEffectivePlatformFee();
            await assert.rejects(
                async () => {
                    await schedulePlatformFeeChange({
                        feePct: currentFee,
                        adminUserId: 1,
                    });
                },
                {
                    name: "ApiError",
                    statusCode: 400,
                },
            );
        });

        it("should schedule a new platform fee with effective date exactly 7 days in the future", async () => {
            // Clean up any pending
            try {
                await cancelScheduledPlatformFee(1);
            } catch {
                // Ignore if none
            }

            const scheduled = await schedulePlatformFeeChange({
                feePct: 14,
                reason: "Điều chỉnh chi phí vận hành máy chủ",
                adminUserId: 1,
            });

            assert.strictEqual(scheduled.feePct, 14);
            assert.strictEqual(scheduled.status, "scheduled");
            assert.strictEqual(scheduled.reason, "Điều chỉnh chi phí vận hành máy chủ");
            assert.strictEqual(scheduled.createdByAdminId, 1);

            const effectiveDate = new Date(scheduled.effectiveAt);
            const diffDays = (effectiveDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
            assert.ok(diffDays >= 6.9 && diffDays <= 7.1, "Effective date must be approximately 7 days away");

            // Verify status reflects scheduled fee and positive countdown
            const status = await getCurrentPlatformFeeStatus();
            assert.ok(status.scheduledFee);
            assert.strictEqual(status.scheduledFee.feePct, 14);
            assert.ok(status.scheduledFee.countdownSeconds > 0);
        });

        it("should reject scheduling duplicate while one is pending (409 Conflict)", async () => {
            // Schedule the first change
            await schedulePlatformFeeChange({
                feePct: 14,
                adminUserId: 1,
            });

            // Second schedule should conflict
            await assert.rejects(
                async () => {
                    await schedulePlatformFeeChange({
                        feePct: 16,
                        adminUserId: 1,
                    });
                },
                {
                    name: "ApiError",
                    statusCode: 409,
                },
            );
        });

        it("should allow admin to cancel the scheduled platform fee change", async () => {
            // Schedule first
            await schedulePlatformFeeChange({
                feePct: 14,
                adminUserId: 1,
            });

            const cancelResult = await cancelScheduledPlatformFee(1);
            assert.strictEqual(cancelResult.success, true);

            // Scheduled should now be null
            const status = await getCurrentPlatformFeeStatus();
            assert.strictEqual(status.scheduledFee, null);
        });

        it("should reject cancelling when no schedule is pending (404 Not Found)", async () => {
            await assert.rejects(
                async () => {
                    await cancelScheduledPlatformFee(1);
                },
                {
                    name: "ApiError",
                    statusCode: 404,
                },
            );
        });

        it("should automatically activate scheduled fee when effective date has passed", async () => {
            // Create a scheduled record with past effectiveAt
            const pastDate = new Date(Date.now() - 1000 * 60); // 1 minute ago
            await PlatformFeeSetting.create({
                feePct: 12.5,
                status: "scheduled",
                effectiveAt: pastDate,
                createdByAdminId: 1,
                reason: "Kiểm thử tự động kích hoạt quá hạn",
            });

            invalidatePlatformFeeCache();
            const activeFee = await syncEffectivePlatformFee();
            assert.strictEqual(activeFee, 12.5);

            // Clean up: set active back to 10
            await PlatformFeeSetting.create({
                feePct: 10,
                status: "active",
                effectiveAt: new Date(),
                createdByAdminId: 1,
                reason: "Khôi phục 10% mặc định",
            });

            invalidatePlatformFeeCache();
            const restoredFee = await syncEffectivePlatformFee();
            assert.strictEqual(restoredFee, 10);
        });
    });

    // ── Suite 2: Booking Pricing Integration & Historical Immutability ──
    describe("Booking Pricing Platform Fee Snapshot", () => {
        it("should calculate serviceFeeAmount based on active platform fee", async () => {
            const mockListing: any = {
                id: 9999,
                basePrice: 1000000,
                cleaningFee: 0,
                maxGuests: 4,
                weekendPrice: null,
                serviceFeePct: 10,
            };

            const pricing = await calculateBookingPricing({
                userId: 1,
                listing: mockListing,
                dates: ["2026-11-10", "2026-11-11"], // 2 nights
                calendarByDate: new Map(),
                guestCount: 2,
                transaction: null as any,
            });

            assert.strictEqual(pricing.totalNights, 2);
            assert.strictEqual(pricing.subtotalAmount, 2000000);

            // At 10% active fee: 2,000,000 * 10% = 200,000
            assert.strictEqual(pricing.serviceFeeAmount, 200000);
            assert.strictEqual(pricing.totalAmount, 2200000);
        });
    });

    // ── Suite 3: Admin HTTP API Endpoints (Supertest) ──
    describe("Admin Fees HTTP Endpoints", () => {
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
                name: user.name,
                status: "active",
                roles: user.roles || ["guest"],
            }));

            const usersMap = new Map([
                ["1", adminUser],
                ["201", guestUser],
                ["101", hostUser],
            ]);

            patch(User, "findByPk", async (id: string | number) => usersMap.get(String(id)) ?? null);
            patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);
            patch(User, "findOne", async ({ where }: any) => {
                const id = where?.id || where?.userId;
                return usersMap.get(String(id)) ?? null;
            });
        });

        it("GET /api/admin/fees/current should return 401 if unauthenticated", async () => {
            const res = await request(app).get("/api/admin/fees/current");
            assert.strictEqual(res.status, 401);
        });

        it("GET /api/admin/fees/current should return 403 if authenticated as guest", async () => {
            const res = await request(app)
                .get("/api/admin/fees/current")
                .set(guestAuth);
            assert.strictEqual(res.status, 403);
        });

        it("GET /api/admin/fees/current should return 200 with fee status for admin", async () => {
            const res = await request(app)
                .get("/api/admin/fees/current")
                .set(adminAuth);

            assert.strictEqual(res.status, 200);
            assert.strictEqual(res.body.success, true);
            assert.ok(res.body.data.activeFee);
            assert.strictEqual(typeof res.body.data.activeFee.feePct, "number");
            assert.strictEqual(res.body.data.activeFee.feePct, 10);
            assert.ok(Array.isArray(res.body.data.history));
        });

        it("POST /api/admin/fees/schedule should return 400 for invalid fee input", async () => {
            const res = await request(app)
                .post("/api/admin/fees/schedule")
                .set(adminAuth)
                .send({ feePct: -2 });

            assert.strictEqual(res.status, 400);
            assert.strictEqual(res.body.success, false);
        });

        it("POST /api/admin/fees/schedule should return 201 when admin schedules valid fee", async () => {
            const res = await request(app)
                .post("/api/admin/fees/schedule")
                .set(adminAuth)
                .send({
                    feePct: 13,
                    reason: "Thử nghiệm API Schedule",
                });

            assert.strictEqual(res.status, 201);
            assert.strictEqual(res.body.success, true);
            assert.strictEqual(res.body.data.feePct, 13);
            assert.strictEqual(res.body.data.status, "scheduled");
        });

        it("POST /api/admin/fees/schedule should return 409 when duplicate schedule is requested", async () => {
            // First schedule
            await request(app)
                .post("/api/admin/fees/schedule")
                .set(adminAuth)
                .send({ feePct: 13 });

            // Duplicate schedule
            const res = await request(app)
                .post("/api/admin/fees/schedule")
                .set(adminAuth)
                .send({ feePct: 15 });

            assert.strictEqual(res.status, 409);
            assert.strictEqual(res.body.success, false);
        });

        it("POST /api/admin/fees/cancel should return 200 when cancelling pending fee", async () => {
            // First schedule
            await request(app)
                .post("/api/admin/fees/schedule")
                .set(adminAuth)
                .send({ feePct: 13 });

            const res = await request(app)
                .post("/api/admin/fees/cancel")
                .set(adminAuth);

            assert.strictEqual(res.status, 200);
            assert.strictEqual(res.body.success, true);
        });

        it("POST /api/admin/fees/cancel should return 404 when no pending fee to cancel", async () => {
            const res = await request(app)
                .post("/api/admin/fees/cancel")
                .set(adminAuth);

            assert.strictEqual(res.status, 404);
            assert.strictEqual(res.body.success, false);
        });
    });
});
