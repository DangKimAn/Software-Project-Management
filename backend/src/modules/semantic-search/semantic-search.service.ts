import { ApiError } from "../../common/api-error";
import { isValidIsoDate } from "../../common/validation";
import {
    getLocationGroupAreaKey,
    isValidLocationGroup,
} from "../../common/vung-tau-location-groups";
import { logger } from "../../config/logger";
import { generateEmbedding } from "./embedding.service";
import { searchListingVectors } from "./qdrant-vector.service";
import { buildSemanticQuery, parseSearchQuery } from "./semantic-search.parser";
import {
    findAvailableListingItems,
    keywordSearchFallback,
    listSemanticSynonymRows,
    recordSemanticSearchLog,
    resolveAmenityIds,
} from "./semantic-search.repository";
import {
    SearchRejectionReason,
    SemanticSearchFilters,
    SemanticSearchItem,
    SemanticSearchRequest,
    SemanticSearchResponse,
    isSupportedCity,
} from "./semantic-search.types";
import {
    getSemanticDefaultCity,
    inferVungTauAreaKeys,
    normalizeKey,
    normalizeVietnameseText,
    shouldForceVungTauOnly,
    uniqueNumbers,
    uniqueStrings,
} from "./semantic-search.utils";

const maxQueryLength = 500;
const maxLimit = 30;

/**
 * Minimum cosine-similarity score from Qdrant below which a result is
 * discarded.  Prevents irrelevant listings from surfacing for vague or
 */
const MIN_SEMANTIC_SCORE = 0.28;

type SemanticSearchContext = {
    userId?: number | null;
};

const isDevMode = () => process.env.NODE_ENV !== "production";

const clamp01 = (value: number) => Math.max(0, Math.min(1, value));

const queryTokens = (query: string) =>
    uniqueStrings(normalizeVietnameseText(query).split(" ").filter((token) => token.length >= 2));

const centralTourismAreaKeys = ["trung_tam", "bai_sau", "thuy_van", "bai_truoc", "tran_phu"];
const nearBeachAreaKeys = ["bai_sau", "thuy_van", "long_cung", "tran_phu", "bai_truoc"];

const expandPreferredAreaKeys = (areaKeys: string[], proximity: string[], suppressGenericExpansion: boolean) => {
    // If user mentioned a specific area (e.g. "bãi sau", "long cung"), do NOT expand
    // with generic beach/tourism areas — they asked for THAT specific area.
    if (suppressGenericExpansion) {
        return uniqueStrings(areaKeys);
    }

    const expanded = [...areaKeys];

    if (areaKeys.includes("trung_tam")) {
        expanded.push(...centralTourismAreaKeys);
    }

    if (proximity.includes("near_beach") || proximity.includes("sea_view")) {
        expanded.push(...nearBeachAreaKeys);
    }

    return uniqueStrings(expanded);
};

// ─── Vietnam timezone helper ──────────────────────────────────────────────────

const getVietnamDateString = (now = new Date()) =>
    new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

// ─── Intent detection ─────────────────────────────────────────────────────────

/**
 * Determines whether a query has a valid villa-search intent.
 *
 * A query is considered valid if it contains at least ONE of:
 *   – an accommodation keyword (villa, homestay, căn hộ, etc.)
 *   – a recognized location (city alias or Vũng Tàu area)
 *   – a recognized amenity keyword
 *   – explicit UI-provided filters (dates, guests, price, amenities, etc.)
 */
const ACCOMMODATION_KEYWORDS = [
    "villa", "biet thu", "homestay", "home stay", "can ho", "chung cu",
    "phong", "resort", "nha nghi", "cho o", "khach san", "hotel",
    "nha", "apartment", "studio", "nha rieng", "nha nguyen can", "nguyen can",
];

const AMENITY_KEYWORDS = [
    "ho boi", "ho boi rieng", "ho boi lon", "be boi", "pool", "swimming pool",
    "karaoke", "bida", "bi a", "bbq", "nuong",
    "gan bien", "sat bien", "cach bien", "di bo ra bien", "gan bai sau", "gan thuy van",
    "view bien", "san vuon", "thang may", "may giat",
    "bep", "wifi", "dieu hoa", "may lanh", "bon tam", "jacuzzi",
    "ban cong", "parking", "bai xe", "dau xe", "pet", "thu cung",
    "gym", "sang trong", "gia re", "yen tinh",
    "loa keo", "phong hat", "hat ho", "ban bida",
    "tiec nuong", "san nuong", "elevator", "lift", "san rong",
];

