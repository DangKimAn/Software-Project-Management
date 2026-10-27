import assert from "node:assert/strict";
import { after, before, beforeEach, describe, it } from "node:test";

import request from "supertest";

import app from "../app";
import { createBooking, createListing, createReview, createUser } from "./helpers/factories";
import { resetTestDatabase, setupTestDatabase, teardownTestDatabase } from "./helpers/test-db";

const createPublishedListing = async (
    input: Parameters<typeof createListing>[1] = {},
) => {
    const host = await createUser({ roles: ["host"] });
    return createListing(host.id, {
        status: "active",
        ...input,
    });
};

before(async () => {
    await setupTestDatabase();
});

beforeEach(async () => {
    await resetTestDatabase();
});

after(async () => {
    await teardownTestDatabase();
});

describe("GET /api/listings", () => {
    it("returns published listings only", async () => {
        await createPublishedListing({ title: "Public villa" });
        const host = await createUser({ roles: ["host"] });
        await createListing(host.id, { status: "draft", title: "Draft villa" });
        await createListing(host.id, { status: "inactive", title: "Hidden villa" });

        const response = await request(app).get("/api/listings");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Public villa");
    });

    it("filters by city", async () => {
        await createPublishedListing({ city: "Vung Tau", title: "Vung Tau stay" });
        await createPublishedListing({ city: "Da Lat", title: "Da Lat stay" });

        const response = await request(app).get("/api/listings?city=Vung%20Tau");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Vung Tau stay");
    });

    it("filters by district", async () => {
        await createPublishedListing({ district: "District 1", title: "District 1 stay" });
        await createPublishedListing({ district: "District 2", title: "District 2 stay" });

        const response = await request(app).get("/api/listings?district=District%202");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "District 2 stay");
    });

    it("filters by guests", async () => {
        await createPublishedListing({ maxGuests: 2, title: "Couple stay" });
        await createPublishedListing({ maxGuests: 6, title: "Family stay" });

        const response = await request(app).get("/api/listings?guests=4");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Family stay");
    });

    it("filters by propertyType", async () => {
        await createPublishedListing({ propertyType: "villa", title: "Villa stay" });
        await createPublishedListing({ propertyType: "apartment", title: "Apartment stay" });

        const response = await request(app).get("/api/listings?propertyType=apartment");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Apartment stay");
    });

    it("filters by roomType", async () => {
        await createPublishedListing({ roomType: "entire_place", title: "Entire place stay" });
        await createPublishedListing({ roomType: "private_room", title: "Private room stay" });

        const response = await request(app).get("/api/listings?roomType=private_room");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Private room stay");
    });

    it("filters by minPrice and maxPrice", async () => {
        await createPublishedListing({ basePrice: 600000, title: "Budget stay" });
        await createPublishedListing({ basePrice: 1800000, title: "Mid stay" });
        await createPublishedListing({ basePrice: 3500000, title: "Luxury stay" });

        const response = await request(app).get("/api/listings?minPrice=1000000&maxPrice=3000000");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Mid stay");
    });

    it("filters by amenities", async () => {
        await createPublishedListing({ title: "Amenity match", amenityIds: [1, 5, 6] });
        await createPublishedListing({ title: "Amenity partial", amenityIds: [1, 5] });

        const response = await request(app).get("/api/listings?amenities=wifi,pool,parking");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Amenity match");
    });

    it("sorts by price ascending", async () => {
        await createPublishedListing({ title: "Expensive", basePrice: 2200000 });
        await createPublishedListing({ title: "Cheap", basePrice: 900000 });

        const response = await request(app).get("/api/listings?sort=price_asc");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items[0].title, "Cheap");
    });

    it("sorts by price descending", async () => {
        await createPublishedListing({ title: "Expensive", basePrice: 2200000 });
        await createPublishedListing({ title: "Cheap", basePrice: 900000 });

        const response = await request(app).get("/api/listings?sort=price_desc");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items[0].title, "Expensive");
    });

    it("sorts by rating descending", async () => {
        const topListing = await createPublishedListing({ title: "Top rated" });
        const lowListing = await createPublishedListing({ title: "Lower rated" });

        await createReview(topListing.listingId, { rating: 5, comment: "Great" });
        await createReview(topListing.listingId, { rating: 4, comment: "Nice" });
        await createReview(lowListing.listingId, { rating: 3, comment: "Okay" });

        const response = await request(app).get("/api/listings?sort=rating_desc");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items[0].title, "Top rated");
        assert.equal(response.body.data.items[0].ratingAvg, 4.5);
    });

    it("supports pagination", async () => {
        await createPublishedListing({ title: "Stay 1" });
        await createPublishedListing({ title: "Stay 2" });
        await createPublishedListing({ title: "Stay 3" });

        const response = await request(app).get("/api/listings?page=2&limit=1");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.pagination.page, 2);
        assert.equal(response.body.data.pagination.limit, 1);
        assert.equal(response.body.data.pagination.total, 3);
        assert.equal(response.body.data.pagination.totalPages, 3);
    });

    it("filters by availability when checkIn and checkOut are provided", async () => {
        await createPublishedListing({
            title: "Blocked stay",
            availabilityCalendar: [
                {
                    date: "2026-04-20",
                    isAvailable: false,
                    isBlockedByHost: true,
                    priceOverride: null,
                    minNightsOverride: null,
                    notes: "Blocked",
                },
            ],
        });
        await createPublishedListing({ title: "Available stay" });

        const response = await request(app).get("/api/listings?checkIn=2026-04-20&checkOut=2026-04-22");

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].title, "Available stay");
        assert.equal(response.body.data.items[0].isAvailable, true);
    });

    it("filters out listings with confirmed overlapping bookings", async () => {
        const bookedListing = await createPublishedListing({ title: "Booked stay" });
        await createBooking({
            listingId: bookedListing.listingId,
            hostUserId: bookedListing.hostId,
            checkInDate: "2026-04-20",
            checkOutDate: "2026-04-22",
            status: "confirmed",
        });
        await createPublishedListing({ title: "Open stay" });

        const response = await request(app).get("/api/listings?checkIn=2026-04-20&checkOut=2026-04-22");

        assert.equal(response.status, 200);
        assert.deepEqual(
            response.body.data.items.map((item: { title: string }) => item.title),
            ["Open stay"],
        );
    });

    it("returns 400 when checkOut is not after checkIn", async () => {
        await createPublishedListing();

        const response = await request(app).get("/api/listings?checkIn=2026-04-20&checkOut=2026-04-20");

        assert.equal(response.status, 400);
    });

    it("returns 422 for invalid query values", async () => {
        const response = await request(app).get("/api/listings?sort=invalid_sort");

        assert.equal(response.status, 422);
    });
});

