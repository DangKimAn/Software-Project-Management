// CONFLICT-RESOLVED: Giữ bộ kiểm thử hợp nhất `tests/public-listings.test.ts` chuyển từ `src/tests/` và loại bỏ bản trùng `listings-public-subroutes.test.ts`.
const assert = require("node:assert/strict");
const { after, before, beforeEach, describe, it } = require("node:test");
const request = require("supertest");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const Amenity = require("../dist/models/amenity").default;
const AvailabilityCalendar = require("../dist/models/availability-calendar").default;
const Booking = require("../dist/models/booking").default;
const Listing = require("../dist/models/listing").default;
const ListingAmenity = require("../dist/models/listing-amenity").default;
const ListingImage = require("../dist/models/listing-image").default;
const ListingRule = require("../dist/models/listing-rule").default;
const Review = require("../dist/models/review").default;
const User = require("../dist/models/user").default;
const sequelize = require("../dist/config/database").default;

type MockListing = Record<string, unknown> & {
    listingId: number;
    hostId: number;
    title: string;
    description: string;
    status: string;
    deletedAt: Date | null;
    city: string;
    district: string;
    ward: string;
    addressLine: string;
    country: string;
    latitude: number;
    longitude: number;
    propertyType: string;
    roomType: string;
    maxGuests: number;
    bedrooms: number;
    beds: number;
    bathrooms: number;
    basePrice: number;
    weekendPrice: number | null;
    currency: string;
    minNights: number;
    maxNights: number | null;
    checkInFrom: string;
    checkOutBefore: string;
    cancellationPolicy: string;
    instantBookEnabled: boolean;
    smokingAllowed: boolean;
    petsAllowed: boolean;
    partyAllowed: boolean;
    quietHours: string | null;
    amenityIds: number[];
    images: Array<Record<string, unknown>>;
    availabilityCalendar: Array<Record<string, unknown>>;
};

type MockReview = {
    reviewId: number;
    listingId: number;
    rating: number;
    comment: string;
    reviewerName: string;
    hostReply: string | null;
    isVisible: boolean;
    deletedAt: Date | null;
    createdAt: Date;
};

type MockBooking = {
    listingId: number;
    checkInDate: string;
    checkOutDate: string;
    status: string;
};

const listings: MockListing[] = [];
const reviews: MockReview[] = [];
const bookings: MockBooking[] = [];
let nextListingId = 500;
let nextReviewId = 1;

const originals = {
    listingFind: Listing.find,
    listingFindOne: Listing.findOne,
    amenityFind: Amenity.find,
    reviewFind: Review.find,
    bookingFindAll: Booking.findAll,
    listingAmenityFindAll: ListingAmenity.findAll,
    listingImageFindAll: ListingImage.findAll,
    listingRuleFindOne: ListingRule.findOne,
    availabilityCalendarFindAll: AvailabilityCalendar.findAll,
    userFindById: User.findById,
};

const addListing = (overrides: Partial<MockListing> = {}): MockListing => {
    const listingId = overrides.listingId ?? nextListingId++;
    const item: MockListing = {
        listingId,
        hostId: 101,
        title: `Stay ${listingId}`,
        description: "Spacious beachfront stay",
        status: "active",
        deletedAt: null,
        city: "Vung Tau",
        district: "District 1",
        ward: "Ward 2",
        addressLine: "12 Thuy Van",
        country: "VN",
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
        currency: "VND",
        minNights: 1,
        maxNights: 14,
        checkInFrom: "14:00",
        checkOutBefore: "12:00",
        cancellationPolicy: "moderate",
        instantBookEnabled: false,
        smokingAllowed: false,
        petsAllowed: false,
        partyAllowed: false,
        quietHours: null,
        amenityIds: [1],
        images: [],
        availabilityCalendar: [],
        ...overrides,
    };
    listings.push(item);
    return item;
};