const LOCATION_KEYWORDS = [
    "vung tau", "bai sau", "bai truoc", "long cung", "chi linh",
    "thuy tien", "trung tam", "gan trung tam", "tran phu", "thuy van",
    "bai dau", "rach dua", "hoanh son", "thuy duong",
    "vt", "vtau", "br vt", "brvt",

];

type IntentResult = {
    valid: boolean;
    reason?: SearchRejectionReason;
    message?: string;
};

const detectSearchIntent = (
    query: string,
    input: SemanticSearchRequest,
    parsedHasRelevantFilters: boolean,
): IntentResult => {
    // If UI explicitly provides filters (dates, guests, price, amenities, etc.)
    // we treat the search as intentional even if the text query is vague.
    if (parsedHasRelevantFilters) {
        return { valid: true };
    }

    const normalized = normalizeVietnameseText(query);

    // Query too short and no keywords → invalid
    if (normalized.length < 2) {
        return {
            valid: false,
            reason: "INVALID_SEARCH_INTENT",
            message: "Vui lòng nhập nhu cầu tìm villa, khu vực, ngày ở hoặc tiện ích mong muốn.",
        };
    }

    const hasAccommodation = ACCOMMODATION_KEYWORDS.some((kw) => new RegExp(`\\b${kw}\\b`, "i").test(normalized));
    const hasAmenity = AMENITY_KEYWORDS.some((kw) => new RegExp(`\\b${kw}\\b`, "i").test(normalized));
    const hasLocation = LOCATION_KEYWORDS.some((kw) => new RegExp(`\\b${kw}\\b`, "i").test(normalized));

    // "cuoi tuan", "hom nay", "ngay mai" are date-related → valid intent
    const hasDateKeyword =
        normalized.includes("cuoi tuan") ||
        normalized.includes("hom nay") ||
        normalized.includes("ngay mai") ||
        normalized.includes("tuan toi") ||
        normalized.includes("tuan sau") ||
        normalized.includes("thang sau") ||
        /thang\s+\d/.test(normalized) ||
        /\d{1,2}[\/-]\d{1,2}/.test(normalized) ||
        /thu\s+[2-7]/.test(normalized) ||
        normalized.includes("thu hai") ||
        normalized.includes("thu ba") ||
        normalized.includes("thu tu") ||
        normalized.includes("thu nam") ||
        normalized.includes("thu sau") ||
        normalized.includes("thu bay") ||
        normalized.includes("chu nhat");

    // Guest-related keywords
    const hasGuestKeyword =
        /\d+\s*(?:nguoi|khach|guest|pax)/.test(normalized) ||
        normalized.includes("nhom lon") ||
        normalized.includes("nhom dong") ||
        normalized.includes("doan dong") ||
        normalized.includes("doan") ||
        normalized.includes("ca nha") ||
        normalized.includes("cap doi") ||
        normalized.includes("gia dinh");

    // Price-related keywords — "4tr", "dưới 4m", etc.
    const hasPriceKeyword =
        /\d+\s*(?:tr(?:ieu)?|m(?:il)?|cu|chai|k)\b/.test(normalized) ||
        /(?:duoi|tren|tu|khoang|tam|toi da|budget)\s+\d/.test(normalized) ||
        /\d{6,}/.test(normalized) ||  // bare VND like 4000000
        /\d{1,3}(?:\.\d{3})+/.test(normalized);  // 4.000.000

    // Room-related keywords — "4pn", "8 phòng ngủ", etc.
    const hasRoomKeyword =
        /\d+\s*(?:pn|phong\s*ngu|phong\s*tam|giuong|wc|toilet|bedroom|bathroom|bed)/.test(normalized) ||
        normalized.includes("nhieu phong");

    if (hasAccommodation || hasAmenity || hasLocation || hasDateKeyword || hasGuestKeyword || hasPriceKeyword || hasRoomKeyword) {
        return { valid: true };
    }

    return {
        valid: false,
        reason: "INVALID_SEARCH_INTENT",
        message: "Vui lòng nhập nhu cầu tìm villa, khu vực, ngày ở hoặc tiện ích mong muốn.",
    };
};

// ─── Scoring ──────────────────────────────────────────────────────────────────

