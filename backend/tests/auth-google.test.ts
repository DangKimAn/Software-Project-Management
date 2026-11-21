// CONFLICT-RESOLVED: Hợp nhất kiểm thử OAuth Google từ `src/tests/auth-google.test.ts` về `tests/auth-google.test.ts`
// sử dụng bản biên dịch `dist/` và kho dữ liệu giả lập trong bộ nhớ thay vì phụ thuộc cơ sở dữ liệu ngoài `tsconfig.json`.
const assert = require("node:assert/strict");
const { after, before, beforeEach, describe, it } = require("node:test");
const request = require("supertest");
import type { Response } from "supertest";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";
process.env.COOKIE_SECRET = "test-cookie-secret";

const authService = require("../dist/modules/auth/auth.service");
const { setGoogleIdTokenVerifierForTests } = require("../dist/modules/auth/google-auth.service");
const SocialAccount = require("../dist/models/social-account").default;
const User = require("../dist/models/user").default;

type MockUserRecord = {
    _id: number;
    id: string;
    email: string;
    firstName: string;
    lastName: string;
    fullName: string;
    role: string;
    status: string;
    isEmailVerified: boolean;
    avatarUrl: string | null;
    save: () => Promise<MockUserRecord>;
};

type MockSocialRecord = {
    id: number;
    userId: number;
    provider: string;
    providerUid: string;
};

type MockSessionRecord = {
    userId: number;
    userAgent: string | null;
};

let nextUserId = 500;
let nextSocialId = 1;
let usersStore: MockUserRecord[] = [];
let socialStore: MockSocialRecord[] = [];
let refreshSessionsStore: MockSessionRecord[] = [];

const originals = {
    userFindById: User.findById,
    userFindOne: User.findOne,
    socialFindOne: SocialAccount.findOne,
    socialDeleteOne: SocialAccount.deleteOne,
    socialPrototypeSave: SocialAccount.prototype.save,
    createSocialUser: authService.createSocialUser,
    issueAuthSession: authService.issueAuthSession,
    toAuthResponseUser: authService.toAuthResponseUser,
};

/**
 * Giải thuật kho lưu trữ giả lập trong bộ nhớ (In-Memory OAuth Identity Store):
 * Mô phỏng quan hệ khóa duy nhất `(provider, providerUid)` và `(provider, userId)` của bảng `social_accounts`
 * cùng trạng thái người dùng `users` để kiểm thử toàn vẹn luồng liên kết tài khoản Google OAuth mà không cần kết nối MySQL.
 */
const seedUser = (overrides: Partial<{ email: string; status: string; role: string }> = {}): MockUserRecord => {
    const numericId = ++nextUserId;
    const record: MockUserRecord = {
        _id: numericId,
        id: String(numericId),
        email: (overrides.email ?? `user${numericId}@example.com`).toLowerCase(),
        firstName: "Google",
        lastName: "User",
        fullName: "Google User",
        role: overrides.role ?? "guest",
        status: overrides.status ?? "active",
        isEmailVerified: false,
        avatarUrl: null,
        async save() {
            return this;
        },
    };
    usersStore.push(record);
    return record;
};

const seedSocialAccount = (input: { userId: string | number; providerUid: string }): MockSocialRecord => {
    const record: MockSocialRecord = {
        id: ++nextSocialId,
        userId: Number(input.userId),
        provider: "google",
        providerUid: input.providerUid,
    };
    socialStore.push(record);
    return record;
};

const buildGoogleProfile = (
    overrides: Partial<{
        sub: string;
        email: string;
        emailVerified: boolean;
        name: string;
        picture: string | null;
    }> = {},
) => ({
    sub: overrides.sub ?? "google-sub-001",
    email: overrides.email ?? "guest@example.com",
    emailVerified: overrides.emailVerified ?? true,
    name: overrides.name ?? "Google Guest",
    picture: overrides.picture ?? "https://example.com/avatar.png",
});

before(() => {
    User.findById = async (id: string | number) =>
        usersStore.find((item) => item._id === Number(id)) ?? null;
    User.findOne = async (query: { email?: string }) => {
        const targetEmail = String(query?.email ?? "").toLowerCase();
        return usersStore.find((item) => item.email === targetEmail) ?? null;
    };
    SocialAccount.findOne = async (query: { provider?: string; providerUid?: string; userId?: number }) =>
        socialStore.find(
            (item) =>
                (!query.provider || item.provider === query.provider) &&
                (query.providerUid === undefined || item.providerUid === query.providerUid) &&
                (query.userId === undefined || item.userId === Number(query.userId)),
        ) ?? null;
    SocialAccount.deleteOne = async (query: { id?: number }) => {
        const beforeCount = socialStore.length;
        socialStore = socialStore.filter((item) => item.id !== Number(query.id));
        return beforeCount - socialStore.length;
    };
    SocialAccount.prototype.save = async function (this: {
        id?: number;
        userId: number;
        provider: string;
        providerUid: string;
    }) {
        if (!this.id) {
            this.id = ++nextSocialId;
            socialStore.push({
                id: this.id,
                userId: Number(this.userId),
                provider: this.provider,
                providerUid: this.providerUid,
            });
        }
        return this;
    };
    authService.createSocialUser = async (input: {
        email: string;
        name: string;
        role: string;
        emailVerified: boolean;
        avatarUrl?: string | null;
    }) => {
        const created = seedUser({ email: input.email, role: input.role, status: "active" });
        created.fullName = input.name;
        created.isEmailVerified = input.emailVerified;
        created.avatarUrl = input.avatarUrl ?? null;
        return created;
    };
    authService.issueAuthSession = async (
        user: MockUserRecord,
        context: { userAgent?: string | null } = {},
    ) => {
        refreshSessionsStore.push({
            userId: user._id,
            userAgent: context.userAgent ?? null,
        });
        return {
            accessToken: `access-token-${user.id}`,
            refreshToken: `refresh-token-${refreshSessionsStore.length}`,
            roles: [user.role],
        };
    };
    authService.toAuthResponseUser = async (user: MockUserRecord, roles: string[]) => ({
        id: user.id,
        userId: user.id,
        email: user.email,
        name: user.fullName,
        status: user.status,
        roles,
        role: roles[0] ?? user.role,
    });
});

