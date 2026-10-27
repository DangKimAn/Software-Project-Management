import { Op } from "sequelize";

import { buildActiveBookingStatusWhere, buildBookingDateOverlapWhere } from "../../common/booking-availability";
import {
    getAvailabilityCalendarMap,
    getListingAmenityIdsMap,
    getListingImagesMap,
    getListingRulesForListing,
} from "../../common/listing-relations";
import { getDistanceMeters } from "../../common/vung-tau-location-groups";
import Amenity from "../../models/amenity";
import Booking from "../../models/booking";
import ListingEmbedding from "../../models/listing-embedding";
import Listing, {
    ListingAvailabilityDayRecord,
    ListingDocument,
    ListingImageRecord,
} from "../../models/listing";
import Review from "../../models/review";
import SearchLog from "../../models/search-log";
import SemanticSynonym from "../../models/semantic-synonym";
import {
    ListingVectorPayload,
    SemanticSearchFilters,
    SemanticSearchItem,
    semanticPublicListingStatuses,
} from "./semantic-search.types";
import {
    buildLocationKeys,
    getVungTauAreaDisplayNames,
    inferVungTauAreaKeys,
    isVungTauRelatedText,
    listNights,
    normalizeKey,
    normalizeVietnameseText,
    toNumber,
    uniqueNumbers,
    uniqueStrings,
} from "./semantic-search.utils";

type ReviewSummary = {
    ratingAvg: number;
    reviewCount: number;
    reviewSnippets: string[];
};

type ListingRulesSummary = {
    checkInFrom: string | null;
    checkOutBefore: string | null;
    smokingAllowed: boolean;
    petsAllowed: boolean;
    partyAllowed: boolean;
    quietHours: string | null;
};

export type ListingIndexRecord = {
    listing: ListingDocument;
    amenityIds: number[];
    amenityNames: string[];
    reviewSummary: ReviewSummary;
    rules: ListingRulesSummary;
};

const defaultAmenityAliases: Record<string, number> = {
    wifi: 1,
    internet: 1,

    air_conditioning: 2,
    airconditioner: 2,
    airconditioning: 2,
    dieuhoa: 2,
    maylanh: 2,

    washer: 3,
    maygiat: 3,

    kitchen: 4,
    bep: 4,

    pool: 5,
    hoboi: 5,
    beboi: 5,

    parking: 6,
    baixe: 6,
    dauxe: 6,

    tv: 7,
    tivi: 7,

    balcony: 8,
    bancong: 8,

    refrigerator: 10,
    fridge: 10,
    tulanh: 10,

    hairdryer: 11,
    maysaytoc: 11,

    iron: 12,
    banui: 12,
};

const beachAnchors = [
    { name: "Bai Sau", latitude: 10.334, longitude: 107.087 },
    { name: "Bai Truoc", latitude: 10.346, longitude: 107.075 },
    { name: "Thuy Van", latitude: 10.333, longitude: 107.088 },
    { name: "Tran Phu", latitude: 10.369, longitude: 107.065 },
    { name: "Long Cung", latitude: 10.374, longitude: 107.151 },
];

const nearBeachAreaKeys = new Set(["bai_sau", "thuy_van", "long_cung", "tran_phu", "bai_truoc"]);

const amenityEvidenceTerms: Record<string, string[]> = {
    pool: ["pool", "swimming pool", "ho boi", "be boi", "ho boi rieng", "ho boi lon"],
    karaoke: ["karaoke", "phong hat", "loa keo", "loa karaoke", "hat ho"],
    billiards: ["bida", "bi a", "billiards", "ban bida", "pool table"],
    bbq: ["bbq", "nuong", "bep nuong", "khu nuong", "san nuong"],
    sea_view: ["view bien", "huong bien", "nhin ra bien", "sea view", "ocean view"],
    kitchen: ["bep", "kitchen", "nau an"],
    parking: ["bai xe", "dau xe", "do xe", "parking"],
    pet_friendly: ["thu cung", "pet", "cho meo", "cho mang"],
    elevator: ["thang may", "elevator", "lift"],
};

const beachEvidenceTerms = [
    "gan bien",
    "sat bien",
    "cach bien",
    "di bo ra bien",
    "di bo ra bai",
    "bai sau",
    "bai truoc",
    "thuy van",
    "long cung",
    "tran phu",
    "bai dau",
    "bo bien",
    "ven bien",
];