const calculateKeywordScore = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    const normalizedQuery = normalizeVietnameseText(filters.query);
    const searchable = normalizeVietnameseText(
        [
            item.title,
            item.description,
            item.addressLine,
            item.ward,
            item.district,
            item.city,
            item.propertyType,
            item.roomType,
            item.vungTauAreas.join(" "),
        ].join(" "),
    );

    if (!normalizedQuery) {
        return 0;
    }

    if (searchable.includes(normalizedQuery)) {
        return 1;
    }

    const tokens = queryTokens(filters.query);
    if (tokens.length === 0) {
        return 0;
    }

    const matchedTokenCount = tokens.filter((token) => searchable.includes(token)).length;
    const requestedAmenityCount = filters.amenityCodes.length;
    const matchedAmenityCount = item.matchSignals?.amenityCodes.filter((code) =>
        filters.amenityCodes.includes(code),
    ).length ?? 0;
    const amenityBoost = requestedAmenityCount > 0
        ? Math.min(0.25, (matchedAmenityCount / requestedAmenityCount) * 0.25)
        : 0;

    return clamp01(matchedTokenCount / tokens.length + amenityBoost);
};

const calculateBedroomFeatureScore = (item: SemanticSearchItem, requestedBedrooms?: number) => {
    if (!requestedBedrooms) {
        return 0;
    }

    if (item.bedrooms === requestedBedrooms) {
        return 0.35;
    }

    if (item.bedrooms > requestedBedrooms) {
        const extraBedrooms = item.bedrooms - requestedBedrooms;
        return Math.max(0.1, 0.25 - extraBedrooms * 0.04);
    }

    return Math.max(0, 0.15 - (requestedBedrooms - item.bedrooms) * 0.05);
};

const calculateBeachFeatureScore = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    if (!filters.nearBeach && !filters.beachDistanceMeters) {
        return 0;
    }

    const beachDistanceMeters = item.matchSignals?.beachDistanceMeters;

    if (filters.beachDistanceMeters && beachDistanceMeters !== undefined) {
        if (beachDistanceMeters <= filters.beachDistanceMeters) return 0.3;
        if (beachDistanceMeters <= Math.max(200, filters.beachDistanceMeters * 2)) return 0.24;
        if (beachDistanceMeters <= 500) return 0.18;
        if (item.matchSignals?.beach) return 0.1;
        return 0;
    }

    return item.matchSignals?.beach ? 0.22 : 0;
};

const calculateFeatureScore = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    let score = 0;

    score += calculateBedroomFeatureScore(item, filters.bedrooms);
    score += calculateBeachFeatureScore(item, filters);

    if (filters.amenityCodes.includes("pool") && item.matchSignals?.pool) {
        score += 0.24;
    }

    if (filters.parsedFilters.parkingRequired && item.matchSignals?.amenityCodes.includes("parking")) {
        score += 0.20;
    }

    const requestedNonPoolAmenities = filters.amenityCodes.filter((code) => code !== "pool" && code !== "parking");
    if (requestedNonPoolAmenities.length > 0) {
        const matchedCount = item.matchSignals?.amenityCodes.filter((code) =>
            requestedNonPoolAmenities.includes(code),
        ).length ?? 0;
        score += Math.min(0.15, (matchedCount / requestedNonPoolAmenities.length) * 0.15);
    }

    if (filters.vungTauAreaKeys.length > 0 && item.matchSignals?.locationAreaMatch) {
        score += 0.14;
    } else if (filters.parsedFilters.nearCenter && item.vungTauAreaKeys.includes("trung_tam")) {
        score += 0.14;
    }

    return clamp01(score);
};

const calculateLocationScore = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    if (filters.vungTauAreaKeys.length > 0) {
        return filters.vungTauAreaKeys.some((areaKey) => item.vungTauAreaKeys.includes(areaKey)) ? 1 : 0;
    }

    if (filters.districtKey && normalizeKey(item.district) === filters.districtKey) {
        return 1;
    }

    if (normalizeKey(item.city) === filters.cityKey) {
        return item.vungTauAreaKeys.length > 0 ? 0.85 : 0.65;
    }

    return item.vungTauAreaKeys.length > 0 ? 0.6 : 0.35;
};

