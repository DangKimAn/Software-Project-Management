import { Op } from "sequelize";

import { ApiError } from "../../common/api-error";
import { buildActiveBookingStatusWhere, buildBookingDateOverlapWhere } from "../../common/booking-availability";
import { getTodayInVietnamDateString } from "../../common/date-time";
import {
    getAvailabilityCalendarForListing,
    getAvailabilityCalendarMap,
    getListingAmenityIdsForListing,
    getListingAmenityIdsMap,
    getListingImagesForListing,
    getListingImagesMap,
    getListingRulesForListing,
} from "../../common/listing-relations";
import { getCoverImage, getDefaultDailyPrice, serializeListingImage } from "../../common/listing-mappers";
import { sanitizeSingleLineText, sanitizeText } from "../../common/sanitization";
import { isValidIsoDate } from "../../common/validation";
import {
    detectLocationGroupsFromQuery,
    getDistanceMeters,
    isCoordinateInVungTauBounds,
    isAddressInLocationGroup,
    isValidLatitude,
    isValidLocationGroup,
    isValidLongitude,
    VUNG_TAU_LOCATION_GROUP_NAMES,
    type LocationGroupName,
} from "../../common/vung-tau-location-groups";
import Amenity from "../../models/amenity";
import Booking from "../../models/booking";
import Listing, {
    ListingAvailabilityDayRecord,
    ListingDocument,
    PropertyType,
    RoomType,
} from "../../models/listing";
import Review from "../../models/review";
import User from "../../models/user";

export const publicListingSortValues = [
    "price_asc",
    "price_desc",
    "rating_desc",
    "newest",
    "relevance",
] as const;
export type PublicListingSort = (typeof publicListingSortValues)[number];
export const publicListingsMaxPageLimit = 50;
const defaultBusinessCity = "Vung Tau";

export type PublicListingsQuery = {
    q?: string;
    city?: string;
    district?: string;
    checkIn?: string;
    checkOut?: string;
    guests?: number;
    propertyType?: PropertyType;
    roomType?: RoomType;
    priceMin?: number;
    priceMax?: number;
    minPrice?: number;
    maxPrice?: number;
    amenities?: string;
    locationGroup?: LocationGroupName;
    lat?: number;
    lng?: number;
    radius?: number;
    sort?: PublicListingSort;
    page?: number;
    limit?: number;
};

export type PublicListingAvailabilityQuery = {
    month?: number;
    year?: number;
};

export type PublicListingReviewsQuery = {
    page?: number;
    limit?: number;
    rating?: number;
};

type ReviewSummary = {
    avgRating: number;
    reviewCount: number;
};

type ReviewSummaryMap = Map<number, ReviewSummary>;

type PublicListingSearchItem = {
    listingId: number;
    title: string;
    description: string;
    basePrice: number;
    ratingAvg: number;
    reviewCount: number;
    isAvailable: boolean;
    addressLine: string;
    ward: string;
    city: string;
    district: string;
    propertyType: PropertyType;
    roomType: RoomType;
    maxGuests: number;
    bedrooms: number;
    beds: number;
    bathrooms: number;
    currency: string;
    imageUrl: string | null;
    coverImage: ReturnType<typeof serializeListingImage> | null;
    images: ReturnType<typeof serializeListingImage>[];
    distanceMeters?: number;
};

type AmenityLookup = {
    amenities: Array<{
        amenityId: number;
        name: string;
        active: boolean;
        isActive: boolean;
    }>;
    aliasMap: Map<string, number>;
    searchTermsById: Map<number, string[]>;
};

type ResolvedAmenityFilters = {
    amenityIds: number[];
    textTokens: string[];
};

const normalizeComparableText = (value: string) =>
    value
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, " ")
        .replace(/\s+/g, " ");

const normalizeAmenityToken = (value: string) =>
    value
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, "");

const compareStrings = (left: string, right: string) => normalizeComparableText(left) === normalizeComparableText(right);

const getQueryTokens = (value: string) => normalizeComparableText(value).split(" ").filter(Boolean);

const parsePagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(publicListingsMaxPageLimit, Math.max(1, limit ?? 10)),
});

const defaultMapSearchRadiusMeters = 800;
const maxMapSearchRadiusMeters = 10000;

const buildSearchableListingAddress = (listing: ListingDocument) =>
    [
        listing.addressLine,
        listing.ward,
        listing.district,
        listing.city,
        listing.stateRegion ?? "",
    ]
        .filter(Boolean)
        .join(" ");

const getListingLocationGroupNames = (listing: ListingDocument) => {
    const address = buildSearchableListingAddress(listing);

    return VUNG_TAU_LOCATION_GROUP_NAMES.filter((groupName) => isAddressInLocationGroup(address, groupName));
};

const getListingLocationSearchTerms = (listing: ListingDocument) => {
    const locationGroups = getListingLocationGroupNames(listing);
    const nearBeachGroups = new Set<LocationGroupName>([
        "Bãi Sau",
        "Bãi Trước",
        "Long Cung",
        "Thủy Tiên",
        "Trần Phú",
        "Thùy Vân",
    ]);

    return [
        ...locationGroups,
        locationGroups.some((groupName) => nearBeachGroups.has(groupName)) ? "Gần biển gan bien beach biển" : "",
    ];
};

const getListingAmenitySearchTerms = (amenityIds: number[], amenityLookup?: AmenityLookup) => {
    if (!amenityLookup) {
        return [];
    }

    return Array.from(
        new Set(
            amenityIds.flatMap((amenityId) => amenityLookup.searchTermsById.get(amenityId) ?? []),
        ),
    );
};

const buildListingKeywordSearchText = (
    listing: ListingDocument,
    listingAmenityIds: number[],
    amenityLookup?: AmenityLookup,
) =>
    [
        listing.title,
        listing.description,
        buildSearchableListingAddress(listing),
        listing.searchText ?? "",
        listing.aiImageSummary ?? "",
        ...(Array.isArray(listing.aiImageTags) ? listing.aiImageTags : []),
        ...getListingLocationSearchTerms(listing),
        ...getListingAmenitySearchTerms(listingAmenityIds, amenityLookup),
        listing.petsAllowed ? "Cho mang thú cưng pets allowed pet friendly petfriendly chó mèo" : "",
        listing.instantBookEnabled ? "Tự check-in self check in nhận phòng nhanh selfcheckin" : "",
    ]
        .filter(Boolean)
        .join(" ");

const matchesKeywordQuery = (
    listing: ListingDocument,
    listingAmenityIds: number[],
    rawQuery?: string,
    amenityLookup?: AmenityLookup,
) => {
    const normalizedQuery = normalizeComparableText(rawQuery ?? "");

    if (!normalizedQuery) {
        return true;
    }

    const searchableText = buildListingKeywordSearchText(listing, listingAmenityIds, amenityLookup);
    const normalizedSearchText = normalizeComparableText(searchableText);
    const queryTokens = getQueryTokens(rawQuery ?? "");

    if (normalizedSearchText.includes(normalizedQuery)) {
        return true;
    }

    if (queryTokens.length > 0 && queryTokens.every((token) => normalizedSearchText.includes(token))) {
        return true;
    }

    const detectedLocationGroups = detectLocationGroupsFromQuery(rawQuery ?? "");
    if (detectedLocationGroups.length === 0) {
        return false;
    }

    const address = buildSearchableListingAddress(listing);
    return detectedLocationGroups.some((groupName) => isAddressInLocationGroup(address, groupName));
};