const safeStringArray = (value: unknown): string[] => {
    if (Array.isArray(value)) {
        return value.map(String).map((item) => item.trim()).filter(Boolean);
    }

    if (typeof value === "string") {
        try {
            const parsed = JSON.parse(value) as unknown;
            return Array.isArray(parsed)
                ? parsed.map(String).map((item) => item.trim()).filter(Boolean)
                : [];
        } catch {
            return [];
        }
    }

    return [];
};

const normalizedIncludesAny = (text: string, terms: string[]) => {
    const normalizedText = normalizeVietnameseText(text);
    const compactText = normalizedText.replace(/\s+/g, "");

    return terms.some((term) => {
        const normalizedTerm = normalizeVietnameseText(term);
        return normalizedText.includes(normalizedTerm) ||
            compactText.includes(normalizedTerm.replace(/\s+/g, ""));
    });
};

const getImageEvidenceText = (images: ListingImageRecord[]) =>
    images.flatMap((image) => [
        image.caption ?? "",
        image.displayTitle ?? "",
        image.altText ?? "",
        image.aiImageType ?? "",
        image.aiDescription ?? "",
        ...safeStringArray(image.aiSceneTags),
        ...safeStringArray(image.aiAmenityTags),
        ...safeStringArray(image.aiQualityWarnings),
    ]).join(" ");

const getListingEvidenceText = (
    listing: ListingDocument,
    amenityNames: string[],
    images: ListingImageRecord[],
) =>
    [
        listing.title,
        listing.description,
        listing.addressLine,
        listing.ward,
        listing.district,
        listing.city,
        listing.stateRegion ?? "",
        listing.searchText ?? "",
        listing.aiImageSummary ?? "",
        ...safeStringArray(listing.aiImageTags),
        ...amenityNames,
        getImageEvidenceText(images),
    ].join(" ");

const parseDistanceValue = (rawValue: string, rawUnit: string) => {
    const value = Number(rawValue.replace(",", "."));
    if (!Number.isFinite(value) || value <= 0) {
        return undefined;
    }

    const unit = rawUnit.toLowerCase();
    return unit.startsWith("km") || unit.startsWith("kilo")
        ? Math.round(value * 1000)
        : Math.round(value);
};

const extractBeachDistanceFromText = (text: string) => {
    const normalized = normalizeVietnameseText(text);
    const target = "(?:bien|bo bien|bai tam|bai sau|bai truoc|bai long cung|long cung|thuy van|tran phu|bai dau)";
    const unit = "(m|met|meter|meters|km|kilomet|kilometer|kilometers)";
    const patterns = [
        new RegExp(`(?:cach|gan|sat)?\\s*${target}(?:\\s+[a-z0-9]+){0,3}\\s+(\\d+(?:[,.]\\d+)?)\\s*${unit}\\b`),
        new RegExp(`cach\\s+(?:khoang\\s+)?(\\d+(?:[,.]\\d+)?)\\s*${unit}\\s*(?:toi|den|ra)?\\s*${target}\\b`),
        new RegExp(`distance to beach\\s*:?\\s*(\\d+(?:[,.]\\d+)?)\\s*${unit}\\b`),
        new RegExp(`distancetobeach\\s*:?\\s*(\\d+(?:[,.]\\d+)?)\\s*${unit}\\b`),
    ];

    for (const pattern of patterns) {
        const match = normalized.match(pattern);
        if (match) {
            return parseDistanceValue(match[1], match[2]);
        }
    }

    return undefined;
};

const getDistanceToBeachMeters = (listing: ListingDocument) => {
    const latitude = toNumber(listing.latitude, Number.NaN);
    const longitude = toNumber(listing.longitude, Number.NaN);

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        return null;
    }

    const nearest = beachAnchors.reduce(
        (best, beach) => {
            const distance = getDistanceMeters(latitude, longitude, beach.latitude, beach.longitude);
            return !best || distance < best.distance ? { ...beach, distance } : best;
        },
        null as null | { name: string; latitude: number; longitude: number; distance: number },
    );

    if (!nearest) {
        return null;
    }

    return {
        beachName: nearest.name,
        meters: Math.round(nearest.distance),
    };
};

const getAmenityEvidenceCodes = (
    filters: SemanticSearchFilters,
    evidenceText: string,
    listingAmenityIds: number[],
) =>
    uniqueStrings(
        filters.amenityCodes.filter((code) => {
            const terms = amenityEvidenceTerms[code] ?? [code];
            const fallbackAmenityId = defaultAmenityAliases[code];

            return normalizedIncludesAny(evidenceText, terms) ||
                (fallbackAmenityId !== undefined && listingAmenityIds.includes(fallbackAmenityId));
        }),
    );