const calculatePopularityScore = (item: SemanticSearchItem) => {
    const ratingComponent = clamp01(item.ratingAvg / 5) * 0.7;
    const reviewComponent = clamp01(Math.log10(item.reviewCount + 1) / 2) * 0.3;

    return clamp01(ratingComponent + reviewComponent);
};

const buildScoreBreakdown = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    const semanticScore = clamp01(item.semanticScore);
    const keywordScore = calculateKeywordScore(item, filters);
    const locationScore = calculateLocationScore(item, filters);
    const availabilityScore = item.isAvailable ? 1 : 0;
    const popularityScore = calculatePopularityScore(item);
    const featureScore = calculateFeatureScore(item, filters);

    return {
        semanticScore,
        keywordScore,
        locationScore,
        availabilityScore,
        popularityScore,
        featureScore,
    };
};

const calculateFinalScore = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    const scoreBreakdown = buildScoreBreakdown(item, filters);
    const finalScore =
        scoreBreakdown.semanticScore * 0.25 +
        scoreBreakdown.keywordScore * 0.2 +
        scoreBreakdown.locationScore * 0.15 +
        scoreBreakdown.availabilityScore * 0.1 +
        scoreBreakdown.popularityScore * 0.05 +
        scoreBreakdown.featureScore * 0.25;

    return {
        scoreBreakdown,
        finalScore: Number(finalScore.toFixed(4)),
    };
};

const buildMatchedReasons = (
    item: SemanticSearchItem,
    filters: SemanticSearchFilters,
    scoreBreakdown: SemanticSearchItem["scoreBreakdown"],
) => {
    const reasons: string[] = [];

    reasons.push("Phù hợp với nhu cầu của bạn");

    if (filters.district && normalizeKey(item.district) === filters.districtKey) {
        reasons.push(`Khu vực ${item.district}`);
    }

    if (filters.guests > 1 && item.maxGuests >= filters.guests) {
        reasons.push(`Đủ cho nhóm ${filters.guests} khách`);
    }

    if (filters.bedrooms && item.bedrooms === filters.bedrooms) {
        reasons.push(`Đúng ${filters.bedrooms} phòng ngủ`);
    } else if (filters.bedrooms && item.bedrooms > filters.bedrooms) {
        reasons.push(`${item.bedrooms} phòng ngủ (nhiều hơn yêu cầu)`);
    }

    if (filters.maxPrice !== undefined && item.basePrice <= filters.maxPrice) {
        reasons.push(`Trong ngân sách`);
    }

    if (filters.amenityCodes.includes("pool") && item.matchSignals?.pool) {
        reasons.push("Có hồ bơi");
    }

    if (filters.parsedFilters.parkingRequired && item.matchSignals?.amenityCodes.includes("parking")) {
        reasons.push("Có chỗ đậu xe");
    }

    const hasNonPoolAmenityMatch = item.matchSignals?.amenityCodes.some((code) =>
        code !== "pool" && code !== "parking" && filters.amenityCodes.includes(code),
    );
    if (hasNonPoolAmenityMatch) {
        reasons.push("Có tiện nghi yêu cầu");
    }

    if ((filters.nearBeach || filters.beachDistanceMeters) && item.matchSignals?.beach) {
        const distance = item.matchSignals.beachDistanceMeters;
        if (
            filters.beachDistanceMeters &&
            distance !== undefined &&
            distance <= Math.max(500, filters.beachDistanceMeters * 5)
        ) {
            reasons.push(`Cách biển ~${distance.toLocaleString("vi-VN")}m`);
        } else {
            reasons.push("Gần biển");
        }
    }

    if (filters.vungTauAreaKeys.length > 0 && item.matchSignals?.locationAreaMatch) {
        reasons.push("Khu vực bạn tìm kiếm");
    } else if (filters.parsedFilters.nearCenter && item.vungTauAreaKeys.includes("trung_tam")) {
        reasons.push("Gần trung tâm");
    }

    if (filters.checkIn && filters.checkOut && item.isAvailable) {
        reasons.push("Còn trống theo ngày chọn");
    }

    return uniqueStrings(reasons);
};

// ─── Date validation ──────────────────────────────────────────────────────────

