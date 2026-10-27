const assert = require("node:assert/strict");
const { before, describe, it } = require("node:test");

const request = require("supertest");
const { Op } = require("sequelize");
import type { AuthenticatedTestUser } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const { ApiError } = require("../dist/common/api-error");
const authService = require("../dist/modules/auth/auth.service");
const User = require("../dist/models/user").default;
const AvailabilityCalendar = require("../dist/models/availability-calendar").default;
const Amenity = require("../dist/models/amenity").default;
const Booking = require("../dist/models/booking").default;
const Listing = require("../dist/models/listing").default;
const ListingAmenity = require("../dist/models/listing-amenity").default;
const ListingImage = require("../dist/models/listing-image").default;
const Review = require("../dist/models/review").default;
const publicListingsService = require("../dist/modules/listings/listings.service");
const hostListingsService = require("../dist/modules/host-listings/host-listings.service");
const adminListingsService = require("../dist/modules/admin/admin.service");
const semanticSearchService = require("../dist/modules/semantic-search/semantic-search.service");
const locationGroups = require("../dist/common/vung-tau-location-groups");

const originalGetPublicListings = publicListingsService.getPublicListings;

type TestUserRecord = {
    _id: number;
    id: number;
    email: string;
    phone: string;
    username: string;
    fullName: string;
    status: string;
    roles: string[];
};

type PublicSearchQuery = {
    q?: string;
    city?: string;
    district?: string;
    checkIn?: string;
    checkOut?: string;
    guests?: number;
    propertyType?: string;
    roomType?: string;
    priceMin?: number;
    priceMax?: number;
    minPrice?: number;
    maxPrice?: number;
    amenities?: string;
    locationGroup?: string;
    lat?: number;
    lng?: number;
    radius?: number;
    sort?: string;
    page?: number;
    limit?: number;
};

type ListingPayload = Record<string, unknown> & {
    title?: string;
    status?: string;
    dates?: string[];
    isAvailable?: boolean;
};

type CapturedCreatePayload = {
    userId?: string | number;
    payload?: ListingPayload;
};

type CapturedUpdatePayload = {
    listingId?: number;
    actor?: AuthenticatedTestUser;
    payload?: ListingPayload;
};

type CapturedCalendarPayload = {
    listingId?: number;
    actor?: AuthenticatedTestUser;
    payload?: ListingPayload;
};

type CapturedAdminApproval = {
    listingId?: number;
    admin?: AuthenticatedTestUser;
};

type SequelizeWhere = Record<PropertyKey, unknown>;
type CapturedAiSearchPayload = {
    query?: string;
    limit?: number;
    city?: string;
    minPrice?: number;
    maxPrice?: number;
    guests?: number;
};

const users = new Map<string, TestUserRecord>([
    [
        "101",
        {
            _id: 101,
            id: 101,
            email: "host@example.com",
            phone: "0901234567",
            username: "host",
            fullName: "Host User",
            status: "active",
            roles: ["host"],
        },
    ],
    [
        "102",
        {
            _id: 102,
            id: 102,
            email: "other-host@example.com",
            phone: "0901234568",
            username: "other-host",
            fullName: "Other Host",
            status: "active",
            roles: ["host"],
        },
    ],
    [
        "201",
        {
            _id: 201,
            id: 201,
            email: "guest@example.com",
            phone: "0900000201",
            username: "guest",
            fullName: "Guest User",
            status: "active",
            roles: ["guest"],
        },
    ],
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
        },
    ],
    [
        "901",
        {
            _id: 901,
            id: 901,
            email: "moderator@example.com",
            phone: "0909999998",
            username: "moderator",
            fullName: "Moderator User",
            status: "active",
            roles: ["moderator"],
        },
    ],
]);

let capturedPublicSearch: PublicSearchQuery = {};
let capturedCreatePayload: CapturedCreatePayload = {};
let capturedUpdatePayload: CapturedUpdatePayload = {};
let capturedCalendarPayload: CapturedCalendarPayload = {};
let capturedAdminApproval: CapturedAdminApproval = {};
let capturedAiListingSearch: CapturedAiSearchPayload = {};