const buildMatchSignals = (
    listing: ListingDocument,
    filters: SemanticSearchFilters,
    input: {
        amenityIds: number[];
        amenityNames: string[];
        images: ListingImageRecord[];
        vungTauAreaKeys: string[];
    },
): NonNullable<SemanticSearchItem["matchSignals"]> => {
    const evidenceText = getListingEvidenceText(listing, input.amenityNames, input.images);
    const amenityCodes = getAmenityEvidenceCodes(filters, evidenceText, input.amenityIds);
    const coordinateDistance = getDistanceToBeachMeters(listing);
    const textDistanceMeters = extractBeachDistanceFromText(evidenceText);
    const beachDistanceMeters = textDistanceMeters ?? coordinateDistance?.meters;
    const beachByArea = input.vungTauAreaKeys.some((areaKey) => nearBeachAreaKeys.has(areaKey));
    const beachByDistance = beachDistanceMeters !== undefined && beachDistanceMeters <= 700;
    const beach = normalizedIncludesAny(evidenceText, beachEvidenceTerms) || beachByArea || beachByDistance;
    const locationAreaMatch = filters.vungTauAreaKeys.length > 0 &&
        filters.vungTauAreaKeys.some((areaKey) => input.vungTauAreaKeys.includes(areaKey));

    return {
        amenityCodes,
        pool: amenityCodes.includes("pool") || normalizedIncludesAny(evidenceText, amenityEvidenceTerms.pool),
        beach,
        ...(beachDistanceMeters !== undefined ? { beachDistanceMeters } : {}),
        ...(coordinateDistance?.beachName ? { beachName: coordinateDistance.beachName } : {}),
        exactBedrooms: Boolean(filters.bedrooms && listing.bedrooms === filters.bedrooms),
        largerBedroomsFallback: Boolean(filters.bedrooms && listing.bedrooms > filters.bedrooms),
        locationAreaMatch,
    };
};

export const getAmenityLookup = async () => {
    const amenities = await Amenity.findAll({
        where: {
            active: true,
            isActive: true,
            deletedAt: null,
        },
        attributes: ["amenityId", "name"],
    });

    const rows = amenities.map((amenity) => ({
        amenityId: amenity.amenityId,
        name: amenity.name,
    }));

    const byId = new Map(rows.map((amenity) => [amenity.amenityId, amenity]));

    const byNormalizedName = new Map<string, number>();

    for (const amenity of rows) {
        const key = normalizeVietnameseText(amenity.name).replace(/\s+/g, "");
        byNormalizedName.set(key, amenity.amenityId);
    }

    const bySemanticCode = new Map<string, number>();

    for (const [code, fallbackId] of Object.entries(defaultAmenityAliases)) {
        const existingByName = byNormalizedName.get(code);
        const existingByFallbackId = byId.get(fallbackId);

        if (existingByName) {
            bySemanticCode.set(code, existingByName);
        } else if (existingByFallbackId) {
            bySemanticCode.set(code, existingByFallbackId.amenityId);
        }
    }

    for (const amenity of rows) {
        const normalized = normalizeVietnameseText(amenity.name).replace(/\s+/g, "");
        bySemanticCode.set(normalized, amenity.amenityId);
    }

    return {
        rows,
        byId,
        byNormalizedName,
        bySemanticCode,
    };
};

export const resolveAmenityIds = async (values: Array<string | number>) => {
    if (values.length === 0) return [];

    const { bySemanticCode, byNormalizedName, byId } = await getAmenityLookup();
    const resolvedIds: number[] = [];

    for (const value of values) {
        if (typeof value === "number" || /^\d+$/.test(String(value))) {
            const id = Number(value);

            if (byId.has(id)) {
                resolvedIds.push(id);
            }

            continue;
        }

        const key = normalizeVietnameseText(String(value)).replace(/\s+/g, "");

        const amenityId =
            bySemanticCode.get(key) ??
            byNormalizedName.get(key);

        if (amenityId) {
            resolvedIds.push(amenityId);
        }
    }

    return uniqueNumbers(resolvedIds);
};

