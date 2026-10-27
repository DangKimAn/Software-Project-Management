import {
    detectLocationGroupsFromQuery,
    getLocationGroupAreaKey,
    type LocationGroupName,
} from "../../common/vung-tau-location-groups";
import type { PropertyType } from "../../models/listing";
import { ParsedQueryFilters, SemanticSearchRequest } from "./semantic-search.types";
import { normalizeVietnameseText, uniqueStrings } from "./semantic-search.utils";

/**
 * Light normalization: strips diacritics and lowercases, but preserves
 * dots, dashes, commas, slashes, and colons needed for price and date parsing.
 */
const normalizeLight = (text: string): string =>
    text
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9.,\-/:<=>=]+/g, " ")
        .replace(/\s+/g, " ");

// ─── City aliases ─────────────────────────────────────────────────────────────

const cityAliases: Record<string, string> = {
    // ── Vũng Tàu (supported) ─────────────────────────────────────────────────
    "vung tau": "Vung Tau",
    vungtau: "Vung Tau",
    "tp vung tau": "Vung Tau",
    "thanh pho vung tau": "Vung Tau",
    "ba ria vung tau": "Vung Tau",
    "br vt": "Vung Tau",
    brvt: "Vung Tau",
    vtau: "Vung Tau",
    "v tau": "Vung Tau",
    vt: "Vung Tau",

    // ── Other cities (unsupported – detection only) ──────────────────────────
    "ho chi minh": "TP Ho Chi Minh",
    "tp ho chi minh": "TP Ho Chi Minh",
    "sai gon": "TP Ho Chi Minh",
    saigon: "TP Ho Chi Minh",

    "nha trang": "Nha Trang",
    nhatrang: "Nha Trang",

    "da lat": "Da Lat",
    dalat: "Da Lat",

    "phan thiet": "Phan Thiet",
    phanthiet: "Phan Thiet",

    "mui ne": "Mui Ne",
    muine: "Mui Ne",

    "da nang": "Da Nang",
    danang: "Da Nang",

    "phu quoc": "Phu Quoc",
    phuquoc: "Phu Quoc",

    "long hai": "Long Hai",
    longhai: "Long Hai",

    "ho tram": "Ho Tram",
    hotram: "Ho Tram",

    "quy nhon": "Quy Nhon",
    quynhon: "Quy Nhon",

    "ha noi": "Ha Noi",
    hanoi: "Ha Noi",

    "ha long": "Ha Long",
    halong: "Ha Long",

    "hue": "Hue",

    "hoi an": "Hoi An",
    hoian: "Hoi An",

    "can tho": "Can Tho",
    cantho: "Can Tho",

    "ninh binh": "Ninh Binh",
    ninhbinh: "Ninh Binh",

    "sa pa": "Sa Pa",
    sapa: "Sa Pa",

    "con dao": "Con Dao",
    condao: "Con Dao",
};

// ─── Amenity synonyms ─────────────────────────────────────────────────────────

const amenitySynonyms: Record<string, string[]> = {
    wifi: ["wifi", "wi fi", "internet", "mang"],
    pool: [
        "ho boi",
        "ho boi rieng",
        "ho boi lon",
        "ho boi tre em",
        "be boi",
        "be boi rieng",
        "pool",
        "swimming pool",
        "co ho boi",
    ],
    parking: ["bai xe", "dau xe", "do xe", "parking", "cho dau xe", "nha xe", "gara", "garage", "cho do xe", "dau o to", "do o to", "dau xe hoi", "cho de xe", "san dau xe"],
    air_conditioning: ["dieu hoa", "may lanh", "air conditioning", "air conditioner", "ac"],
    kitchen: ["bep", "nau an", "kitchen", "co bep", "bep day du"],
    washer: ["may giat", "giat ui", "washer", "giat do"],
    tv: ["tv", "tivi", "truyen hinh"],
    balcony: ["ban cong", "balcony"],
    bathtub: ["bon tam", "bathtub", "bath tub", "bec tam", "jacuzzi", "tam bun", "spa", "hot tub"],
    breakfast: ["an sang", "bua sang", "buffet sang", "breakfast", "bua sang mien phi", "bao gom bua sang"],
    sea_view: ["view bien", "huong bien", "gan bien", "bien", "sea view", "ocean view", "nhin ra bien"],
    mountain_view: ["view nui", "huong nui", "mountain view"],
    garden: ["san vuon", "vuon", "garden", "co san", "co vuon", "san rong", "khuon vien"],
    desk: ["ban lam viec", "cong tac", "workspace", "desk", "lam viec", "remote work"],
    gym: ["phong gym", "gym", "fitness", "tap the duc"],
    bbq: ["bbq", "nuong", "bep nuong", "khu nuong", "lo nuong", "tiec nuong", "san nuong"],
    pet_friendly: ["cho thu cung", "thu cung", "mang cho", "cho meo", "thu nuoi", "pet"],
    karaoke: ["karaoke", "phong hat", "hat ho", "loa keo", "loa karaoke"],
    billiards: ["bida", "bi a", "billiards", "ban bida", "bida le"],
    elevator: ["thang may", "elevator", "lift"],
};

// ─── Property type synonyms ───────────────────────────────────────────────────

const propertyTypeSynonyms: Record<PropertyType, string[]> = {
    villa: ["villa", "biet thu", "biet thu nghi duong", "nha rieng lon", "nha nguyen can", "nguyen can"],
    apartment: ["can ho", "apartment", "chung cu", "studio"],
    hotel: ["khach san", "hotel"],
    homestay: ["homestay", "home stay", "nha nghi homestay", "nha nghi"],
};