before(() => {
    authService.verifyAuthToken = (token: string) => {
        if (token === "host-token") {
            return { userId: "101", role: "host" };
        }

        if (token === "other-host-token") {
            return { userId: "102", role: "host" };
        }

        if (token === "admin-token") {
            return { userId: "900", role: "admin" };
        }

        if (token === "moderator-token") {
            return { userId: "901", role: "moderator" };
        }

        if (token === "guest-token") {
            return { userId: "201", role: "guest" };
        }

        throw new ApiError(401, "Unauthorized");
    };
    authService.toAuthenticatedUser = async (user: TestUserRecord): Promise<AuthenticatedTestUser> => ({
        id: String(user._id),
        email: user.email,
        phone: user.phone,
        name: user.fullName,
        username: user.username,
        status: user.status,
        roles: user.roles,
    });
    User.findById = async (id: string | number) => users.get(String(id)) ?? null;

    publicListingsService.getPublicListings = async (query: PublicSearchQuery) => {
        capturedPublicSearch = query;
        return {
            items: [
                {
                    listingId: 801,
                    title: "Open stay",
                    description: "Available listing",
                    basePrice: 1500000,
                    ratingAvg: 4.8,
                    reviewCount: 12,
                    isAvailable: true,
                    addressLine: "12 Nguyen Hue",
                    ward: "Ward 1",
                    city: "Vung Tau",
                    district: "District 1",
                    propertyType: "villa",
                    roomType: "entire_place",
                    maxGuests: 6,
                    bedrooms: 3,
                    beds: 4,
                    bathrooms: 2,
                    currency: "VND",
                    imageUrl: "https://example.com/listing.jpg",
                },
            ],
            pagination: { page: query.page ?? 1, limit: query.limit ?? 10, total: 1, totalPages: 1 },
        };
    };
    publicListingsService.getPublicListingDetail = async (listingId: number) => ({
        listingId,
        title: "Open stay",
        description: "Available listing",
        basePrice: 1500000,
        currency: "VND",
        maxGuests: 6,
        bedrooms: 3,
        beds: 4,
        bathrooms: 2,
        propertyType: "villa",
        roomType: "entire_place",
        minNights: 2,
        maxNights: 10,
        checkInFrom: "14:00",
        checkOutBefore: "12:00",
        cancellationPolicy: "moderate",
        instantBookEnabled: false,
        addressSummary: {
            addressLine: "12 Nguyen Hue",
            ward: "Ward 1",
            district: "District 1",
            city: "Vung Tau",
            country: "VN",
        },
        amenities: [{ amenityId: 1, name: "WiFi", icon: null }],
        images: [{ imageId: 1, url: "https://example.com/listing.jpg", caption: null, sortOrder: 1 }],
        ratingSummary: { avgRating: 4.8, reviewCount: 12 },
        host: { userId: 101, name: "Host User" },
    });

    hostListingsService.createListing = async (userId: string | number, payload: ListingPayload) => {
        capturedCreatePayload = { userId, payload };
        return { listingId: 900, status: payload.status ?? "draft" };
    };
    hostListingsService.updateListing = async (
        listingId: number,
        actor: AuthenticatedTestUser,
        payload: ListingPayload,
    ) => {
        capturedUpdatePayload = { listingId, actor, payload };
        return { listingId, status: "pending_approval" };
    };
    hostListingsService.getListingDetail = async (listingId: number, actor: AuthenticatedTestUser) => {
        if (listingId === 901 && actor.id !== "101") {
            throw new ApiError(403, "Forbidden");
        }

        return {
            listingId,
            hostId: "101",
            title: "Owner stay",
            status: "draft",
        };
    };
    hostListingsService.bulkUpdateListingCalendar = async (
        listingId: number,
        actor: AuthenticatedTestUser,
        payload: ListingPayload,
    ) => {
        capturedCalendarPayload = { listingId, actor, payload };
        const dates = payload.dates ?? [];
        if (dates.includes("2026-04-20") && payload.isAvailable === false) {
            throw new ApiError(409, "Cannot block dates with active bookings");
        }
        return { listingId, updatedDates: dates };
    };
    adminListingsService.approveAdminListing = async (listingId: number, admin: AuthenticatedTestUser) => {
        if (!admin.roles.includes("admin")) {
            throw new ApiError(403, "Forbidden");
        }
        capturedAdminApproval = { listingId, admin };
        return {
            listingId,
            status: "published",
            approvedBy: Number(admin.id),
            approvedAt: new Date().toISOString(),
        };
    };
    semanticSearchService.semanticSearchListings = async (payload: CapturedAiSearchPayload) => {
        capturedAiListingSearch = payload;
        return {
            items: [
                {
                    listingId: 802,
                    title: "Beach AI stay",
                    description: "Public semantic search result",
                    basePrice: 1200000,
                    weekendPrice: null,
                    currency: "VND",
                    ratingAvg: 4.7,
                    reviewCount: 8,
                    isAvailable: true,
                    addressLine: "2 Thuy Van",
                    ward: "Ward 2",
                    district: "Vung Tau",
                    city: "Vung Tau",
                    vungTauAreas: ["Bai Sau"],
                    vungTauAreaKeys: ["bai_sau"],
                    propertyType: "villa",
                    roomType: "entire_place",
                    maxGuests: 4,
                    bedrooms: 2,
                    beds: 2,
                    bathrooms: 2,
                    imageUrl: null,
                    semanticScore: 0.91,
                    finalScore: 0.88,
                    matchedReasons: ["Semantic match"],
                },
            ],
            pagination: { page: 1, limit: payload.limit ?? 12, total: 1, totalPages: 1 },
            fallback: false,
            searchMeta: {
                query: payload.query,
                semanticQuery: payload.query,
                usedVectorSearch: true,
                candidateCount: 1,
                forceVungTauOnly: true,
                filters: {
                    city: payload.city ?? "Vung Tau",
                    minPrice: payload.minPrice,
                    maxPrice: payload.maxPrice,
                    guests: payload.guests ?? 1,
                    amenityIds: [],
                    amenityCodes: [],
                    vungTauAreaKeys: [],
                },
            },
        };
    };
});

