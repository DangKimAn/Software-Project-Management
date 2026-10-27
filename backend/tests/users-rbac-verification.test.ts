const assert = require("node:assert/strict");
const { beforeEach, describe, it } = require("node:test");

const request = require("supertest");
import type { AuditLogRecord, AsyncOrSync, AuthenticatedTestUser } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const { ApiError } = require("../dist/common/api-error");
const authRepository = require("../dist/modules/auth/auth.repository");
const authService = require("../dist/modules/auth/auth.service");
const usersRepository = require("../dist/modules/users/users.repository");
const User = require("../dist/models/user").default;
const hostVerificationsService = require("../dist/modules/verifications/verifications.service");
const adminListingsService = require("../dist/modules/admin/admin.service");

type TestUserRecord = {
    _id: number;
    id: number;
    userId: number;
    email: string;
    phone: string;
    username: string;
    fullName: string;
    firstName: string;
    lastName: string;
    dateOfBirth: null;
    bio: null;
    avatarUrl: null;
    passwordHash: string;
    status: string;
    createdAt: Date;
    updatedAt: Date;
    roles: string[];
};

type TestUserProfileRecord = {
    userId: number;
    location: string | null;
    job: string | null;
    dreamDestination: string | null;
    school: string | null;
    languages: string[] | null;
};

type HostVerificationInput = {
    verificationType: string;
    fullName: string;
    documentUrls: string[];
    notes?: string | null;
};

type VerificationRecord = {
    verificationId: number;
    hostId: number;
    verificationType: string;
    fullName: string;
    idNumber: string;
    idNumberMasked: string;
    documentUrls: string[];
    notes: string | null;
    status: string;
    reviewedByUserId: number | null;
    reviewedAt: Date | null;
    reviewNotes: string | null;
    rejectionReason: string | null;
    createdAt: Date;
    updatedAt: Date;
};

const users = new Map<string, TestUserRecord>();
const userProfiles = new Map<string, TestUserProfileRecord>();
const roles = new Map<string, string[]>();
let auditLogs: AuditLogRecord[] = [];
let verifications: VerificationRecord[] = [];
let nextVerificationId = 700;

const makeUser = (
    id: string,
    email: string,
    phone: string,
    fullName: string,
    userRoles: string[],
    status = "active",
): TestUserRecord => {
    const [firstName, ...rest] = fullName.split(" ");

    return {
        _id: Number(id),
        id: Number(id),
        userId: Number(id),
        email,
        phone,
        username: email.split("@")[0],
        fullName,
        firstName,
        lastName: rest.join(" "),
        dateOfBirth: null,
        bio: null,
        avatarUrl: null,
        passwordHash: "secret",
        status,
        createdAt: new Date("2026-01-01T00:00:00Z"),
        updatedAt: new Date("2026-01-01T00:00:00Z"),
        roles: userRoles,
    };
};

const resetState = () => {
    users.clear();
    userProfiles.clear();
    roles.clear();

    for (const user of [
        makeUser("101", "guest@example.com", "0901234567", "Guest User", ["guest"]),
        makeUser("102", "host@example.com", "0902222222", "Host User", ["host"]),
        makeUser("800", "moderator@example.com", "0908888888", "Moderator User", ["moderator"]),
        makeUser("900", "admin@example.com", "0909999999", "Admin User", ["admin"]),
    ]) {
        users.set(String(user._id), user);
        roles.set(String(user._id), [...user.roles]);
    }

    auditLogs = [];
    verifications = [
        {
            verificationId: 601,
            hostId: 102,
            verificationType: "identity",
            fullName: "Host User",
            idNumber: "********2222",
            idNumberMasked: "********2222",
            documentUrls: ["https://cdn.example.com/docs/host-id.pdf"],
            notes: null,
            status: "pending",
            reviewedByUserId: null,
            reviewedAt: null,
            reviewNotes: null,
            rejectionReason: null,
            createdAt: new Date("2026-01-01T00:00:00Z"),
            updatedAt: new Date("2026-01-01T00:00:00Z"),
        },
    ];
    nextVerificationId = 700;
};

