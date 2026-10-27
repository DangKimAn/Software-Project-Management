const assert = require("node:assert/strict");
const { before, describe, it } = require("node:test");

const request = require("supertest");
import type { AuthenticatedTestUser } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const authService = require("../dist/modules/auth/auth.service");
const User = require("../dist/models/user").default;
const hostOnboardingService = require("../dist/modules/host-onboarding/host-onboarding.service");
const hostVerificationsService = require("../dist/modules/verifications/verifications.service");
const hostListingsService = require("../dist/modules/host-listings/host-listings.service");
const adminListingsService = require("../dist/modules/admin/admin.service");

type TestUserRecord = {
    _id: number;
    id: number;
    email: string;
    phone: string;
    username: string;
    fullName: string;
    status: string;
    roles: string[];
    isHostVerified: boolean;
    hostApplicationStatus: string | null;
};

type HostApplicationRecord = Record<string, unknown> & {
    applicationId: number;
    userId: number;
    status: string;
    hostApplicationStatus: string;
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
    rejectionReason: string | null;
};

type ListingInput = Record<string, unknown> & {
    title: string;
    status?: string;
};

type ListingRecord = {
    listingId: number;
    hostId: number;
    title: string;
    status: string;
    approvedBy: number | null;
    approvedAt: string | null;
    rejectionReason: string | null;
};

const users = new Map<string, TestUserRecord>([
    [
        "101",
        {
            _id: 101,
            id: 101,
            email: "guest@example.com",
            phone: "0901234567",
            username: "guest",
            fullName: "Guest User",
            status: "active",
            roles: ["guest"],
            isHostVerified: false,
            hostApplicationStatus: null,
        },
    ] as const,
    [
        "900",
        {
            _id: 900,
            id: 900,
            email: "admin@example.com",
            phone: "0909999999",
            username: "admin",
            fullName: "Admin User",
            status: "active",
            roles: ["admin"],
            isHostVerified: true,
            hostApplicationStatus: null,
        },
    ] as const,
]);

let application: HostApplicationRecord | null = null;
let nextVerificationId = 501;
let nextListingId = 801;
const verifications: VerificationRecord[] = [];
const listings: ListingRecord[] = [];

const userToAuthUser = (user: TestUserRecord): AuthenticatedTestUser => ({
    id: String(user._id),
    email: user.email,
    phone: user.phone,
    name: user.fullName,
    username: user.username,
    status: user.status,
    roles: user.roles,
});

before(() => {
    authService.verifyAuthToken = (token: string) => {
        if (token === "admin-token") {
            return { userId: "900", role: "admin" };
        }

        if (token === "guest-token") {
            return { userId: "101", role: "guest" };
        }

        throw new Error("Unauthorized");
    };
    authService.toAuthenticatedUser = async (user: TestUserRecord) => userToAuthUser(user);
    authService.assertUserCanAuthenticate = () => undefined;
    User.findById = async (id: string | number) => users.get(String(id)) ?? null;

    hostOnboardingService.registerHostApplication = async (user: AuthenticatedTestUser, input: Record<string, unknown>) => {
        application = {
            applicationId: 301,
            userId: Number(user.id),
            status: "pending",
            hostApplicationStatus: "pending",
            ...input,
            created: true,
        };
        users.get(user.id)!.hostApplicationStatus = "pending";
        return application;
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
            rejectionReason: null,
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
            total: verifications.length,
            totalPages: 1,
        },
    });

    hostVerificationsService.approveHostVerification = async (verificationId: number, admin: AuthenticatedTestUser) => {
        assert.equal(admin.roles.includes("admin"), true);
        const verification = verifications.find((item) => item.verificationId === verificationId);
        if (!verification) {
            throw new Error("Missing verification fixture");
        }
        verification.status = "approved";

        const host = users.get(String(verification.hostId));
        if (!host) {
            throw new Error("Missing host fixture");
        }
        host.roles = ["guest", "host"];
        host.isHostVerified = true;
        host.hostApplicationStatus = "approved";

        return {
            verificationId,
            status: "approved",
        };
    };

    hostListingsService.createListing = async (userId: string | number, input: ListingInput) => {
        const listing = {
            listingId: nextListingId++,
            hostId: Number(userId),
            title: input.title,
            status: input.status === "pending_approval" ? "pending_approval" : "draft",
            approvedBy: null,
            approvedAt: null,
            rejectionReason: null,
        };
        listings.push(listing);
        return {
            listingId: listing.listingId,
            status: listing.status,
        };
    };

    adminListingsService.listPendingAdminListings = async () => ({
        items: listings.filter((listing) => listing.status === "pending_approval"),
        pagination: {
            page: 1,
            limit: 10,
            total: listings.filter((listing) => listing.status === "pending_approval").length,
            totalPages: 1,
        },
    });

    adminListingsService.approveAdminListing = async (listingId: number, admin: AuthenticatedTestUser) => {
        assert.equal(admin.roles.includes("admin"), true);
        const listing = listings.find((item) => item.listingId === listingId);
        if (!listing) {
            throw new Error("Missing listing fixture");
        }
        listing.status = "published";
        listing.approvedBy = Number(admin.id);
        listing.approvedAt = new Date().toISOString();
        return listing;
    };
});