const validateDateRange = (input: SemanticSearchRequest) => {
    if ((input.checkIn && !input.checkOut) || (!input.checkIn && input.checkOut)) {
        throw new ApiError(422, "checkIn and checkOut must be provided together");
    }

    if (!input.checkIn || !input.checkOut) {
        return;
    }

    if (!isValidIsoDate(input.checkIn) || !isValidIsoDate(input.checkOut)) {
        throw new ApiError(422, "checkIn and checkOut must use YYYY-MM-DD format");
    }

    if (input.checkOut <= input.checkIn) {
        throw new ApiError(422, "checkOut must be after checkIn");
    }
};

/**
 * Checks whether explicitly-provided check-in/check-out dates are in the past.
 * Returns a rejection reason or null if dates are OK (or not provided).
 */
const checkPastDates = (checkIn?: string, checkOut?: string): IntentResult | null => {
    if (!checkIn || !checkOut) {
        return null;
    }

    const todayVN = getVietnamDateString();

    if (checkIn < todayVN) {
        return {
            valid: false,
            reason: "PAST_DATE_NOT_ALLOWED",
            message: "Không thể tìm phòng cho ngày trong quá khứ.",
        };
    }

    return null;
};

/**
 * Checks whether a date intent parsed from the query text is in the past.
 * If so we discard the date intent rather than rejecting the whole search.
 */
const isParsedDateInPast = (checkIn?: string): boolean => {
    if (!checkIn) return false;
    return checkIn < getVietnamDateString();
};

// ─── Filter building ──────────────────────────────────────────────────────────

const getExplicitLocationAreaKeys = (locationGroup?: string) => {
    if (!locationGroup) {
        return [];
    }

    if (isValidLocationGroup(locationGroup)) {
        return [getLocationGroupAreaKey(locationGroup)];
    }

    return inferVungTauAreaKeys(locationGroup);
};

const buildFilters = async (input: SemanticSearchRequest): Promise<SemanticSearchFilters> => {
    const rawQuery = input.query;

    if (typeof rawQuery !== "string") {
        throw new ApiError(422, "query must be a string");
    }

    const query = rawQuery.trim();

    if (!query) {
        throw new ApiError(422, "query is required");
    }

    if (query.length > maxQueryLength) {
        throw new ApiError(422, `query must be at most ${maxQueryLength} characters`);
    }

    validateDateRange(input);

    if (input.minPrice !== undefined && input.maxPrice !== undefined && input.minPrice > input.maxPrice) {
        throw new ApiError(422, "maxPrice must be greater than or equal to minPrice");
    }

    const synonymRows = await listSemanticSynonymRows();
    const parsed = parseSearchQuery(query, synonymRows);

    // ── Date handling ─────────────────────────────────────────────────────────
    // If user provided explicit dates via UI, use those.
    // Otherwise try parsed dateIntent from query text — but only if not in past.
    let checkIn = input.checkIn;
    let checkOut = input.checkOut;

    if (!checkIn && !checkOut && parsed.dateIntent?.checkIn && parsed.dateIntent?.checkOut) {
        if (!parsed.dateIntent.reason && !isParsedDateInPast(parsed.dateIntent.checkIn)) {
            checkIn = parsed.dateIntent.checkIn;
            checkOut = parsed.dateIntent.checkOut;
        }
        // If parsed date is in the past, we silently discard it — the search
        // proceeds without date filter rather than failing hard.
    }

    // ── City / location handling ──────────────────────────────────────────────
    // Detect the user's intended city from the query text or explicit input.
    // Even when forceVungTauOnly is true, we MUST respect the parsed city to
    // return UNSUPPORTED_LOCATION instead of showing Vũng Tàu listings for
    // queries like "villa Nha Trang".
    const forceVungTauOnly = shouldForceVungTauOnly();
    const parsedCity = input.city ?? parsed.city;
    const city = parsedCity ?? getSemanticDefaultCity();

    const semanticQuery = buildSemanticQuery(
        {
            ...input,
            city,
            checkIn,
            checkOut,
        },
        parsed,
    );

    const requestAmenities = Array.isArray(input.amenities)
        ? input.amenities
        : [];
    const amenityCodes = uniqueStrings([
        ...(parsed.amenityCodes ?? []),
        ...requestAmenities.map(String),
    ]);
    const amenityIds = await resolveAmenityIds(amenityCodes);

    const district = input.district ?? parsed.district;
    const page = Math.max(1, Math.floor(input.page ?? 1));
    const limit = Math.min(maxLimit, Math.max(1, Math.floor(input.limit ?? 12)));
    const explicitLocationAreaKeys = getExplicitLocationAreaKeys(input.locationGroup);
    const parsedLocationAreaKeys = parsed.locationIntent?.areaKeys ?? [];
    const inferredAreaKeys = inferVungTauAreaKeys(`${query} ${semanticQuery}`);

    // Determine if user specified a specific location group (e.g. "bãi sau", "long cung")
    // Either via UI dropdown (explicitLocationAreaKeys) or via query text (parsedLocationAreaKeys)
    const hasExplicitLocation = explicitLocationAreaKeys.length > 0;
    const suppressGenericExpansion =
        hasExplicitLocation ||
        (parsedLocationAreaKeys.length > 0 && !parsedLocationAreaKeys.includes("trung_tam"));

    const preferredAreaKeys = uniqueStrings([
        ...explicitLocationAreaKeys,
        ...parsedLocationAreaKeys,
        ...inferredAreaKeys,
    ]);
    const vungTauAreaKeys = expandPreferredAreaKeys(preferredAreaKeys, parsed.proximity, suppressGenericExpansion);

    // Use hard filter when user explicitly mentioned a specific area.
    // This ensures "villa gần bãi sau" only returns Bãi Sau listings,
    // not Bãi Long Cung or other beach areas.
    const locationAreaFilterMode = hasExplicitLocation ? "hard" : "soft";

    return {
        query,
        semanticQuery,

        checkIn,
        checkOut,

        guests: Math.max(1, Math.floor(input.guests ?? parsed.guests ?? 1)),

        city,
        cityKey: normalizeKey(city),
        district,
        districtKey: district ? normalizeKey(district) : undefined,

        minPrice: input.minPrice ?? parsed.minPrice,
        maxPrice: input.maxPrice ?? parsed.maxPrice,

        bedrooms: parsed.bedrooms,
        beds: parsed.beds,
        bathrooms: parsed.bathrooms,
        nearBeach: Boolean(parsed.nearBeach || parsed.proximity.includes("near_beach")),
        beachDistanceMeters: parsed.beachDistanceMeters,

        amenityIds,
        amenityCodes,

        locationGroup: input.locationGroup,
        explicitLocationAreaKeys,

        propertyType: input.propertyType ?? parsed.propertyType,
        roomType: input.roomType,

        page,
        limit,

        forceVungTauOnly,
        vungTauAreaKeys,
        locationAreaFilterMode,
        parsedFilters: parsed,
    };
};

