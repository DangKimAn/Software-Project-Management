// CONFLICT-RESOLVED: Giữ bộ kiểm thử hợp nhất `tests/host-listings.test.ts` chuyển từ `src/tests/` và loại bỏ bản trùng `listings-host-subroutes.test.ts`.
const assert = require("node:assert/strict");
const { after, before, beforeEach, describe, it } = require("node:test");
const request = require("supertest");

import type { AuthenticatedTestUser } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const { ApiError } = require("../dist/common/api-error");
const authService = require("../dist/modules/auth/auth.service");
const Amenity = require("../dist/models/amenity").default;
const AvailabilityCalendar = require("../dist/models/availability-calendar").default;
const Booking = require("../dist/models/booking").default;
const CounterModel = require("../dist/models/counter");
const Counter = CounterModel.default;
const Listing = require("../dist/models/listing").default;
const ListingAmenity = require("../dist/models/listing-amenity").default;
const ListingImage = require("../dist/models/listing-image").default;
const ListingRule = require("../dist/models/listing-rule").default;
const User = require("../dist/models/user").default;
const auditLogService = require("../dist/services/audit-log.service");
const hostVerificationStatus = require("../dist/modules/host-kyc/host-status-sync.service");
const notificationService = require("../dist/modules/notifications/notification.service");
const sheetSyncService = require("../dist/modules/host-sheet-sync/host-sheet-sync.service");
const sequelize = require("../dist/config/database").default;

type HostListingRecord = Record<string, unknown> & {
    listingId: number;
    hostId: number;
    title: string;
    description: string;
    status: string;
    deletedAt: Date | null;
    latitude: number;
    longitude: number;
    basePrice: number;
    minNights: number;
    maxNights: number | null;
    checkInFrom: string;
    checkOutBefore: string;
    smokingAllowed: boolean;
    petsAllowed: boolean;
    partyAllowed: boolean;
    quietHours: string | null;
    amenityIds: number[];
    images: Array<Record<string, unknown>>;
    availabilityCalendar: Array<Record<string, unknown>>;
    save: () => Promise<HostListingRecord>;
};

const listings = new Map<number, HostListingRecord>();
let nextListingSeq = 200;
let nextImageSeq = 3000;

const originals = {
    verifyAuthToken: authService.verifyAuthToken,
    toAuthenticatedUser: authService.toAuthenticatedUser,
    userFindById: User.findById,
    sequelizeTransaction: sequelize.transaction,
    listingMax: Listing.max,
    listingFindOne: Listing.findOne,
    listingFind: Listing.find,
    listingCount: Listing.countDocuments,
    listingProtoSave: Listing.prototype.save,
    counterFindOrCreate: Counter.findOrCreate,
    counterUpsert: Counter.upsert,
    amenityCount: Amenity.countDocuments,
    listingAmenityDestroy: ListingAmenity.destroy,
    listingAmenityBulkCreate: ListingAmenity.bulkCreate,
    listingAmenityFindAll: ListingAmenity.findAll,
    listingRuleFindOne: ListingRule.findOne,
    listingRuleCreate: ListingRule.create,
    listingImageFindAll: ListingImage.findAll,
    listingImageBulkCreate: ListingImage.bulkCreate,
    listingImageDestroy: ListingImage.destroy,
    listingImageUpdate: ListingImage.update,
    availabilityFindAll: AvailabilityCalendar.findAll,
    bookingFindAll: Booking.findAll,
    writeAuditLog: auditLogService.writeAuditLog,
    isHostVerifiedForPublishing: hostVerificationStatus.isHostVerifiedForPublishing,
    notifyListingSubmitted: notificationService.notifyListingSubmitted,
    enqueueHostSheetSyncJobSafe: sheetSyncService.enqueueHostSheetSyncJobSafe,
};

const seedHostListing = (hostId: number, overrides: Partial<HostListingRecord> = {}): HostListingRecord => {
    const listingId = overrides.listingId ?? nextListingSeq++;
    const record: HostListingRecord = {
        listingId,
        hostId,
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
        smokingAllowed: false,
        petsAllowed: false,
        partyAllowed: false,
        quietHours: null,
        status: "draft",
        rejectionReason: null,
        amenityIds: [1, 2],
        images: [],
        availabilityCalendar: [],
        deletedAt: null,
        createdAt: new Date("2026-05-01T00:00:00.000Z"),
        updatedAt: new Date("2026-05-01T00:00:00.000Z"),
        ...overrides,
        save: async () => {
            listings.set(listingId, record);
            return record;
        },
    };
    listings.set(listingId, record);
    return record;
};