const app = require("../dist/app").default;

const guestAuth = { Authorization: "Bearer guest-token" };
const adminAuth = { Authorization: "Bearer admin-token" };

const createListingPayload = () => ({
    title: "Villa gan bien",
    description: "Spacious villa near the beach",
    addressLine: "12 Nguyen Hue",
    ward: "Ward 1",
    district: "District 1",
    city: "Vung Tau",
    stateRegion: "Ba Ria - Vung Tau",
    country: "VN",
    postalCode: "790000",
    latitude: 10.3456,
    longitude: 107.0842,
    propertyType: "villa",
    roomType: "entire_place",
    maxGuests: 6,
    bedrooms: 3,
    beds: 4,
    bathrooms: 2,
    basePrice: 1500000,
    weekendPrice: 1800000,
    cleaningFee: 200000,
    serviceFeePct: 10,
    currency: "VND",
    minNights: 2,
    maxNights: 10,
    checkInFrom: "14:00",
    checkOutBefore: "12:00",
    cancellationPolicy: "moderate",
    instantBookEnabled: false,
    amenityIds: [1, 2],
    status: "pending_approval",
});

describe("Host onboarding and verification flow", () => {
    it("allows guest host registration, verification approval, pending listing, and admin publish", async () => {
        const registerResponse = await request(app)
            .post("/api/host/register")
            .set(guestAuth)
            .send({
                contactName: "Guest User",
                contactEmail: "guest@example.com",
                contactPhone: "0901234567",
                businessAddress: "12 Nguyen Hue, Vung Tau",
                entityType: "individual",
                notes: "Small homestay owner",
            });

        assert.equal(registerResponse.status, 201);
        assert.equal(registerResponse.body.data.hostApplicationStatus, "pending");
        if (!application) {
            throw new Error("Expected host application to be captured");
        }
        assert.equal(application.status, "pending");

        const verificationResponse = await request(app)
            .post("/api/host/verifications")
            .set(guestAuth)
            .send({
                verificationType: "identity",
                fullName: "Guest User",
                idNumber: "0123456789",
                documentUrls: ["https://cdn.example.com/docs/identity-front.jpg"],
                notes: "Citizen ID",
            });

        assert.equal(verificationResponse.status, 201);
        assert.equal(verificationResponse.body.data.status, "pending");

        const myVerificationsResponse = await request(app)
            .get("/api/host/verifications/me")
            .set(guestAuth);

        assert.equal(myVerificationsResponse.status, 200);
        assert.equal(myVerificationsResponse.body.data.items[0].idNumber, "********6789");
        assert.notEqual(myVerificationsResponse.body.data.items[0].idNumber, "0123456789");

        const approveVerificationResponse = await request(app)
            .patch(`/api/admin/verifications/${verificationResponse.body.data.verificationId}/approve`)
            .set(adminAuth)
            .send({ notes: "Documents match" });

        assert.equal(approveVerificationResponse.status, 200);
        assert.equal(approveVerificationResponse.body.data.status, "approved");
        assert.deepEqual(users.get("101")!.roles, ["guest", "host"]);
        assert.equal(users.get("101")!.isHostVerified, true);

        const createListingResponse = await request(app)
            .post("/api/host/listings")
            .set(guestAuth)
            .send(createListingPayload());

        assert.equal(createListingResponse.status, 201);
        assert.equal(createListingResponse.body.data.status, "pending_approval");

        const pendingListingsResponse = await request(app)
            .get("/api/admin/listings/pending")
            .set(adminAuth);

        assert.equal(pendingListingsResponse.status, 200);
        assert.equal(pendingListingsResponse.body.data.items.length, 1);
        assert.equal(pendingListingsResponse.body.data.items[0].status, "pending_approval");

        const approveListingResponse = await request(app)
            .patch(`/api/admin/listings/${createListingResponse.body.data.listingId}/approve`)
            .set(adminAuth)
            .send({});

        assert.equal(approveListingResponse.status, 200);
        assert.equal(approveListingResponse.body.data.status, "published");
        assert.equal(approveListingResponse.body.data.approvedBy, 900);
    });
});

export {};