// ─── Ranking & pagination ─────────────────────────────────────────────────────

const bedroomPriority = (item: SemanticSearchItem, filters: SemanticSearchFilters) => {
    if (!filters.bedrooms) {
        return 0;
    }

    if (item.bedrooms === filters.bedrooms) {
        return 3;
    }

    if (item.bedrooms > filters.bedrooms) {
        return 2 - (item.bedrooms - filters.bedrooms) * 0.1;
    }

    return 1 - (filters.bedrooms - item.bedrooms) * 0.1;
};

const rankItems = (items: SemanticSearchItem[], filters: SemanticSearchFilters) =>
    items
        .map((item) => {
            const { finalScore, scoreBreakdown } = calculateFinalScore(item, filters);

            return {
                ...item,
                ...scoreBreakdown,
                finalScore,
                scoreBreakdown,
                matchedReasons: buildMatchedReasons(item, filters, scoreBreakdown),
            };
        })
        .sort((left, right) =>
            bedroomPriority(right, filters) - bedroomPriority(left, filters) ||
            right.finalScore - left.finalScore ||
            right.listingId - left.listingId,
        );

const paginate = (
    items: SemanticSearchItem[],
    filters: SemanticSearchFilters,
    fallback: boolean,
    usedVectorSearch: boolean,
    candidateCount: number,
    extra?: {
        reason?: SearchRejectionReason;
        message?: string;
        availabilityNotice?: string;
    },
): SemanticSearchResponse => {
    const totalItems = items.length;
    const start = (filters.page - 1) * filters.limit;
    const paginatedItems = items.slice(start, start + filters.limit);

    return {
        query: filters.query,
        mode: fallback ? "keyword_fallback" : "semantic",
        items: paginatedItems,
        pagination: {
            page: filters.page,
            limit: filters.limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / filters.limit)),
        },
        fallback,
        reason: extra?.reason,
        message: extra?.message,
        availabilityNotice: extra?.availabilityNotice,
        searchMeta: {
            query: filters.query,
            semanticQuery: filters.semanticQuery,
            usedVectorSearch,
            candidateCount,
            forceVungTauOnly: filters.forceVungTauOnly,
            filters: {
                city: filters.city,
                district: filters.district,
                minPrice: filters.minPrice,
                maxPrice: filters.maxPrice,
                guests: filters.guests,
                bedrooms: filters.bedrooms,
                beds: filters.beds,
                bathrooms: filters.bathrooms,
                nearBeach: filters.nearBeach,
                beachDistanceMeters: filters.beachDistanceMeters,
                amenityIds: filters.amenityIds,
                amenityCodes: filters.amenityCodes,
                locationGroup: filters.locationGroup,
                vungTauAreaKeys: filters.vungTauAreaKeys,
                proximity: filters.parsedFilters.proximity,
                propertyType: filters.propertyType,
                roomType: filters.roomType,
                locationAreaFilterMode: filters.locationAreaFilterMode,
            },
            parsedFilters: filters.parsedFilters,
        },
    };
};