const getReviewSummaryMap = async (listingIds: number[]) => {
    if (listingIds.length === 0) {
        return new Map<number, ReviewSummary>();
    }

    const reviews = await Review.findAll({
        where: {
            listingId: { [Op.in]: listingIds },
            isVisible: true,
            deletedAt: null,
        },
        attributes: ["listingId", "rating", "comment", "createdAt"],
        order: [["createdAt", "DESC"]],
    });

    const summaryMap = new Map<
        number,
        {
            ratingSum: number;
            reviewCount: number;
            reviewSnippets: string[];
        }
    >();

    for (const review of reviews) {
        const current = summaryMap.get(review.listingId) ?? {
            ratingSum: 0,
            reviewCount: 0,
            reviewSnippets: [],
        };

        current.ratingSum += review.rating;
        current.reviewCount += 1;

        if (review.comment && current.reviewSnippets.length < 3) {
            current.reviewSnippets.push(review.comment.slice(0, 180));
        }

        summaryMap.set(review.listingId, current);
    }

    return new Map(
        Array.from(summaryMap.entries()).map(([listingId, summary]) => [
            listingId,
            {
                ratingAvg: Number((summary.ratingSum / summary.reviewCount).toFixed(1)),
                reviewCount: summary.reviewCount,
                reviewSnippets: summary.reviewSnippets,
            },
        ]),
    );
};

const isCalendarAvailable = (
    calendarRows: ListingAvailabilityDayRecord[],
    checkIn?: string,
    checkOut?: string,
) => {
    if (!checkIn || !checkOut) return true;

    const calendarByDate = new Map(calendarRows.map((row) => [row.date, row] as const));

    return listNights(checkIn, checkOut).every((date) => {
        const day = calendarByDate.get(date);
        return !day || (day.isAvailable && !day.isBlockedByHost);
    });
};

const getBookedListingIds = async (listingIds: number[], checkIn?: string, checkOut?: string) => {
    if (!checkIn || !checkOut || listingIds.length === 0) {
        return new Set<number>();
    }

    const bookings = await Booking.findAll({
        where: {
            listingId: { [Op.in]: listingIds },
            ...buildActiveBookingStatusWhere(),
            ...buildBookingDateOverlapWhere(checkIn, checkOut),
        },
        attributes: ["listingId"],
    });

    return new Set(bookings.map((booking) => booking.listingId));
};

const getListingLocationText = (listing: ListingDocument) =>
    [
        listing.title,
        listing.description,
        listing.addressLine,
        listing.ward,
        listing.district,
        listing.city,
        listing.stateRegion ?? "",
    ].join(" ");

const isListingAllowedForVungTauSearch = (listing: ListingDocument, forceVungTauOnly: boolean) => {
    if (!forceVungTauOnly) return true;
    return isVungTauRelatedText(getListingLocationText(listing));
};

export const getActiveListingIndexRecords = async (
    forceVungTauOnly = true,
): Promise<ListingIndexRecord[]> => {
    const listings = await Listing.findAll({
        where: {
            status: { [Op.in]: semanticPublicListingStatuses },
            deletedAt: null,
        },
        order: [["listingId", "ASC"]],
    });

    const filteredListings = listings.filter((listing) =>
        isListingAllowedForVungTauSearch(listing, forceVungTauOnly),
    );

    const listingIds = filteredListings.map((listing) => listing.listingId);

    const [amenityIdsMap, reviewSummaryMap, amenityLookup, listingRulesEntries] = await Promise.all([
        getListingAmenityIdsMap(filteredListings),
        getReviewSummaryMap(listingIds),
        getAmenityLookup(),
        Promise.all(
            filteredListings.map(async (listing) => [
                listing.listingId,
                await getListingRulesForListing(listing),
            ] as const),
        ),
    ]);
    const listingRulesMap = new Map(listingRulesEntries);

    return filteredListings.map((listing) => {
        const amenityIds = amenityIdsMap.get(listing.listingId) ?? [];

        return {
            listing,
            amenityIds,
            amenityNames: amenityIds
                .map((amenityId) => amenityLookup.byId.get(amenityId)?.name)
                .filter((name): name is string => Boolean(name)),
            reviewSummary: reviewSummaryMap.get(listing.listingId) ?? {
                ratingAvg: 0,
                reviewCount: 0,
                reviewSnippets: [],
            },
            rules: listingRulesMap.get(listing.listingId) ?? {
                checkInFrom: listing.checkInFrom,
                checkOutBefore: listing.checkOutBefore,
                smokingAllowed: listing.smokingAllowed,
                petsAllowed: listing.petsAllowed,
                partyAllowed: listing.partyAllowed,
                quietHours: listing.quietHours ?? null,
            },
        };
    });
};