const app = require("../dist/app").default;

const hostAuth = { Authorization: "Bearer host-token" };
const otherHostAuth = { Authorization: "Bearer other-host-token" };
const adminAuth = { Authorization: "Bearer admin-token" };
const moderatorAuth = { Authorization: "Bearer moderator-token" };
const guestAuth = { Authorization: "Bearer guest-token" };

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
});

describe("Listings endpoint contracts", () => {
    it("allows public AI listing search before protected image AI routes", async () => {
        capturedAiListingSearch = {};

        const response = await request(app)
            .post("/api/ai/listings/search")
            .send({
                query: "bai sau",
                limit: 5,
                filters: {
                    city: "Vung Tau",
                    guests: 2,
                },
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.query, "bai sau");
        assert.equal(response.body.data.mode, "semantic");
        assert.equal(response.body.data.items[0].title, "Beach AI stay");
        assert.equal(capturedAiListingSearch.query, "bai sau");
        assert.equal(capturedAiListingSearch.limit, 5);
        assert.equal(capturedAiListingSearch.city, "Vung Tau");
        assert.equal(capturedAiListingSearch.guests, 2);
    });

    it("passes supported public search filters to the listing service", async () => {
        const response = await request(app).get(
            "/api/listings?q=pool%20villa&city=Vung%20Tau&district=District%201&checkIn=2026-04-20&checkOut=2026-04-22&guests=4&propertyType=villa&roomType=entire_place&priceMin=1000000&priceMax=2000000&amenities=wifi,pool&locationGroup=B%C3%A3i%20Sau&lat=10.345&lng=107.084&radius=800&sort=price_asc&page=2&limit=5",
        );

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items[0].title, "Open stay");
        assert.equal(capturedPublicSearch.q, "pool villa");
        assert.equal(capturedPublicSearch.city, "Vung Tau");
        assert.equal(capturedPublicSearch.checkIn, "2026-04-20");
        assert.equal(capturedPublicSearch.guests, 4);
        assert.equal(capturedPublicSearch.priceMin, 1000000);
        assert.equal(capturedPublicSearch.priceMax, 2000000);
        assert.equal(capturedPublicSearch.locationGroup, "Bãi Sau");
        assert.equal(capturedPublicSearch.lat, 10.345);
        assert.equal(capturedPublicSearch.lng, 107.084);
        assert.equal(capturedPublicSearch.radius, 800);
        assert.equal(capturedPublicSearch.page, 2);
        assert.equal(capturedPublicSearch.limit, 5);
    });

    it("rejects an unknown locationGroup before calling the public listing service", async () => {
        const previousCapturedSearch = capturedPublicSearch;
        const response = await request(app).get("/api/listings?locationGroup=Vung%20Tau");

        assert.equal(response.status, 422);
        assert.equal(capturedPublicSearch, previousCapturedSearch);
    });

    it("returns listing detail without sensitive host fields", async () => {
        const response = await request(app).get("/api/listings/801");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.listingId, 801);
        assert.deepEqual(response.body.data.host, { userId: 101, name: "Host User" });
        assert.equal(response.body.data.host.email, undefined);
    });

    it("allows hosts to create draft or pending approval listings", async () => {
        const response = await request(app)
            .post("/api/host/listings")
            .set(hostAuth)
            .send({ ...createListingPayload(), status: "pending_approval" });

        assert.equal(response.status, 201);
        assert.equal(response.body.data.status, "pending_approval");
        assert.equal(capturedCreatePayload.userId, "101");
        assert.equal(capturedCreatePayload.payload!.status, "pending_approval");
    });

    it("rejects guest access to host listing routes", async () => {
        const response = await request(app)
            .get("/api/host/listings/mine")
            .set(guestAuth);

        assert.equal(response.status, 403);
    });

    it("rejects admin access to host listing routes", async () => {
        const response = await request(app)
            .get("/api/host/listings/mine")
            .set(adminAuth);

        assert.equal(response.status, 403);
    });

    it("allows missing district and city while normalizing comma decimal coordinates", async () => {
        const payload: Record<string, unknown> = {
            ...createListingPayload(),
            latitude: "10,3456",
            longitude: "107,0842",
        };
        delete payload.city;
        delete payload.district;

        const response = await request(app)
            .post("/api/host/listings")
            .set(hostAuth)
            .send(payload);

        assert.equal(response.status, 201);
        assert.equal(capturedCreatePayload.payload!.city, undefined);
        assert.equal(capturedCreatePayload.payload!.district, undefined);
        assert.equal(capturedCreatePayload.payload!.latitude, 10.3456);
        assert.equal(capturedCreatePayload.payload!.longitude, 107.0842);
    });

    it("rejects invalid listing create input before calling the service", async () => {
        const previousCapturedCreatePayload = capturedCreatePayload;
        const response = await request(app)
            .post("/api/host/listings")
            .set(hostAuth)
            .send({ ...createListingPayload(), latitude: 100 });

        assert.equal(response.status, 422);
        assert.equal(capturedCreatePayload, previousCapturedCreatePayload);
    });

    it("rejects SQL injection-like sort input before calling the public listing service", async () => {
        const previousCapturedSearch = capturedPublicSearch;
        const response = await request(app).get(
            "/api/listings?sort=price%20DESC%3B%20DROP%20TABLE%20bookings%3B%20--",
        );

        assert.equal(response.status, 422);
        assert.equal(capturedPublicSearch, previousCapturedSearch);
    });

    it("enforces host listing ownership through the host service", async () => {
        const response = await request(app)
            .get("/api/host/listings/901")
            .set(otherHostAuth);

        assert.equal(response.status, 403);
    });

    it("returns pending approval when a published listing receives a sensitive update", async () => {
        const response = await request(app)
            .patch("/api/host/listings/900")
            .set(hostAuth)
            .send({ description: "New sensitive description", basePrice: 1700000 });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.status, "pending_approval");
        assert.equal(capturedUpdatePayload.payload!.description, "New sensitive description");
        assert.equal(capturedUpdatePayload.payload!.basePrice, 1700000);
    });

    it("returns conflict when calendar bulk update tries to close a booked date", async () => {
        const response = await request(app)
            .patch("/api/host/listings/900/calendar/bulk")
            .set(hostAuth)
            .send({ dates: ["2026-04-20"], isAvailable: false });

        assert.equal(response.status, 409);
        assert.equal(capturedCalendarPayload.payload!.isAvailable, false);
    });

    it("rejects javascript and data image URLs before storing listing attachments", async () => {
        let serviceCalled = false;
        const originalAddListingImages = hostListingsService.addListingImages;

        try {
            hostListingsService.addListingImages = async () => {
                serviceCalled = true;
                return { listingId: 900, images: [] };
            };

            const javascriptResponse = await request(app)
                .post("/api/host/listings/900/images")
                .set(hostAuth)
                .send({
                    images: [{ url: "javascript:alert(1)", sortOrder: 1 }],
                });

            assert.equal(javascriptResponse.status, 422);

            const dataResponse = await request(app)
                .post("/api/host/listings/900/images")
                .set(hostAuth)
                .send({
                    images: [{ url: "data:text/html,<script>alert(1)</script>", sortOrder: 1 }],
                });

            assert.equal(dataResponse.status, 422);
            assert.equal(serviceCalled, false);
        } finally {
            hostListingsService.addListingImages = originalAddListingImages;
        }
    });

    it("allows admins to approve pending listings", async () => {
        const response = await request(app)
            .patch("/api/admin/listings/900/approve")
            .set(adminAuth)
            .send({});

        assert.equal(response.status, 200);
        assert.equal(response.body.data.status, "published");
        assert.equal(response.body.data.approvedBy, 900);
        assert.equal(capturedAdminApproval.listingId, 900);
        assert.equal(capturedAdminApproval.admin!.roles.includes("admin"), true);
    });

    it("rejects moderator access to admin listing approval routes", async () => {
        const response = await request(app)
            .patch("/api/admin/listings/900/approve")
            .set(moderatorAuth);

        assert.equal(response.status, 403);
    });
});