// ─── Empty-result helpers ─────────────────────────────────────────────────────

const buildEmptyResponse = (
    filters: SemanticSearchFilters,
    reason: SearchRejectionReason,
    message: string,
): SemanticSearchResponse =>
    paginate([], filters, false, false, 0, {
        reason,
        message: reason === "UNSUPPORTED_LOCATION"
            ? "Minh Thành Villa hiện chỉ hỗ trợ khu vực Vũng Tàu."
            : message,
    });

// ─── Logging ──────────────────────────────────────────────────────────────────

const logSearch = async (
    response: SemanticSearchResponse,
    filters: SemanticSearchFilters,
    context: SemanticSearchContext,
) => {
    await recordSemanticSearchLog({
        userId: context.userId ?? null,
        query: filters.query,
        parsedFilters: filters.parsedFilters as unknown as Record<string, unknown>,
        resultListingIds: response.items.map((item) => item.listingId),
    });
};

const debugLog = (label: string, data: Record<string, unknown>) => {
    if (isDevMode()) {
        logger.info(`[SemanticSearch] ${label}`, data);
    }
};

const runKeywordFallbackSearch = async (
    filters: SemanticSearchFilters,
    context: SemanticSearchContext,
    options: {
        usedVectorSearch: boolean;
        candidateCount: number;
        availabilityNotice?: string;
    },
) => {
    const fallbackItems = await keywordSearchFallback(filters);
    const rankedFallback = rankItems(fallbackItems, filters);
    const response = paginate(
        rankedFallback,
        filters,
        true,
        options.usedVectorSearch,
        options.candidateCount || fallbackItems.length,
        {
            reason: rankedFallback.length === 0 ? "NO_RESULTS" : undefined,
            message: rankedFallback.length === 0
                ? "Không tìm thấy chỗ nghỉ phù hợp với yêu cầu của bạn."
                : undefined,
            availabilityNotice: options.availabilityNotice,
        },
    );

    await logSearch(response, filters, context);
    return response;
};

// ─── Main search entry point ──────────────────────────────────────────────────