const matchesAmenityTextToken = (
    listing: ListingDocument,
    listingAmenityIds: number[],
    textToken: string,
    amenityLookup?: AmenityLookup,
) => {
    if (!textToken) {
        return true;
    }

    const searchableText = buildListingKeywordSearchText(listing, listingAmenityIds, amenityLookup);
    const normalizedText = normalizeComparableText(searchableText);
    const compactText = normalizeAmenityToken(searchableText);

    if (textToken === "nearbeach" || textToken === "ganbien") {
        return normalizedText.includes("bien") || 
               normalizedText.includes("beach") || 
               normalizedText.includes("bai sau") || 
               normalizedText.includes("thuy van") || 
               normalizedText.includes("long cung") || 
               normalizedText.includes("tran phu");
    }

    if (textToken === "bbq") {
        return normalizedText.includes("bbq") || normalizedText.includes("nuong");
    }

    if (textToken === "niceview" || textToken === "viewdep") {
        return normalizedText.includes("view dep") || normalizedText.includes("view bien") || normalizedText.includes("sea view") || normalizedText.includes("ocean view");
    }

    return normalizedText.includes(normalizeComparableText(textToken)) || compactText.includes(textToken);
};

const hasValidListingCoordinates = (listing: ListingDocument) =>
    isValidLatitude(Number(listing.latitude)) && isValidLongitude(Number(listing.longitude));

const resolveMapSearchInput = (query: PublicListingsQuery) => {
    if (query.lat === undefined && query.lng === undefined) {
        return null;
    }

    if (query.lat === undefined || query.lng === undefined) {
        return null;
    }

    if (!isValidLatitude(query.lat) || !isValidLongitude(query.lng)) {
        throw new ApiError(422, "Validation error", [
            {
                path: !isValidLatitude(query.lat) ? "lat" : "lng",
                msg: "lat/lng is invalid",
            },
        ]);
    }

    if (!isCoordinateInVungTauBounds(query.lat, query.lng)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "lat",
                msg: "map search location must be inside Vung Tau",
            },
            {
                path: "lng",
                msg: "map search location must be inside Vung Tau",
            },
        ]);
    }

    const radius = Math.min(
        maxMapSearchRadiusMeters,
        Math.max(1, query.radius ?? defaultMapSearchRadiusMeters),
    );

    return {
        lat: query.lat,
        lng: query.lng,
        radius,
    };
};

const validatePublicListingDateRange = (query: PublicListingsQuery) => {
    if ((query.checkIn && !query.checkOut) || (!query.checkIn && query.checkOut)) {
        throw new ApiError(422, "Validation error", [
            {
                path: !query.checkIn ? "checkIn" : "checkOut",
                msg: "checkIn and checkOut must be provided together",
            },
        ]);
    }

    if (!query.checkIn || !query.checkOut) {
        return;
    }

    if (!isValidIsoDate(query.checkIn) || !isValidIsoDate(query.checkOut)) {
        throw new ApiError(422, "Validation error", [
            ...(!isValidIsoDate(query.checkIn)
                ? [{ path: "checkIn", msg: "checkIn must use YYYY-MM-DD format" }]
                : []),
            ...(!isValidIsoDate(query.checkOut)
                ? [{ path: "checkOut", msg: "checkOut must use YYYY-MM-DD format" }]
                : []),
        ]);
    }

    if (query.checkIn < getTodayInVietnamDateString()) {
        throw new ApiError(422, "Không thể tìm phòng cho ngày trong quá khứ.", [
            {
                path: "checkIn",
                msg: "checkIn must not be in the past",
            },
        ]);
    }

    if (query.checkOut <= query.checkIn) {
        throw new ApiError(422, "Validation error", [
            {
                path: "checkOut",
                msg: "checkOut must be after checkIn",
            },
        ]);
    }
};

const getPublicListingOrThrow = async (listingId: number) => {
    const listing = await Listing.findOne({
        listingId,
        status: "active",
        deletedAt: null,
    });

    if (!listing) {
        throw new ApiError(404, "Listing not found");
    }

    return listing;
};

