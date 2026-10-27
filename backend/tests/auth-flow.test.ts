const assert = require("node:assert/strict");
const { before, describe, it } = require("node:test");

const request = require("supertest");
import type { Response } from "supertest";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";
process.env.COOKIE_SECRET = "test-cookie-secret";

const { ApiError } = require("../dist/common/api-error");
const authService = require("../dist/modules/auth/auth.service");

const fakeUser = {
    _id: 101,
    id: 101,
    email: "guest@example.com",
    phone: "0901234567",
    username: "guest",
    fullName: "Guest User",
    passwordHash: "hashed-password",
    status: "active",
};

const responseUser = {
    id: "101",
    userId: "101",
    email: fakeUser.email,
    phone: fakeUser.phone,
    name: fakeUser.fullName,
    username: fakeUser.username,
    status: "active",
    roles: ["guest"],
    role: "guest",
};

const session = {
    accessToken: "access-token",
    refreshToken: "refresh-token",
    roles: ["guest"],
};

let revokedToken = null;
type ResetPasswordPayload = {
    identifier: string;
    otp: string;
    newPassword: string;
};

type OtpPayload = {
    identifier: string;
    purpose: "verify_email" | "forgot_password";
};

let resetPayload: ResetPasswordPayload | null = null;
let otpPayload: OtpPayload | null = null;

before(() => {
    authService.registerUser = async () => fakeUser;
    authService.findUserForLogin = async () => fakeUser;
    authService.comparePassword = async (password: string) => password === "Password1";
    authService.issueAuthSession = async () => session;
    authService.isLoginTemporarilyLocked = async () => false;
    authService.toAuthResponseUser = async () => responseUser;
    authService.recordFailedLoginAttempt = async () => 1;
    authService.refreshAuthSession = async (refreshToken: string) => ({
        accessToken: "next-access-token",
        refreshToken: "next-refresh-token",
        roles: ["guest"],
        user: responseUser,
    });
    authService.revokeRefreshSessionByToken = async (refreshToken: string) => {
        revokedToken = refreshToken;
    };
    authService.resetPasswordWithOtp = async (payload: ResetPasswordPayload) => {
        resetPayload = payload;
        return {
            userId: "101",
        };
    };
    authService.issueAuthOtp = async (payload: OtpPayload) => {
        otpPayload = payload;
        return {
            maskedDestination: "gu***@example.com",
            expiresAt: new Date("2026-01-01T00:10:00.000Z"),
        };
    };
});

const app = require("../dist/app").default;

const getSetCookies = (response: Response): string[] => {
    const raw = response.headers["set-cookie"];
    return Array.isArray(raw) ? raw : raw ? [raw] : [];
};

const isCookieCleared = (cookieString: string) => {
    return cookieString.includes("Expires=Thu, 01 Jan 1970") || cookieString.includes("Max-Age=0") || cookieString.includes("=;");
};

