import { Op } from "sequelize";

import { ApiError } from "../../common/api-error";
import { buildActiveBookingStatusWhere, buildBookingDateOverlapWhere } from "../bookings/booking-availability";
import { getTodayInVietnamDateString } from "../../common/date-time";
import {
    getAvailabilityCalendarForListing,
    getAvailabilityCalendarMap,
    getListingAmenityIdsForListing,
    getListingAmenityIdsMap,
    getListingImagesForListing,
    getListingImagesMap,
    getListingRulesForListing,
} from "./listing-relations";
import { getCoverImage, getDefaultDailyPrice, serializeListingImage } from "./listing-mappers";
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
} from "./vung-tau-location-groups";
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
import { syncEffectivePlatformFee } from "../admin/admin-fees.service";

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
    bedrooms?: number;
    beds?: number;
    bathrooms?: number;
    pets?: boolean;
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
    aliasMap: Map<string, number[]>;
    searchTermsById: Map<number, string[]>;
};

type ResolvedAmenityFilters = {
    amenityIdGroups: number[][];
    textTokens: string[];
};

/**
 * Giải thuật chuẩn hóa văn bản phục vụ đối sánh và tìm kiếm không dấu:
 * - Phân rã ký tự Unicode theo chuẩn NFD, khử toàn bộ dấu thanh thuộc lớp `\p{Diacritic}` và ánh xạ `đ/Đ -> d/D`.
 * - Chuyển chữ thường, thay thế dãy ký tự phi chữ-số bằng khoảng trắng đơn và cắt khoảng trắng thừa ở hai đầu. Độ phức tạp: O(n).
 */
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

/**
 * Giải thuật chuẩn hóa nhãn tiện ích về dạng token chữ-số viết liền không dấu (`[a-z0-9]+`),
 * giúp khớp bất biến giữa các biến thể dấu gạch nối hoặc khoảng trắng (ví dụ `"wi-fi"`, `"Wi Fi"` -> `"wifi"`). Độ phức tạp: O(n).
 */
const normalizeAmenityToken = (value: string) =>
    value
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, "");

/**
 * Giải thuật so sánh tương đương ngữ nghĩa hai chuỗi văn bản sau khi chuẩn hóa không dấu qua `normalizeComparableText`.
 * Độ phức tạp: O(|left| + |right|).
 */
const compareStrings = (left: string, right: string) => normalizeComparableText(left) === normalizeComparableText(right);

/**
 * Giải thuật tách chuỗi truy vấn thành mảng các từ khóa đơn (tokens) đã chuẩn hóa không dấu và lọc bỏ chuỗi rỗng. Độ phức tạp: O(n).
 */
const getQueryTokens = (value: string) => normalizeComparableText(value).split(" ").filter(Boolean);

/**
 * Giải thuật chuẩn hóa và kẹp biên tham số phân trang (`clamping`):
 * Đảm bảo `page >= 1` và `1 <= limit <= publicListingsMaxPageLimit` (50) để giới hạn kích thước tập kết quả trả về. Độ phức tạp: O(1).
 */
const parsePagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(publicListingsMaxPageLimit, Math.max(1, limit ?? 10)),
});

const defaultMapSearchRadiusMeters = 800;
const maxMapSearchRadiusMeters = 10000;

/**
 * Giải thuật hợp nhất có thứ tự các cấp địa chỉ hành chính của chỗ nghỉ (`addressLine`, `ward`, `district`, `city`, `stateRegion`),
 * tạo chuỗi địa chỉ đầy đủ phục vụ phân loại phân khu địa lý và tìm kiếm toàn văn.
 */
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

/**
 * Giải thuật xác định danh sách các phân khu địa lý Vũng Tàu mà chỗ nghỉ thuộc về dựa trên đối sánh địa chỉ qua `isAddressInLocationGroup`.
 */
const getListingLocationGroupNames = (listing: ListingDocument) => {
    const address = buildSearchableListingAddress(listing);

    return VUNG_TAU_LOCATION_GROUP_NAMES.filter((groupName) => isAddressInLocationGroup(address, groupName));
};

