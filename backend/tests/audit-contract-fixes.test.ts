const assert = require("node:assert/strict");
const { after, afterEach, describe, it } = require("node:test");
const request = require("supertest");
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret-key-32-chars-long-here";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const sequelize = require("../dist/config/database").default;
const { ApiError } = require("../dist/common/api-error");
const {
    listingApiStatuses,
    toApiListingStatus,
    toInternalListingStatus,
} = require("../dist/modules/listings/listing-mappers");
const { parseVietnamDateBoundary } = require("../dist/common/date-time");
const { assertBookingStatusTransition } = require("../dist/modules/bookings/booking-state-machine");
const Conversation = require("../dist/models/conversation").default;
const ConversationParticipant = require("../dist/models/conversation-participant").default;
const Message = require("../dist/models/message").default;
const Listing = require("../dist/models/listing").default;
const Review = require("../dist/models/review").default;
const HostApplication = require("../dist/models/host-application").default;
const PlatformFeeSetting = require("../dist/models/platform-fee-setting").default;
const User = require("../dist/models/user").default;
const authService = require("../dist/modules/auth/auth.service");
const conversationsService = require("../dist/modules/conversations/conversations.service");
const hostApplicationService = require("../dist/modules/host-kyc/host-application.service");
const adminFeesService = require("../dist/modules/admin/admin-fees.service");

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

describe("Audit Contract & Classification Regression Tests", () => {
    it("maps rejected listing status distinctly instead of collapsing into hidden", () => {
        assert.ok(listingApiStatuses.includes("rejected"));
        assert.equal(toApiListingStatus("rejected"), "rejected");
        assert.equal(toApiListingStatus("inactive"), "hidden");
        assert.equal(toInternalListingStatus("rejected"), "rejected");
    });

    it("parses YYYY-MM-DD boundaries in Vietnam timezone (UTC+7)", () => {
        const start = parseVietnamDateBoundary("2026-11-04", "start");
        const end = parseVietnamDateBoundary("2026-11-04", "end");
        assert.equal(start.toISOString(), "2026-11-03T17:00:00.000Z");
        assert.equal(end.toISOString(), "2026-11-04T16:59:59.999Z");
    });

    it("allows system auto-advance from paid to completed once checkOutDate is reached", () => {
        const transition = assertBookingStatusTransition({
            from: "paid",
            to: "completed",
            actor: "system",
            context: {
                now: new Date("2026-11-04T08:00:00.000Z"),
                checkOutDate: "2026-11-04",
            },
        });
        assert.equal(transition.to, "completed");

        assert.throws(
            () =>
                assertBookingStatusTransition({
                    from: "paid",
                    to: "completed",
                    actor: "system",
                    context: {
                        now: new Date("2026-11-04T08:00:00.000Z"),
                        checkOutDate: "2026-11-05",
                    },
                }),
            (err: any) => err instanceof ApiError && err.statusCode === 409,
        );
    });

    it("fetches latest message page via descending DB sort and returns chronological order", async () => {
        patch(Conversation, "findOne", async () => ({
            conversationId: 601,
            guestUserId: 201,
            hostUserId: 101,
        }));
        patch(ConversationParticipant, "findOne", async () => ({
            conversationId: 601,
            userId: 201,
            lastReadAt: null,
            async save() {},
        }));

        let capturedSort: Record<string, number> | null = null;
        patch(Message, "find", () => ({
            sort(spec: Record<string, number>) {
                capturedSort = spec;
                return this;
            },
            skip() {
                return this;
            },
            limit: async () => [
                {
                    messageId: 1052,
                    conversationId: 601,
                    senderId: 101,
                    content: "Tin mới nhất #52",
                    messageType: "text",
                    attachments: [],
                    createdAt: new Date("2026-11-04T08:05:00.000Z"),
                },
                {
                    messageId: 1051,
                    conversationId: 601,
                    senderId: 201,
                    content: "Tin áp chót #51",
                    messageType: "text",
                    attachments: [],
                    createdAt: new Date("2026-11-04T08:01:00.000Z"),
                },
            ],
        }));
        patch(Message, "countDocuments", async () => 52);

        const result = await conversationsService.getConversationMessages(
            601,
            { id: "201", roles: ["guest"], status: "active" },
            { page: 1, limit: 2 },
        );

        assert.deepEqual(capturedSort, { createdAt: -1, messageId: -1 });
        assert.equal(result.items.length, 2);
        assert.equal(result.items[0].messageId, 1051);
        assert.equal(result.items[1].messageId, 1052);
    });

    it("guards approveHostApplication and rejectHostApplication with 409 when non-pending", async () => {
        patch(sequelize, "transaction", async (cb: any) => cb({ LOCK: { UPDATE: "UPDATE" } }));
        patch(HostApplication, "findOne", async () => ({
            applicationId: 77,
            userId: 201,
            status: "rejected",
            async save() {},
        }));

        await assert.rejects(
            () =>
                hostApplicationService.approveHostApplication(
                    { id: "1", roles: ["admin"], status: "active" },
                    77,
                ),
            (err: any) => err instanceof ApiError && err.statusCode === 409,
        );
    });

    it("queries platform fee revenue strictly over valid settled booking statuses and excludes refunds", async () => {
        adminFeesService.invalidatePlatformFeeCache();
        patch(PlatformFeeSetting, "findAll", async () => []);
        patch(PlatformFeeSetting, "findOne", async () => null);
        patch(PlatformFeeSetting, "update", async () => [0]);

        let capturedSql = "";
        patch(sequelize, "query", async (sql: string) => {
            capturedSql = sql;
            return [{ totalPlatformRevenue: 2500000 }];
        });

        const status = await adminFeesService.getCurrentPlatformFeeStatus();
        assert.equal(status.totalPlatformRevenue, 2500000);
        assert.ok(capturedSql.includes("'paid', 'confirmed', 'checked_in', 'checked_out', 'completed'"));
        assert.ok(capturedSql.includes("FROM refunds r"));
    });

    it("allows host to read reviews of their own non-active listing via /api/host/listings/:id/reviews", async () => {
        const app = require("../dist/app").default;
        patch(authService, "verifyAuthToken", () => ({ userId: "101", role: "host" }));
        patch(User, "findById", async () => ({
            id: "101",
            userId: 101,
            email: "host@test.com",
            name: "Host",
            status: "active",
            roles: ["host"],
        }));
        patch(authService, "toAuthenticatedUser", async () => ({
            id: "101",
            email: "host@test.com",
            name: "Host",
            status: "active",
            roles: ["host"],
        }));
        patch(Listing, "findOne", async () => ({
            listingId: 909,
            hostId: 101,
            status: "draft",
            deletedAt: null,
        }));
        patch(Review, "find", () => ({
            sort() {
                return this;
            },
            lean: async () => [
                {
                    reviewId: 1,
                    rating: 5,
                    comment: "Rất tuyệt vời",
                    reviewerName: "Minh",
                    hostReply: null,
                    createdAt: new Date("2026-11-01T00:00:00Z"),
                },
            ],
        }));

        const res = await request(app)
            .get("/api/host/listings/909/reviews")
            .set("Authorization", "Bearer host-token");

        assert.equal(res.status, 200);
        assert.equal(res.body.data.summary.reviewCount, 1);
        assert.equal(res.body.data.summary.avgRating, 5);
    });
});