beforeEach(() => {
    usersStore = [];
    socialStore = [];
    refreshSessionsStore = [];
    setGoogleIdTokenVerifierForTests();
});

after(async () => {
    setGoogleIdTokenVerifierForTests();
    User.findById = originals.userFindById;
    User.findOne = originals.userFindOne;
    SocialAccount.findOne = originals.socialFindOne;
    SocialAccount.deleteOne = originals.socialDeleteOne;
    SocialAccount.prototype.save = originals.socialPrototypeSave;
    authService.createSocialUser = originals.createSocialUser;
    authService.issueAuthSession = originals.issueAuthSession;
    authService.toAuthResponseUser = originals.toAuthResponseUser;

    const sequelize = require("../dist/config/database").default;
    try {
        await sequelize.close();
    } catch {
        // ignore
    }
});

const app = require("../dist/app").default;

const getSetCookies = (response: Response): string[] => {
    const raw = response.headers["set-cookie"];
    return Array.isArray(raw) ? raw : raw ? [raw] : [];
};

describe("POST /api/auth/google", () => {
    it("logs in with an existing Google social account and creates a refresh session", async () => {
        const user = seedUser({ email: "social@example.com" });
        const socialAccount = seedSocialAccount({
            userId: user.id,
            providerUid: "google-sub-existing",
        });

        setGoogleIdTokenVerifierForTests(async (idToken: string) => {
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
            .send({ idToken: "existing-id-token" });

        assert.equal(response.status, 200);
        assert.equal(response.body.success, true);
        assert.equal(response.body.message, "Google login successfully");
        assert.equal(typeof response.body.data.accessToken, "string");
        assert.equal(response.body.data.refreshToken, undefined);
        assert.equal(response.body.data.user.userId, user.id);
        assert.equal(response.body.data.user.email, user.email);

        const setCookies = getSetCookies(response);
        assert.equal(setCookies.some((cookie) => cookie.startsWith("auth_token=")), false);
        assert.ok(setCookies.some((cookie) => cookie.startsWith("refreshToken=")));
        assert.equal(refreshSessionsStore.length, 1);
        assert.equal(refreshSessionsStore[0]?.userAgent, "google-auth-test");
    });

    it("links a Google account to an existing user with the same email", async () => {
        const user = seedUser({ email: "linkme@example.com" });

        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-link",
                email: user.email,
                name: "Link Existing User",
            }),
        );

        const response = await request(app).post("/api/auth/google").send({ idToken: "link-id-token" });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.user.userId, user.id);
        assert.equal(socialStore.length, 1);
        assert.equal(socialStore[0]?.providerUid, "google-sub-link");
    });

    it("creates a new guest user and social account when the email does not exist", async () => {
        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({
                sub: "google-sub-new-user",
                email: "brandnew@example.com",
                name: "Brand New Guest",
            }),
        );

        const response = await request(app).post("/api/auth/google").send({ idToken: "new-user-id-token" });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.user.role, "guest");
        assert.equal(response.body.data.user.email, "brandnew@example.com");
        assert.equal(usersStore.length, 1);
        assert.equal(socialStore[0]?.providerUid, "google-sub-new-user");
        assert.equal(refreshSessionsStore.length, 1);
    });

    it("returns 400 when idToken is missing", async () => {
        const response = await request(app).post("/api/auth/google").send({});
        assert.equal(response.status, 400);
        assert.equal(response.body.message, "idToken is required");
    });

    it("returns 422 when idToken has the wrong type", async () => {
        const response = await request(app).post("/api/auth/google").send({ idToken: 12345 });
        assert.equal(response.status, 422);
    });

    it("returns 401 when the Google token is invalid", async () => {
        setGoogleIdTokenVerifierForTests(async () => {
            throw new Error("bad token");
        });
        const response = await request(app).post("/api/auth/google").send({ idToken: "invalid-id-token" });
        assert.equal(response.status, 401);
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
        const response = await request(app).post("/api/auth/google").send({ idToken: "unverified-id-token" });
        assert.equal(response.status, 401);
    });

    it("returns 423 when the matched user is locked", async () => {
        // CONFLICT-RESOLVED: Cập nhật mã trạng thái khóa tài khoản từ 403 (test cũ bị bỏ rơi) sang 423 Locked theo hợp đồng hiện hành của `assertUserCanAuthenticate`.
        const user = seedUser({ email: "locked@example.com", status: "locked" });
        seedSocialAccount({ userId: user.id, providerUid: "google-sub-locked" });

        setGoogleIdTokenVerifierForTests(async () =>
            buildGoogleProfile({ sub: "google-sub-locked", email: user.email }),
        );

        const response = await request(app).post("/api/auth/google").send({ idToken: "locked-id-token" });
        assert.equal(response.status, 423);
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

        const firstResponse = await request(app).post("/api/auth/google").send({ idToken: "repeat-first-token" });
        const secondResponse = await request(app).post("/api/auth/google").send({ idToken: "repeat-second-token" });

        assert.equal(firstResponse.status, 200);
        assert.equal(secondResponse.status, 200);
        assert.equal(socialStore.length, 1);
        assert.equal(refreshSessionsStore.length, 2);
    });
});