export const getListingIndexRecord = async (
    listingId: number,
    forceVungTauOnly = true,
): Promise<ListingIndexRecord | null> => {
    const listing = await Listing.findOne({
        where: {
            listingId,
            status: { [Op.in]: semanticPublicListingStatuses },
            deletedAt: null,
        },
    });

    if (!listing || !isListingAllowedForVungTauSearch(listing, forceVungTauOnly)) {
        return null;
    }

    const [amenityIdsMap, reviewSummaryMap, amenityLookup, rules] = await Promise.all([
        getListingAmenityIdsMap([listing]),
        getReviewSummaryMap([listing.listingId]),
        getAmenityLookup(),
        getListingRulesForListing(listing),
    ]);
    const amenityIds = amenityIdsMap.get(listing.listingId) ?? [];

    return {
        listing,
        amenityIds,
        amenityNames: amenityIds
            .map((amenityId) => amenityLookup.byId.get(amenityId)?.name)
            .filter((name): name is string => Boolean(name)),
        reviewSummary: reviewSummaryMap.get(listing.listingId) ?? {
            ratingAvg: 0,
            reviewCount: 0,
            reviewSnippets: [],
        },
        rules,
    };
};

const buildLegacyListingSearchDocument = (record: ListingIndexRecord) => {
    const { listing, amenityNames, reviewSummary } = record;
    const locationText = getListingLocationText(listing);
    const vungTauAreaKeys = inferVungTauAreaKeys(locationText);
    const vungTauAreaNames = getVungTauAreaDisplayNames(vungTauAreaKeys);

    const stayPurposeHints = [
        listing.maxGuests >= 4 ? "phù hợp gia đình hoặc nhóm bạn" : "",
        listing.maxGuests === 2 ? "phù hợp cặp đôi hoặc hai người" : "",
        listing.roomType === "entire_place" ? "nguyên căn, riêng tư" : "",
        listing.propertyType === "villa" ? "villa nghỉ dưỡng" : "",
        listing.propertyType === "hotel" ? "khách sạn lưu trú ngắn ngày" : "",
        listing.propertyType === "apartment" ? "căn hộ tiện nghi" : "",
        vungTauAreaNames.length > 0 ? `khu vực Vũng Tàu: ${vungTauAreaNames.join(", ")}` : "",
    ].filter(Boolean);

    return [
        `Tên nơi ở: ${listing.title}.`,
        `Mô tả: ${listing.description}.`,
        `Địa chỉ: ${listing.addressLine}, ${listing.ward}, ${listing.district}, ${listing.city}.`,
        `Tỉnh/thành hoặc vùng: ${listing.stateRegion ?? listing.city}.`,
        `Khu vực du lịch Vũng Tàu: ${vungTauAreaNames.join(", ") || "không xác định cụ thể"}.`,
        `Loại chỗ ở: ${listing.propertyType}. Loại phòng: ${listing.roomType}.`,
        `Sức chứa: tối đa ${listing.maxGuests} khách, ${listing.bedrooms} phòng ngủ, ${listing.beds} giường, ${listing.bathrooms} phòng tắm.`,
        `Tiện nghi: ${amenityNames.join(", ") || "không có dữ liệu"}.`,
        `Giá cơ bản mỗi đêm: ${toNumber(listing.basePrice)} ${listing.currency}.`,
        `Giá cuối tuần: ${listing.weekendPrice ? toNumber(listing.weekendPrice) : "không có"}.`,
        `Phù hợp: ${stayPurposeHints.join(", ") || "lưu trú du lịch Vũng Tàu"}.`,
        `Quy định: hút thuốc ${listing.smokingAllowed ? "được phép" : "không được phép"}, thú cưng ${listing.petsAllowed ? "được phép" : "không được phép"}, tiệc tùng ${listing.partyAllowed ? "được phép" : "không được phép"}.`,
        `Check-in từ ${listing.checkInFrom}, check-out trước ${listing.checkOutBefore}.`,
        `Đánh giá trung bình: ${reviewSummary.ratingAvg}/5 từ ${reviewSummary.reviewCount} đánh giá.`,
        `Nhận xét nổi bật: ${reviewSummary.reviewSnippets.join(" | ") || "chưa có nhận xét"}.`,
        `Ngữ cảnh tìm kiếm: du lịch biển Vũng Tàu, nghỉ dưỡng cuối tuần, gần biển, căn hộ, khách sạn, villa, homestay.`,
    ]
        .join("\n")
        .replace(/\s+/g, " ")
        .trim();
};