before(() => {
    Listing.find = async (filter: Record<string, unknown> = {}) =>
        listings.filter((item) => {
            if (filter.status && item.status !== filter.status) return false;
            if (filter.deletedAt === null && item.deletedAt !== null) return false;
            if (filter.propertyType && item.propertyType !== filter.propertyType) return false;
            if (filter.roomType && item.roomType !== filter.roomType) return false;
            const maxGuests = filter.maxGuests as { $gte?: number } | undefined;
            if (maxGuests?.$gte !== undefined && item.maxGuests < maxGuests.$gte) return false;
            const basePrice = filter.basePrice as { $gte?: number; $lte?: number } | undefined;
            if (basePrice?.$gte !== undefined && item.basePrice < basePrice.$gte) return false;
            if (basePrice?.$lte !== undefined && item.basePrice > basePrice.$lte) return false;
            return true;
        });

    Listing.findOne = async (options: { where?: { listingId?: number; status?: string; deletedAt?: null } } | { listingId?: number; status?: string; deletedAt?: null }) => {
        const where = ("where" in options && options.where ? options.where : options) as {
            listingId?: number;
            status?: string;
            deletedAt?: null;
        };
        return (
            listings.find(
                (item) =>
                    (where.listingId === undefined || item.listingId === Number(where.listingId)) &&
                    (where.status === undefined || item.status === where.status) &&
                    (where.deletedAt === undefined || item.deletedAt === null),
            ) ?? null
        );
    };

    Amenity.find = (filter: { amenityId?: { $in?: number[] } } = {}) => ({
        lean: async () => {
            const catalog = [
                { amenityId: 1, name: "WiFi", icon: "wifi", active: true, isActive: true },
                { amenityId: 5, name: "Pool", icon: "pool", active: true, isActive: true },
                { amenityId: 6, name: "Parking", icon: "parking", active: true, isActive: true },
            ];
            const ids = filter?.amenityId?.$in;
            return ids ? catalog.filter((a) => ids.includes(a.amenityId)) : catalog;
        },
    });

    Review.find = (filter: { listingId?: number | { $in?: number[] }; isVisible?: boolean } = {}) => {
        const matched = reviews.filter((r) => {
            if (filter.isVisible !== undefined && r.isVisible !== filter.isVisible) return false;
            if (typeof filter.listingId === "number") return r.listingId === filter.listingId;
            if (filter.listingId && typeof filter.listingId === "object" && Array.isArray(filter.listingId.$in)) {
                return filter.listingId.$in.includes(r.listingId);
            }
            return true;
        });
        const sorted = [...matched].sort((a, b) => b.reviewId - a.reviewId);
        return {
            sort: () => ({ lean: async () => sorted }),
            lean: async () => sorted,
        };
    };

    Booking.findAll = async () =>
        bookings.filter((b) => b.status === "confirmed");

    ListingAmenity.findAll = async () => [];
    ListingImage.findAll = async () => [];
    ListingRule.findOne = async () => null;
    AvailabilityCalendar.findAll = async () => [];
    User.findById = async () => ({
        id: 101,
        _id: 101,
        firstName: "Host",
        lastName: "Owner",
        avatarUrl: null,
        status: "active",
    });
});

beforeEach(() => {
    listings.length = 0;
    reviews.length = 0;
    bookings.length = 0;
    nextListingId = 500;
    nextReviewId = 1;
});

after(async () => {
    Listing.find = originals.listingFind;
    Listing.findOne = originals.listingFindOne;
    Amenity.find = originals.amenityFind;
    Review.find = originals.reviewFind;
    Booking.findAll = originals.bookingFindAll;
    ListingAmenity.findAll = originals.listingAmenityFindAll;
    ListingImage.findAll = originals.listingImageFindAll;
    ListingRule.findOne = originals.listingRuleFindOne;
    AvailabilityCalendar.findAll = originals.availabilityCalendarFindAll;
    User.findById = originals.userFindById;
    try {
        await sequelize.close();
    } catch {}
});

const app = require("../dist/app").default;

