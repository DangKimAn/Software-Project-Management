import assert from "node:assert/strict";
import { after, before, beforeEach, describe, it } from "node:test";

import request from "supertest";

import app from "../app";
import Listing from "../models/listing";
import { buildAuthHeader } from "./helpers/auth";
import { createBooking, createListing, createUser } from "./helpers/factories";
import { resetTestDatabase, setupTestDatabase, teardownTestDatabase } from "./helpers/test-db";

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
    propertyType: "villa" as const,
    roomType: "entire_place" as const,
    maxGuests: 6,
    bedrooms: 3,
    beds: 4,
    bathrooms: 2,
    basePrice: 1500000,
    weekendPrice: 1800000,
    cleaningFee: 200000,
    serviceFeePct: 10,
    currency: "VND" as const,
    minNights: 2,
    maxNights: 10,
    checkInFrom: "14:00",
    checkOutBefore: "12:00",
    cancellationPolicy: "moderate" as const,
    instantBookEnabled: false,
    amenityIds: [1, 2],
});

before(async () => {
    await setupTestDatabase();
});

beforeEach(async () => {
    await resetTestDatabase();
});

after(async () => {
    await teardownTestDatabase();
});

describe("POST /api/host/listings", () => {
    it("creates a listing for the authenticated host", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(host))
            .send({
                ...createListingPayload(),
                amenityIds: [1, 2, 2],
            });

        assert.equal(response.status, 201);
        assert.equal(response.body.success, true);
        assert.equal(response.body.message, "Listing created");
        assert.equal(response.body.data.status, "draft");
        assert.equal(typeof response.body.data.listingId, "number");

        const listing = await Listing.findOne({ listingId: response.body.data.listingId });
        assert.ok(listing);
        assert.equal(String(listing.hostId), host.id);
        assert.deepEqual(listing.amenityIds, [1, 2]);
    });

    it("rejects non-host users", async () => {
        const guest = await createUser({ roles: ["guest"] });

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(guest))
            .send(createListingPayload());

        assert.equal(response.status, 403);
    });

    it("requires authentication", async () => {
        const response = await request(app).post("/api/host/listings").send(createListingPayload());

        assert.equal(response.status, 401);
    });

    it("returns validation errors for missing required fields", async () => {
        const host = await createUser({ roles: ["host"] });
        const payload = createListingPayload();
        delete (payload as Partial<typeof payload>).title;

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(host))
            .send(payload);

        assert.equal(response.status, 422);
    });

    it("validates latitude and longitude", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(host))
            .send({
                ...createListingPayload(),
                latitude: 100,
            });

        assert.equal(response.status, 422);
    });

    it("rejects coordinates outside Vung Tau", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(host))
            .send({
                ...createListingPayload(),
                latitude: 10.7769,
                longitude: 106.7009,
            });

        assert.equal(response.status, 422);
    });

    it("validates min/max nights relationship", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(host))
            .send({
                ...createListingPayload(),
                minNights: 5,
                maxNights: 3,
            });

        assert.equal(response.status, 422);
    });

    it("validates amenityIds against the amenity catalog", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .post("/api/host/listings")
            .set("Authorization", buildAuthHeader(host))
            .send({
                ...createListingPayload(),
                amenityIds: [999],
            });

        assert.equal(response.status, 422);
    });
});

describe("GET /api/host/listings/mine", () => {
    it("returns only the current host listings and supports pagination", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });

        const firstListing = await createListing(host.id, { title: "Listing A" });
        await createListing(host.id, { title: "Listing B", status: "active" });
        await createListing(otherHost.id, { title: "Listing C", status: "active" });

        const response = await request(app)
            .get("/api/host/listings/mine?page=1&limit=1")
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);
        assert.equal(response.body.data.pagination.total, 2);
        assert.equal(response.body.data.pagination.totalPages, 2);
        assert.equal(response.body.data.items.length, 1);
        assert.notEqual(response.body.data.items[0].listingId, firstListing.listingId + 2);
    });

    it("filters by external status", async () => {
        const host = await createUser({ roles: ["host"] });
        await createListing(host.id, { title: "Draft listing", status: "draft" });
        await createListing(host.id, { title: "Published listing", status: "active" });

        const response = await request(app)
            .get("/api/host/listings/mine?status=published")
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);
        assert.equal(response.body.data.items.length, 1);
        assert.equal(response.body.data.items[0].status, "published");
    });

    it("requires authentication", async () => {
        const response = await request(app).get("/api/host/listings/mine");
        assert.equal(response.status, 401);
    });
});