describe("Auth flow", () => {
    it("registers a user, sets refresh cookie, and does not return password or refresh token", async () => {
        const response = await request(app).post("/api/auth/register").send({
            email: "guest@example.com",
            password: "Password1",
            firstName: "Guest",
            lastName: "User",
            phone: "0901234567",
        });

        assert.equal(response.status, 201);
        assert.equal(response.body.success, true);
        assert.equal(response.body.data.accessToken, "access-token");
        assert.equal(response.body.data.refreshToken, undefined);
        assert.equal(response.body.data.user.passwordHash, undefined);

        const cookies = getSetCookies(response);
        assert.ok(cookies.some((cookie) => cookie.startsWith("refreshToken=")));
        assert.equal(cookies.some((cookie) => cookie.startsWith("auth_token=")), false);
        assert.ok(cookies.some((cookie) => /HttpOnly/i.test(cookie)));
    });

    it("logs in with valid credentials and rejects invalid credentials", async () => {
        const success = await request(app).post("/api/auth/login").send({
            identifier: "guest@example.com",
            password: "Password1",
        });

        assert.equal(success.status, 200);
        assert.equal(success.body.success, true);
        assert.equal(success.body.data.refreshToken, undefined);
        assert.equal(success.body.data.user.passwordHash, undefined);

        const cookies = getSetCookies(success);
        assert.ok(cookies.some((cookie) => cookie.startsWith("refreshToken=")));
        assert.equal(cookies.some((cookie) => cookie.startsWith("auth_token=")), false);

        const failure = await request(app).post("/api/auth/login").send({
            identifier: "guest@example.com",
            password: "Wrongpass1",
        });

        assert.equal(failure.status, 401);
        assert.equal(failure.body.success, false);
    });

    it("refreshes an access token using the refresh cookie", async () => {
        // Need to provide a properly signed cookie if signed is enabled
        // s%3Arefresh-token.<signature>
        // Since we are mocking refreshAuthSession to ignore the actual signature, any value matching our mock works
        const cookieValue = process.env.COOKIE_SECRET ? "s%3Arefresh-token.fakesig" : "refresh-token";
        const response = await request(app)
            .post("/api/auth/refresh")
            .set("Cookie", `refreshToken=${cookieValue}`)
            .send({});

        assert.equal(response.status, 200);
        assert.equal(response.body.success, true);
        assert.equal(response.body.data.accessToken, "next-access-token");
        assert.equal(response.body.data.refreshToken, undefined);

        const cookies = getSetCookies(response);
        assert.ok(cookies.some((cookie) => cookie.startsWith("refreshToken=")));
        assert.ok(cookies.some((cookie) => cookie.includes("next-refresh-token")));
    });

    it("can disable body and header refresh tokens while still accepting the httpOnly cookie", async () => {
        const previousBodyFlag = process.env.ALLOW_REFRESH_TOKEN_IN_BODY;
        const previousHeaderFlag = process.env.ALLOW_REFRESH_TOKEN_IN_HEADER;

        try {
            process.env.ALLOW_REFRESH_TOKEN_IN_BODY = "false";
            process.env.ALLOW_REFRESH_TOKEN_IN_HEADER = "false";

            const bodyResponse = await request(app)
                .post("/api/auth/refresh")
                .send({ refreshToken: "refresh-token" });

            assert.equal(bodyResponse.status, 403);

            const headerResponse = await request(app)
                .post("/api/auth/refresh")
                .set("x-refresh-token", "refresh-token")
                .send({});

            assert.equal(headerResponse.status, 403);

            const cookieValue = process.env.COOKIE_SECRET ? "s%3Arefresh-token.fakesig" : "refresh-token";
            const cookieResponse = await request(app)
                .post("/api/auth/refresh")
                .set("Cookie", `refreshToken=${cookieValue}`)
                .send({});

            assert.equal(cookieResponse.status, 200);
            assert.equal(cookieResponse.body.data.accessToken, "next-access-token");
        } finally {
            if (previousBodyFlag === undefined) {
                delete process.env.ALLOW_REFRESH_TOKEN_IN_BODY;
            } else {
                process.env.ALLOW_REFRESH_TOKEN_IN_BODY = previousBodyFlag;
            }

            if (previousHeaderFlag === undefined) {
                delete process.env.ALLOW_REFRESH_TOKEN_IN_HEADER;
            } else {
                process.env.ALLOW_REFRESH_TOKEN_IN_HEADER = previousHeaderFlag;
            }
        }
    });

    it("revokes the current refresh session on logout", async () => {
        revokedToken = null;
        
        const cookieValue = process.env.COOKIE_SECRET ? "s%3Arefresh-token.fakesig" : "refresh-token";

        const response = await request(app)
            .post("/api/auth/logout")
            .set("Cookie", `refreshToken=${cookieValue}`)
            .send({});

        assert.equal(response.status, 200);
        assert.equal(response.body.success, true);
        assert.equal(revokedToken, decodeURIComponent(cookieValue));
    });

    it("sets Secure on the refresh cookie when cookie secure config is enabled", async () => {
        const previousSecureFlag = process.env.REFRESH_TOKEN_COOKIE_SECURE;

        try {
            process.env.REFRESH_TOKEN_COOKIE_SECURE = "true";

            const response = await request(app).post("/api/auth/login").send({
                identifier: "guest@example.com",
                password: "Password1",
            });
            const cookies = getSetCookies(response);

            assert.equal(response.status, 200);
            assert.ok(cookies.some((cookie) => cookie.startsWith("refreshToken=") && /Secure/i.test(cookie)));
        } finally {
            if (previousSecureFlag === undefined) {
                delete process.env.REFRESH_TOKEN_COOKIE_SECURE;
            } else {
                process.env.REFRESH_TOKEN_COOKIE_SECURE = previousSecureFlag;
            }
        }
    });

    it("returns 403 when a refresh token is missing", async () => {
        const response = await request(app).post("/api/auth/refresh").send({});

        assert.equal(response.status, 403);
        assert.equal(response.body.success, false);
        assert.equal(response.body.code, "FORBIDDEN");
    });

    it("sends auth OTP and maps forgot-password to forgot_password purpose", async () => {
        otpPayload = null;

        const otpResponse = await request(app).post("/api/auth/send-otp").send({
            identifier: "guest@example.com",
            purpose: "verify_email",
        });

        assert.equal(otpResponse.status, 200);
        assert.equal(otpResponse.body.success, true);
        assert.deepEqual(otpPayload, {
            identifier: "guest@example.com",
            purpose: "verify_email",
        });

        otpPayload = null;

        const forgotResponse = await request(app).post("/api/auth/forgot-password").send({
            identifier: "guest@example.com",
        });

        assert.equal(forgotResponse.status, 200);
        assert.equal(forgotResponse.body.success, true);
        assert.deepEqual(otpPayload, {
            identifier: "guest@example.com",
            purpose: "forgot_password",
        });
    });

    it("resets password with OTP and clears auth cookies", async () => {
        resetPayload = null;

        const response = await request(app).post("/api/auth/reset-password").send({
            identifier: "guest@example.com",
            otp: "123456",
            newPassword: "Newpass1",
        });

        assert.equal(response.status, 200);
        assert.equal(response.body.success, true);
        assert.deepEqual(resetPayload, {
            identifier: "guest@example.com",
            otp: "123456",
            newPassword: "Newpass1",
        });
        assert.equal(response.body.data.userId, "101");

        const cookies = getSetCookies(response);
        assert.ok(cookies.some((cookie) => cookie.startsWith("auth_token=") && isCookieCleared(cookie)));
        assert.ok(cookies.some((cookie) => cookie.startsWith("refreshToken=") && isCookieCleared(cookie)));
    });

    it("uses 410 for expired reset tokens and 423 for temporary login locks", async () => {
        const originalResetPasswordWithOtp = authService.resetPasswordWithOtp;
        const originalIsLoginTemporarilyLocked = authService.isLoginTemporarilyLocked;

        try {
            authService.resetPasswordWithOtp = async () => {
                throw new ApiError(410, "Reset token expired");
            };

            const resetResponse = await request(app).post("/api/auth/reset-password").send({
                identifier: "guest@example.com",
                otp: "123456",
                newPassword: "Newpass1",
            });

            assert.equal(resetResponse.status, 410);
            assert.equal(resetResponse.body.code, "GONE");

            authService.isLoginTemporarilyLocked = async () => true;

            const loginResponse = await request(app).post("/api/auth/login").send({
                identifier: "guest@example.com",
                password: "Password1",
            });

            assert.equal(loginResponse.status, 423);
            assert.equal(loginResponse.body.code, "LOCKED");
        } finally {
            authService.resetPasswordWithOtp = originalResetPasswordWithOtp;
            authService.isLoginTemporarilyLocked = originalIsLoginTemporarilyLocked;
        }
    });

    it("returns 400 for missing auth input and 422 for invalid auth input", async () => {
        const missing = await request(app).post("/api/auth/login").send({
            identifier: "guest@example.com",
        });

        assert.equal(missing.status, 400);
        assert.equal(missing.body.success, false);

        const invalid = await request(app).post("/api/auth/register").send({
            email: "not-an-email",
            password: "short",
            firstName: "Guest",
            lastName: "User",
        });

        assert.equal(invalid.status, 422);
        assert.equal(invalid.body.success, false);
    });
});

export {};