export {};

describe("Listings service availability rules", () => {
    const createPublicListingMock = (
        listingId: number,
        overrides: Record<string, unknown> = {},
    ) => ({
        listingId,
        title: "Open stay",
        description: "Available listing",
        basePrice: 1500000,
        addressLine: "12 Nguyen Hue",
        ward: "Ward 1",
        city: "Vung Tau",
        district: "District 1",
        stateRegion: "Ba Ria - Vung Tau",
        propertyType: "villa",
        roomType: "entire_place",
        maxGuests: 6,
        bedrooms: 3,
        beds: 4,
        bathrooms: 2,
        currency: "VND",
        amenityIds: [],
        images: [],
        availabilityCalendar: [],
        petsAllowed: false,
        instantBookEnabled: false,
        searchText: null,
        aiImageTags: null,
        aiImageSummary: null,
        latitude: 10.345,
        longitude: 107.084,
        ...overrides,
    });

    it("rejects public map searches outside Vung Tau before querying listings", async () => {
        await assert.rejects(
            () => originalGetPublicListings({ lat: 10.7769, lng: 106.7009 }),
            (error: { statusCode?: number; errors?: Array<{ path?: string }> }) => {
                assert.equal(error.statusCode, 422);
                assert.ok(error.errors?.some((item) => item.path === "lat"));
                assert.ok(error.errors?.some((item) => item.path === "lng"));
                return true;
            },
        );
    });

    it("searches q across listing fields, location groups, and amenities before paginating", async () => {
        const originals = {
            listingFind: Listing.find,
            reviewFind: Review.find,
            listingAmenityFindAll: ListingAmenity.findAll,
            listingImageFindAll: ListingImage.findAll,
            availabilityCalendarFindAll: AvailabilityCalendar.findAll,
            bookingFindAll: Booking.findAll,
            amenityFind: Amenity.find,
        };

        try {
            Listing.find = async () => [
                createPublicListingMock(801, { title: "Sunrise villa" }),
                createPublicListingMock(802, {
                    title: "Garden villa",
                    description: "Không gian có karaoke cho nhóm đông",
                }),
                createPublicListingMock(803, {
                    title: "Seaside apartment",
                    addressLine: "12 Tran Phu",
                }),
                createPublicListingMock(804, {
                    title: "Quiet homestay",
                    addressLine: "88 Hoang Hoa Tham",
                }),
                createPublicListingMock(805, {
                    title: "Relax house",
                    amenityIds: [5],
                }),
            ];
            Review.find = () => ({
                lean: async () => [],
            });
            ListingAmenity.findAll = async () => [];
            ListingImage.findAll = async () => [];
            AvailabilityCalendar.findAll = async () => [];
            Booking.findAll = async () => [];
            Amenity.find = () => ({
                lean: async () => [
                    { amenityId: 1, name: "WiFi", active: true, isActive: true },
                    { amenityId: 5, name: "Pool", active: true, isActive: true },
                ],
            });

            const byTitle = await originalGetPublicListings({ q: "sunrise", limit: 10 });
            const byDescription = await originalGetPublicListings({ q: "karaoke", limit: 10 });
            const byAddress = await originalGetPublicListings({ q: "Tran Phu", limit: 10 });
            const byLocationGroup = await originalGetPublicListings({ q: "Bãi Sau", limit: 10 });
            const byAmenity = await originalGetPublicListings({ q: "hồ bơi", limit: 10 });
            const paginated = await originalGetPublicListings({ q: "villa", page: 2, limit: 1 });

            assert.deepEqual(byTitle.items.map((item: { title: string }) => item.title), ["Sunrise villa"]);
            assert.deepEqual(byDescription.items.map((item: { title: string }) => item.title), ["Garden villa"]);
            assert.deepEqual(byAddress.items.map((item: { title: string }) => item.title), ["Seaside apartment"]);
            assert.deepEqual(byLocationGroup.items.map((item: { title: string }) => item.title), ["Quiet homestay"]);
            assert.deepEqual(byAmenity.items.map((item: { title: string }) => item.title), ["Relax house"]);
            assert.equal(paginated.pagination.total, 2);
            assert.equal(paginated.items.length, 1);
            assert.equal(paginated.pagination.page, 2);
        } finally {
            Listing.find = originals.listingFind;
            Review.find = originals.reviewFind;
            ListingAmenity.findAll = originals.listingAmenityFindAll;
            ListingImage.findAll = originals.listingImageFindAll;
            AvailabilityCalendar.findAll = originals.availabilityCalendarFindAll;
            Booking.findAll = originals.bookingFindAll;
            Amenity.find = originals.amenityFind;
        }
    });

    it("treats expired pending payment bookings as non-blocking", async () => {
        const originals = {
            listingFind: Listing.find,
            reviewFind: Review.find,
            listingAmenityFindAll: ListingAmenity.findAll,
            listingImageFindAll: ListingImage.findAll,
            availabilityCalendarFindAll: AvailabilityCalendar.findAll,
            bookingFindAll: Booking.findAll,
        };
        const capturedBookingQueries: SequelizeWhere[] = [];

        try {
            Listing.find = async () => [
                {
                    listingId: 801,
                    title: "Open stay",
                    description: "Available listing",
                    basePrice: 1500000,
                    addressLine: "12 Nguyen Hue",
                    ward: "Ward 1",
                    city: "Vung Tau",
                    district: "District 1",
                    propertyType: "villa",
                    roomType: "entire_place",
                    maxGuests: 6,
                    bedrooms: 3,
                    beds: 4,
                    bathrooms: 2,
                    currency: "VND",
                    amenityIds: [],
                    images: [],
                    availabilityCalendar: [],
                },
            ];
            Review.find = () => ({
                lean: async () => [],
            });
            ListingAmenity.findAll = async () => [];
            ListingImage.findAll = async () => [];
            AvailabilityCalendar.findAll = async () => [];
            Booking.findAll = async (options: { where: SequelizeWhere }) => {
                capturedBookingQueries.push(options.where);
                return [];
            };

            await originalGetPublicListings({
                checkIn: "2026-07-20",
                checkOut: "2026-07-22",
            });

            assert.equal(capturedBookingQueries.length, 1);
            const statusClauses = capturedBookingQueries[0][Op.or] as SequelizeWhere[];
            const pendingPaymentClause = statusClauses.find((clause) => clause.status === "pending_payment");

            if (!pendingPaymentClause) {
                throw new Error("Missing pending payment status clause");
            }
            assert.ok((pendingPaymentClause.lockedUntil as Record<PropertyKey, unknown>)[Op.gt] instanceof Date);
        } finally {
            Listing.find = originals.listingFind;
            Review.find = originals.reviewFind;
            ListingAmenity.findAll = originals.listingAmenityFindAll;
            ListingImage.findAll = originals.listingImageFindAll;
            AvailabilityCalendar.findAll = originals.availabilityCalendarFindAll;
            Booking.findAll = originals.bookingFindAll;
        }
    });

    it("rejects public listing searches with a past check-in date", async () => {
        await assert.rejects(
            () =>
                originalGetPublicListings({
                    checkIn: "2026-06-06",
                    checkOut: "2026-06-08",
                }),
            (error: { statusCode?: number; errors?: Array<{ path?: string; msg?: string }> }) => {
                assert.equal(error.statusCode, 422);
                assert.ok(error.errors?.some((item) => item.path === "checkIn"));
                return true;
            },
        );
    });
});