describe("GET /api/listings/:listingId", () => {
    it("returns public listing detail with amenities and images", async () => {
        const listing = await createPublishedListing({
            title: "Detail stay",
            amenityIds: [1, 5],
            images: [
                {
                    imageId: 1001,
                    url: "https://example.com/detail.jpg",
                    caption: "Front view",
                    sortOrder: 1,
                },
            ],
        });

        const response = await request(app).get(`/api/listings/${listing.listingId}`);

        assert.equal(response.status, 200);
        assert.equal(response.body.data.listingId, listing.listingId);
        assert.equal(response.body.data.amenities.length, 2);
        assert.equal(response.body.data.images.length, 1);
    });

    it("returns 404 when listing does not exist", async () => {
        const response = await request(app).get("/api/listings/9999");

        assert.equal(response.status, 404);
    });

    it("returns 404 for hidden or draft listings", async () => {
        const host = await createUser({ roles: ["host"] });
        const hiddenListing = await createListing(host.id, { status: "inactive" });

        const response = await request(app).get(`/api/listings/${hiddenListing.listingId}`);

        assert.equal(response.status, 404);
    });
});

describe("GET /api/listings/:listingId/availability", () => {
    it("returns availability with default price, overrides, and blocked days", async () => {
        const listing = await createPublishedListing({
            basePrice: 1500000,
            weekendPrice: 1800000,
            availabilityCalendar: [
                {
                    date: "2026-04-20",
                    isAvailable: true,
                    isBlockedByHost: false,
                    priceOverride: 1700000,
                    minNightsOverride: 3,
                    notes: "Festival",
                },
                {
                    date: "2026-04-21",
                    isAvailable: false,
                    isBlockedByHost: true,
                    priceOverride: null,
                    minNightsOverride: null,
                    notes: "Blocked",
                },
            ],
        });

        const response = await request(app).get(`/api/listings/${listing.listingId}/availability?month=4&year=2026`);

        assert.equal(response.status, 200);
        assert.equal(response.body.data.days.length, 30);

        const overrideDay = response.body.data.days.find((item: { date: string }) => item.date === "2026-04-20");
        const blockedDay = response.body.data.days.find((item: { date: string }) => item.date === "2026-04-21");
        const defaultDay = response.body.data.days.find((item: { date: string }) => item.date === "2026-04-22");

        assert.ok(overrideDay);
        assert.equal(overrideDay.price, 1700000);
        assert.equal(overrideDay.isAvailable, true);
        assert.ok(blockedDay);
        assert.equal(blockedDay.isAvailable, false);
        assert.ok(defaultDay);
        assert.equal(defaultDay.price, 1500000);
    });

    it("marks booked days unavailable in public availability", async () => {
        const listing = await createPublishedListing();
        await createBooking({
            listingId: listing.listingId,
            hostUserId: listing.hostId,
            checkInDate: "2026-04-20",
            checkOutDate: "2026-04-22",
            status: "confirmed",
        });

        const response = await request(app).get(`/api/listings/${listing.listingId}/availability?month=4&year=2026`);

        assert.equal(response.status, 200);
        const bookedDay = response.body.data.days.find((item: { date: string }) => item.date === "2026-04-20");
        assert.equal(bookedDay.isAvailable, false);
    });

    it("returns 422 for invalid month/year", async () => {
        const listing = await createPublishedListing();

        const response = await request(app).get(`/api/listings/${listing.listingId}/availability?month=13&year=2026`);

        assert.equal(response.status, 422);
    });

    it("returns 404 when listing is not public", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { status: "draft" });

        const response = await request(app).get(`/api/listings/${listing.listingId}/availability?month=4&year=2026`);

        assert.equal(response.status, 404);
    });
});