export const semanticSearchListings = async (
    input: SemanticSearchRequest,
    context: SemanticSearchContext = {},
): Promise<SemanticSearchResponse> => {
    const filters = await buildFilters(input);
    const parsedDateIntent = filters.parsedFilters.dateIntent;

    if (parsedDateIntent?.reason) {
        const response = buildEmptyResponse(
            filters,
            parsedDateIntent.reason,
            parsedDateIntent.message ?? "Không thể tìm phòng cho ngày trong quá khứ.",
        );
        await logSearch(response, filters, context);
        return response;
    }

    // ── Step 1: Check for past dates (explicit from UI) ───────────────────────
    const pastDateCheck = checkPastDates(filters.checkIn, filters.checkOut);
    if (pastDateCheck && !pastDateCheck.valid) {
        const response = buildEmptyResponse(
            filters,
            pastDateCheck.reason!,
            pastDateCheck.message!,
        );
        await logSearch(response, filters, context);
        return response;
    }

    // ── Step 2: Intent detection — reject garbage queries ─────────────────────
    const hasExplicitFilters =
        Boolean(input.checkIn) ||
        Boolean(input.checkOut) ||
        Boolean(input.guests && input.guests > 1) ||
        Boolean(input.minPrice) ||
        Boolean(input.maxPrice) ||
        Boolean(input.amenities && input.amenities.length > 0) ||
        Boolean(input.locationGroup) ||
        Boolean(input.propertyType) ||
        Boolean(input.roomType) ||
        Boolean(input.city) ||
        Boolean(input.district);

    const intent = detectSearchIntent(filters.query, input, hasExplicitFilters);

    debugLog("Intent detection", {
        query: filters.query,
        valid: intent.valid,
        reason: intent.reason,
        hasExplicitFilters,
    });

    if (!intent.valid) {
        const response = buildEmptyResponse(
            filters,
            intent.reason!,
            intent.message!,
        );
        await logSearch(response, filters, context);
        return response;
    }

    // ── Step 3: Location validation — reject unsupported cities ───────────────
    // If the user searched for a specific city that is NOT Vũng Tàu (or its
    // known aliases/areas), and forceVungTauOnly is on, return empty.
    const cityKey = normalizeKey(filters.city);
    const cityIsVungTau = isSupportedCity(normalizeVietnameseText(filters.city));

    if (filters.forceVungTauOnly && !cityIsVungTau && filters.parsedFilters.city) {
        debugLog("Unsupported location", {
            query: filters.query,
            detectedCity: filters.city,
            cityKey,
        });

        const response = buildEmptyResponse(
            filters,
            "UNSUPPORTED_LOCATION",
            `Hiện chưa có villa phù hợp tại ${filters.city}.`,
        );
        await logSearch(response, filters, context);
        return response;
    }

    // ── Step 4: Availability notice (no dates) ────────────────────────────────
    const availabilityNotice = (!filters.checkIn || !filters.checkOut)
        ? "Chọn ngày để kiểm tra tình trạng còn trống."
        : undefined;

    // ── Step 5: Semantic vector search ────────────────────────────────────────
    try {
        const vector = await generateEmbedding(filters.semanticQuery);
        const vectorHits = await searchListingVectors(vector, filters, 250);

        debugLog("Qdrant results", {
            query: filters.query,
            totalHits: vectorHits.length,
            topScore: vectorHits[0]?.score ?? 0,
            bottomScore: vectorHits[vectorHits.length - 1]?.score ?? 0,
        });

        // ── Apply semantic score threshold ────────────────────────────────────
        const qualifiedHits = vectorHits.filter((hit) => hit.score >= MIN_SEMANTIC_SCORE);

        debugLog("After score threshold", {
            before: vectorHits.length,
            after: qualifiedHits.length,
            threshold: MIN_SEMANTIC_SCORE,
        });

        if (qualifiedHits.length === 0) {
            return runKeywordFallbackSearch(filters, context, {
                usedVectorSearch: true,
                candidateCount: vectorHits.length,
                availabilityNotice,
            });
        }

        const listingIds = uniqueNumbers(qualifiedHits.map((hit) => hit.payload.listing_id));
        const semanticScoreMap = new Map(
            qualifiedHits.map((hit) => [hit.payload.listing_id, clamp01(hit.score)]),
        );
        const availableItems = await findAvailableListingItems(
            listingIds,
            filters,
            semanticScoreMap,
        );

        debugLog("After DB filters", {
            vectorCandidates: listingIds.length,
            availableItems: availableItems.length,
            checkIn: filters.checkIn,
            checkOut: filters.checkOut,
        });

        if (availableItems.length === 0) {
            return runKeywordFallbackSearch(filters, context, {
                usedVectorSearch: true,
                candidateCount: qualifiedHits.length,
                availabilityNotice,
            });
        }

        const rankedItems = rankItems(availableItems, filters);
        const response = paginate(
            rankedItems,
            filters,
            false,
            true,
            qualifiedHits.length,
            {
                reason: rankedItems.length === 0 ? "NO_RESULTS" : undefined,
                message: rankedItems.length === 0
                    ? "Không tìm thấy chỗ nghỉ phù hợp với yêu cầu của bạn."
                    : undefined,
                availabilityNotice,
            },
        );

        await logSearch(response, filters, context);
        return response;
    } catch (error) {
        logger.warn("Semantic vector search failed. Falling back to keyword search", {
            errorMessage: error instanceof Error ? error.message : String(error),
        });

        return runKeywordFallbackSearch(filters, context, {
            usedVectorSearch: false,
            candidateCount: 0,
            availabilityNotice,
        });
    }
};