describe("Vung Tau location group helpers", () => {
    it("matches Vietnamese and non-accented street names to the right groups", () => {
        assert.equal(
            locationGroups.isAddressInLocationGroup("87 Trần Phú, Vũng Tàu", "Trần Phú"),
            true,
        );
        assert.equal(
            locationGroups.isAddressInLocationGroup("87 Tran Phu, Vung Tau", "Bãi Sau"),
            false,
        );
        assert.equal(
            locationGroups.isAddressInLocationGroup("Thuy Van, Vung Tau", "Thùy Vân"),
            true,
        );
        assert.equal(
            locationGroups.isAddressInLocationGroup("C2-09 Hoành Sơn, Rạch Dừa, Vũng Tàu", "Long Cung"),
            true,
        );
        assert.equal(
            locationGroups.isAddressInLocationGroup(
                "Bãi Thủy Tiên, Vũng Tàu",
                "Thủy Tiên",
            ),
            true,
        );
    });

    it("detects location groups from semantic-style queries", () => {
        assert.equal(locationGroups.detectLocationGroupFromQuery("villa bãi sau có hồ bơi"), "Bãi Sau");
        assert.equal(locationGroups.detectLocationGroupFromQuery("căn ở Tran Phu view biển"), "Trần Phú");
        assert.equal(locationGroups.detectLocationGroupFromQuery("villa Hoanh Son có karaoke"), "Long Cung");
        assert.equal(
            locationGroups.detectLocationGroupFromQuery("villa Thuy Tien yên tĩnh"),
            "Thủy Tiên",
        );
    });
});