const tokenToUserId: Record<string, string> = {
    "guest-token": "101",
    "host-token": "102",
    "moderator-token": "800",
    "admin-token": "900",
};

authService.verifyAuthToken = (token: string) => {
    const userId = tokenToUserId[token];

    if (!userId) {
        throw new ApiError(401, "Unauthorized");
    }

    return {
        userId,
        role: roles.get(userId)?.[0] ?? "guest",
    };
};

authService.assertUserCanAuthenticate = (user: TestUserRecord) => {
    if (user.status !== "active") {
        throw new ApiError(403, "Account is not active");
    }
};

authService.toAuthenticatedUser = async (user: TestUserRecord): Promise<AuthenticatedTestUser> => ({
    id: String(user._id),
    email: user.email,
    phone: user.phone,
    name: user.fullName,
    username: user.username,
    status: user.status,
    roles: roles.get(String(user._id)) ?? ["guest"],
});

User.findById = async (id: string | number) => users.get(String(id)) ?? null;

usersRepository.findUserById = async (id: string | number) => users.get(String(id)) ?? null;
usersRepository.getUserRoles = async (id: string | number) => roles.get(String(id)) ?? ["guest"];
usersRepository.replaceUserRoles = async (id: string | number, nextRoles: string[]) => {
    roles.set(String(id), Array.from(new Set(nextRoles)));
};
usersRepository.saveUserUpdates = async (user: TestUserRecord, values: Partial<TestUserRecord>) => {
    Object.assign(user, values, { updatedAt: new Date("2026-01-02T00:00:00Z") });
    return user;
};
usersRepository.findUserProfileByUserId = async (id: string | number) => userProfiles.get(String(id)) ?? null;
usersRepository.saveUserProfileUpdates = async (
    id: string | number,
    values: Partial<TestUserProfileRecord>,
) => {
    const key = String(id);
    const profile = userProfiles.get(key) ?? {
        userId: Number(id),
        location: null,
        job: null,
        dreamDestination: null,
        school: null,
        languages: null,
    };

    Object.assign(profile, values);
    userProfiles.set(key, profile);
    return profile;
};
usersRepository.withTransaction = async (callback: (transaction: unknown) => AsyncOrSync) => callback(undefined);
usersRepository.findUserByPhone = async (phone: string) =>
    Array.from(users.values()).find((user) => user.phone === phone) ?? null;
usersRepository.findUserByEmail = async (email: string) =>
    Array.from(users.values()).find((user) => user.email === email) ?? null;
usersRepository.findUserByUsername = async (username: string) =>
    Array.from(users.values()).find((user) => user.username === username) ?? null;
usersRepository.countActiveUsersWithRole = async (role: string) =>
    Array.from(users.values()).filter(
        (user) => user.status === "active" && (roles.get(String(user._id)) ?? []).includes(role),
    ).length;

authRepository.createAuditLog = async (input: AuditLogRecord) => {
    auditLogs.push(input);
};

hostVerificationsService.submitHostVerification = async (user: AuthenticatedTestUser, input: HostVerificationInput) => {
    const verification = {
        verificationId: nextVerificationId++,
        hostId: Number(user.id),
        verificationType: input.verificationType,
        fullName: input.fullName,
        idNumber: "********6789",
        idNumberMasked: "********6789",
        documentUrls: input.documentUrls,
        notes: input.notes ?? null,
        status: "pending",
        reviewedByUserId: null,
        reviewedAt: null,
        reviewNotes: null,
        rejectionReason: null,
        createdAt: new Date("2026-01-02T00:00:00Z"),
        updatedAt: new Date("2026-01-02T00:00:00Z"),
    };

    verifications.push(verification);
    return {
        verificationId: verification.verificationId,
        status: verification.status,
    };
};

hostVerificationsService.getMyHostVerifications = async (user: AuthenticatedTestUser) => ({
    items: verifications.filter((item) => String(item.hostId) === user.id),
    latestOnly: false,
    pagination: {
        page: 1,
        limit: 10,
        total: verifications.filter((item) => String(item.hostId) === user.id).length,
        totalPages: 1,
    },
});