/**
 * Giải thuật mở rộng từ khóa ngữ nghĩa vị trí cho chỗ nghỉ:
 * Kết hợp tên các phân khu của chỗ nghỉ và tự động gắn nhãn đồng nghĩa `"Gần biển gan bien beach biển"` nếu thuộc tập phân khu ven biển (`nearBeachGroups`).
 */
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

/**
 * Giải thuật thu thập và khử trùng lặp (`Set`) toàn bộ tên gọi cùng từ đồng nghĩa song ngữ Việt-Anh cho tập mã tiện ích `amenityIds` của chỗ nghỉ.
 */
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

/**
 * Giải thuật tổng hợp văn bản chỉ mục tìm kiếm đa trường cho một chỗ nghỉ:
 * Hợp nhất tiêu đề, mô tả, địa chỉ hành chính, trường `searchText`, tóm tắt & nhãn ảnh AI (`aiImageSummary`, `aiImageTags`),
 * từ khóa phân khu ven biển, từ đồng nghĩa tiện ích và nhãn ngữ nghĩa cho phép thú cưng / tự nhận phòng nhanh.
 */
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

/**
 * Giải thuật đối sánh từ khóa tìm kiếm đa trường không dấu kết hợp khớp tiện ích và suy luận phân khu địa lý:
 * - Tầng 1 (Exact Normalized Phrase): Khớp trực tiếp cụm truy vấn đã chuẩn hóa trên văn bản chỉ mục tổng hợp của chỗ nghỉ.
 * - Tầng 2 (Conjunctive Token Match - AND): Khớp khi mọi token từ đơn trong truy vấn đều xuất hiện trong văn bản chỉ mục (bao gồm tên và bí danh tiện ích).
 * - Tầng 3 (Geographic Group Fallback): Nhận diện phân khu Vũng Tàu từ truy vấn qua `detectLocationGroupsFromQuery` và kiểm tra địa chỉ chỗ nghỉ có thuộc phân khu đó không.
 * - Độ phức tạp: O(|S| + |Q| * K) với |S| là độ dài văn bản chỉ mục và K là số lượng token truy vấn.
 */
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

/**
 * Giải thuật đối sánh mềm nhãn tiện ích văn bản tự do trên chỉ mục tìm kiếm của chỗ nghỉ:
 * Áp dụng tập luật từ đồng nghĩa chuyên biệt cho các tiêu chí phổ biến (`nearbeach`/`ganbien`, `bbq`, `niceview`/`viewdep`)
 * hoặc kiểm tra bao hàm chuỗi con trên cả văn bản chuẩn hóa có khoảng trắng và dạng token viết liền `compactText`.
 */
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

    if (textToken === "petfriendly" || textToken === "petsallowed" || textToken === "thucung") {
        return (
            Boolean(listing.petsAllowed) ||
            normalizedText.includes("thu cung") ||
            normalizedText.includes("pet")
        );
    }

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

/**
 * Giải thuật kiểm tra cặp tọa độ (latitude, longitude) của chỗ nghỉ có hợp lệ theo miền giá trị WGS84 hay không trước khi tính khoảng cách Haversine.
 */
const hasValidListingCoordinates = (listing: ListingDocument) =>
    isValidLatitude(Number(listing.latitude)) && isValidLongitude(Number(listing.longitude));

/**
 * Giải thuật xác thực và chuẩn hóa đầu vào tìm kiếm theo tâm và bán kính bản đồ:
 * - Bỏ qua nếu thiếu vĩ độ hoặc kinh độ; kiểm tra tính hợp lệ WGS84 và ràng buộc tọa độ tâm phải nằm trong khung biên Vũng Tàu (`isCoordinateInVungTauBounds`), ném lỗi 422 nếu vi phạm.
 * - Kẹp biên bán kính tìm kiếm `radius` trong đoạn [1, 10000] mét (mặc định 800m). Độ phức tạp: O(1).
 */
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

