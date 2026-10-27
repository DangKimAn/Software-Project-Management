const assert = require("node:assert/strict");
const { describe, it } = require("node:test");

const request = require("supertest");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.CORS_ORIGIN = "https://app.example.com";
process.env.GLOBAL_RATE_LIMIT_MAX = "1000";

const app = require("../dist/app").default;
const { getCorsOptions } = require("../dist/config/cors");
const sequelize = require("../dist/config/database").default;
const { getEnv } = require("../dist/config/env");
const { logger } = require("../dist/config/logger");
const { sanitizePayload } = require("../dist/middlewares/sanitizeInput");
const authService = require("../dist/modules/auth/auth.service");
const { vnpayCallbackPayloadSchema } = require("../dist/modules/payments/payments.validator");
const { shutdownServer } = require("../dist/server");

const withEnv = async (overrides: Record<string, string | undefined>, callback: () => Promise<void> | void) => {
    const previous = new Map<string, string | undefined>();

    for (const key of Object.keys(overrides)) {
        previous.set(key, process.env[key]);

        if (overrides[key] === undefined) {
            delete process.env[key];
        } else {
            process.env[key] = overrides[key];
        }
    }

    try {
        await callback();
    } finally {
        for (const [key, value] of previous) {
            if (value === undefined) {
                delete process.env[key];
            } else {
                process.env[key] = value;
            }
        }
    }
};

const productionEnv = {
    NODE_ENV: "production",
    JWT_SECRET_KEY: "prod-main-secret-value-with-more-than-32-chars",
    JWT_ACCESS_SECRET: "prod-access-secret-value-with-more-than-32-chars",
    JWT_REFRESH_SECRET: "prod-refresh-secret-value-with-more-than-32-chars",
    TOKEN_HASH_SECRET: "prod-token-hash-secret-value-with-more-than-32-chars",
    OTP_HASH_SECRET: "prod-otp-hash-secret-value-with-more-than-32-chars",
    COOKIE_SECRET: "prod-cookie-secret-value-with-more-than-32-chars",
    MYSQLHOST: "db.example.internal",
    MYSQLDATABASE: "booking",
    MYSQLUSER: "booking_app",
    MYSQLPASSWORD: "prod-db-password",
    CLIENT_URL: "https://app.example.com",
    CORS_ORIGINS: "https://app.example.com",
    VNPAY_TMN_CODE: "TESTTMN",
    VNPAY_HASH_SECRET: "prod-vnpay-hash-secret-value-with-more-than-32-chars",
    VNPAY_PAYMENT_URL: "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
    VNPAY_RETURN_URL: "https://api.example.com/api/payments/vnpay/return",
    MAIL_HOST: "smtp.example.com",
    MAIL_USER: "mailer",
    MAIL_PASSWORD: "prod-mail-password",
    MAIL_FROM: "Booking <no-reply@example.com>",
    MOMO_PARTNER_CODE: "MOMO",
    MOMO_ACCESS_KEY: "prod-momo-access-key",
    MOMO_SECRET_KEY: "prod-momo-secret-key-value-with-more-than-32-chars",
    MOMO_ENDPOINT: "https://payment.example.com/create",
    MOMO_REDIRECT_URL: "https://api.example.com/api/payments/momo/return",
    MOMO_IPN_URL: "https://api.example.com/api/payments/webhooks/momo",
    AUTH_DEBUG_OTP: undefined,
    ALLOW_REFRESH_TOKEN_IN_BODY: undefined,
    ALLOW_REFRESH_TOKEN_IN_HEADER: undefined,
    ALLOW_PRODUCTION_AUTO_SCHEMA_SYNC: undefined,
};