before(() => {
    const userMap = new Map<string, { _id: number; id: number; email: string; fullName: string; status: string; roles: string[] }>([
        ["101", { _id: 101, id: 101, email: "host@example.com", fullName: "Host 101", status: "active", roles: ["host"] }],
        ["102", { _id: 102, id: 102, email: "other@example.com", fullName: "Host 102", status: "active", roles: ["host"] }],
        ["201", { _id: 201, id: 201, email: "guest@example.com", fullName: "Guest 201", status: "active", roles: ["guest"] }],
    ]);

    authService.verifyAuthToken = (token: string) => {
        if (token === "host-101") return { userId: "101", role: "host" };
        if (token === "host-102") return { userId: "102", role: "host" };
        if (token === "guest-201") return { userId: "201", role: "guest" };
        throw new ApiError(401, "Unauthorized");
    };
    User.findById = async (id: string | number) => userMap.get(String(id)) ?? null;
    authService.toAuthenticatedUser = async (u: { id: number; email: string; fullName: string; status: string; roles: string[] }): Promise<AuthenticatedTestUser> => ({
        id: String(u.id),
        email: u.email,
        phone: "0900000000",
        name: u.fullName,
        username: `u${u.id}`,
        status: u.status,
        roles: u.roles,
    });

    sequelize.transaction = async (cb: (tx: Record<string, unknown>) => Promise<unknown>) =>
        cb({ LOCK: { UPDATE: "UPDATE" }, afterCommit: (fn: () => void) => fn() });

    Listing.max = async () => Math.max(100, ...Array.from(listings.keys()));
    Counter.findOrCreate = async () => [{ key: "listing", value: nextListingSeq++, save: async () => {} }, true];
    Counter.upsert = async () => [null, true];

    Listing.prototype.save = async function saveListing(this: HostListingRecord) {
        listings.set(Number(this.listingId), this);
        return this;
    };

    Listing.findOne = async (options: { where?: { listingId?: number; deletedAt?: null } }) => {
        const lid = Number(options?.where?.listingId);
        const found = listings.get(lid) ?? null;
        if (!found) return null;
        if (options?.where && "deletedAt" in options.where && options.where.deletedAt === null && found.deletedAt !== null) {
            return null;
        }
        return found;
    };

    const filterMine = (filter: { hostId?: number; status?: string; deletedAt?: null }) =>
        Array.from(listings.values()).filter(
            (item) =>
                (filter.deletedAt !== null || item.deletedAt === null) &&
                (filter.hostId === undefined || Number(item.hostId) === Number(filter.hostId)) &&
                (filter.status === undefined || item.status === filter.status),
        );

    Listing.find = (filter: { hostId?: number; status?: string; deletedAt?: null } = {}) => {
        const all = filterMine(filter);
        return {
            sort: () => ({
                skip: (offset: number) => ({
                    limit: async (lim: number) => all.slice(offset, offset + lim),
                }),
            }),
        };
    };
    Listing.countDocuments = async (filter: { hostId?: number; status?: string; deletedAt?: null } = {}) =>
        filterMine(filter).length;

    Amenity.countDocuments = async (filter: { amenityId?: { $in?: number[] } }) => {
        const allowed = new Set([1, 2, 3, 4]);
        const ids = filter?.amenityId?.$in ?? [];
        return ids.filter((id) => allowed.has(id)).length;
    };

    ListingAmenity.destroy = async () => 0;
    ListingAmenity.bulkCreate = async () => [];
    ListingAmenity.findAll = async () => [];
    ListingRule.findOne = async () => null;
    ListingRule.create = async (values: Record<string, unknown>) => {
        const found = listings.get(Number(values.listingId));
        if (found) {
            found.checkInFrom = String(values.checkInFrom ?? found.checkInFrom);
            found.checkOutBefore = String(values.checkOutBefore ?? found.checkOutBefore);
            found.smokingAllowed = Boolean(values.smokingAllowed);
            found.petsAllowed = Boolean(values.petsAllowed);
            found.partyAllowed = Boolean(values.partyAllowed);
            found.quietHours = (values.quietHours as string | null) ?? null;
        }
        return values;
    };
    ListingImage.findAll = async () => [];
    ListingImage.update = async () => [0];
    ListingImage.destroy = async () => 1;
    ListingImage.bulkCreate = async (rows: Array<Record<string, unknown>>) =>
        rows.map((row) => ({ ...row, id: nextImageSeq++ }));
    AvailabilityCalendar.findAll = async () => [];
    Booking.findAll = async () => [];
    auditLogService.writeAuditLog = async () => {};
    hostVerificationStatus.isHostVerifiedForPublishing = async () => true;
    notificationService.notifyListingSubmitted = async () => {};
    sheetSyncService.enqueueHostSheetSyncJobSafe = () => {};
});

beforeEach(() => {
    listings.clear();
    nextListingSeq = 200;
    nextImageSeq = 3000;
});