export const buildListingSearchDocument = (record: ListingIndexRecord) => {
    const { listing, amenityNames, reviewSummary, rules } = record;
    const locationText = getListingLocationText(listing);
    const vungTauAreaKeys = inferVungTauAreaKeys(locationText);
    const vungTauAreaNames = getVungTauAreaDisplayNames(vungTauAreaKeys);
    const distanceToBeach = getDistanceToBeachMeters(listing);
    const aiImageTags = safeStringArray(listing.aiImageTags);
    const aiImageSummary = listing.aiImageSummary?.trim() ?? "";

    const stayPurposeHints = [
        listing.maxGuests >= 4 ? "phu hop gia dinh hoac nhom ban" : "",
        listing.maxGuests === 2 ? "phu hop cap doi hoac hai nguoi" : "",
        listing.roomType === "entire_place" ? "nguyen can, rieng tu" : "",
        listing.propertyType === "villa" ? "villa nghi duong" : "",
        listing.propertyType === "hotel" ? "khach san luu tru ngan ngay" : "",
        listing.propertyType === "apartment" ? "can ho tien nghi" : "",
        vungTauAreaNames.length > 0 ? `locationGroup: ${vungTauAreaNames.join(", ")}` : "",
    ].filter(Boolean);

    return [
        `title: ${listing.title}.`,
        `description: ${listing.description}.`,
        `address: ${listing.addressLine}, ${listing.ward}, ${listing.district}, ${listing.city}, ${listing.stateRegion ?? listing.city}.`,
        `locationGroup: ${vungTauAreaNames.join(", ") || "unknown"}.`,
        `propertyType: ${listing.propertyType}. roomType: ${listing.roomType}.`,
        `maxGuests: ${listing.maxGuests}. bedrooms: ${listing.bedrooms}. beds: ${listing.beds}. bathrooms: ${listing.bathrooms}.`,
        `amenities: ${amenityNames.join(", ") || "none"}.`,
        `rules: checkInFrom ${rules.checkInFrom ?? listing.checkInFrom}, checkOutBefore ${rules.checkOutBefore ?? listing.checkOutBefore}, smokingAllowed ${rules.smokingAllowed}, petsAllowed ${rules.petsAllowed}, partyAllowed ${rules.partyAllowed}, quietHours ${rules.quietHours ?? "none"}.`,
        distanceToBeach ? `distanceToBeach: ${distanceToBeach.meters} meters to ${distanceToBeach.beachName}.` : "",
        `basePricePerNight: ${toNumber(listing.basePrice)} ${listing.currency}. weekendPrice: ${listing.weekendPrice ? toNumber(listing.weekendPrice) : "none"}.`,
        `fit: ${stayPurposeHints.join(", ") || "du lich bien Vung Tau"}.`,
        aiImageTags.length > 0 ? `aiImageTags: ${aiImageTags.join(", ")}.` : "",
        aiImageSummary ? `aiImageSummary: ${aiImageSummary}.` : "",
        `reviewHighlights: ${reviewSummary.reviewSnippets.join(" | ") || "none"}.`,
        `rating: ${reviewSummary.ratingAvg}/5 from ${reviewSummary.reviewCount} reviews.`,
        "searchContext: du lich bien Vung Tau, nghi duong cuoi tuan, gan bien, can ho, khach san, villa, homestay.",
    ]
        .filter(Boolean)
        .join("\n")
        .replace(/\s+/g, " ")
        .trim();
};

export const buildListingVectorPayload = (record: ListingIndexRecord): ListingVectorPayload => {
    const { listing, amenityIds, amenityNames } = record;
    const locationText = getListingLocationText(listing);
    const vungTauAreaKeys = inferVungTauAreaKeys(locationText);
    const vungTauAreaNames = getVungTauAreaDisplayNames(vungTauAreaKeys);

    return {
        listing_id: listing.listingId,
        title: listing.title,

        city: listing.city,
        city_key: normalizeKey(listing.city),
        district: listing.district,
        district_key: normalizeKey(listing.district),
        ward: listing.ward,
        ward_key: normalizeKey(listing.ward),

        location_keys: buildLocationKeys({
            city: listing.city,
            district: listing.district,
            ward: listing.ward,
            addressLine: listing.addressLine,
            title: listing.title,
            description: listing.description,
        }),
        vung_tau_area_keys: vungTauAreaKeys,
        vung_tau_area_names: vungTauAreaNames,

        base_price: toNumber(listing.basePrice),
        max_guests: listing.maxGuests,

        amenity_ids: amenityIds,
        amenity_names: amenityNames,

        property_type: listing.propertyType,
        room_type: listing.roomType,

        status: listing.status as ListingVectorPayload["status"],
    };
};