hostVerificationsService.getAdminVerifications = async (admin: AuthenticatedTestUser) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    return {
        items: verifications,
        pagination: {
            page: 1,
            limit: 10,
            total: verifications.length,
            totalPages: 1,
        },
    };
};

hostVerificationsService.approveHostVerification = async (verificationId: number, admin: AuthenticatedTestUser) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const verification = verifications.find((item) => item.verificationId === verificationId);
    if (!verification) {
        throw new Error("Missing verification fixture");
    }
    verification.status = "approved";
    auditLogs.push({ action: "host_verification.approve", targetId: verificationId });
    return {
        verificationId,
        status: "approved",
    };
};

hostVerificationsService.rejectHostVerification = async (
    verificationId: number,
    admin: AuthenticatedTestUser,
    input: { reason: string },
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const verification = verifications.find((item) => item.verificationId === verificationId);
    if (!verification) {
        throw new Error("Missing verification fixture");
    }
    verification.status = "rejected";
    verification.rejectionReason = input.reason;
    auditLogs.push({ action: "host_verification.reject", targetId: verificationId });
    return {
        verificationId,
        status: "rejected",
    };
};

adminListingsService.listPendingAdminListings = async (actor: AuthenticatedTestUser) => {
    if (!actor.roles.includes("admin") && !actor.roles.includes("moderator")) {
        throw new ApiError(403, "Forbidden");
    }

    return {
        items: [],
        pagination: {
            page: 1,
            limit: 10,
            total: 0,
            totalPages: 1,
        },
    };
};

const app = require("../dist/app").default;

const guestAuth = { Authorization: "Bearer guest-token" };
const moderatorAuth = { Authorization: "Bearer moderator-token" };
const adminAuth = { Authorization: "Bearer admin-token" };

beforeEach(resetState);

