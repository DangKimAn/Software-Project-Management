import assert from "node:assert/strict";
import { after, before, beforeEach, describe, it } from "node:test";

import request from "supertest";

import app from "../app";
import RefreshSession from "../models/refresh-session";
import SocialAccount from "../models/social-account";
import User from "../models/user";
import { setGoogleIdTokenVerifierForTests } from "../modules/auth/google-auth.service";
import { createSocialAccount, createUser } from "./helpers/factories";
import { resetTestDatabase, setupTestDatabase, teardownTestDatabase } from "./helpers/test-db";

const buildGoogleProfile = (overrides: Partial<{
    sub: string;
    email: string;
    emailVerified: boolean;
    name: string;
    picture: string | null;
}> = {}) => ({
    sub: overrides.sub ?? "google-sub-001",
    email: overrides.email ?? "guest@example.com",
    emailVerified: overrides.emailVerified ?? true,
    name: overrides.name ?? "Google Guest",
    picture: overrides.picture ?? "https://example.com/avatar.png",
});

before(async () => {
    await setupTestDatabase();
});

beforeEach(async () => {
    await resetTestDatabase();
    setGoogleIdTokenVerifierForTests();
});

after(async () => {
    setGoogleIdTokenVerifierForTests();
    await teardownTestDatabase();
});

describe("POST /api/auth/google", () => {
    it("logs in with an existing Google social account and creates a refresh session", async () => {
        const user = await createUser({ email: "social@example.com" });
        const socialAccount = await createSocialAccount({
            userId: user.id,
            providerUid: "google-sub-existing",
        });

        setGoogleIdTokenVerifierForTests(async (idToken) => {
            assert.equal(idToken, "existing-id-token");
            return buildGoogleProfile({
                sub: socialAccount.providerUid,
                email: user.email,
                name: "Existing Social User",
            });
        });

        const response = await request(app)
            .post("/api/auth/google")
            .set("User-Agent", "google-auth-test")
            .send({
                idToken: "existing-id-token",
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.success, true);
        assert.equal(response.body.message, "Google login successfully");
        assert.equal(typeof response.body.data.accessToken, "string");
        assert.equal(response.body.data.refreshToken, undefined);
        assert.equal(response.body.data.user.userId, user.id);
        assert.equal(response.body.data.user.email, user.email);
        assert.equal(response.body.data.user.role, user.role);

        const rawSetCookies = response.headers["set-cookie"];
        const setCookies = Array.isArray(rawSetCookies)
            ? rawSetCookies
            : rawSetCookies
              ? [rawSetCookies]
              : [];
        assert.equal(setCookies.some((cookie: string) => cookie.startsWith("auth_token=")), false);
        assert.ok(setCookies.some((cookie: string) => cookie.startsWith("refreshToken=")));

        const refreshSessions = await RefreshSession.find({ userId: user._id });
        assert.equal(refreshSessions.length, 1);
        assert.ok(refreshSessions[0]);
        assert.equal(refreshSessions[0]?.userAgent, "google-auth-test");
    });

    it("links a Google account to an existing user with the same email", async () => {
        const user = await createUser({ email: "linkme@example.com" });

        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-link",
                email: user.email,
                name: "Link Existing User",
            }),
        );

        const response = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "link-id-token",
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.user.userId, user.id);

        const socialAccount = await SocialAccount.findOne({
            provider: "google",
            userId: user._id,
        });

        assert.ok(socialAccount);
        assert.equal(socialAccount?.providerUid, "google-sub-link");
    });

    it("creates a new guest user and social account when the email does not exist", async () => {
        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-new-user",
                email: "brandnew@example.com",
                name: "Brand New Guest",
            }),
        );

        const response = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "new-user-id-token",
            });

        assert.equal(response.status, 200);
        assert.equal(typeof response.body.data.accessToken, "string");
        assert.equal(response.body.data.refreshToken, undefined);
        assert.equal(response.body.data.user.role, "guest");
        assert.equal(response.body.data.user.email, "brandnew@example.com");

        const createdUser = await User.findOne({ email: "brandnew@example.com" });
        assert.ok(createdUser);
        assert.equal(createdUser?.role, "guest");
        assert.equal(createdUser?.status, "active");

        const socialAccount = await SocialAccount.findOne({
            provider: "google",
            userId: createdUser?._id,
        });

        assert.ok(socialAccount);
        assert.equal(socialAccount?.providerUid, "google-sub-new-user");

        const refreshSessions = await RefreshSession.find({ userId: createdUser?._id });
        assert.equal(refreshSessions.length, 1);
    });

    it("returns 400 when idToken is missing", async () => {
        const response = await request(app).post("/api/auth/google").send({});

        assert.equal(response.status, 400);
        assert.equal(response.body.success, false);
        assert.equal(response.body.message, "idToken is required");
    });

    it("returns 422 when idToken has the wrong type", async () => {
        const response = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: 12345,
            });

        assert.equal(response.status, 422);
        assert.equal(response.body.success, false);
    });

    it("returns 401 when the Google token is invalid", async () => {
        setGoogleIdTokenVerifierForTests(async () => {
            throw new Error("bad token");
        });

        const response = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "invalid-id-token",
            });

        assert.equal(response.status, 401);
        assert.equal(response.body.success, false);
        assert.equal(response.body.message, "Invalid Google token");
    });

    it("returns 401 when Google returns an unverified email", async () => {
        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-unverified",
                email: "unverified@example.com",
                emailVerified: false,
            }),
        );

        const response = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "unverified-id-token",
            });

        assert.equal(response.status, 401);
        assert.equal(response.body.success, false);
    });

    it("returns 403 when the matched user is locked", async () => {
        const user = await createUser({
            email: "locked@example.com",
            status: "locked",
        });

        await createSocialAccount({
            userId: user.id,
            providerUid: "google-sub-locked",
        });

        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-locked",
                email: user.email,
            }),
        );

        const response = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "locked-id-token",
            });

        assert.equal(response.status, 403);
        assert.equal(response.body.success, false);
        assert.equal(response.body.message, "Account is locked");
    });

    it("does not create duplicate social accounts when the same user logs in again", async () => {
        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-repeat",
                email: "repeat@example.com",
                name: "Repeat User",
            }),
        );

        const firstResponse = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "repeat-first-token",
            });

        assert.equal(firstResponse.status, 200);

        const secondResponse = await request(app)
            .post("/api/auth/google")
            .send({
                idToken: "repeat-second-token",
            });

        assert.equal(secondResponse.status, 200);

        const user = await User.findOne({ email: "repeat@example.com" });
        assert.ok(user);

        const socialAccounts = await SocialAccount.find({
            provider: "google",
            userId: user?._id,
        });
        const refreshSessions = await RefreshSession.find({
            userId: user?._id,
        });

        assert.equal(socialAccounts.length, 1);
        assert.equal(refreshSessions.length, 2);
    });
});