const listInclusiveDates = (checkIn: string, checkOut: string) => {
    const dates: string[] = [];
    const cursor = new Date(`${checkIn}T00:00:00.000Z`);
    const end = new Date(`${checkOut}T00:00:00.000Z`);

    while (cursor < end) {
        dates.push(cursor.toISOString().slice(0, 10));
        cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    return dates;
};

const isDateRangeAvailable = (
    calendarRows: ListingAvailabilityDayRecord[],
    checkIn: string,
    checkOut: string,
) => {
    const availabilityByDate = new Map(calendarRows.map((item) => [item.date, item] as const));

    return listInclusiveDates(checkIn, checkOut).every((date) => {
        const day = availabilityByDate.get(date);

        if (!day) {
            return true;
        }

        return !day.isBlockedByHost && day.isAvailable;
    });
};

const buildAmenityLookup = async (): Promise<AmenityLookup> => {
    const amenities = (await Amenity.find({
        active: true,
        isActive: true,
        deletedAt: null,
    }).lean()) as Array<{
        amenityId: number;
        name: string;
        active: boolean;
        isActive: boolean;
    }>;
    const aliasMap = new Map<string, number>();
    const searchTermsById = new Map<number, Set<string>>();

    const addAlias = (value: string, amenityId: number) => {
        aliasMap.set(normalizeAmenityToken(value), amenityId);

        const terms = searchTermsById.get(amenityId) ?? new Set<string>();
        terms.add(value);
        searchTermsById.set(amenityId, terms);
    };

    for (const amenity of amenities) {
        addAlias(amenity.name, amenity.amenityId);
    }

    [
        ["wifi", 1],
        ["wi-fi", 1],
        ["air conditioning", 2],
        ["airconditioning", 2],
        ["điều hòa", 2],
        ["dieu hoa", 2],
        ["máy lạnh", 2],
        ["washer", 3],
        ["máy giặt", 3],
        ["may giat", 3],
        ["kitchen", 4],
        ["bếp", 4],
        ["bep", 4],
        ["pool", 5],
        ["hồ bơi", 5],
        ["ho boi", 5],
        ["swimming pool", 5],
        ["parking", 6],
        ["chỗ đậu xe", 6],
        ["cho dau xe", 6],
        ["đậu xe", 6],
        ["dau xe", 6],
        ["đỗ xe", 6],
        ["bãi xe", 6],
        ["gara", 6],
        ["tv", 7],
        ["television", 7],
        ["balcony", 8],
        ["ban công", 8],
        ["ban cong", 8],
        ["fireplace", 9],
        ["fridge", 10],
        ["refrigerator", 10],
        ["tủ lạnh", 10],
        ["tu lanh", 10],
        ["hair dryer", 11],
        ["hairdryer", 11],
        ["máy sấy tóc", 11],
        ["may say toc", 11],
        ["iron", 12],
        ["bàn ủi", 12],
        ["ban ui", 12],
    ].forEach(([value, amenityId]) => addAlias(String(value), Number(amenityId)));

    return {
        amenities,
        aliasMap,
        searchTermsById: new Map(
            Array.from(searchTermsById.entries()).map(([amenityId, terms]) => [amenityId, Array.from(terms)]),
        ),
    };
};

const resolveAmenityFilters = async (
    amenitiesQuery?: string,
    amenityLookup?: AmenityLookup,
): Promise<ResolvedAmenityFilters | undefined> => {
    if (!amenitiesQuery) {
        return undefined;
    }

    const requestedTokens = Array.from(
        new Set(
            amenitiesQuery
                .split(",")
                .map((item) => normalizeAmenityToken(item))
                .filter(Boolean),
        ),
    );

    if (requestedTokens.length === 0) {
        return undefined;
    }

    const { aliasMap } = amenityLookup ?? (await buildAmenityLookup());
    const amenityIds: number[] = [];
    const textTokens: string[] = [];

    for (const token of requestedTokens) {
        const amenityId = aliasMap.get(token);

        if (amenityId === undefined) {
            textTokens.push(token);
            continue;
        }

        amenityIds.push(amenityId);
    }

    return {
        amenityIds: Array.from(new Set(amenityIds)),
        textTokens,
    };
};

const getReviewSummaryMap = async (listingIds: number[]): Promise<ReviewSummaryMap> => {
    if (listingIds.length === 0) {
        return new Map();
    }

    const visibleReviews = (await Review.find({
        listingId: { $in: listingIds },
        isVisible: true,
        deletedAt: null,
    }).lean()) as Array<{
        listingId: number;
        rating: number;
    }>;

    const summaryByListing = new Map<number, { ratingSum: number; reviewCount: number }>();

    for (const review of visibleReviews) {
        const current = summaryByListing.get(review.listingId) ?? {
            ratingSum: 0,
            reviewCount: 0,
        };

        current.ratingSum += review.rating;
        current.reviewCount += 1;
        summaryByListing.set(review.listingId, current);
    }

    return new Map(
        Array.from(summaryByListing.entries()).map(([listingId, summary]) => [
            listingId,
            {
                avgRating: Number((summary.ratingSum / summary.reviewCount).toFixed(1)),
                reviewCount: summary.reviewCount,
            },
        ]),
    );
};

const getAmenityDetails = async (amenityIds: number[]) => {
    if (amenityIds.length === 0) {
        return [];
    }

    const amenities = (await Amenity.find({
        amenityId: { $in: amenityIds },
        active: true,
        isActive: true,
        deletedAt: null,
    }).lean()) as Array<{
        amenityId: number;
        name: string;
        icon?: string | null;
        active: boolean;
    }>;
    const amenityById = new Map(amenities.map((amenity) => [amenity.amenityId, amenity]));

    return amenityIds
        .map((amenityId) => amenityById.get(amenityId))
        .filter((amenity): amenity is NonNullable<typeof amenity> => Boolean(amenity))
        .map((amenity) => ({
            amenityId: amenity.amenityId,
            name: amenity.name,
            icon: amenity.icon ?? null,
        }));
};

const getListingReviewSummary = async (listingId: number) => {
    const summaryMap = await getReviewSummaryMap([listingId]);

    return (
        summaryMap.get(listingId) ?? {
            avgRating: 0,
            reviewCount: 0,
        }
    );
};

const getBookedListingIdsForRange = async (listingIds: number[], checkIn?: string, checkOut?: string) => {
    if (!checkIn || !checkOut || listingIds.length === 0) {
        return new Set<number>();
    }

    const bookings = await Booking.findAll({
        where: {
            listingId: {
                [Op.in]: listingIds,
            },
            ...buildActiveBookingStatusWhere(),
            ...buildBookingDateOverlapWhere(checkIn, checkOut),
        },
        attributes: ["listingId"],
    });

    return new Set(bookings.map((booking) => booking.listingId));
};

const getBookedDatesForMonth = async (listingId: number, month: number, year: number) => {
    const start = `${year}-${String(month).padStart(2, "0")}-01`;
    const nextMonth = month === 12 ? 1 : month + 1;
    const nextYear = month === 12 ? year + 1 : year;
    const end = `${nextYear}-${String(nextMonth).padStart(2, "0")}-01`;

    const bookings = await Booking.findAll({
        where: {
            listingId,
            ...buildActiveBookingStatusWhere(),
            ...buildBookingDateOverlapWhere(start, end),
        },
    });

    const bookedDates = new Set<string>();

    for (const booking of bookings) {
        for (const date of listInclusiveDates(
            booking.checkInDate > start ? booking.checkInDate : start,
            booking.checkOutDate < end ? booking.checkOutDate : end,
        )) {
            bookedDates.add(date);
        }
    }

    return bookedDates;
};

export const getPublicListings = async (query: PublicListingsQuery) => {
    const { page, limit } = parsePagination(query.page, query.limit);
    validatePublicListingDateRange(query);
    const mapSearch = resolveMapSearchInput(query);
    const distanceByListingId = new Map<number, number>();
    const effectiveCity = query.city ?? defaultBusinessCity;
    const priceMin = query.priceMin ?? query.minPrice;
    const priceMax = query.priceMax ?? query.maxPrice;
    const shouldUseAmenityLookup = Boolean(query.q?.trim() || query.amenities?.trim());

    if (priceMin !== undefined && priceMax !== undefined && priceMin > priceMax) {
        throw new ApiError(422, "Validation error", [
            {
                path: "priceMax",
                msg: "priceMax must be greater than or equal to priceMin",
            },
        ]);
    }

    if (query.locationGroup && !isValidLocationGroup(query.locationGroup)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "locationGroup",
                msg: "locationGroup is invalid",
            },
        ]);
    }

    const publicFilter: {
        status: "active";
        deletedAt: null;
        propertyType?: PropertyType;
        roomType?: RoomType;
        maxGuests?: { $gte: number };
        basePrice?: { $gte?: number; $lte?: number };
    } = {
        status: "active",
        deletedAt: null,
    };

    if (query.propertyType) publicFilter.propertyType = query.propertyType;
    if (query.roomType) publicFilter.roomType = query.roomType;
    if (query.guests !== undefined) publicFilter.maxGuests = { $gte: query.guests };

    if (priceMin !== undefined || priceMax !== undefined) {
        publicFilter.basePrice = {};
        if (priceMin !== undefined) publicFilter.basePrice.$gte = priceMin;
        if (priceMax !== undefined) publicFilter.basePrice.$lte = priceMax;
    }

    const amenityLookup = shouldUseAmenityLookup ? await buildAmenityLookup() : undefined;
    const amenityFilters = await resolveAmenityFilters(query.amenities, amenityLookup);
    const listings = await Listing.find(publicFilter);
    const listingIds = listings.map((listing) => listing.listingId);
    const [reviewSummaryMap, amenityIdsMap, imageMap, availabilityMap, bookedListingIds] = await Promise.all([
        getReviewSummaryMap(listingIds),
        getListingAmenityIdsMap(listings),
        getListingImagesMap(listings),
        getAvailabilityCalendarMap(listings),
        getBookedListingIdsForRange(listingIds, query.checkIn, query.checkOut),
    ]);

    const filteredListings = listings.filter((listing) => {
        if (effectiveCity && !compareStrings(listing.city, effectiveCity)) {
            return false;
        }

        if (query.district && !compareStrings(listing.district, query.district)) {
            return false;
        }

        if (
            query.locationGroup &&
            !isAddressInLocationGroup(buildSearchableListingAddress(listing), query.locationGroup)
        ) {
            return false;
        }

        if (mapSearch) {
            if (!hasValidListingCoordinates(listing)) {
                return false;
            }

            const distanceMeters = getDistanceMeters(
                mapSearch.lat,
                mapSearch.lng,
                Number(listing.latitude),
                Number(listing.longitude),
            );

            if (distanceMeters > mapSearch.radius) {
                return false;
            }

            distanceByListingId.set(listing.listingId, Math.round(distanceMeters));
        }

        const listingAmenityIds = amenityIdsMap.get(listing.listingId) ?? [];

        if (amenityFilters) {
            const hasAllAmenityIds = amenityFilters.amenityIds.every((amenityId) => {
                if (listingAmenityIds.includes(amenityId)) return true;
                
                // Fallback to text match if relation is missing
                const terms = amenityLookup?.searchTermsById.get(amenityId) ?? [];
                return terms.some(term => matchesAmenityTextToken(listing, listingAmenityIds, term, amenityLookup));
            });

            if (!hasAllAmenityIds) return false;

            const hasAllTextTokens = amenityFilters.textTokens.every((token) =>
                matchesAmenityTextToken(listing, listingAmenityIds, token, amenityLookup)
            );

            if (!hasAllTextTokens) return false;
        }

        if (!matchesKeywordQuery(listing, listingAmenityIds, query.q, amenityLookup)) {
            return false;
        }

        if (query.checkIn && query.checkOut) {
            const requestedNights = Math.round(
                (new Date(`${query.checkOut}T00:00:00.000Z`).getTime() - new Date(`${query.checkIn}T00:00:00.000Z`).getTime()) / (1000 * 60 * 60 * 24),
            );

            if (listing.minNights && requestedNights < listing.minNights) {
                return false;
            }

            if (listing.maxNights && requestedNights > listing.maxNights) {
                return false;
            }

            if (bookedListingIds.has(listing.listingId)) {
                return false;
            }

            if (!isDateRangeAvailable(availabilityMap.get(listing.listingId) ?? [], query.checkIn, query.checkOut)) {
                return false;
            }
        }

        return true;
    });

    const items = filteredListings.map<PublicListingSearchItem>((listing) => {
        const summary = reviewSummaryMap.get(listing.listingId) ?? {
            avgRating: 0,
            reviewCount: 0,
        };
        const images = imageMap.get(listing.listingId) ?? [];
        const coverImage = getCoverImage(images);

        return {
            listingId: listing.listingId,
            title: listing.title,
            description: listing.description,
            basePrice: listing.basePrice,
            ratingAvg: summary.avgRating,
            reviewCount: summary.reviewCount,
            isAvailable: true,
            addressLine: listing.addressLine,
            ward: listing.ward,
            city: listing.city,
            district: listing.district,
            propertyType: listing.propertyType,
            roomType: listing.roomType,
            maxGuests: listing.maxGuests,
            bedrooms: listing.bedrooms,
            beds: listing.beds,
            bathrooms: listing.bathrooms,
            currency: listing.currency,
            imageUrl: coverImage?.url ?? null,
            coverImage: coverImage ? serializeListingImage(coverImage) : null,
            images: images.map(serializeListingImage),
            ...(distanceByListingId.has(listing.listingId)
                ? { distanceMeters: distanceByListingId.get(listing.listingId) }
                : {}),
        };
    });

    const sortKey = query.sort ?? "newest";

    items.sort((left, right) => {
        if (mapSearch && query.sort === undefined) {
            return (left.distanceMeters ?? Number.MAX_SAFE_INTEGER) -
                (right.distanceMeters ?? Number.MAX_SAFE_INTEGER) ||
                right.listingId - left.listingId;
        }

        const businessCityPriority =
            Number(compareStrings(right.city, defaultBusinessCity)) -
            Number(compareStrings(left.city, defaultBusinessCity));

        if (!query.city && sortKey === "newest" && businessCityPriority !== 0) {
            return businessCityPriority;
        }

        if (sortKey === "price_asc") {
            return left.basePrice - right.basePrice || right.listingId - left.listingId;
        }

        if (sortKey === "price_desc") {
            return right.basePrice - left.basePrice || right.listingId - left.listingId;
        }

        if (sortKey === "rating_desc") {
            return right.ratingAvg - left.ratingAvg || right.listingId - left.listingId;
        }

        return right.listingId - left.listingId;
    });

    const totalItems = items.length;
    const paginatedItems = items.slice((page - 1) * limit, page * limit);

    return {
        items: paginatedItems,
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

export const getPublicListingDetail = async (listingId: number) => {
    const listing = await getPublicListingOrThrow(listingId);
    const [amenityIds, images, rules, reviewSummary, host] = await Promise.all([
        getListingAmenityIdsForListing(listing),
        getListingImagesForListing(listing),
        getListingRulesForListing(listing),
        getListingReviewSummary(listing.listingId),
        User.findById(listing.hostId),
    ]);
    const amenities = await getAmenityDetails(amenityIds);

    return {
        listingId: listing.listingId,
        title: listing.title,
        description: listing.description,
        basePrice: listing.basePrice,
        weekendPrice: listing.weekendPrice ?? null,
        cleaningFee: listing.cleaningFee ?? null,
        serviceFeePct: listing.serviceFeePct ?? null,
        extraGuestFee: listing.extraGuestFee ?? null,
        currency: listing.currency,
        maxGuests: listing.maxGuests,
        includedGuests: listing.includedGuests ?? null,
        bedrooms: listing.bedrooms,
        beds: listing.beds,
        bathrooms: listing.bathrooms,
        propertyType: listing.propertyType,
        roomType: listing.roomType,
        minNights: listing.minNights,
        maxNights: listing.maxNights ?? null,
        checkInFrom: rules.checkInFrom,
        checkOutBefore: rules.checkOutBefore,
        cancellationPolicy: listing.cancellationPolicy,
        instantBookEnabled: listing.instantBookEnabled,
        addressSummary: {
            addressLine: listing.addressLine,
            ward: listing.ward,
            district: listing.district,
            city: listing.city,
            stateRegion: listing.stateRegion ?? null,
            country: listing.country,
            postalCode: listing.postalCode ?? null,
        },
        amenities,
        images: images.map(serializeListingImage),
        ratingSummary: reviewSummary,
        host: host
            ? {
                  userId: Number(host.id),
                  name: `${host.firstName} ${host.lastName}`.trim(),
                  avatarUrl: host.avatarUrl ?? null,
              }
            : null,
    };
};

export const getPublicListingAvailability = async (listingId: number, query: PublicListingAvailabilityQuery) => {
    const listing = await getPublicListingOrThrow(listingId);
    const now = new Date();
    const month = query.month ?? now.getUTCMonth() + 1;
    const year = query.year ?? now.getUTCFullYear();
    const totalDays = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const todayVN = getTodayInVietnamDateString(now);
    const [calendarRows, bookedDates] = await Promise.all([
        getAvailabilityCalendarForListing(listing),
        getBookedDatesForMonth(listing.listingId, month, year),
    ]);
    const availabilityMap = new Map(calendarRows.map((item) => [item.date, item] as const));

    const days = Array.from({ length: totalDays }, (_, index) => {
        const date = `${year}-${String(month).padStart(2, "0")}-${String(index + 1).padStart(2, "0")}`;
        const existing = availabilityMap.get(date);
        const isPast = date < todayVN;
        const calendarAvailable = existing ? !existing.isBlockedByHost && existing.isAvailable : true;

        return {
            date,
            isAvailable: isPast ? false : bookedDates.has(date) ? false : calendarAvailable,
            isPast,
            price: existing?.priceOverride ?? getDefaultDailyPrice(listing, date),
            minNights: existing?.minNightsOverride ?? listing.minNights,
        };
    });

    return {
        listingId: listing.listingId,
        month,
        year,
        days,
    };
};

export const getPublicListingReviews = async (listingId: number, query: PublicListingReviewsQuery) => {
    await getPublicListingOrThrow(listingId);

    const { page, limit } = parsePagination(query.page, query.limit);
    const overallReviews = (await Review.find({
        listingId,
        isVisible: true,
        deletedAt: null,
    })
        .sort({ createdAt: -1, reviewId: -1 })
        .lean()) as Array<{
        reviewId: number;
        rating: number;
        comment: string;
        reviewerName: string;
        hostReply: string | null;
        createdAt: Date;
    }>;

    const summary =
        overallReviews.length > 0
            ? {
                  avgRating: Number(
                      (
                          overallReviews.reduce((total, review) => total + review.rating, 0) / overallReviews.length
                      ).toFixed(1),
                  ),
                  reviewCount: overallReviews.length,
              }
            : {
                  avgRating: 0,
                  reviewCount: 0,
              };

    const filteredReviews =
        query.rating !== undefined ? overallReviews.filter((review) => review.rating === query.rating) : overallReviews;
    const paginatedReviews = filteredReviews.slice((page - 1) * limit, page * limit);

    return {
        items: paginatedReviews.map((review) => ({
            reviewId: review.reviewId,
            rating: review.rating,
            comment: sanitizeText(review.comment),
            reviewerName: sanitizeSingleLineText(review.reviewerName),
            hostReply: review.hostReply ? sanitizeText(review.hostReply) : null,
            createdAt: review.createdAt,
        })),
        summary,
        pagination: {
            page,
            limit,
            total: filteredReviews.length,
            totalPages: Math.max(1, Math.ceil(filteredReviews.length / limit)),
        },
    };
};

export const getPublicListingRules = async (listingId: number) => {
    const listing = await getPublicListingOrThrow(listingId);
    const rules = await getListingRulesForListing(listing);

    return {
        checkInFrom: rules.checkInFrom,
        checkOutBefore: rules.checkOutBefore,
        smokingAllowed: rules.smokingAllowed,
        petsAllowed: rules.petsAllowed,
        partyAllowed: rules.partyAllowed,
        quietHours: rules.quietHours ?? null,
    };
};