describe("GET /api/listings/:listingId/reviews", () => {
    it("returns visible reviews with correct summary", async () => {
        const listing = await createPublishedListing();
        await createReview(listing.listingId, { rating: 5, comment: "Excellent", reviewerName: "Alice" });
        await createReview(listing.listingId, { rating: 4, comment: "Very good", reviewerName: "Bob" });
        await createReview(listing.listingId, { rating: 1, comment: "Hidden", isVisible: false });

        const response = await request(app).get(`/api/listings/${listing.listingId}/reviews`);

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 2);
        assert.equal(response.body.data.summary.avgRating, 4.5);
        assert.equal(response.body.data.summary.reviewCount, 2);
    });

    it("supports review pagination", async () => {
        const listing = await createPublishedListing();
        await createReview(listing.listingId, { rating: 5, comment: "Review 1" });
        await createReview(listing.listingId, { rating: 4, comment: "Review 2" });
        await createReview(listing.listingId, { rating: 3, comment: "Review 3" });

        const response = await request(app).get(`/api/listings/${listing.listingId}/reviews?page=2&limit=1`);

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.pagination.page, 2);
        assert.equal(response.body.data.pagination.total, 3);
    });

    it("filters reviews by rating while preserving overall summary", async () => {
        const listing = await createPublishedListing();
        await createReview(listing.listingId, { rating: 5, comment: "Review 1" });
        await createReview(listing.listingId, { rating: 4, comment: "Review 2" });
        await createReview(listing.listingId, { rating: 5, comment: "Review 3" });

        const response = await request(app).get(`/api/listings/${listing.listingId}/reviews?rating=5`);

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 2);
        assert.ok(response.body.data.items.every((item: { rating: number }) => item.rating === 5));
        assert.equal(response.body.data.summary.avgRating, 4.7);
        assert.equal(response.body.data.summary.reviewCount, 3);
    });

    it("returns 404 when listing does not exist or is not public", async () => {
        const response = await request(app).get("/api/listings/9999/reviews");

        assert.equal(response.status, 404);
    });

    it("returns 422 for invalid review query", async () => {
        const listing = await createPublishedListing();

        const response = await request(app).get(`/api/listings/${listing.listingId}/reviews?rating=6`);

        assert.equal(response.status, 422);
    });
});

describe("GET /api/listings/:listingId/rules", () => {
    it("returns public listing rules", async () => {
        const listing = await createPublishedListing({
            checkInFrom: "15:00",
            checkOutBefore: "11:00",
            smokingAllowed: false,
            petsAllowed: true,
            partyAllowed: false,
            quietHours: "22:00-06:00",
        });

        const response = await request(app).get(`/api/listings/${listing.listingId}/rules`);

        assert.equal(response.status, 200);
        assert.equal(response.body.data.checkInFrom, "15:00");
        assert.equal(response.body.data.checkOutBefore, "11:00");
        assert.equal(response.body.data.smokingAllowed, false);
        assert.equal(response.body.data.petsAllowed, true);
        assert.equal(response.body.data.partyAllowed, false);
        assert.equal(response.body.data.quietHours, "22:00-06:00");
    });

    it("returns 404 when listing does not exist", async () => {
        const response = await request(app).get("/api/listings/9999/rules");

        assert.equal(response.status, 404);
    });
});