/**
 * Giải thuật kiểm tra bất biến khoảng ngày nhận/trả phòng `[checkIn, checkOut)` cho tìm kiếm công khai:
 * - Bắt buộc cung cấp đồng thời cả `checkIn` và `checkOut` theo định dạng lịch ISO `YYYY-MM-DD`.
 * - Chặn ngày nhận phòng trong quá khứ so với ngày hiện tại theo múi giờ Việt Nam (`UTC+7`) và đảm bảo `checkOut > checkIn`.
 */
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

/**
 * Giải thuật truy vấn bảo vệ chỗ nghỉ công khai:
 * Chỉ cho phép truy xuất bản ghi có `status = "active"` và `deletedAt = null`; ném lỗi 404 với mọi căn đang nháp, chờ duyệt, bị từ chối hoặc đã ẩn/xóa.
 */
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

/**
 * Giải thuật sinh dãy ngày lưu trú rời rạc theo nửa khoảng đóng-mở `[checkIn, checkOut)` dưới định dạng UTC `YYYY-MM-DD`.
 * Ngày `checkOut` là mốc trả phòng nên không tính vào tập đêm chiếm chỗ. Độ phức tạp: O(D) với D là số đêm.
 */
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

/**
 * Giải thuật kiểm tra toàn bộ các đêm trong nửa khoảng `[checkIn, checkOut)` có khả dụng trên lịch cấu hình của chủ nhà hay không:
 * Dựng bảng băm `availabilityByDate` O(C) và kiểm tra mọi ngày trong khoảng đều không bị chủ nhà khóa (`!isBlockedByHost`) và đang mở bán (`isAvailable`).
 * Độ phức tạp: O(C + D) với C là số dòng cấu hình lịch và D là số đêm lưu trú.
 */
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

        return !day.isBlockedByHost && !day.isBlockedByAdmin && day.isAvailable;
    });
};

/**
 * Giải thuật xây dựng chỉ mục tra cứu tiện ích song ngữ Việt-Anh động theo dữ liệu thực trong DB (TC-023):
 * - Tải danh mục tiện ích đang hoạt động và đối sánh từng nhóm từ đồng nghĩa với tên `Amenity` thực tế trong CSDL
 *   thay vì gán cứng `amenityId` số học, cho phép một mã slug (ví dụ `"pool"`, `"air_conditioner"`) khớp chính xác
 *   với tập các `amenityId` tương ứng (ví dụ cả `"Hồ bơi"` lẫn `"Hồ bơi riêng"`).
 */
const amenitySynonymGroups: string[][] = [
    ["wifi", "wi-fi", "internet", "mạng không dây"],
    ["air_conditioner", "airconditioner", "air conditioning", "airconditioning", "điều hòa", "dieu hoa", "máy lạnh", "may lanh"],
    ["washer", "washing machine", "máy giặt", "may giat"],
    ["kitchen", "bếp", "bep", "nhà bếp", "nha bep"],
    ["pool", "swimming pool", "private pool", "hồ bơi", "ho boi", "hồ bơi riêng", "bể bơi", "be boi"],
    ["parking", "free parking", "chỗ đậu xe", "cho dau xe", "đậu xe", "dau xe", "đỗ xe", "bãi xe", "gara"],
    ["tv", "television", "smart tv", "tivi"],
    ["balcony", "patio", "ban công", "ban cong", "sân thượng"],
    ["bbq", "bếp nướng", "bep nuong", "nướng bbq", "nuong bbq", "grill"],
    ["jacuzzi", "hot tub", "bồn tắm sục", "bon tam suc", "bồn sục"],
    ["fireplace", "lò sưởi", "lo suoi"],
    ["fridge", "refrigerator", "tủ lạnh", "tu lanh"],
    ["hair dryer", "hairdryer", "máy sấy tóc", "may say toc"],
    ["iron", "bàn ủi", "ban ui"],
];

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
    const aliasMap = new Map<string, Set<number>>();
    const searchTermsById = new Map<number, Set<string>>();

    const addAlias = (value: string, amenityId: number) => {
        const token = normalizeAmenityToken(value);
        if (!token) return;
        const ids = aliasMap.get(token) ?? new Set<number>();
        ids.add(amenityId);
        aliasMap.set(token, ids);

        const terms = searchTermsById.get(amenityId) ?? new Set<string>();
        terms.add(value);
        searchTermsById.set(amenityId, terms);
    };

    for (const amenity of amenities) {
        addAlias(amenity.name, amenity.amenityId);
        const normalizedAmenityName = normalizeAmenityToken(amenity.name);

        for (const group of amenitySynonymGroups) {
            const normalizedGroupTokens = group.map(normalizeAmenityToken).filter(Boolean);
            const isMatch = normalizedGroupTokens.some(
                (groupToken) =>
                    normalizedAmenityName === groupToken ||
                    (groupToken.length >= 3 && normalizedAmenityName.includes(groupToken)),
            );
            if (isMatch) {
                for (const synonym of group) {
                    addAlias(synonym, amenity.amenityId);
                }
            }
        }
    }

    return {
        amenities,
        aliasMap: new Map(
            Array.from(aliasMap.entries()).map(([token, ids]) => [token, Array.from(ids)]),
        ),
        searchTermsById: new Map(
            Array.from(searchTermsById.entries()).map(([amenityId, terms]) => [amenityId, Array.from(terms)]),
        ),
    };
};