describe("GET /api/host/listings/:listingId", () => {
    it("returns the owner listing detail, including hidden listings", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { status: "inactive" });

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);
        assert.equal(response.body.data.listingId, listing.listingId);
        assert.equal(response.body.data.status, "hidden");
        assert.equal(response.body.data.hostId, host.id);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .get("/api/host/listings/9999")
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 403);
    });
});

describe("PATCH /api/host/listings/:listingId", () => {
    it("updates listing fields partially", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { title: "Original title", basePrice: 1200000 });

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                title: "Updated title",
                basePrice: 1700000,
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.listingId, listing.listingId);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.ok(updated);
        assert.equal(updated.title, "Updated title");
        assert.equal(updated.basePrice, 1700000);
        assert.equal(updated.description, listing.description);
    });

    it("moves published listings back to pending approval on sensitive edits", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { status: "active", description: "Original" });

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                description: "Updated description",
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.status, "pending_approval");

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.equal(updated?.status, "pending_approval");
    });

    it("prevents invalid host status transitions", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { status: "draft" });

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                status: "published",
            });

        assert.equal(response.status, 422);
    });

    it("returns validation errors for invalid payloads", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                bathrooms: 0,
            });

        assert.equal(response.status, 422);
    });

    it("rejects coordinate updates outside Vung Tau", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                latitude: 10.7769,
                longitude: 106.7009,
            });

        assert.equal(response.status, 422);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .patch("/api/host/listings/9999")
            .set("Authorization", buildAuthHeader(host))
            .send({
                title: "No listing",
            });

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                title: "Hack attempt",
            });

        assert.equal(response.status, 403);
    });

    it("requires authentication", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app).patch(`/api/host/listings/${listing.listingId}`).send({
            title: "No auth",
        });

        assert.equal(response.status, 401);
    });
});

describe("DELETE /api/host/listings/:listingId", () => {
    it("soft deletes the listing", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { status: "active" });

        const response = await request(app)
            .delete(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);
        assert.equal(response.body.message, "Listing deleted");

        const deleted = await Listing.findOne({ listingId: listing.listingId });
        assert.ok(deleted?.deletedAt);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .delete("/api/host/listings/9999")
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .delete(`/api/host/listings/${listing.listingId}`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 403);
    });

    it("requires authentication", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app).delete(`/api/host/listings/${listing.listingId}`);
        assert.equal(response.status, 401);
    });
});

describe("POST /api/host/listings/:listingId/images", () => {
    it("adds multiple images to the listing", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .post(`/api/host/listings/${listing.listingId}/images`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                images: [
                    { url: "https://example.com/living-room.jpg", caption: "Living room", sortOrder: 1 },
                    { url: "https://example.com/bed-room.jpg", caption: "Bed room", sortOrder: 2 },
                ],
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.count, 2);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.equal(updated?.images.length, 2);
    });

    it("validates image URLs", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .post(`/api/host/listings/${listing.listingId}/images`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                images: [{ url: "not-a-url", caption: "Bad", sortOrder: 1 }],
            });

        assert.equal(response.status, 422);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .post("/api/host/listings/9999/images")
            .set("Authorization", buildAuthHeader(host))
            .send({
                images: [{ url: "https://example.com/living-room.jpg", sortOrder: 1 }],
            });

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .post(`/api/host/listings/${listing.listingId}/images`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                images: [{ url: "https://example.com/living-room.jpg", sortOrder: 1 }],
            });

        assert.equal(response.status, 403);
    });

    it("rejects duplicate sort orders", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, {
            images: [
                {
                    imageId: 1001,
                    url: "https://example.com/existing.jpg",
                    caption: "Existing",
                    sortOrder: 1,
                },
            ],
        });

        const response = await request(app)
            .post(`/api/host/listings/${listing.listingId}/images`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                images: [{ url: "https://example.com/new.jpg", sortOrder: 1 }],
            });

        assert.equal(response.status, 422);
    });
});

describe("DELETE /api/host/listings/:listingId/images/:imageId", () => {
    it("deletes a listing image", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, {
            images: [
                {
                    imageId: 1001,
                    url: "https://example.com/existing.jpg",
                    caption: "Existing",
                    sortOrder: 1,
                },
            ],
        });

        const response = await request(app)
            .delete(`/api/host/listings/${listing.listingId}/images/1001`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.equal(updated?.images.length, 0);
    });

    it("returns 404 when the image does not exist", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .delete(`/api/host/listings/${listing.listingId}/images/9999`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 404);
    });

    it("does not delete images from another listing", async () => {
        const host = await createUser({ roles: ["host"] });
        const listingA = await createListing(host.id);
        await createListing(host.id, {
            images: [
                {
                    imageId: 1002,
                    url: "https://example.com/other.jpg",
                    caption: "Other",
                    sortOrder: 1,
                },
            ],
        });

        const response = await request(app)
            .delete(`/api/host/listings/${listingA.listingId}/images/1002`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id, {
            images: [
                {
                    imageId: 1001,
                    url: "https://example.com/existing.jpg",
                    caption: "Existing",
                    sortOrder: 1,
                },
            ],
        });

        const response = await request(app)
            .delete(`/api/host/listings/${listing.listingId}/images/1001`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 403);
    });
});

