const assert = require("node:assert/strict");
const { afterEach, describe, it } = require("node:test");
import type { AuditLogRecord, PatchEntry, Rejectable, TransactionCallback } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default;
const AuditLog = require("../dist/models/audit-log").default;
const Booking = require("../dist/models/booking").default;
const Conversation = require("../dist/models/conversation").default;
const ConversationParticipant = require("../dist/models/conversation-participant").default;
const Listing = require("../dist/models/listing").default;
const Report = require("../dist/models/report").default;
const Review = require("../dist/models/review").default;
const conversationsService = require("../dist/modules/conversations/conversations.service");
const reviewsService = require("../dist/modules/reviews/reviews.service");
const reportsService = require("../dist/modules/reports/reports.service");

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

const assertRejectsApiError = async (fn: Rejectable, statusCode: number): Promise<void> => {
    await assert.rejects(fn, (error: unknown) => {
        assert.equal(error instanceof ApiError, true);
        assert.equal((error as { statusCode: number }).statusCode, statusCode);
        return true;
    });
};

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

const adminUser = {
    id: "900",
    email: "admin@example.com",
    phone: "0900000900",
    name: "Admin User",
    username: "admin",
    status: "active",
    roles: ["admin"],
};

const buildBooking = (overrides: Record<string, unknown> = {}) => ({
    bookingId: 7001,
    listingId: 801,
    guestUserId: 201,
    hostUserId: 101,
    status: "completed",
    checkedOutAt: new Date("2026-05-01T00:00:00.000Z"),
    ...overrides,
});

describe("UC-09 reviews, conversations, and reports rules", () => {
    it("returns 409 when a booking is not completed before review", async () => {
        patch(sequelize, "transaction", async (callback: TransactionCallback) => callback({}));
        patch(Booking, "findOne", async () => buildBooking({ status: "confirmed", checkedOutAt: null }));

        await assertRejectsApiError(
            () => reviewsService.createReview(guestUser, { bookingId: 7001, rating: 5, comment: "Nice stay" }),
            409,
        );
    });

    it("returns 409 when a booking already has a review", async () => {
        patch(sequelize, "transaction", async (callback: TransactionCallback) => callback({}));
        patch(Booking, "findOne", async () => buildBooking());
        patch(Review, "findOne", async () => ({ reviewId: 1, bookingId: 7001 }));

        await assertRejectsApiError(
            () => reviewsService.createReview(guestUser, { bookingId: 7001, rating: 5, comment: "Nice stay" }),
            409,
        );
    });

    it("returns 403 when a host replies to a review outside their listing", async () => {
        patch(Review, "findOne", async () => ({
            reviewId: 55,
            listingId: 801,
            hostReply: null,
            deletedAt: null,
            isVisible: true,
        }));
        patch(Listing, "findOne", async () => ({
            listingId: 801,
            hostId: 999,
            deletedAt: null,
        }));

        await assertRejectsApiError(
            () => reviewsService.createReviewReply(hostUser, 55, { reply: "Thanks for staying" }),
            403,
        );
    });

    it("returns 403 when a guest edits another user's review", async () => {
        patch(Review, "findOne", async () => ({
            reviewId: 55,
            reviewerUserId: 999,
            deletedAt: null,
            isVisible: true,
            async save() {
                return this;
            },
        }));

        await assertRejectsApiError(
            () => reviewsService.updateReview(guestUser, 55, { rating: 4, comment: "Updated" }),
            403,
        );
    });

    it("strips executable HTML from review and message text", async () => {
        const { sanitizeAndModerateText } = require("../dist/services/trust-safety-service");
        const payloads = [
            "<script>alert(1)</script>Hello",
            "<img src=x onerror=alert(1)>Nice",
            "javascript:alert(1)",
        ];

        for (const payload of payloads) {
            const sanitized = sanitizeAndModerateText(payload, {
                field: "comment",
                allowEmpty: true,
            });

            assert.equal(/<script|<img|onerror=/i.test(sanitized), false);
        }
    });

    it("returns 403 when a user reads a conversation they do not participate in", async () => {
        patch(ConversationParticipant, "findOne", async () => null);
        patch(Conversation, "findOne", async () => ({ conversationId: 44 }));

        await assertRejectsApiError(
            () => conversationsService.assertConversationParticipant(44, Number(guestUser.id)),
            403,
        );
    });

    it("returns 404 when a report target does not exist", async () => {
        patch(sequelize, "transaction", async (callback: TransactionCallback) => callback({}));
        patch(Listing, "findOne", async () => null);

        await assertRejectsApiError(
            () =>
                reportsService.createReport(guestUser, {
                    targetType: "listing",
                    targetId: 9999,
                    reason: "Misleading listing",
                    description: "The target does not exist in this test.",
                }),
            404,
        );
    });

    it("allows an admin to resolve an open report and writes an audit log", async () => {
        const auditLogs: AuditLogRecord[] = [];
        const report = {
            reportId: 88,
            reporterId: 201,
            targetType: "listing",
            targetId: 801,
            reason: "Misleading listing",
            description: null,
            status: "open",
            resolvedBy: null,
            resolvedAt: null,
            resolution: null,
            createdAt: new Date("2026-05-01T00:00:00.000Z"),
            updatedAt: new Date("2026-05-01T00:00:00.000Z"),
            async save() {
                return this;
            },
        };

        patch(sequelize, "transaction", async (callback: TransactionCallback) => callback({}));
        patch(Report, "findOne", async () => report);
        patch(AuditLog, "create", async (payload: AuditLogRecord) => {
            auditLogs.push(payload);
            return payload;
        });

        const result = await reportsService.resolveReport(
            adminUser,
            88,
            { resolution: "Reviewed and actioned" },
            { ipAddress: "127.0.0.1", userAgent: "test-agent" },
        );

        assert.equal(result.status, "resolved");
        assert.equal(result.resolvedBy, 900);
        assert.equal(result.resolution, "Reviewed and actioned");
        assert.equal(auditLogs.length, 1);
        assert.equal(auditLogs[0].action, "reports.resolved");
        assert.equal(auditLogs[0].targetId, 88);
    });
});

export {};