/**
 * Giải thuật phân giải bộ lọc chuỗi tiện ích (`amenitiesQuery` phân tách bằng dấu phẩy):
 * Khử trùng lặp các token chuẩn hóa và phân loại thành các nhóm mã tiện ích tương đương (`amenityIdGroups`) cùng tập nhãn văn bản tự do (`textTokens`).
 */
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
    const amenityIdGroups: number[][] = [];
    const textTokens: string[] = [];

    for (const token of requestedTokens) {
        if (token === "petfriendly" || token === "petsallowed" || token === "thucung") {
            textTokens.push(token);
            continue;
        }

        const candidateIds = aliasMap.get(token);

        if (!candidateIds || candidateIds.length === 0) {
            textTokens.push(token);
            continue;
        }

        amenityIdGroups.push(candidateIds);
    }

    return {
        amenityIdGroups,
        textTokens,
    };
};

/**
 * Giải thuật tổng hợp thống kê đánh giá hàng loạt cho danh sách chỗ nghỉ:
 * Duyệt một lượt O(R) qua các đánh giá hợp lệ đang hiển thị (`isVisible = true`, `deletedAt = null`) để cộng dồn tổng điểm `ratingSum`,
 * đếm `reviewCount` và tính trung bình cộng `avgRating = round(ratingSum / reviewCount, 1)` theo từng `listingId`.
 */
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

/**
 * Giải thuật truy xuất thông tin chi tiết danh sách tiện ích đang kích hoạt theo mảng `amenityIds`,
 * sử dụng bảng băm `amenityById` O(A) để bảo toàn đúng thứ tự khai báo tiện ích trên chỗ nghỉ.
 */
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

/**
 * Giải thuật lấy tóm tắt điểm đánh giá trung bình và số lượt đánh giá hiển thị của một chỗ nghỉ đơn lẻ.
 */
const getListingReviewSummary = async (listingId: number) => {
    const summaryMap = await getReviewSummaryMap([listingId]);

    return (
        summaryMap.get(listingId) ?? {
            avgRating: 0,
            reviewCount: 0,
        }
    );
};

/**
 * Giải thuật xác định tập mã chỗ nghỉ đã bị chiếm chỗ trên khoảng ngày `[checkIn, checkOut)`:
 * Truy vấn các đơn đặt phòng đang giữ chỗ hiệu lực (`buildActiveBookingStatusWhere`) có khoảng ngày giao cắt (`checkInDate < checkOut AND checkOutDate > checkIn`),
 * trả về cấu trúc `Set<number>` cho phép kiểm tra loại trừ O(1) trong pipeline lọc.
 */
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