type SemanticSynonymInput = {
    keyword: string;
    synonyms: string[] | string;
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRICE PARSING
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Million-scale unit keywords (after normalizeVietnameseText).
 * "tr", "trieu", "m", "mil", "million", "cu", "chai"
 */
const MILLION_UNITS = new Set(["tr", "trieu", "m", "mil", "million", "cu", "chai"]);
const THOUSAND_UNITS = new Set(["k", "nghin", "ngan"]);

/**
 * Detects whether a raw numeric string uses Vietnamese dot-for-thousands notation.
 * E.g. "4.000.000" has ≥2 dots separating groups of 3 → treat as 4000000
 * Vs. "3.5" has 1 dot → treat as 3.5 (decimal)
 */
const parseVietnameseNumber = (raw: string): number | undefined => {
    if (!raw) return undefined;

    // Strip whitespace
    let cleaned = raw.trim();

    // Vietnamese thousands separator: "4.000.000" → "4000000"
    if (/^\d{1,3}(\.\d{3})+$/.test(cleaned)) {
        cleaned = cleaned.replace(/\./g, "");
        const num = Number(cleaned);
        return Number.isFinite(num) ? num : undefined;
    }

    // Allow comma as decimal separator: "3,5" → "3.5"
    cleaned = cleaned.replace(/,/g, ".");

    const num = Number(cleaned);
    return Number.isFinite(num) ? num : undefined;
};

/**
 * Converts a (number, unit?) pair to VND.
 *
 * Handles:
 *   4tr → 4,000,000
 *   3.5m → 3,500,000
 *   500k → 500,000
 *   4.000.000 → 4,000,000
 *   4000000 → 4,000,000
 */
const amountToVnd = (numericRaw: string, unitRaw?: string): number | undefined => {
    const numeric = parseVietnameseNumber(numericRaw);
    if (numeric === undefined) return undefined;

    const unit = normalizeVietnameseText(unitRaw ?? "").trim();

    if (MILLION_UNITS.has(unit)) {
        return Math.round(numeric * 1_000_000);
    }

    if (THOUSAND_UNITS.has(unit)) {
        return Math.round(numeric * 1_000);
    }

    // No unit — if the number is small (< 100) assume millions for villa context
    // E.g. "villa 4" → likely 4 million, but "villa 4000000" → 4 million as-is
    if (!unit && numeric > 0) {
        if (numeric >= 100_000) {
            // Already in VND (e.g. 4000000, 500000)
            return Math.round(numeric);
        }
        if (numeric <= 100) {
            // Likely in millions (e.g. "villa 4" = 4M, "villa 3.5" = 3.5M)
            return Math.round(numeric * 1_000_000);
        }
        // Between 100-100000 — ambiguous, return as-is
        return Math.round(numeric);
    }

    return Math.round(numeric);
};

/**
 * Main regex for capturing a price amount + optional unit from normalized text.
 *
 * Captures: (number_part)(unit_part?)
 *
 * Number part: digits with optional decimal (comma or dot) — e.g. 4, 3.5, 3,5
 * Also supports Vietnamese dot-thousands: 4.000.000
 * Unit part: tr, trieu, m, mil, million, cu, chai, k, nghin, ngan
 */
const PRICE_AMOUNT_PATTERN =
    /(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai|k|nghin|ngan)?/;

/**
 * Pattern for "Ntr5" → N.5 million (e.g. "3tr5" = 3,500,000)
 */
const PRICE_TR_HALF_PATTERN = /(\d+)\s*tr\s*(\d)/;

/**
 * Pattern for "N triệu rưỡi" → N.5 million
 */
const PRICE_TRIEU_RUOI_PATTERN = /(\d+(?:[,.]\d+)?)\s*(?:trieu|tr)\s+ruoi/;

type PriceParseResult = {
    minPrice?: number;
    maxPrice?: number;
    priceMode?: "per_night" | "total";
};

/**
 * Parse a single price amount from a regex match.
 * Handles special "Ntr5" and "N triệu rưỡi" patterns first.
 */
const extractSinglePrice = (text: string): number | undefined => {
    // Check "3tr5" pattern first
    const trHalfMatch = text.match(PRICE_TR_HALF_PATTERN);
    if (trHalfMatch) {
        const whole = Number(trHalfMatch[1]);
        const frac = Number(trHalfMatch[2]);
        if (Number.isFinite(whole) && Number.isFinite(frac)) {
            return Math.round((whole + frac / 10) * 1_000_000);
        }
    }

    // Check "N triệu rưỡi" pattern
    const ruoiMatch = text.match(PRICE_TRIEU_RUOI_PATTERN);
    if (ruoiMatch) {
        const base = parseVietnameseNumber(ruoiMatch[1]);
        if (base !== undefined) {
            return Math.round((base + 0.5) * 1_000_000);
        }
    }

    // Standard amount+unit pattern
    const match = text.match(PRICE_AMOUNT_PATTERN);
    if (match) {
        return amountToVnd(match[1], match[2]);
    }

    return undefined;
};

/**
 * Parse all price-related information from a normalized query string.
 *
 * Handles:
 *   - "dưới 4tr" / "tối đa 4tr" / "không quá 4tr" / "<= 4tr"
 *   - "trên 5tr" / "hơn 5tr" / "tối thiểu 5tr" / ">= 5tr"
 *   - "từ 3tr đến 5tr" / "3-5tr" / "3tr đến 5tr"
 *   - "tầm 4tr" / "khoảng 4tr" / "cỡ 4tr" / "quanh 4tr"
 *   - "4tr đổ lại"
 *   - bare "villa 4tr" → approximate ±15%
 */
const parsePrice = (normalized: string): PriceParseResult => {
    const result: PriceParseResult = {};

    // ── Price mode detection ──────────────────────────────────────────────────
    if (
        /(?:\/dem|mot dem|moi dem|\/ngay|mot ngay|moi ngay|tren dem|each night)/.test(normalized)
    ) {
        result.priceMode = "per_night";
    } else if (
        /(?:tong|ca chuyen|ca trip|total|tat ca)/.test(normalized)
    ) {
        result.priceMode = "total";
    }

    // ── Range: "từ 3tr đến 5tr" / "3tr đến 5tr" / "3 đến 5 triệu" ──────────
    const rangeExplicit = normalized.match(
        /(?:tu\s+)?(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*((?:tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai|k|nghin|ngan)\b)?\s*(?:den|toi|~|-)\s*(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)(?!\d)\s*((?:tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai|k|nghin|ngan)\b)?(?!\s*(?:khach|nguoi|guest|pax))/,
    );
    if (rangeExplicit) {
        const lowUnit = rangeExplicit[2] || rangeExplicit[4];
        const highUnit = rangeExplicit[4] || rangeExplicit[2];
        // Require at least one price unit
        if (lowUnit || highUnit) {
            const low = amountToVnd(rangeExplicit[1], lowUnit);
            const high = amountToVnd(rangeExplicit[3], highUnit);
            if (low !== undefined && high !== undefined && low < high) {
                result.minPrice = low;
                result.maxPrice = high;
                return result;
            }
        }
    }

    // ── Dash range: "3-5tr" / "3tr-5tr" / "3m-5m" ───────────────────────────
    const dashRange = normalized.match(
        /(\d+(?:[,.]\d+)?)\s*((?:tr(?:ieu)?|m|cu|chai|k)\b)?\s*-\s*(\d+(?:[,.]\d+)?)(?!\d)\s*((?:tr(?:ieu)?|m|cu|chai|k)\b)?(?!\s*(?:khach|nguoi|guest|pax))/,
    );
    if (dashRange) {
        const lowUnit = dashRange[2] || dashRange[4];
        const highUnit = dashRange[4] || dashRange[2];
        // Require at least one price unit to avoid matching "10-30 khách"
        if (lowUnit || highUnit) {
            const low = amountToVnd(dashRange[1], lowUnit);
            const high = amountToVnd(dashRange[3], highUnit);
            if (low !== undefined && high !== undefined && low < high) {
                result.minPrice = low;
                result.maxPrice = high;
                return result;
            }
        }
    }

    // ── "N đổ lại" → maxPrice ────────────────────────────────────────────────
    const doLaiMatch = normalized.match(
        /(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m|cu|chai|k)?\s*do lai/,
    );
    if (doLaiMatch) {
        const price = amountToVnd(doLaiMatch[1], doLaiMatch[2]);
        if (price) {
            result.maxPrice = price;
            return result;
        }
    }

    // ── Under / max: "dưới 4tr" / "tối đa 4tr" / "không quá 4tr" / "<= 4tr" / "nhỏ hơn 4tr"
    const underMatch = normalized.match(
        /(?:duoi|nho hon|khong qua|toi da|max|<=?)\s+(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai|k|nghin|ngan)?/,
    );
    if (underMatch) {
        const price = amountToVnd(underMatch[1], underMatch[2]);
        if (price) {
            result.maxPrice = price;
            return result;
        }
    }

    // ── Over / min: "trên 5tr" / "hơn 5tr" / "tối thiểu 5tr" / ">= 5tr"
    const overMatch = normalized.match(
        /(?:tren|hon|lon hon|toi thieu|min|>=?)\s+(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai|k|nghin|ngan)?/,
    );
    if (overMatch) {
        const price = amountToVnd(overMatch[1], overMatch[2]);
        if (price) {
            result.minPrice = price;
            return result;
        }
    }

    // ── "từ Ntr" without "đến" → minPrice only ──────────────────────────────
    const tuOnlyMatch = normalized.match(
        /tu\s+(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m|cu|chai|k)?(?!\s*(?:den|toi|~))/,
    );
    if (tuOnlyMatch) {
        const price = amountToVnd(tuOnlyMatch[1], tuOnlyMatch[2]);
        if (price) {
            result.minPrice = price;
            return result;
        }
    }

    // ── Approximate: "tầm 4tr" / "khoảng 4tr" / "cỡ 4tr" / "quanh 4tr"
    const approxMatch = normalized.match(
        /(?:tam|khoang|co|quanh|xap xi)\s+(\d{1,3}(?:\.\d{3})+|\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai|k|nghin|ngan)?/,
    );
    if (approxMatch) {
        const price = amountToVnd(approxMatch[1], approxMatch[2]);
        if (price) {
            result.minPrice = Math.round(price * 0.85);
            result.maxPrice = Math.round(price * 1.15);
            return result;
        }
    }

    // ── Bare price: "villa 4tr" → approximate ±15% ──────────────────────────
    // Only trigger when there's a clear price unit (tr, m, cu, etc.) to avoid
    // matching random numbers like guest counts or room counts.
    const bareMatch = normalized.match(
        /(\d+(?:[,.]\d+)?)\s*(tr(?:ieu)?|m(?:il(?:lion)?)?|cu|chai)\b/,
    );
    if (bareMatch && !result.minPrice && !result.maxPrice) {
        const price = amountToVnd(bareMatch[1], bareMatch[2]);
        if (price) {
            result.minPrice = Math.round(price * 0.85);
            result.maxPrice = Math.round(price * 1.15);
            return result;
        }
    }

    // ── Check "Ntr5" pattern (e.g. "3tr5") as bare price ────────────────────
    const trHalfBare = normalized.match(PRICE_TR_HALF_PATTERN);
    if (trHalfBare && !result.minPrice && !result.maxPrice) {
        const price = extractSinglePrice(normalized);
        if (price) {
            result.minPrice = Math.round(price * 0.85);
            result.maxPrice = Math.round(price * 1.15);
            return result;
        }
    }

    // ── Check "N triệu rưỡi" pattern as bare price ─────────────────────────
    const ruoiBare = normalized.match(PRICE_TRIEU_RUOI_PATTERN);
    if (ruoiBare && !result.minPrice && !result.maxPrice) {
        const price = extractSinglePrice(normalized);
        if (price) {
            result.minPrice = Math.round(price * 0.85);
            result.maxPrice = Math.round(price * 1.15);
            return result;
        }
    }

    // ── Large bare number that looks like VND: "villa 4000000" ──────────────
    const largeBareMatch = normalized.match(/(\d{6,})/);
    if (largeBareMatch && !result.minPrice && !result.maxPrice) {
        const price = amountToVnd(largeBareMatch[1]);
        if (price && price >= 100_000) {
            result.minPrice = Math.round(price * 0.85);
            result.maxPrice = Math.round(price * 1.15);
            return result;
        }
    }

    // ── Vietnamese dot-thousands: "4.000.000" ───────────────────────────────
    const vnDotMatch = normalized.match(/(\d{1,3}(?:\.\d{3})+)/);
    if (vnDotMatch && !result.minPrice && !result.maxPrice) {
        const price = amountToVnd(vnDotMatch[1]);
        if (price && price >= 100_000) {
            result.minPrice = Math.round(price * 0.85);
            result.maxPrice = Math.round(price * 1.15);
            return result;
        }
    }

    return result;
};

// ═══════════════════════════════════════════════════════════════════════════════
// GUEST PARSING
// ═══════════════════════════════════════════════════════════════════════════════

const BEACH_DISTANCE_TARGET_PATTERN =
    "(?:bien|bo bien|bai tam|bai sau|bai truoc|bai long cung|long cung|thuy van|tran phu|bai dau)";
const DISTANCE_UNIT_PATTERN = "(?:m|met|meter|meters|km|kilomet|kilometer|kilometers)";

const stripBeachDistanceForPriceParsing = (normalized: string) =>
    normalized
        .replace(
            new RegExp(
                `(?:cach|gan|sat)?\\s*${BEACH_DISTANCE_TARGET_PATTERN}(?:\\s+[a-z0-9]+){0,3}\\s+\\d+(?:[,.]\\d+)?\\s*${DISTANCE_UNIT_PATTERN}\\b`,
                "g",
            ),
            " ",
        )
        .replace(
            new RegExp(
                `cach\\s+(?:khoang\\s+)?\\d+(?:[,.]\\d+)?\\s*${DISTANCE_UNIT_PATTERN}\\s*(?:toi|den|ra)?\\s*${BEACH_DISTANCE_TARGET_PATTERN}\\b`,
                "g",
            ),
            " ",
        );

type GuestParseResult = {
    guests?: number;
    capacity?: number;
};

const parseGuests = (normalized: string): GuestParseResult => {
    // ── Range: "10-30 khách" / "từ 10 đến 30 khách" → use max ───────────────
    const rangeMatch = normalized.match(
        /(?:tu\s+)?(\d+)\s*(?:-|den|toi)\s*(\d+)\s*(?:nguoi|khach|guest|pax)/,
    );
    if (rangeMatch) {
        const max = Math.max(Number(rangeMatch[1]), Number(rangeMatch[2]));
        return { guests: max, capacity: max };
    }

    // ── Explicit: "20 khách" / "cho 20 người" / "nhóm 20" / "đoàn 20" ──────
    const explicitMatch = normalized.match(
        /(?:cho\s+)?(\d+)\s*(?:nguoi|khach|guest|pax)/,
    );
    if (explicitMatch) {
        const count = Number(explicitMatch[1]);
        return { guests: count, capacity: count };
    }

    // ── "nhóm N" / "đoàn N" without suffix ──────────────────────────────────
    const groupMatch = normalized.match(/(?:nhom|doan)\s+(\d+)/);
    if (groupMatch) {
        const count = Number(groupMatch[1]);
        return { guests: count, capacity: count };
    }

    // ── "khoảng/tầm N khách" ────────────────────────────────────────────────
    const approxMatch = normalized.match(
        /(?:khoang|tam)\s+(\d+)\s*(?:nguoi|khach|guest|pax)/,
    );
    if (approxMatch) {
        const count = Number(approxMatch[1]);
        return { guests: count, capacity: count };
    }

    // ── Keyword-based hints ─────────────────────────────────────────────────
    if (normalized.includes("cap doi") || normalized.includes("couple")) {
        return { guests: 2, capacity: 2 };
    }

    if (normalized.includes("gia dinh nho")) {
        return { guests: 5, capacity: 5 };
    }

    if (
        normalized.includes("gia dinh") &&
        !normalized.includes("gia dinh nho") &&
        !normalized.includes("gia dinh co con")
    ) {
        return { guests: 6, capacity: 6 };
    }

    if (
        normalized.includes("nhom dong") ||
        normalized.includes("doan dong")
    ) {
        return { guests: 15, capacity: 15 };
    }

    if (
        normalized.includes("nhom lon") ||
        normalized.includes("doan") ||
        normalized.includes("ca nha") ||
        normalized.includes("nguyen can")
    ) {
        return { guests: 8, capacity: 8 };
    }

    return {};
};

// ═══════════════════════════════════════════════════════════════════════════════
// BEDROOM / BED / BATHROOM PARSING
// ═══════════════════════════════════════════════════════════════════════════════

type RoomParseResult = {
    bedrooms?: number;
    beds?: number;
    bathrooms?: number;
};

const parseRooms = (normalized: string): RoomParseResult => {
    const result: RoomParseResult = {};

    // ── Bedrooms: "4 phòng ngủ" / "4pn" / "4 PN" / "4 phòng" ───────────────
    const bedroomMatch = normalized.match(
        /(\d+)\s*(?:phong\s*ngu|pn\b|bedrooms?\b|br\b)/,
    );
    if (bedroomMatch) {
        result.bedrooms = Number(bedroomMatch[1]);
    } else {
        // "4 phòng" without "ngủ" — treat as bedrooms if no other context
        const roomOnlyMatch = normalized.match(/(?:nha\s+)?(\d+)\s*phong(?!\s*(?:tam|ve sinh|hat|gym|an))/);
        if (roomOnlyMatch) {
            result.bedrooms = Number(roomOnlyMatch[1]);
        }
    }

    // ── "nhiều phòng" hint ──────────────────────────────────────────────────
    if (!result.bedrooms && normalized.includes("nhieu phong")) {
        result.bedrooms = 4;
    }

    // ── Beds: "10 giường" / "10 bed" ────────────────────────────────────────
    const bedMatch = normalized.match(/(\d+)\s*(?:giuong|beds?\b)/);
    if (bedMatch) {
        result.beds = Number(bedMatch[1]);
    }

    // ── Bathrooms: "9 wc" / "9 toilet" / "9 phòng tắm" / "9 phòng vệ sinh"
    const bathMatch = normalized.match(
        /(\d+)\s*(?:wc|toilets?|nha ve sinh|phong tam|phong ve sinh|bathrooms?)/,
    );
    if (bathMatch) {
        result.bathrooms = Number(bathMatch[1]);
    }

    return result;
};

// ═══════════════════════════════════════════════════════════════════════════════
// DATE PARSING — Vietnam timezone (UTC+7)
// ═══════════════════════════════════════════════════════════════════════════════

type BeachParseResult = {
    nearBeach: boolean;
    beachDistanceMeters?: number;
};

const parseDistanceToMeters = (rawValue: string, rawUnit: string) => {
    const value = Number(rawValue.replace(",", "."));
    if (!Number.isFinite(value) || value <= 0) {
        return undefined;
    }

    const unit = rawUnit.toLowerCase();
    return unit.startsWith("km") || unit.startsWith("kilo")
        ? Math.round(value * 1000)
        : Math.round(value);
};

const firstBeachDistanceMatch = (normalized: string) => {
    const patterns = [
        new RegExp(
            `(?:cach|gan|sat)?\\s*${BEACH_DISTANCE_TARGET_PATTERN}(?:\\s+[a-z0-9]+){0,3}\\s+(\\d+(?:[,.]\\d+)?)\\s*(${DISTANCE_UNIT_PATTERN})\\b`,
        ),
        new RegExp(
            `cach\\s+(?:khoang\\s+)?(\\d+(?:[,.]\\d+)?)\\s*(${DISTANCE_UNIT_PATTERN})\\s*(?:toi|den|ra)?\\s*${BEACH_DISTANCE_TARGET_PATTERN}\\b`,
        ),
    ];

    for (const pattern of patterns) {
        const match = normalized.match(pattern);
        if (match) {
            return parseDistanceToMeters(match[1], match[2]);
        }
    }

    return undefined;
};

const parseBeachIntent = (normalized: string): BeachParseResult => {
    const beachDistanceMeters = firstBeachDistanceMatch(normalized);
    const nearBeach =
        beachDistanceMeters !== undefined ||
        [
            "gan bien",
            "sat bien",
            "gan bo bien",
            "sat bo bien",
            "di bo ra bien",
            "di bo ra bai",
            "ven bien",
            "bo bien",
            "gan bai tam",
            "gan bai sau",
            "gan bai truoc",
            "gan bai long cung",
            "gan thuy van",
            "gan tran phu",
            "cach bien",
            "cach bai sau",
            "cach bai truoc",
            "cach bai long cung",
        ].some((phrase) => normalized.includes(phrase));

    return {
        nearBeach,
        beachDistanceMeters,
    };
};

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;

/** Get "today" in Vietnam timezone as a UTC Date at midnight. */
const getVnToday = (now = new Date()): Date => {
    const vnMs = now.getTime() + VN_OFFSET_MS;
    const vnIso = new Date(vnMs).toISOString().slice(0, 10);
    return new Date(`${vnIso}T00:00:00.000Z`);
};

const formatDate = (date: Date) => date.toISOString().slice(0, 10);

const addDays = (date: Date, days: number) => {
    const next = new Date(date);
    next.setUTCDate(next.getUTCDate() + days);
    return next;
};

const pastDateMessage = "Không thể tìm phòng cho ngày trong quá khứ.";

const createPastDateIntent = (
    label: string,
    reason: "PAST_DATE_NOT_ALLOWED" | "PAST_DATE_IN_QUERY" = "PAST_DATE_IN_QUERY",
): ParsedQueryFilters["dateIntent"] => ({
    label,
    friendlyName: "Ngày đã chọn",
    reason,
    message: pastDateMessage,
});

/** Parse a specific date "D/M" or "D/M/Y" into a UTC Date. Uses the current VN year when year is omitted. */
const parseSpecificDateParts = (
    dayStr: string,
    monthStr: string,
    yearStr: string | undefined,
    today: Date,
): Date | null => {
    const day = parseInt(dayStr, 10);
    const month = parseInt(monthStr, 10) - 1; // 0-indexed

    if (day < 1 || day > 31 || month < 0 || month > 11) return null;

    const nowYear = today.getUTCFullYear();
    const year = yearStr ? parseInt(yearStr, 10) : nowYear;
    let candidate = new Date(Date.UTC(year, month, day));

    if (candidate.getUTCMonth() !== month) return null;

    return candidate;
};

const buildSingleDateIntent = (
    label: string,
    date: Date,
    today: Date,
    reason: "PAST_DATE_NOT_ALLOWED" | "PAST_DATE_IN_QUERY" = "PAST_DATE_IN_QUERY",
): ParsedQueryFilters["dateIntent"] => {
    if (date < today) {
        return createPastDateIntent(label, reason);
    }

    return {
        label,
        friendlyName: "Ngày đã chọn",
        checkIn: formatDate(date),
        checkOut: formatDate(addDays(date, 1)),
    };
};

const buildDateRangeIntent = (
    startDay: string,
    startMonth: string,
    startYear: string | undefined,
    endDay: string,
    endMonth: string,
    endYear: string | undefined,
    today: Date,
): ParsedQueryFilters["dateIntent"] | null => {
    const checkInDate = parseSpecificDateParts(startDay, startMonth, startYear, today);

    if (!checkInDate) {
        return null;
    }

    if (checkInDate < today) {
        return createPastDateIntent("date_range", "PAST_DATE_IN_QUERY");
    }

    const defaultEndYear = endYear ?? startYear ?? String(checkInDate.getUTCFullYear());
    let checkOutDate = parseSpecificDateParts(endDay, endMonth, defaultEndYear, today);

    if (checkOutDate && !endYear && checkOutDate <= checkInDate) {
        checkOutDate = new Date(Date.UTC(
            checkOutDate.getUTCFullYear() + 1,
            checkOutDate.getUTCMonth(),
            checkOutDate.getUTCDate(),
        ));
    }

    if (!checkOutDate || checkOutDate <= checkInDate) {
        return null;
    }

    return {
        label: "date_range",
        friendlyName: "Ngày đã chọn",
        checkIn: formatDate(checkInDate),
        checkOut: formatDate(checkOutDate),
    };
};

const parseDateIntent = (normalized: string, now = new Date(), lightNorm?: string): ParsedQueryFilters["dateIntent"] | undefined => {
    const today = getVnToday(now);

    // ── "hôm nay" ───────────────────────────────────────────────────────────
    if (normalized.includes("hom nay")) {
        return {
            label: "today",
            friendlyName: "Hôm nay",
            checkIn: formatDate(today),
            checkOut: formatDate(addDays(today, 1)),
        };
    }

    // ── "ngày mai" ──────────────────────────────────────────────────────────
    if (normalized.includes("ngay mai")) {
        const checkIn = addDays(today, 1);
        return {
            label: "tomorrow",
            friendlyName: "Ngày mai",
            checkIn: formatDate(checkIn),
            checkOut: formatDate(addDays(checkIn, 1)),
        };
    }

    // ── Specific day of week: "thứ 6 này" / "thứ sáu này" / "thứ 7 này" ───
    const dayOfWeekMap: Record<string, number> = {
        "thu 2": 1, "thu hai": 1,
        "thu 3": 2, "thu ba": 2,
        "thu 4": 3, "thu tu": 3,
        "thu 5": 4, "thu nam": 4,
        "thu 6": 5, "thu sau": 5,
        "thu 7": 6, "thu bay": 6,
        "chu nhat": 0, "cn": 0,
    };

    for (const [keyword, targetDay] of Object.entries(dayOfWeekMap)) {
        if (normalized.includes(keyword)) {
            const currentDay = today.getUTCDay();
            let daysUntil = (targetDay - currentDay + 7) % 7;
            if (daysUntil === 0) daysUntil = 7; // Next occurrence if today
            const checkIn = addDays(today, daysUntil);
            return {
                label: `day_of_week_${targetDay}`,
                friendlyName: `Thứ ${targetDay === 0 ? "Chủ nhật" : targetDay + 1}`,
                checkIn: formatDate(checkIn),
                checkOut: formatDate(addDays(checkIn, 1)),
            };
        }
    }

    // ── "cuối tuần sau" / "cuối tuần tới" ───────────────────────────────────
    if (normalized.includes("cuoi tuan sau") || normalized.includes("cuoi tuan toi")) {
        const daysUntilNextSaturday = ((6 - today.getUTCDay() + 7) % 7) + 7;
        const checkIn = addDays(today, daysUntilNextSaturday);
        return {
            label: "next_weekend",
            friendlyName: "Cuối tuần sau",
            checkIn: formatDate(checkIn),
            checkOut: formatDate(addDays(checkIn, 2)),
        };
    }

    // ── "cuối tuần này" / "cuối tuần" ───────────────────────────────────────
    if (normalized.includes("cuoi tuan")) {
        const daysUntilSaturday = (6 - today.getUTCDay() + 7) % 7 || 7;
        const checkIn = addDays(today, daysUntilSaturday);
        return {
            label: "this_weekend",
            friendlyName: "Cuối tuần này",
            checkIn: formatDate(checkIn),
            checkOut: formatDate(addDays(checkIn, 2)),
        };
    }

    // ── "tuần tới" / "tuần sau" ─────────────────────────────────────────────
    if (normalized.includes("tuan toi") || normalized.includes("tuan sau")) {
        const dow = today.getUTCDay();
        const daysUntilNextMonday = dow === 0 ? 1 : 8 - dow;
        const checkIn = addDays(today, daysUntilNextMonday);
        return {
            label: "next_week",
            friendlyName: "Tuần sau",
            checkIn: formatDate(checkIn),
            checkOut: formatDate(addDays(checkIn, 2)),
        };
    }

    // ── Date range: "10/6 đến 12/6" / "10/6-12/6" / "10-12/6" ──────────────
    const dateText = lightNorm ?? normalized;
    const dateRangeFullMatch = dateText.match(
        /(\d{1,2})\s*[/\-]\s*(\d{1,2})(?:\s*[/\-]\s*(\d{4}))?\s*(?:den|-)\s*(\d{1,2})\s*[/\-]\s*(\d{1,2})(?:\s*[/\-]\s*(\d{4}))?/,
    );
    if (dateRangeFullMatch) {
        const intent = buildDateRangeIntent(
            dateRangeFullMatch[1],
            dateRangeFullMatch[2],
            dateRangeFullMatch[3],
            dateRangeFullMatch[4],
            dateRangeFullMatch[5],
            dateRangeFullMatch[6],
            today,
        );
        if (intent) {
            return intent;
        }
    }

    // ── Short date range: "10-12/6" (same month) ────────────────────────────
    const shortRangeMatch = dateText.match(
        /(\d{1,2})\s*-\s*(\d{1,2})\s*\/\s*(\d{1,2})(?:\s*\/\s*(\d{4}))?/,
    );
    if (shortRangeMatch) {
        const intent = buildDateRangeIntent(
            shortRangeMatch[1],
            shortRangeMatch[3],
            shortRangeMatch[4],
            shortRangeMatch[2],
            shortRangeMatch[3],
            shortRangeMatch[4],
            today,
        );
        if (intent) {
            return intent;
        }
    }

    // ── "N ngày M đêm" → nights = M ────────────────────────────────────────
    const nightsDaysMatch = normalized.match(/(\d+)\s*ngay\s+(\d+)\s*dem/);
    if (nightsDaysMatch) {
        const nights = Number(nightsDaysMatch[2]);
        if (nights > 0) {
            const checkIn = addDays(today, 1); // default to tomorrow
            return {
                label: `${nightsDaysMatch[1]}_days_${nights}_nights`,
                friendlyName: `${nightsDaysMatch[1]} ngày ${nights} đêm`,
                checkIn: formatDate(checkIn),
                checkOut: formatDate(addDays(checkIn, nights)),
            };
        }
    }

    // ── "ngày D tháng M" / "D tháng M năm Y" ───────────────────────────────
    const textDateMatch = normalized.match(
        /(?:ngay\s+)?(\d{1,2})\s+thang\s+(\d{1,2})(?:\s+(?:nam\s+)?(\d{4}))?/,
    );
    if (textDateMatch) {
        const date = parseSpecificDateParts(textDateMatch[1], textDateMatch[2], textDateMatch[3], today);
        if (date) {
            return buildSingleDateIntent("specific_date", date, today);
        }
    }

    // ── Specific date: "15/6", "15-6", "15/6/2025" ─────────────────────────
    const slashDateMatch = dateText.match(
        /(?:ngay\s+)?(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{4}))?\b/,
    );
    if (slashDateMatch) {
        const date = parseSpecificDateParts(slashDateMatch[1], slashDateMatch[2], slashDateMatch[3], today);
        if (date) {
            return buildSingleDateIntent("specific_date", date, today);
        }
    }

    // ── "tháng sau" ─────────────────────────────────────────────────────────
    if (normalized.includes("thang sau") && !normalized.match(/\d+\s*thang sau/)) {
        const nextMonthIndex = (today.getUTCMonth() + 1) % 12;
        const nextMonthYear = today.getUTCMonth() === 11 ? today.getUTCFullYear() + 1 : today.getUTCFullYear();
        const firstOfNextMonth = new Date(Date.UTC(nextMonthYear, nextMonthIndex, 1));
        const dayOfWeek = firstOfNextMonth.getUTCDay();
        const daysToSaturday = (6 - dayOfWeek + 7) % 7 || 7;
        const checkIn = addDays(firstOfNextMonth, daysToSaturday);
        return {
            label: "next_month",
            friendlyName: "Tháng sau",
            checkIn: formatDate(checkIn),
            checkOut: formatDate(addDays(checkIn, 2)),
            isAutoFilled: true,
        };
    }

    // ── Month with year: "7/2026" / "07/2026" / "tháng 7/2026" ─────────────
    const monthYearSlash = dateText.match(/(?:thang\s+)?(\d{1,2})\s*\/\s*(\d{4})/);
    if (monthYearSlash) {
        const month = parseInt(monthYearSlash[1], 10) - 1;
        const year = parseInt(monthYearSlash[2], 10);

        if (month >= 0 && month <= 11) {
            const firstOfMonth = new Date(Date.UTC(year, month, 1));
            const lastOfMonth = new Date(Date.UTC(year, month + 1, 0));

            // If the entire month is in the past → will be caught by past-date check
            if (lastOfMonth < today) {
                return createPastDateIntent(`month_${month + 1}_${year}`, "PAST_DATE_NOT_ALLOWED");
            }

            // Pick first Saturday of the month (or today if in current month)
            const dayOfWeek = firstOfMonth.getUTCDay();
            const daysToSaturday = (6 - dayOfWeek + 7) % 7 || 7;
            let checkIn = addDays(firstOfMonth, daysToSaturday);
            if (checkIn < today) checkIn = today;
            return {
                label: `month_${month + 1}_${year}`,
                friendlyName: `Tháng ${month + 1} năm ${year}`,
                checkIn: formatDate(checkIn),
                checkOut: formatDate(addDays(checkIn, 2)),
                isAutoFilled: true,
            };
        }
    }

    // ── Month only: "tháng 6", "tháng 7 năm 2025" ──────────────────────────
    const monthOnlyMatch = normalized.match(/thang\s+(\d{1,2})(?:\s+(?:nam\s+)?(\d{4}))?/);
    if (monthOnlyMatch) {
        const month = parseInt(monthOnlyMatch[1], 10) - 1;
        const yearInput = monthOnlyMatch[2] ? parseInt(monthOnlyMatch[2], 10) : null;

        if (month >= 0 && month <= 11) {
            const year = yearInput ?? today.getUTCFullYear();
            const firstOfMonth = new Date(Date.UTC(year, month, 1));
            const lastOfMonth = new Date(Date.UTC(year, month + 1, 0));

            if (lastOfMonth < today) {
                return createPastDateIntent(
                    yearInput ? `month_${month + 1}_${year}` : `month_${month + 1}`,
                    "PAST_DATE_NOT_ALLOWED",
                );
            }

            const dayOfWeek = firstOfMonth.getUTCDay();
            const daysToSaturday = (6 - dayOfWeek + 7) % 7 || 7;
            let checkIn = addDays(firstOfMonth, daysToSaturday);
            if (checkIn < today) checkIn = today;

            return {
                label: `month_${month + 1}`,
                friendlyName: `Tháng ${month + 1}`,
                checkIn: formatDate(checkIn),
                checkOut: formatDate(addDays(checkIn, 2)),
                isAutoFilled: true,
            };
        }
    }

    return undefined;
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYNONYM NORMALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

const normalizeSynonymRows = (synonymRows: SemanticSynonymInput[]) => {
    const normalized: Record<string, string[]> = {};

    for (const row of synonymRows) {
        const synonyms = Array.isArray(row.synonyms)
            ? row.synonyms
            : (() => {
                  try {
                      const parsed = JSON.parse(row.synonyms) as unknown;
                      return Array.isArray(parsed) ? parsed.map(String) : [];
                  } catch {
                      return [];
                  }
              })();

        normalized[row.keyword] = [row.keyword, ...synonyms];
    }

    return normalized;
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN PARSER
// ═══════════════════════════════════════════════════════════════════════════════

export const parseSearchQuery = (
    query: string,
    synonymRows: SemanticSynonymInput[] = [],
    now = new Date(),
): ParsedQueryFilters => {
    const normalized = normalizeVietnameseText(query);
    const filters: ParsedQueryFilters = {
        amenityCodes: [],
        proximity: [],
    };

    // ── City detection ─────────────────────────────────────────────────────────
    for (const [alias, city] of Object.entries(cityAliases)) {
        if (normalized.includes(alias)) {
            filters.city = city;
            break;
        }
    }

    const matchedLocationGroups = detectLocationGroupsFromQuery(query);

    if (matchedLocationGroups.length > 0 && !filters.city) {
        filters.city = "Vung Tau";
    }

    if (matchedLocationGroups.length > 0) {
        filters.locationIntent = {
            city: filters.city,
            locationGroups: matchedLocationGroups,
            areaKeys: matchedLocationGroups.map(getLocationGroupAreaKey),
        };
    }

    // ── Price (use light normalization to preserve dots/dashes/commas) ─────────
    const lightNorm = normalizeLight(query);
    const priceResult = parsePrice(stripBeachDistanceForPriceParsing(lightNorm));
    if (priceResult.minPrice !== undefined) filters.minPrice = priceResult.minPrice;
    if (priceResult.maxPrice !== undefined) filters.maxPrice = priceResult.maxPrice;
    if (priceResult.priceMode) filters.priceMode = priceResult.priceMode;

    // ── Guests ────────────────────────────────────────────────────────────────
    const guestResult = parseGuests(normalized);
    if (guestResult.guests) {
        filters.guests = guestResult.guests;
        filters.capacity = guestResult.capacity;
    }

    // ── Bedrooms / Beds / Bathrooms ───────────────────────────────────────────
    const roomResult = parseRooms(normalized);
    if (roomResult.bedrooms) filters.bedrooms = roomResult.bedrooms;
    if (roomResult.beds) filters.beds = roomResult.beds;
    if (roomResult.bathrooms) filters.bathrooms = roomResult.bathrooms;

    const beachResult = parseBeachIntent(normalized);
    if (beachResult.nearBeach) {
        filters.nearBeach = true;
        filters.proximity.push("near_beach");
    }
    if (beachResult.beachDistanceMeters !== undefined) {
        filters.beachDistanceMeters = beachResult.beachDistanceMeters;
    }

    // ── Property type ─────────────────────────────────────────────────────────
    for (const [propertyType, synonyms] of Object.entries(propertyTypeSynonyms) as Array<[PropertyType, string[]]>) {
        if (synonyms.some((word) => normalized.includes(normalizeVietnameseText(word)))) {
            filters.propertyType = propertyType;
            break;
        }
    }

    // ── Amenities ─────────────────────────────────────────────────────────────
    const mergedAmenitySynonyms = {
        ...amenitySynonyms,
        ...normalizeSynonymRows(synonymRows),
    };

    for (const [code, synonyms] of Object.entries(mergedAmenitySynonyms)) {
        if (synonyms.some((word) => {
            const normalizedWord = normalizeVietnameseText(word);
            // Use word-boundary matching to avoid false positives (e.g. "ac" inside "khach")
            const pattern = new RegExp(`(?:^|\\s)${normalizedWord.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:\\s|$)`);
            return pattern.test(normalized);
        })) {
            filters.amenityCodes.push(code);
        }
    }

    if (filters.amenityCodes.includes("parking")) {
        filters.parkingRequired = true;
    }

    // ── Proximity / context ───────────────────────────────────────────────────
    if (
        normalized.includes("gan trung tam") ||
        normalized.includes("trung tam") ||
        normalized.includes("cho") ||
        normalized.includes("city center")
    ) {
        filters.nearCenter = true;
    }

    if (
        normalized.includes("gan bien") ||
        normalized.includes("sat bien") ||
        normalized.includes("di bo ra bien") ||
        normalized.includes("ven bien") ||
        normalized.includes("bo bien") ||
        normalized.includes("gan bo bien") ||
        normalized.includes("cach bien") ||
        normalized.includes("gan bai tam")
    ) {
        filters.proximity.push("near_beach");
    }

    if (normalized.includes("view bien") || normalized.includes("huong bien") || normalized.includes("nhin ra bien")) {
        filters.proximity.push("sea_view");
    }

    if (
        normalized.includes("yen tinh") ||
        normalized.includes("rieng tu") ||
        normalized.includes("binh yen") ||
        normalized.includes("khong gian rieng")
    ) {
        filters.proximity.push("quiet");
    }

    if (
        normalized.includes("sang trong") ||
        normalized.includes("cao cap") ||
        normalized.includes("luxury") ||
        normalized.includes("xa xi") ||
        normalized.includes("5 sao")
    ) {
        filters.proximity.push("luxury");
    }

    if (
        normalized.includes("binh dan") ||
        normalized.includes("gia re") ||
        normalized.includes("tiet kiem") ||
        normalized.includes("gia tot") ||
        normalized.includes("gia ca hop ly")
    ) {
        filters.proximity.push("budget");
    }

    if (
        normalized.includes("gia dinh co con") ||
        normalized.includes("tre em") ||
        normalized.includes("em be") ||
        normalized.includes("con nho")
    ) {
        filters.proximity.push("family_kids");
    }

    if (
        normalized.includes("lam viec") ||
        normalized.includes("cong tac") ||
        normalized.includes("remote") ||
        normalized.includes("work") ||
        normalized.includes("doanh nhan")
    ) {
        filters.proximity.push("workation");
    }

    // ── Large group proximity (from guest parsing) ────────────────────────────
    if (
        guestResult.guests && guestResult.guests >= 10 &&
        !filters.proximity.includes("large_group")
    ) {
        filters.proximity.push("large_group");
    }
    if (
        (normalized.includes("nhom dong") || normalized.includes("doan dong")) &&
        !filters.proximity.includes("large_group")
    ) {
        filters.proximity.push("large_group");
    }

    // ── Date intent (use lightNorm for slash-based dates, normalized for keywords)
    filters.dateIntent = parseDateIntent(normalized, now, lightNorm);
    filters.amenityCodes = uniqueStrings(filters.amenityCodes);
    filters.proximity = uniqueStrings(filters.proximity);

    return filters;
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC QUERY BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

const buildLocationSemanticBoost = (groupName: LocationGroupName) =>
    `Uu tien khu vuc ${groupName} Vung Tau va cac dia chi lien quan trong cung location group.`;

export const buildSemanticQuery = (input: SemanticSearchRequest, parsed: ParsedQueryFilters) => {
    const parts = [input.query.trim()];
    const guests = input.guests ?? parsed.guests;

    // ── Guest context ─────────────────────────────────────────────────────────
    if (guests === 2) {
        parts.push("Phu hop cho cap doi hoac hai nguoi.");
    } else if (guests && guests >= 4 && guests <= 6) {
        parts.push("Phu hop cho gia dinh hoac nhom ban.");
    } else if (guests && guests > 6) {
        parts.push("Can khong gian rong, phu hop cho nhom dong nguoi hoac gia dinh lon.");
    }

    // ── Amenity context ───────────────────────────────────────────────────────
    const amenityCodes = uniqueStrings([
        ...(parsed.amenityCodes ?? []),
        ...((input.amenities ?? []).map(String)),
    ]);

    if (amenityCodes.includes("sea_view")) {
        parts.push("Uu tien gan bien, huong bien, view bien, nghi duong.");
    }

    if (parsed.proximity.includes("near_beach")) {
        parts.push("Uu tien cho o gan bien, di chuyen nhanh ra bai tam.");
    }

    if (parsed.beachDistanceMeters) {
        parts.push(
            `Uu tien cho o cach bien khoang ${parsed.beachDistanceMeters}m; neu khong co dung khoang cach thi uu tien noi gan bien nhat.`,
        );
    }

    if (amenityCodes.includes("pool")) {
        parts.push("Co ho boi hoac be boi.");
    }

    if (amenityCodes.includes("bathtub")) {
        parts.push("Co bon tam, jacuzzi hoac spa, phu hop nghi duong lang man.");
    }

    if (amenityCodes.includes("desk") || parsed.proximity.includes("workation")) {
        parts.push("Phu hop khach cong tac, lam viec tu xa, co khu vuc lam viec yen tinh.");
    }

    if (amenityCodes.includes("bbq")) {
        parts.push("Co khu vuc BBQ nuong ngoai troi.");
    }

    if (amenityCodes.includes("garden")) {
        parts.push("Co san vuon, khuon vien xanh, khong gian ngoai troi rong.");
    }

    if (amenityCodes.includes("kitchen")) {
        parts.push("Co bep day du tien nghi de tu nau an.");
    }

    if (amenityCodes.includes("pet_friendly")) {
        parts.push("Cho phep mang theo thu cung.");
    }

    if (amenityCodes.includes("karaoke")) {
        parts.push("Co karaoke hoac phong hat, trang bi am thanh.");
    }

    if (amenityCodes.includes("billiards")) {
        parts.push("Co bida hoac ban bida.");
    }

    if (amenityCodes.includes("elevator")) {
        parts.push("Co thang may, phu hop nguoi lon tuoi.");
    }

    // ── Room context ──────────────────────────────────────────────────────────
    if (parsed.bedrooms && parsed.bedrooms >= 4) {
        parts.push(`Can it nhat ${parsed.bedrooms} phong ngu.`);
    }

    // ── Style / vibe context ──────────────────────────────────────────────────
    if (parsed.proximity.includes("quiet")) {
        parts.push("Khong gian yen tinh, rieng tu, tranh xa on ao.");
    }

    if (parsed.proximity.includes("luxury")) {
        parts.push("Phong cach sang trong, cao cap, tien nghi day du.");
    }

    if (parsed.proximity.includes("budget")) {
        parts.push("Gia ca phai chang, tiet kiem, phu hop ngan sach.");
    }

    if (parsed.proximity.includes("family_kids")) {
        parts.push("An toan cho tre em, phu hop gia dinh co con nho.");
    }

    if (parsed.proximity.includes("large_group")) {
        parts.push("Khong gian rong, phong ngu nhieu, phu hop doan dong.");
    }

    // ── Property type context ─────────────────────────────────────────────────
    const propertyType = input.propertyType ?? parsed.propertyType;
    if (propertyType) {
        parts.push(`Loai cho o mong muon: ${propertyType}.`);
    }

    // ── Date context ──────────────────────────────────────────────────────────
    if (parsed.dateIntent?.label) {
        parts.push(`Ngu canh thoi gian: ${parsed.dateIntent.label}.`);
    }

    // ── Location context ──────────────────────────────────────────────────────
    const matchedLocationGroups = detectLocationGroupsFromQuery(input.query);
    if (matchedLocationGroups.length > 0) {
        parts.push("Uu tien luu tru tai khu vuc duoc nhan dien tu dia chi hoac ten duong.");

        for (const groupName of matchedLocationGroups) {
            parts.push(buildLocationSemanticBoost(groupName));
        }
    }

    return parts.join(" ").replace(/\s+/g, " ").trim();
};