export const listSemanticSynonymRows = async () => {
    try {
        return await SemanticSynonym.findAll({
            attributes: ["keyword", "synonyms"],
            order: [["keyword", "ASC"]],
        });
    } catch {
        return [];
    }
};

export const upsertListingEmbeddingRecord = async (input: {
    listingId: number;
    embeddingProvider: string;
    embeddingModel: string;
    embeddingVector?: number[] | null;
    qdrantPointId?: string | null;
    searchableText: string;
    version: string;
}) => {
    const where = {
        listingId: input.listingId,
        embeddingProvider: input.embeddingProvider,
        embeddingModel: input.embeddingModel,
        version: input.version,
    };
    const existing = await ListingEmbedding.findOne({ where });
    const values = {
        ...where,
        embeddingVector: input.embeddingVector ?? null,
        qdrantPointId: input.qdrantPointId ?? null,
        searchableText: input.searchableText,
    };

    if (existing) {
        await existing.update(values);
        return existing;
    }

    return ListingEmbedding.create(values);
};

export const recordSemanticSearchLog = async (input: {
    userId?: number | null;
    query: string;
    parsedFilters: Record<string, unknown>;
    resultListingIds: number[];
    clickedListingId?: number | null;
    bookedListingId?: number | null;
}) => {
    try {
        await SearchLog.create({
            userId: input.userId ?? null,
            query: input.query.slice(0, 500),
            parsedFilters: input.parsedFilters,
            resultListingIds: input.resultListingIds,
            clickedListingId: input.clickedListingId ?? null,
            bookedListingId: input.bookedListingId ?? null,
        });
    } catch {
        // Search logging should never make the user-facing query fail.
    }
};

export const findAvailableListingItems = async (
    listingIds: number[],
    filters: SemanticSearchFilters,
    semanticScoreMap: Map<number, number>,
): Promise<SemanticSearchItem[]> => {
    if (listingIds.length === 0) return [];

    const where: Record<string, unknown> = {
        listingId: { [Op.in]: listingIds },
        status: { [Op.in]: semanticPublicListingStatuses },
        deletedAt: null,
        maxGuests: { [Op.gte]: filters.guests },
    };

    if (filters.minPrice !== undefined || filters.maxPrice !== undefined) {
        where.basePrice = {
            ...(filters.minPrice !== undefined ? { [Op.gte]: filters.minPrice } : {}),
            ...(filters.maxPrice !== undefined ? { [Op.lte]: filters.maxPrice } : {}),
        };
    }

    if (filters.bedrooms) {
        where.bedrooms = { [Op.gte]: filters.bedrooms };
    }

    if (filters.beds) {
        where.beds = { [Op.gte]: filters.beds };
    }

    if (filters.bathrooms) {
        where.bathrooms = { [Op.gte]: filters.bathrooms };
    }

    if (filters.propertyType) {
        where.propertyType = filters.propertyType;
    }

    if (filters.roomType) {
        where.roomType = filters.roomType;
    }

    const listings = await Listing.findAll({ where });

    const [amenityIdsMap, imageMap, availabilityMap, reviewSummaryMap, bookedListingIds, amenityLookup] =
        await Promise.all([
            getListingAmenityIdsMap(listings),
            getListingImagesMap(listings),
            getAvailabilityCalendarMap(listings),
            getReviewSummaryMap(listings.map((listing) => listing.listingId)),
            getBookedListingIds(
                listings.map((listing) => listing.listingId),
                filters.checkIn,
                filters.checkOut,
            ),
            getAmenityLookup(),
        ]);

    return listings
        .filter((listing) => {
            if (!isListingAllowedForVungTauSearch(listing, filters.forceVungTauOnly)) {
                return false;
            }

            if (filters.districtKey && normalizeKey(listing.district) !== filters.districtKey) {
                return false;
            }

            const locationText = getListingLocationText(listing);
            const listingAreaKeys = inferVungTauAreaKeys(locationText);

            if (
                filters.locationAreaFilterMode === "hard" &&
                filters.vungTauAreaKeys.length > 0 &&
                !filters.vungTauAreaKeys.some((areaKey) => listingAreaKeys.includes(areaKey))
            ) {
                return false;
            }

            if (bookedListingIds.has(listing.listingId)) {
                return false;
            }

            if (
                !isCalendarAvailable(
                    availabilityMap.get(listing.listingId) ?? [],
                    filters.checkIn,
                    filters.checkOut,
                )
            ) {
                return false;
            }

            return true;
        })
        .map((listing) => {
            const images = imageMap.get(listing.listingId) ?? [];
            const reviewSummary = reviewSummaryMap.get(listing.listingId) ?? {
                ratingAvg: 0,
                reviewCount: 0,
                reviewSnippets: [],
            };

            const locationText = getListingLocationText(listing);
            const vungTauAreaKeys = inferVungTauAreaKeys(locationText);
            const semanticScore = semanticScoreMap.get(listing.listingId) ?? 0;
            const listingAmenityIds = amenityIdsMap.get(listing.listingId) ?? [];
            const amenityNames = listingAmenityIds
                .map((amenityId) => amenityLookup.byId.get(amenityId)?.name)
                .filter((name): name is string => Boolean(name));
            const matchSignals = buildMatchSignals(listing, filters, {
                amenityIds: listingAmenityIds,
                amenityNames,
                images,
                vungTauAreaKeys,
            });

            return {
                listingId: listing.listingId,
                title: listing.title,
                description: listing.description,

                basePrice: toNumber(listing.basePrice),
                weekendPrice: listing.weekendPrice === null ? null : toNumber(listing.weekendPrice),
                currency: listing.currency,

                ratingAvg: reviewSummary.ratingAvg,
                reviewCount: reviewSummary.reviewCount,

                isAvailable: true,

                addressLine: listing.addressLine,
                ward: listing.ward,
                district: listing.district,
                city: listing.city,

                vungTauAreas: getVungTauAreaDisplayNames(vungTauAreaKeys),
                vungTauAreaKeys,

                propertyType: listing.propertyType,
                roomType: listing.roomType,

                maxGuests: listing.maxGuests,
                bedrooms: listing.bedrooms,
                beds: listing.beds,
                bathrooms: toNumber(listing.bathrooms),

                imageUrl: images[0]?.url ?? null,

                semanticScore,
                keywordScore: 0,
                locationScore: 0,
                availabilityScore: 1,
                popularityScore: 0,
                featureScore: 0,
                finalScore: 0,
                scoreBreakdown: {
                    semanticScore,
                    keywordScore: 0,
                    locationScore: 0,
                    availabilityScore: 1,
                    popularityScore: 0,
                    featureScore: 0,
                },
                matchSignals,
                matchedReasons: [],
            };
        });
};