describe("Public listings API end-to-end", () => {
    it("filters published listings by city, district, guests, price, amenities, and sorts results", async () => {
        addListing({ title: "Public villa", amenityIds: [1, 5, 6], basePrice: 1800000, maxGuests: 6 });
        addListing({ title: "Draft villa", status: "draft" });
        addListing({ title: "Cheap apartment", propertyType: "apartment", basePrice: 700000, maxGuests: 2 });

        const filtered = await request(app).get(
            "/api/listings?city=Vung%20Tau&guests=4&minPrice=1000000&maxPrice=2500000&amenities=wifi,pool,parking",
        );
        assert.equal(filtered.status, 200);
        assert.equal(filtered.body.data.items.length, 1);
        assert.equal(filtered.body.data.items[0].title, "Public villa");

        const sortedAsc = await request(app).get("/api/listings?sort=price_asc");
        assert.equal(sortedAsc.status, 200);
        assert.equal(sortedAsc.body.data.items[0].title, "Cheap apartment");
    });

    it("filters by availability and overlapping confirmed bookings on future dates", async () => {
        addListing({
            title: "Blocked stay",
            availabilityCalendar: [
                {
                    date: "2027-04-20",
                    isAvailable: false,
                    isBlockedByHost: true,
                    priceOverride: null,
                    minNightsOverride: null,
                    notes: "Blocked",
                },
            ],
        });
        const booked = addListing({ title: "Booked stay" });
        bookings.push({
            listingId: booked.listingId,
            checkInDate: "2027-04-20",
            checkOutDate: "2027-04-22",
            status: "confirmed",
        });
        addListing({ title: "Open stay" });

        const res = await request(app).get("/api/listings?checkIn=2027-04-20&checkOut=2027-04-22");
        assert.equal(res.status, 200);
        assert.deepEqual(
            res.body.data.items.map((item: { title: string }) => item.title),
            ["Open stay"],
        );
    });

    it("serves public detail, monthly availability, visible reviews summary, and rules", async () => {
        const listing = addListing({
            title: "Detail stay",
            amenityIds: [1, 5],
            petsAllowed: true,
            quietHours: "22:00-06:00",
            images: [{ imageId: 1001, url: "https://example.com/detail.jpg", sortOrder: 1 }],
            availabilityCalendar: [
                {
                    date: "2027-04-20",
                    isAvailable: true,
                    isBlockedByHost: false,
                    priceOverride: 1700000,
                    minNightsOverride: 3,
                    notes: null,
                },
            ],
        });
        reviews.push(
            {
                reviewId: nextReviewId++,
                listingId: listing.listingId,
                rating: 5,
                comment: "Excellent",
                reviewerName: "Alice",
                hostReply: null,
                isVisible: true,
                deletedAt: null,
                createdAt: new Date("2026-05-01T00:00:00.000Z"),
            },
            {
                reviewId: nextReviewId++,
                listingId: listing.listingId,
                rating: 4,
                comment: "Good",
                reviewerName: "Bob",
                hostReply: null,
                isVisible: true,
                deletedAt: null,
                createdAt: new Date("2026-05-02T00:00:00.000Z"),
            },
            {
                reviewId: nextReviewId++,
                listingId: listing.listingId,
                rating: 1,
                comment: "Hidden",
                reviewerName: "Hidden",
                hostReply: null,
                isVisible: false,
                deletedAt: null,
                createdAt: new Date("2026-05-03T00:00:00.000Z"),
            },
        );

        const detail = await request(app).get(`/api/listings/${listing.listingId}`);
        assert.equal(detail.status, 200);
        assert.equal(detail.body.data.amenities.length, 2);

        const availability = await request(app).get(
            `/api/listings/${listing.listingId}/availability?month=4&year=2027`,
        );
        assert.equal(availability.status, 200);
        const day20 = availability.body.data.days.find((d: { date: string }) => d.date === "2027-04-20");
        assert.equal(day20.price, 1700000);

        const reviewRes = await request(app).get(`/api/listings/${listing.listingId}/reviews?rating=5`);
        assert.equal(reviewRes.status, 200);
        assert.equal(reviewRes.body.data.items.length, 1);
        assert.equal(reviewRes.body.data.summary.avgRating, 4.5);

        const rulesRes = await request(app).get(`/api/listings/${listing.listingId}/rules`);
        assert.equal(rulesRes.status, 200);
        assert.equal(rulesRes.body.data.petsAllowed, true);
        assert.equal(rulesRes.body.data.quietHours, "22:00-06:00");
    });
});

export {};