/**
 * Giải thuật thu thập tập các ngày (`YYYY-MM-DD`) đã có khách đặt giữ chỗ trong phạm vi một tháng lịch `[start, end)`:
 * Cắt biên khoảng lưu trú của từng booking hiệu lực theo đoạn `[max(checkInDate, start), min(checkOutDate, end))` và hợp nhất vào `Set<string>`.
 */
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

/**
 * Giải thuật pipeline truy vấn, lọc đa tiêu chí, sắp xếp và phân trang danh sách chỗ nghỉ công khai:
 * - Giai đoạn 1 (Xác thực tham số): Kẹp biên phân trang, kiểm tra bất biến khoảng ngày `[checkIn, checkOut)`, tọa độ bản đồ Vũng Tàu, khoảng giá `priceMin <= priceMax` và tên phân khu `locationGroup`.
 * - Giai đoạn 2 (Lọc sơ cấp tại CSDL): Chỉ lấy bản ghi đang mở bán (`status = "active"`, `deletedAt = null`) thỏa mãn loại hình, sức chứa tối thiểu (`maxGuests >= guests`) và khoảng giá cơ sở (`basePrice`).
 * - Giai đoạn 3 (Nạp song song dữ liệu liên kết): Đồng thời tải tóm tắt đánh giá, tiện ích, hình ảnh, lịch cấu hình của chủ nhà và tập `bookedListingIds` giao cắt khoảng ngày lưu trú.
 * - Giai đoạn 4 (Pipeline lọc tinh trên bộ nhớ): Kiểm tra thành phố/quận không dấu, thông số phòng (`bedrooms`, `beds`, `bathrooms`), quy định thú cưng, phân khu địa lý, khoảng cách Haversine `<= radius`, bao hàm tập con tiện ích (kèm fallback khớp từ khóa tiện ích), đối sánh từ khóa `matchesKeywordQuery`, giới hạn số đêm `[minNights, maxNights]` và loại trừ căn trùng lịch giữ chỗ hoặc ngày chủ nhà khóa lịch.
 * - Giai đoạn 5 (Sắp xếp tất định & Phân trang): Xếp hạng theo khoảng cách bản đồ, ưu tiên thành phố mặc định, giá tăng/giảm hoặc điểm đánh giá giảm dần (khóa phụ `listingId` giảm dần), sau đó cắt trang `[(page - 1) * limit, page * limit)`.
 */
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
        bedrooms?: { $gte: number };
        beds?: { $gte: number };
        bathrooms?: { $gte: number };
        petsAllowed?: boolean;
        basePrice?: { $gte?: number; $lte?: number };
    } = {
        status: "active",
        deletedAt: null,
    };

    if (query.propertyType) publicFilter.propertyType = query.propertyType;
    if (query.roomType) publicFilter.roomType = query.roomType;
    if (query.guests !== undefined) publicFilter.maxGuests = { $gte: query.guests };
    if (query.bedrooms !== undefined && query.bedrooms > 0) publicFilter.bedrooms = { $gte: query.bedrooms };
    if (query.beds !== undefined && query.beds > 0) publicFilter.beds = { $gte: query.beds };
    if (query.bathrooms !== undefined && query.bathrooms > 0) publicFilter.bathrooms = { $gte: query.bathrooms };
    if (query.pets === true) publicFilter.petsAllowed = true;

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

    // Giải thuật lọc bổ sung thông số phòng và quy định thú cưng cho tìm kiếm công khai:
    // So khớp tối thiểu số phòng ngủ, giường, phòng tắm và cờ cho phép thú cưng trước khi tính khoảng cách / lịch trống.
    const filteredListings = listings.filter((listing) => {
        if (effectiveCity && !compareStrings(listing.city, effectiveCity)) {
            return false;
        }
        if (query.bedrooms !== undefined && Number(listing.bedrooms ?? 0) < query.bedrooms) {
            return false;
        }
        if (query.beds !== undefined && Number(listing.beds ?? 0) < query.beds) {
            return false;
        }
        if (query.bathrooms !== undefined && Number(listing.bathrooms ?? 0) < query.bathrooms) {
            return false;
        }
        if (query.pets === true && !listing.petsAllowed) {
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
            const hasAllAmenityIds = amenityFilters.amenityIdGroups.every((candidateIds) => {
                if (candidateIds.some((amenityId) => listingAmenityIds.includes(amenityId))) {
                    return true;
                }

                // Fallback to text match if relation is missing
                const terms = candidateIds.flatMap(
                    (amenityId) => amenityLookup?.searchTermsById.get(amenityId) ?? [],
                );
                return terms.some((term) => matchesAmenityTextToken(listing, listingAmenityIds, term, amenityLookup));
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

/**
 * Giải thuật tổng hợp hồ sơ chi tiết chỗ nghỉ công khai:
 * Xác thực trạng thái mở bán qua `getPublicListingOrThrow`, nạp song song danh sách tiện ích đang kích hoạt, bộ ảnh chuẩn hóa, nội quy lưu trú,
 * thống kê điểm đánh giá và thông tin công khai tối thiểu của chủ nhà (chỉ xuất tên và ảnh đại diện, ẩn email/SĐT chống lộ PII).
 */
export const getPublicListingDetail = async (listingId: number) => {
    const listing = await getPublicListingOrThrow(listingId);
    const [amenityIds, images, rules, reviewSummary, host, effectivePlatformFeePct] = await Promise.all([
        getListingAmenityIdsForListing(listing),
        getListingImagesForListing(listing),
        getListingRulesForListing(listing),
        getListingReviewSummary(listing.listingId),
        User.findById(listing.hostId),
        syncEffectivePlatformFee().catch(() => 10),
    ]);
    const amenities = await getAmenityDetails(amenityIds);

    return {
        listingId: listing.listingId,
        title: listing.title,
        description: listing.description,
        basePrice: listing.basePrice,
        weekendPrice: listing.weekendPrice ?? null,
        cleaningFee: listing.cleaningFee ?? null,
        serviceFeePct: listing.serviceFeePct ?? effectivePlatformFeePct,
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

/**
 * Giải thuật dựng lịch trống và tính giá hiển thị từng ngày trong tháng cho trang chi tiết chỗ nghỉ:
 * - Xác định số ngày của tháng theo lịch UTC và mốc ngày hiện tại theo múi giờ Việt Nam (`UTC+7`).
 * - Với mỗi ngày, hợp nhất trạng thái từ 3 điều kiện độc lập: ngày quá khứ (`isPast`), ngày đã có đơn giữ chỗ (`bookedDates`) và cấu hình đóng/mở của chủ nhà (`!isBlockedByHost && isAvailable`).
 * - Tính giá hiển thị theo thứ tự ưu tiên: `priceOverride` cấu hình riêng cho ngày đó -> giá cuối tuần/ngày thường mặc định (`getDefaultDailyPrice`); tương tự cho `minNights`.
 * - Độ phức tạp: O(C + B + D_month) với C là số bản ghi lịch, B là số ngày đã đặt và D_month <= 31.
 */
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
        const calendarAvailable = existing
            ? !existing.isBlockedByHost && !existing.isBlockedByAdmin && existing.isAvailable
            : true;

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

/**
 * Giải thuật truy vấn, thống kê điểm trung bình cộng và phân trang danh sách đánh giá công khai của chỗ nghỉ:
 * - Tính `avgRating` và tổng `reviewCount` trên toàn bộ đánh giá hợp lệ đang hiển thị (`isVisible = true`, `deletedAt = null`) trước khi áp dụng bộ lọc số sao `query.rating`.
 * - Làm sạch chống XSS nội dung bình luận, tên người đánh giá và phản hồi của chủ nhà trước khi xuất ra client.
 */
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

/**
 * Giải thuật truy xuất nội quy lưu trú công khai của chỗ nghỉ (khung giờ nhận/trả phòng, quy định hút thuốc, thú cưng, tiệc tùng và giờ yên tĩnh)
 * sau khi xác thực chỗ nghỉ đang mở bán hợp lệ qua `getPublicListingOrThrow`.
 */
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