after(async () => {
    authService.verifyAuthToken = originals.verifyAuthToken;
    authService.toAuthenticatedUser = originals.toAuthenticatedUser;
    User.findById = originals.userFindById;
    sequelize.transaction = originals.sequelizeTransaction;
    Listing.max = originals.listingMax;
    Listing.findOne = originals.listingFindOne;
    Listing.find = originals.listingFind;
    Listing.countDocuments = originals.listingCount;
    Listing.prototype.save = originals.listingProtoSave;
    Counter.findOrCreate = originals.counterFindOrCreate;
    Counter.upsert = originals.counterUpsert;
    Amenity.countDocuments = originals.amenityCount;
    ListingAmenity.destroy = originals.listingAmenityDestroy;
    ListingAmenity.bulkCreate = originals.listingAmenityBulkCreate;
    ListingAmenity.findAll = originals.listingAmenityFindAll;
    ListingRule.findOne = originals.listingRuleFindOne;
    ListingRule.create = originals.listingRuleCreate;
    ListingImage.findAll = originals.listingImageFindAll;
    ListingImage.bulkCreate = originals.listingImageBulkCreate;
    ListingImage.destroy = originals.listingImageDestroy;
    ListingImage.update = originals.listingImageUpdate;
    AvailabilityCalendar.findAll = originals.availabilityFindAll;
    Booking.findAll = originals.bookingFindAll;
    auditLogService.writeAuditLog = originals.writeAuditLog;
    hostVerificationStatus.isHostVerifiedForPublishing = originals.isHostVerifiedForPublishing;
    notificationService.notifyListingSubmitted = originals.notifyListingSubmitted;
    sheetSyncService.enqueueHostSheetSyncJobSafe = originals.enqueueHostSheetSyncJobSafe;
    try {
        await sequelize.close();
    } catch {}
});

const app = require("../dist/app").default;

const validCreatePayload = () => ({
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
    amenityIds: [1, 2, 2],
});

describe("Host listings API end-to-end", () => {
    it("creates listings for hosts, deduplicates amenities, and enforces RBAC and Vung Tau bounds", async () => {
        const created = await request(app)
            .post("/api/host/listings")
            .set("Authorization", "Bearer host-101")
            .send(validCreatePayload());

        assert.equal(created.status, 201);
        assert.equal(created.body.data.status, "draft");

        const guestDenied = await request(app)
            .post("/api/host/listings")
            .set("Authorization", "Bearer guest-201")
            .send(validCreatePayload());
        assert.equal(guestDenied.status, 403);

        const outsideVungTau = await request(app)
            .post("/api/host/listings")
            .set("Authorization", "Bearer host-101")
            .send({ ...validCreatePayload(), latitude: 10.7769, longitude: 106.7009 });
        assert.equal(outsideVungTau.status, 422);
    });

    it("lists host-owned listings, protects cross-host BOLA, demotes sensitive edits, and soft-deletes", async () => {
        const ownActive = seedHostListing(101, { status: "active", title: "Published Villa" });
        const otherOwned = seedHostListing(102, { status: "active", title: "Other Villa" });

        const mine = await request(app)
            .get("/api/host/listings/mine?status=published")
            .set("Authorization", "Bearer host-101");
        assert.equal(mine.status, 200);
        assert.equal(mine.body.data.items.length, 1);

        const forbidden = await request(app)
            .get(`/api/host/listings/${otherOwned.listingId}`)
            .set("Authorization", "Bearer host-101");
        assert.equal(forbidden.status, 403);

        const edited = await request(app)
            .patch(`/api/host/listings/${ownActive.listingId}`)
            .set("Authorization", "Bearer host-101")
            .send({ description: "Updated sensitive description" });
        assert.equal(edited.status, 200);
        assert.equal(edited.body.data.status, "pending_approval");

        const deleted = await request(app)
            .delete(`/api/host/listings/${ownActive.listingId}`)
            .set("Authorization", "Bearer host-101");
        assert.equal(deleted.status, 200);
        assert.ok(ownActive.deletedAt instanceof Date);
    });

    it("manages images, blocks IPv4-mapped IPv6 SSRF image URLs, updates rules and calendar", async () => {
        const listing = seedHostListing(101, {
            availabilityCalendar: [
                {
                    date: "2027-04-20",
                    isAvailable: true,
                    isBlockedByHost: false,
                    priceOverride: 1700000,
                    minNightsOverride: 3,
                    notes: "Festival",
                },
            ],
        });

        const ssrfImage = await request(app)
            .post(`/api/host/listings/${listing.listingId}/images`)
            .set("Authorization", "Bearer host-101")
            .send({ images: [{ url: "https://[::ffff:169.254.169.254]/latest/meta-data", sortOrder: 1 }] });
        assert.equal(ssrfImage.status, 422);

        const addedImages = await request(app)
            .post(`/api/host/listings/${listing.listingId}/images`)
            .set("Authorization", "Bearer host-101")
            .send({ images: [{ url: "https://example.com/room.jpg", caption: "Room", sortOrder: 1 }] });
        assert.equal(addedImages.status, 200);
        assert.equal(addedImages.body.data.count, 1);

        const rulesRes = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/rules`)
            .set("Authorization", "Bearer host-101")
            .send({ checkInFrom: "15:00", petsAllowed: true, quietHours: "22:00-06:00" });
        assert.equal(rulesRes.status, 200);

        const calendarRes = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=4&year=2027`)
            .set("Authorization", "Bearer host-101");
        assert.equal(calendarRes.status, 200);
        assert.equal(calendarRes.body.data.days.length, 30);
    });
});

export {};

