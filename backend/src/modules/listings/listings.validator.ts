import { z } from "zod";

import { isValidLocationGroup } from "../../common/vung-tau-location-groups";

export const listingIdParamSchema = z.object({
    listingId: z.coerce.number().int().positive(),
});

export const publicListingsQuerySchema = z.object({
    q: z.string().trim().min(1).max(255).optional(),
    city: z.string().trim().min(1).optional(),
    district: z.string().trim().min(1).optional(),
    checkIn: z.string().optional(),
    checkOut: z.string().optional(),
    guests: z.coerce.number().int().positive().optional(),
    propertyType: z.enum(["apartment", "villa", "hotel", "homestay"]).optional(),
    roomType: z.enum(["entire_place", "private_room", "shared_room"]).optional(),
    priceMin: z.coerce.number().min(0).optional(),
    priceMax: z.coerce.number().min(0).optional(),
    minPrice: z.coerce.number().min(0).optional(),
    maxPrice: z.coerce.number().min(0).optional(),
    amenities: z.string().trim().min(1).optional(),
    locationGroup: z.string().trim().refine(isValidLocationGroup, "locationGroup is invalid").optional(),
    lat: z.coerce.number().min(-90).max(90).optional(),
    lng: z.coerce.number().min(-180).max(180).optional(),
    radius: z.coerce.number().min(1).max(10000).optional(),
    sort: z.enum(["price_asc", "price_desc", "rating_desc", "newest", "relevance"]).optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
});