describe("PUT /api/host/listings/:listingId/amenities", () => {
    it("replaces listing amenities", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { amenityIds: [1, 2] });

        const response = await request(app)
            .put(`/api/host/listings/${listing.listingId}/amenities`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                amenityIds: [2, 3, 3, 4],
            });

        assert.equal(response.status, 200);
        assert.equal(response.body.data.amenityCount, 3);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.deepEqual(updated?.amenityIds, [2, 3, 4]);
    });

    it("clears amenities with an empty array", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { amenityIds: [1, 2] });

        const response = await request(app)
            .put(`/api/host/listings/${listing.listingId}/amenities`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                amenityIds: [],
            });

        assert.equal(response.status, 200);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.deepEqual(updated?.amenityIds, []);
    });

    it("validates amenity ids", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .put(`/api/host/listings/${listing.listingId}/amenities`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                amenityIds: [999],
            });

        assert.equal(response.status, 422);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .put("/api/host/listings/9999/amenities")
            .set("Authorization", buildAuthHeader(host))
            .send({
                amenityIds: [1],
            });

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .put(`/api/host/listings/${listing.listingId}/amenities`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                amenityIds: [1],
            });

        assert.equal(response.status, 403);
    });
});

describe("PATCH /api/host/listings/:listingId/rules", () => {
    it("updates check-in and check-out rules", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/rules`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                checkInFrom: "15:00",
                checkOutBefore: "11:00",
            });

        assert.equal(response.status, 200);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.equal(updated?.checkInFrom, "15:00");
        assert.equal(updated?.checkOutBefore, "11:00");
    });

    it("updates boolean rules and quiet hours", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/rules`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                smokingAllowed: true,
                petsAllowed: true,
                partyAllowed: false,
                quietHours: "22:00-06:00",
            });

        assert.equal(response.status, 200);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.equal(updated?.smokingAllowed, true);
        assert.equal(updated?.petsAllowed, true);
        assert.equal(updated?.partyAllowed, false);
        assert.equal(updated?.quietHours, "22:00-06:00");
    });

    it("validates time format", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/rules`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                checkInFrom: "25:00",
            });

        assert.equal(response.status, 422);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .patch("/api/host/listings/9999/rules")
            .set("Authorization", buildAuthHeader(host))
            .send({
                quietHours: "22:00-06:00",
            });

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/rules`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                quietHours: "22:00-06:00",
            });

        assert.equal(response.status, 403);
    });
});

