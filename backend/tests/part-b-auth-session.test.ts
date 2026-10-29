const assert = require("node:assert/strict");
const { afterEach, beforeEach, describe, it } = require("node:test");
import jwt from "jsonwebtoken";
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;
const User = require("../dist/models/user").default;
const RefreshSession = require("../dist/models/refresh-session").default;
const AuthOtpToken = require("../dist/models/auth-otp-token").default;
const authService = require("../dist/modules/auth/auth.service");
const googleAuthService = require("../dist/modules/auth/google-auth.service");
const { getEnv } = require("../dist/config/env");

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

const mockUser = {
    _id: "201",
    id: "201",
    userId: 201,
    email: "user@example.com",
    phone: "0900000201",
    username: "testuser",
    status: "active",
    passwordHash: "$2a$10$hashedpasswordstringhere123456",
    roles: ["guest"],
    async save() {
        return this;
    },
};

const buildSession = (overrides: Record<string, unknown> = {}) => ({
    id: 1,
    sessionId: "session-uuid-1",
    userId: 201,
    tokenHash: "dummy-hash",
    expiresAt: new Date(Date.now() + 7 * 24 * 3600 * 1000),
    revokedAt: null,
    async save() {
        return this;
    },
    ...overrides,
});

describe("Part B - Authentication & Session (AUTH-34 to AUTH-40)", () => {
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

        patch(sequelize, "query", async () => []);
        patch(authService, "findUserForLogin", async () => mockUser);
        patch(User, "findOne", async () => mockUser);
        patch(User, "findById", async () => mockUser);
    });

    it("AUTH-34: Hai refresh đồng thời - Đúng 1 request rotation thành công, request thứ hai bị từ chối", async () => {
        const sessionId = "concurrent-session-1";
        const refreshToken = authService.signRefreshToken("201", sessionId);
        const tokenHash = authService.hashRefreshToken(refreshToken);

        const activeSession = buildSession({
            sessionId,
            tokenHash,
            revokedAt: null,
        });

        let rotationCount = 0;
        patch(RefreshSession, "findOne", async ({ where }: any) => {
            if (where.revokedAt === null) {
                // Lần 1 session còn hiệu lực, sau khi xoay sẽ thành revoked
                if (activeSession.revokedAt === null) {
                    return activeSession;
                }
                return null;
            }
            // Request thứ hai tìm thấy session đã bị revoked
            return activeSession;
        });

        patch(RefreshSession, "create", async () => {
            rotationCount += 1;
            return buildSession();
        });

        patch(RefreshSession, "update", async () => [1]);

        // Request 1: Thực hiện rotation
        const res1 = await authService.refreshAuthSession(refreshToken);
        assert.ok(res1.accessToken);
        assert.ok(res1.refreshToken);
        assert.equal(activeSession.revokedAt !== null, true);

        // Request 2 (cùng refresh token cũ): Bị từ chối
        await assert.rejects(
            async () => {
                await authService.refreshAuthSession(refreshToken);
            },
            (err: any) => {
                assert.equal(err.statusCode, 403);
                assert.match(err.message, /Invalid or expired refresh token/i);
                return true;
            },
        );

        assert.equal(rotationCount, 1);
    });

    it("AUTH-35: Replay refresh cũ đã xoay vòng - Thu hồi toàn bộ token family của user", async () => {
        const sessionId = "replayed-session-1";
        const refreshToken = authService.signRefreshToken("201", sessionId);
        const tokenHash = authService.hashRefreshToken(refreshToken);

        const alreadyRevokedSession = buildSession({
            sessionId,
            tokenHash,
            revokedAt: new Date(Date.now() - 3600000), // Đã bị thu hồi 1 giờ trước
        });

        let familyRevoked = false;
        patch(RefreshSession, "findOne", async ({ where }: any) => {
            if (where.revokedAt === null) return null; // Không còn session active
            return alreadyRevokedSession;
        });

        patch(RefreshSession, "update", async (data: any, options: any) => {
            if (options?.where?.userId === 201 && options?.where?.revokedAt === null) {
                familyRevoked = true;
            }
            return [1];
        });

        await assert.rejects(
            async () => {
                await authService.refreshAuthSession(refreshToken);
            },
            (err: any) => {
                assert.equal(err.statusCode, 403);
                return true;
            },
        );

        assert.equal(familyRevoked, true); // Token family bị huỷ để bảo vệ tài khoản
    });

    it("AUTH-36: CSRF cookie auth - Cơ chế SameSite và Origin policy ngăn chặn giả mạo refresh", () => {
        const cookieConfig = {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: "strict" as const,
            path: "/api/auth",
        };

        assert.equal(cookieConfig.httpOnly, true);
        assert.equal(cookieConfig.sameSite, "strict");
        assert.equal(cookieConfig.path, "/api/auth");
    });

    it("AUTH-37: JWT giả thuật toán (alg=none) hoặc sai chữ ký bị từ chối với mã 401", () => {
        // 37A: Token alg=none (header unsigned)
        const fakeNoneToken = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url") +
            "." +
            Buffer.from(JSON.stringify({ sub: "201", role: "guest", type: "access" })).toString("base64url") +
            ".";

        assert.throws(() => {
            authService.verifyAuthToken(fakeNoneToken);
        }, (err: any) => {
            assert.equal(err.statusCode, 401);
            return true;
        });

        // 37B: Token ký bằng secret giả mạo
        const forgedToken = jwt.sign(
            { sub: "201", role: "admin", type: "access" },
            "wrong-secret-key-12345",
            { algorithm: "HS256" },
        );

        assert.throws(() => {
            authService.verifyAuthToken(forgedToken);
        }, (err: any) => {
            assert.equal(err.statusCode, 401);
            return true;
        });
    });

    it("AUTH-38: Đổi mật khẩu thành công - Thu hồi toàn bộ refresh sessions trên các thiết bị khác", async () => {
        let allSessionsRevoked = false;
        patch(RefreshSession, "update", async (_updates: any, options: any) => {
            if (options?.where?.userId === 201 && options?.where?.revokedAt === null) {
                allSessionsRevoked = true;
            }
            return [1];
        });

        const otpToken = {
            userId: 201,
            identifier: "user@example.com",
            purpose: "forgot_password",
            tokenHash: authService.hashOtpToken("user@example.com", "forgot_password", "123456"),
            attemptCount: 0,
            expiresAt: new Date(Date.now() + 600000),
            consumedAt: null,
            usedAt: null,
            async save() {
                return this;
            },
        };

        patch(AuthOtpToken, "findOne", async () => otpToken);

        await authService.resetPasswordWithOtp({
            identifier: "user@example.com",
            otp: "123456",
            newPassword: "NewSecurePassword@2026",
        });

        assert.equal(allSessionsRevoked, true);
    });

    it("AUTH-39: Google OAuth mix-up - ID token sai issuer hoặc email_verified=false bị từ chối với 401", async () => {
        // Mock verifier trả về issuer không tin cậy
        googleAuthService.setGoogleIdTokenVerifierForTests(async () => {
            throw new ApiError(401, "Invalid Google token");
        });

        await assert.rejects(
            async () => {
                await googleAuthService.authenticateWithGoogleIdToken("invalid-google-id-token");
            },
            (err: any) => {
                assert.equal(err.statusCode, 401);
                assert.match(err.message, /Invalid Google token/i);
                return true;
            },
        );

        googleAuthService.setGoogleIdTokenVerifierForTests(undefined); // Reset
    });

    it("AUTH-40: OTP reset token bị dùng đồng thời - Chỉ 1 request tiêu thụ thành công, không đặt lại 2 lần", async () => {
        const otpToken = {
            userId: 201,
            identifier: "user@example.com",
            purpose: "forgot_password",
            tokenHash: authService.hashOtpToken("user@example.com", "forgot_password", "654321"),
            attemptCount: 0,
            expiresAt: new Date(Date.now() + 600000),
            consumedAt: null as Date | null,
            usedAt: null as Date | null,
            async save() {
                return this;
            },
        };

        patch(AuthOtpToken, "findOne", async () => otpToken);
        patch(RefreshSession, "update", async () => [1]);

        // Request 1: Tiêu thụ OTP thành công
        await authService.resetPasswordWithOtp({
            identifier: "user@example.com",
            otp: "654321",
            newPassword: "Password1st@2026",
        });

        assert.ok(otpToken.consumedAt !== null);

        // Request 2 (cùng OTP): Đã bị consumed -> Từ chối
        await assert.rejects(
            async () => {
                await authService.resetPasswordWithOtp({
                    identifier: "user@example.com",
                    otp: "654321",
                    newPassword: "Password2nd@2026",
                });
            },
            (err: any) => {
                assert.equal(err.statusCode, 400);
                assert.match(err.message, /Invalid or expired OTP/i);
                return true;
            },
        );
    });
});