describe("Users, verification, and RBAC contracts", () => {
    it("requires authentication for current user and host verification endpoints", async () => {
        const meResponse = await request(app).get("/api/users/me");
        assert.equal(meResponse.status, 401);

        const verificationResponse = await request(app).post("/api/host/verifications").send({});
        assert.equal(verificationResponse.status, 401);
    });

    it("returns the current user's own profile and blocks self role/status changes", async () => {
        const meResponse = await request(app).get("/api/users/me").set(guestAuth);

        assert.equal(meResponse.status, 200);
        assert.equal(meResponse.body.data.user.email, "guest@example.com");
        assert.equal(meResponse.body.data.user.passwordHash, undefined);

        const roleEscalationResponse = await request(app)
            .patch("/api/users/me")
            .set(guestAuth)
            .send({ role: "admin", status: "active" });

        assert.equal(roleEscalationResponse.status, 422);
    });

    it("validates profile fields and checks phone uniqueness", async () => {
        const invalidResponse = await request(app)
            .patch("/api/users/me")
            .set(guestAuth)
            .send({ avatarUrl: "not-a-url", dob: "2999-01-01" });

        assert.equal(invalidResponse.status, 422);

        const duplicatePhoneResponse = await request(app)
            .patch("/api/users/me")
            .set(guestAuth)
            .send({ phone: "0902222222" });

        assert.equal(duplicatePhoneResponse.status, 409);
    });

    it("persists editable public profile fields for the current user", async () => {
        const updateResponse = await request(app)
            .patch("/api/users/me")
            .set(guestAuth)
            .send({
                fullName: "Guest Updated",
                bio: "Short public bio",
                location: "Vung Tau",
                job: "Traveler",
                dreamDestination: "Da Lat",
                school: "Open University",
                languages: ["Vietnamese", "English"],
            });

        assert.equal(updateResponse.status, 200);
        assert.equal(updateResponse.body.data.user.fullName, "Guest Updated");
        assert.equal(updateResponse.body.data.user.bio, "Short public bio");
        assert.equal(updateResponse.body.data.user.location, "Vung Tau");
        assert.equal(updateResponse.body.data.user.job, "Traveler");
        assert.equal(updateResponse.body.data.user.dreamDestination, "Da Lat");
        assert.equal(updateResponse.body.data.user.school, "Open University");
        assert.deepEqual(updateResponse.body.data.user.languages, ["Vietnamese", "English"]);

        const meResponse = await request(app).get("/api/users/me").set(guestAuth);

        assert.equal(meResponse.status, 200);
        assert.equal(meResponse.body.data.user.location, "Vung Tau");
        assert.deepEqual(meResponse.body.data.user.languages, ["Vietnamese", "English"]);
    });

    it("keeps user administration admin-only and masks sensitive contact fields", async () => {
        const forbiddenResponse = await request(app).get("/api/users/102").set(guestAuth);
        assert.equal(forbiddenResponse.status, 403);

        const moderatorResponse = await request(app).get("/api/users/102").set(moderatorAuth);
        assert.equal(moderatorResponse.status, 403);

        const adminResponse = await request(app).get("/api/users/101").set(adminAuth);
        assert.equal(adminResponse.status, 200);
        assert.notEqual(adminResponse.body.data.user.email, "guest@example.com");
        assert.notEqual(adminResponse.body.data.user.phone, "0901234567");
        assert.equal(adminResponse.body.data.user.emailMasked, adminResponse.body.data.user.email);
        assert.equal(adminResponse.body.data.user.passwordHash, undefined);
    });

    it("allows admin role/status changes for other users and writes audit logs", async () => {
        const response = await request(app)
            .patch("/api/users/101")
            .set(adminAuth)
            .send({ role: "host", status: "active" });

        assert.equal(response.status, 200);
        assert.deepEqual(roles.get("101"), ["host"]);
        assert.ok(auditLogs.some((item) => item.action === "users.role_changed"));
        assert.ok(auditLogs.some((item) => item.action === "users.status_changed"));
    });

    it("does not allow disabling or demoting the last active admin", async () => {
        const statusResponse = await request(app)
            .patch("/api/users/900/status")
            .set(adminAuth)
            .send({ status: "blocked" });

        assert.equal(statusResponse.status, 409);

        const roleResponse = await request(app)
            .patch("/api/users/900")
            .set(adminAuth)
            .send({ roles: ["guest"] });

        assert.equal(roleResponse.status, 409);
        assert.deepEqual(roles.get("900"), ["admin"]);
    });

    it("keeps moderator scoped to listing moderation, not payout, user, or verification admin", async () => {
        const listingResponse = await request(app).get("/api/admin/listings/pending").set(moderatorAuth);
        assert.equal(listingResponse.status, 200);

        const payoutResponse = await request(app).get("/api/admin/host-payouts").set(moderatorAuth);
        assert.equal(payoutResponse.status, 403);

        const verificationResponse = await request(app).get("/api/admin/verifications").set(moderatorAuth);
        assert.equal(verificationResponse.status, 403);
    });

    it("validates verification documents, enforces owner view, and requires rejection reason", async () => {
        const invalidDocumentResponse = await request(app)
            .post("/api/host/verifications")
            .set(guestAuth)
            .send({
                verificationType: "identity",
                fullName: "Guest User",
                documentUrls: ["https://cdn.example.com/docs/identity.exe"],
            });

        assert.equal(invalidDocumentResponse.status, 422);

        const submitResponse = await request(app)
            .post("/api/host/verifications")
            .set(guestAuth)
            .send({
                verificationType: "identity",
                fullName: "Guest User",
                idNumber: "0123456789",
                documentUrls: ["https://cdn.example.com/docs/identity-front.jpg"],
            });

        assert.equal(submitResponse.status, 201);

        const myResponse = await request(app).get("/api/host/verifications/me").set(guestAuth);
        assert.equal(myResponse.status, 200);
        assert.equal(myResponse.body.data.items.length, 1);
        assert.equal(myResponse.body.data.items[0].hostId, 101);
        assert.equal(myResponse.body.data.items[0].idNumber, "********6789");
        assert.notEqual(myResponse.body.data.items[0].idNumber, "0123456789");

        const rejectResponse = await request(app)
            .patch(`/api/admin/verifications/${submitResponse.body.data.verificationId}/reject`)
            .set(adminAuth)
            .send({});

        assert.equal(rejectResponse.status, 422);
    });
});

export {};