describe("GET /api/host/listings/:listingId/calendar", () => {
    it("returns a full calendar month including overrides", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, {
            availabilityCalendar: [
                {
                    date: "2026-04-20",
                    isAvailable: true,
                    isBlockedByHost: false,
                    priceOverride: 1700000,
                    minNightsOverride: 3,
                    notes: "Festival weekend",
                },
            ],
        });

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=4&year=2026`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);
        assert.equal(response.body.data.days.length, 30);

        const overriddenDay = response.body.data.days.find((item: { date: string }) => item.date === "2026-04-20");
        const defaultDay = response.body.data.days.find((item: { date: string }) => item.date === "2026-04-21");

        assert.ok(overriddenDay);
        assert.equal(overriddenDay.priceOverride, 1700000);
        assert.equal(overriddenDay.minNightsOverride, 3);
        assert.equal(defaultDay.priceOverride, null);
    });

    it("validates month and year", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=13&year=2026`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 422);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .get("/api/host/listings/9999/calendar?month=4&year=2026")
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=4&year=2026`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 403);
    });
});

describe("PATCH /api/host/listings/:listingId/calendar/bulk", () => {
    it("upserts multiple dates and applies host block logic", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2026-04-20", "2026-04-21"],
                isBlockedByHost: true,
                priceOverride: 1700000,
                minNightsOverride: 2,
                notes: "Owner block",
            });

        assert.equal(response.status, 200);
        assert.deepEqual(response.body.data.updatedDates, ["2026-04-20", "2026-04-21"]);

        const updated = await Listing.findOne({ listingId: listing.listingId });
        assert.equal(updated?.availabilityCalendar.length, 2);
        assert.ok(
            updated?.availabilityCalendar.every(
                (item: { isBlockedByHost: boolean; isAvailable: boolean }) => item.isBlockedByHost && item.isAvailable === false,
            ),
        );
    });

    it("does not close dates with pending payment bookings", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);
        await createBooking({
            listingId: listing.listingId,
            hostUserId: Number(host.id),
            checkInDate: "2026-04-20",
            checkOutDate: "2026-04-22",
            status: "pending_payment",
        });

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2026-04-20"],
                isAvailable: false,
            });

        assert.equal(response.status, 409);
    });

    it("validates the date list", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2026-04-99"],
                isAvailable: true,
            });

        assert.equal(response.status, 422);
    });

    it("validates override values", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2026-04-20"],
                minNightsOverride: 0,
            });

        assert.equal(response.status, 422);
    });

    it("returns 404 for missing listings", async () => {
        const host = await createUser({ roles: ["host"] });

        const response = await request(app)
            .patch("/api/host/listings/9999/calendar/bulk")
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2026-04-20"],
                isAvailable: false,
            });

        assert.equal(response.status, 404);
    });

    it("returns 403 for listings owned by another host", async () => {
        const host = await createUser({ roles: ["host"] });
        const otherHost = await createUser({ roles: ["host"] });
        const listing = await createListing(otherHost.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2026-04-20"],
                isAvailable: false,
            });

        assert.equal(response.status, 403);
    });
});

describe("PATCH /api/host/listings/:listingId/calendar/bulk — past-date rejection", () => {
    it("rejects requests containing past dates", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2020-01-01"],
                isAvailable: true,
            });

        assert.equal(response.status, 422);
        assert.ok(response.body.message.includes("past"));
    });

    it("rejects entire request when mixing past and future dates", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const futureDate = "2028-06-15";
        const pastDate = "2020-01-01";

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: [pastDate, futureDate],
                isAvailable: false,
            });

        assert.equal(response.status, 422);

        // Verify the future date was NOT updated either (entire request rejected)
        const calendarResponse = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=6&year=2028`)
            .set("Authorization", buildAuthHeader(host));

        const futureDay = calendarResponse.body.data.days.find((d: { date: string }) => d.date === futureDate);
        assert.equal(futureDay.isAvailable, true);
    });

    it("allows updating today's date when no active booking exists", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const now = new Date();
        const todayVN = new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: [todayVN],
                isAvailable: false,
                isBlockedByHost: true,
            });

        assert.equal(response.status, 200);
    });

    it("allows updating a future date", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .patch(`/api/host/listings/${listing.listingId}/calendar/bulk`)
            .set("Authorization", buildAuthHeader(host))
            .send({
                dates: ["2028-12-25"],
                isAvailable: false,
                isBlockedByHost: true,
            });

        assert.equal(response.status, 200);
        assert.deepEqual(response.body.data.updatedDates, ["2028-12-25"]);
    });
});

describe("GET /api/host/listings/:listingId/calendar — isPast and canEdit", () => {
    it("returns isPast=true and canEdit=false for past dates", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=1&year=2020`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);

        for (const day of response.body.data.days) {
            assert.equal(day.isPast, true, `${day.date} should be past`);
            assert.equal(day.canEdit, false, `${day.date} should not be editable`);
        }
    });

    it("returns price and minNights for each day", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id, { basePrice: 1500000, minNights: 2 });

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=6&year=2028`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);

        const day = response.body.data.days[0];
        assert.ok(day.price > 0, "price should be > 0");
        assert.ok(day.minNights >= 1, "minNights should be >= 1");
        assert.ok(day.defaultPrice > 0, "defaultPrice should be > 0");
        assert.ok(day.defaultMinNights >= 1, "defaultMinNights should be >= 1");
    });

    it("returns month and year in the response", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=6&year=2028`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);
        assert.equal(response.body.data.month, 6);
        assert.equal(response.body.data.year, 2028);
    });

    it("marks booked future dates as canEdit=false", async () => {
        const host = await createUser({ roles: ["host"] });
        const listing = await createListing(host.id);
        await createBooking({
            listingId: listing.listingId,
            hostUserId: Number(host.id),
            checkInDate: "2028-06-15",
            checkOutDate: "2028-06-17",
            status: "confirmed",
        });

        const response = await request(app)
            .get(`/api/host/listings/${listing.listingId}/calendar?month=6&year=2028`)
            .set("Authorization", buildAuthHeader(host));

        assert.equal(response.status, 200);

        const bookedDay = response.body.data.days.find((d: { date: string }) => d.date === "2028-06-15");
        assert.equal(bookedDay.isBooked, true);
        assert.equal(bookedDay.isPast, false);
        assert.equal(bookedDay.canEdit, false);

        const normalDay = response.body.data.days.find((d: { date: string }) => d.date === "2028-06-20");
        assert.equal(normalDay.isBooked, false);
        assert.equal(normalDay.isPast, false);
        assert.equal(normalDay.canEdit, true);
    });
});