describe("Security middleware", () => {
    it("sets security headers, disables x-powered-by, and returns a request id", async () => {
        const response = await request(app).get("/api/test");

        assert.equal(response.status, 200);
        assert.equal(response.headers["x-powered-by"], undefined);
        assert.equal(response.headers["x-content-type-options"], "nosniff");
        assert.equal(typeof response.headers["x-request-id"], "string");
    });

    it("allows only configured CORS origins when credentials are enabled", async () => {
        const allowed = await request(app)
            .get("/api/test")
            .set("Origin", "https://app.example.com");

        assert.equal(allowed.status, 200);
        assert.equal(allowed.headers["access-control-allow-origin"], "https://app.example.com");
        assert.equal(allowed.headers["access-control-allow-credentials"], "true");

        const denied = await request(app)
            .get("/api/test")
            .set("Origin", "https://evil.example.com");

        assert.equal(denied.status, 403);
        assert.equal(denied.body.success, false);
        assert.equal(denied.body.code, "FORBIDDEN");
    });

    it("sanitizes text fields without altering secrets", () => {
        const sanitized = sanitizePayload({
            title: "<script>alert(1)</script>",
            password: "<b>KeepRawPassword1</b>",
            nested: {
                comment: "Nice & <b>clean</b>",
            },
        });

        assert.deepEqual(sanitized, {
            title: "&lt;script&gt;alert(1)&lt;/script&gt;",
            password: "<b>KeepRawPassword1</b>",
            nested: {
                comment: "Nice &amp; &lt;b&gt;clean&lt;/b&gt;",
            },
        });
    });

    it("validates VNPay callback payload shape", () => {
        const invalid = vnpayCallbackPayloadSchema.safeParse({
            vnp_TxnRef: "890",
            vnp_Amount: "not-a-number",
            vnp_ResponseCode: "00",
            vnp_SecureHash: "abc123",
        });

        assert.equal(invalid.success, false);
    });

    it("normalizes malformed JSON errors instead of returning a server error", async () => {
        const response = await request(app)
            .post("/api/auth/login")
            .set("Content-Type", "application/json")
            .send("{");

        assert.equal(response.status, 400);
        assert.equal(response.body.success, false);
        assert.equal(response.body.code, "BAD_REQUEST");
        assert.equal(response.body.message, "Invalid request body");
    });

    it("fails fast for missing or weak production secrets and disables non-cookie refresh channels by default", async () => {
        await withEnv({ ...productionEnv, JWT_SECRET_KEY: undefined }, () => {
            assert.throws(() => getEnv(), /JWT_SECRET/);
        });

        await withEnv({ ...productionEnv, ALLOW_REFRESH_TOKEN_IN_BODY: "true" }, () => {
            assert.throws(() => getEnv(), /allowed only in development/);
        });

        await withEnv({ ...productionEnv, ALLOW_REFRESH_TOKEN_IN_HEADER: "true" }, () => {
            assert.throws(() => getEnv(), /allowed only in development/);
        });

        await withEnv({ ...productionEnv, NODE_ENV: "test", ALLOW_REFRESH_TOKEN_IN_BODY: "true" }, () => {
            assert.throws(() => getEnv(), /allowed only in development/);
        });

        await withEnv(productionEnv, () => {
            const env = getEnv();

            assert.equal(env.refreshCookieSecure, true);
            assert.equal(env.allowRefreshTokenInBody, false);
            assert.equal(env.allowRefreshTokenInHeader, false);
            assert.equal(env.authDebugOtp, false);
            assert.equal(env.allowProductionAutoSchemaSync, false);
        });
    });

    it("allows only CLIENT_URL for production CORS and ignores body/header refresh tokens", async () => {
        await withEnv(
            {
                ...productionEnv,
                CORS_ORIGINS: "https://admin.example.com",
                CORS_ORIGIN: "https://legacy.example.com",
            },
            async () => {
                const corsOptions = getCorsOptions();
                assert.equal(corsOptions.credentials, true);
                assert.equal(typeof corsOptions.origin, "function");

                await new Promise<void>((resolve, reject) => {
                    corsOptions.origin("https://app.example.com", (error: Error | null, allowed?: boolean) => {
                        try {
                            assert.equal(error, null);
                            assert.equal(allowed, true);
                            resolve();
                        } catch (assertionError) {
                            reject(assertionError);
                        }
                    });
                });

                await new Promise<void>((resolve, reject) => {
                    corsOptions.origin("https://admin.example.com", (error: Error | null, allowed?: boolean) => {
                        try {
                            assert.equal(error, null);
                            assert.equal(allowed, true);
                            resolve();
                        } catch (assertionError) {
                            reject(assertionError);
                        }
                    });
                });

                await new Promise<void>((resolve, reject) => {
                    corsOptions.origin("https://unknown.example.com", (error: Error | null) => {
                        try {
                            assert.ok(error);
                            assert.equal(error?.message, "CORS origin is not allowed");
                            resolve();
                        } catch (assertionError) {
                            reject(assertionError);
                        }
                    });
                });

                const fromCookie = authService.extractRefreshToken({
                    body: { refreshToken: "body-token" },
                    header(name: string) {
                        if (name === "x-refresh-token") return "header-token";
                        if (name === "cookie") return "refreshToken=cookie-token";
                        return undefined;
                    },
                    cookies: {},
                    signedCookies: {},
                });
                assert.equal(fromCookie, "cookie-token");

                const withoutCookie = authService.extractRefreshToken({
                    body: { refreshToken: "body-token" },
                    header(name: string) {
                        return name === "x-refresh-token" ? "header-token" : undefined;
                    },
                    cookies: {},
                    signedCookies: {},
                });
                assert.equal(withoutCookie, undefined);
            },
        );
    });

    it("merges CLIENT_URL and legacy CORS origins whenever credentials are enabled", async () => {
        await withEnv(
            {
                ...productionEnv,
                NODE_ENV: "development",
                CLIENT_URL: "https://client.example.com",
                CORS_ORIGIN: "https://legacy.example.com",
                CORS_ORIGINS: "https://admin.example.com",
            },
            async () => {
                const corsOptions = getCorsOptions();

                await new Promise<void>((resolve, reject) => {
                    corsOptions.origin("https://client.example.com", (error: Error | null, allowed?: boolean) => {
                        try {
                            assert.equal(error, null);
                            assert.equal(allowed, true);
                            resolve();
                        } catch (assertionError) {
                            reject(assertionError);
                        }
                    });
                });

                await new Promise<void>((resolve, reject) => {
                    corsOptions.origin("https://legacy.example.com", (error: Error | null, allowed?: boolean) => {
                        try {
                            assert.equal(error, null);
                            assert.equal(allowed, true);
                            resolve();
                        } catch (assertionError) {
                            reject(assertionError);
                        }
                    });
                });
            },
        );
    });

    it("redacts sensitive values from structured and error logs", () => {
        const previousConsoleError = console.error;
        const lines: string[] = [];

        try {
            console.error = (line?: unknown) => {
                lines.push(String(line));
            };

            logger.error("Security log test", new Error("Authorization=Bearer abc.def.ghi token=raw-refresh"), {
                password: "PlainPassword1",
                nested: {
                    refreshToken: "raw-refresh-token",
                    note: "Bearer abc.def.ghi",
                },
            });
        } finally {
            console.error = previousConsoleError;
        }

        const output = lines.join("\n");
        assert.equal(output.includes("PlainPassword1"), false);
        assert.equal(output.includes("raw-refresh-token"), false);
        assert.equal(output.includes("abc.def.ghi"), false);
        assert.match(output, /\[REDACTED\]/);
    });

    it("closes the HTTP server and database connection during graceful shutdown", async () => {
        const previousClose = sequelize.close;
        let serverClosed = false;
        let databaseClosed = false;
        let exitCode: number | undefined;
        const fakeServer = {
            close(callback: (error?: Error) => void) {
                serverClosed = true;
                callback();
            },
        };

        try {
            sequelize.close = async () => {
                databaseClosed = true;
            };

            await shutdownServer(fakeServer, "SIGTERM", (code: number) => {
                exitCode = code;
            });
        } finally {
            sequelize.close = previousClose;
        }

        assert.equal(serverClosed, true);
        assert.equal(databaseClosed, true);
        assert.equal(exitCode, 0);
    });
});

export {};