export const keywordSearchFallback = async (
    filters: SemanticSearchFilters,
): Promise<SemanticSearchItem[]> => {
    const where: Record<string, unknown> = {
        status: { [Op.in]: semanticPublicListingStatuses },
        deletedAt: null,
        maxGuests: { [Op.gte]: filters.guests },
    };

    if (filters.minPrice !== undefined || filters.maxPrice !== undefined) {
        where.basePrice = {
            ...(filters.minPrice !== undefined ? { [Op.gte]: filters.minPrice } : {}),
            ...(filters.maxPrice !== undefined ? { [Op.lte]: filters.maxPrice } : {}),
        };
    }

    if (filters.bedrooms) {
        where.bedrooms = { [Op.gte]: filters.bedrooms };
    }

    if (filters.beds) {
        where.beds = { [Op.gte]: filters.beds };
    }

    if (filters.bathrooms) {
        where.bathrooms = { [Op.gte]: filters.bathrooms };
    }

    if (filters.propertyType) {
        where.propertyType = filters.propertyType;
    }

    if (filters.roomType) {
        where.roomType = filters.roomType;
    }

    const listings = await Listing.findAll({
        where,
        limit: 100,
        order: [["listingId", "DESC"]],
    });

    const filteredListingIds = listings
        .filter((listing) => isListingAllowedForVungTauSearch(listing, filters.forceVungTauOnly))
        .filter((listing) => {
            // Enforce district filter if specified
            if (filters.districtKey && normalizeKey(listing.district) !== filters.districtKey) {
                return false;
            }

            if (filters.locationAreaFilterMode !== "hard" || filters.vungTauAreaKeys.length === 0) return true;

            const listingAreaKeys = inferVungTauAreaKeys(getListingLocationText(listing));
            return filters.vungTauAreaKeys.some((areaKey) => listingAreaKeys.includes(areaKey));
        })
        .map((listing) => listing.listingId);

    // Use score 0 — ranking will rely on keyword & location scores only.
    // This prevents the fallback from inflating irrelevant listings.
    return findAvailableListingItems(
        uniqueNumbers(filteredListingIds),
        filters,
        new Map(filteredListingIds.map((id) => [id, 0])),
    );
};
