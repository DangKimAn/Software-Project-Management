const assert = require("node:assert/strict");
const { afterEach, describe, it } = require("node:test");
const jwt = require("jsonwebtoken");
import type { PatchEntry, TransactionCallback } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.JWT_ACCESS_SECRET = "test-access-secret";
process.env.JWT_REFRESH_SECRET = "test-refresh-secret";
process.env.TOKEN_HASH_SECRET = "test-token-hash-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default;
const RefreshSession = require("../dist/models/refresh-session").default;
const User = require("../dist/models/user").default;
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

const activeUser = {
    _id: 101,
    id: 101,
    userId: 101,
    email: "guest@example.com",
    phone: "0901234567",
    username: "guest",
    fullName: "Guest User",
    status: "active",
};

const assertRejectsApiError = async (fn: () => Promise<unknown>, statusCode: number): Promise<void> => {
    await assert.rejects(fn, (error: unknown) => {
        assert.equal(error instanceof ApiError, true);
        assert.equal((error as { statusCode: number }).statusCode, statusCode);
        return true;
    });
};

describe("JWT and refresh-token security", () => {
    it("rejects expired access tokens with 401", () => {
        const expiredToken = jwt.sign(
            {
                role: "guest",
                type: "access",
            },
            process.env.JWT_ACCESS_SECRET,
            {
                subject: "101",
                expiresIn: "-1s",
            },
        );

        assert.throws(() => authService.verifyAuthToken(expiredToken), (error: unknown) => {
            assert.equal(error instanceof ApiError, true);
            assert.equal((error as { statusCode: number }).statusCode, 401);
            return true;
        });
    });

    it("rejects random refresh tokens without touching the session store", async () => {
        let sessionLookups = 0;
        patch(RefreshSession, "findOne", async () => {
            sessionLookups += 1;
            return null;
        });

        await assertRejectsApiError(() => authService.refreshAuthSession("not-a-jwt"), 403);
        assert.equal(sessionLookups, 0);
    });

    it("rejects reuse of a rotated refresh token and revokes remaining active sessions for that user", async () => {
        const oldToken = authService.signRefreshToken("101", "session-1");
        let lookupCount = 0;
        let revokedUserId: number | undefined;

        patch(sequelize, "transaction", async (callback: TransactionCallback) =>
            callback({
                LOCK: {
                    UPDATE: "UPDATE",
                },
            }),
        );
        patch(RefreshSession, "findOne", async () => {
            lookupCount += 1;

            if (lookupCount === 1) {
                return null;
            }

            return {
                sessionId: "session-1",
                userId: 101,
                revokedAt: new Date("2026-05-10T00:00:00.000Z"),
            };
        });
        patch(RefreshSession, "update", async (_values: unknown, options: { where?: { userId?: number } }) => {
            revokedUserId = options.where?.userId;
            return [1];
        });
        patch(User, "findOne", async () => activeUser);

        await assertRejectsApiError(() => authService.refreshAuthSession(oldToken), 403);

        assert.equal(lookupCount, 2);
        assert.equal(revokedUserId, 101);
    });
});

export {};
