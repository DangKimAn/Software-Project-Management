import { Op, type Transaction } from "sequelize";

// CONFLICT-RESOLVED: Chuyển truy vấn quan hệ chỗ nghỉ từ `src/common/listing-relations.ts` về `src/modules/listings/`.
import AvailabilityCalendar from "../../models/availability-calendar";
import ListingAmenity from "../../models/listing-amenity";
import ListingImage from "../../models/listing-image";
import ListingRule from "../../models/listing-rule";
import {
    ListingAvailabilityDayRecord,
    ListingDocument,
    ListingImageRecord,
} from "../../models/listing";

const normalizeTime = (value?: string | null) => (value ? value.slice(0, 5) : null);

const legacyImages = (listing: ListingDocument) => listing.images as ListingImageRecord[];
const legacyCalendar = (listing: ListingDocument) =>
    listing.availabilityCalendar as ListingAvailabilityDayRecord[];

/**
 * Giải thuật hợp nhất danh sách ảnh chỗ nghỉ từ bảng quan hệ `listing_images` và dữ liệu JSON kế thừa:
 * - Truy vấn bảng `listing_images` ưu tiên `isCover DESC, sortOrder ASC, id ASC`.
 * - Khử trùng lặp theo `imageId` trước khi bổ sung các bản ghi kế thừa chưa di trú rồi sắp xếp theo `sortOrder`.
 */
export const getListingImagesForListing = async (
    listing: ListingDocument,
    transaction?: Transaction,
) => {
    const rows = await ListingImage.findAll({
        where: {
            listingId: listing.listingId,
        },
        order: [
            ["isCover", "DESC"],
            ["sortOrder", "ASC"],
            ["id", "ASC"],
        ],
        transaction,
    });

    const normalizedImages = rows.map<ListingImageRecord>((row) => ({
        imageId: Number(row.id),
        url: row.url,
        objectKey: row.objectKey,
        key: row.objectKey,
        caption: row.caption,

        // AI image label fields
        displayTitle: row.displayTitle,
        altText: row.altText,
        aiImageType: row.aiImageType,
        aiSceneTags: row.aiSceneTags,
        aiAmenityTags: row.aiAmenityTags,
        aiDescription: row.aiDescription,
        aiConfidence: row.aiConfidence,
        aiQualityWarnings: row.aiQualityWarnings,
        aiAnalysisStatus: row.aiAnalysisStatus,
        aiErrorMessage: row.aiErrorMessage,
        aiAnalyzedAt: row.aiAnalyzedAt,

        sortOrder: row.sortOrder,
        isCover: row.isCover,
    }));
    const normalizedImageIds = new Set(normalizedImages.map((image) => image.imageId));

    return [
        ...normalizedImages,
        ...legacyImages(listing).filter((image) => !normalizedImageIds.has(image.imageId)),
    ].sort((left, right) => left.sortOrder - right.sortOrder);
};

/**
 * Giải thuật hợp nhất tập mã tiện nghi (`amenityId`) từ bảng nối `listing_amenities` và mảng JSON trên `listings`.
 */
export const getListingAmenityIdsForListing = async (
    listing: ListingDocument,
    transaction?: Transaction,
) => {
    const rows = await ListingAmenity.findAll({
        where: {
            listingId: listing.listingId,
        },
        order: [["amenityId", "ASC"]],
        transaction,
    });

    return Array.from(new Set([...listing.amenityIds, ...rows.map((row) => row.amenityId)])).sort(
        (left, right) => left - right,
    );
};

/**
 * Giải thuật tra cứu nội quy chỗ nghỉ với cơ chế rơi về (fallback) cấu hình gốc trên bản ghi `listings`.
 */
export const getListingRulesForListing = async (
    listing: ListingDocument,
    transaction?: Transaction,
) => {
    const row = await ListingRule.findOne({
        where: {
            listingId: listing.listingId,
        },
        transaction,
    });

    if (!row) {
        return {
            checkInFrom: normalizeTime(listing.checkInFrom),
            checkOutBefore: normalizeTime(listing.checkOutBefore),
            smokingAllowed: listing.smokingAllowed,
            petsAllowed: listing.petsAllowed,
            partyAllowed: listing.partyAllowed,
            quietHours: listing.quietHours ?? null,
        };
    }

    return {
        checkInFrom: normalizeTime(row.checkInFrom) ?? normalizeTime(listing.checkInFrom),
        checkOutBefore: normalizeTime(row.checkOutBefore) ?? normalizeTime(listing.checkOutBefore),
        smokingAllowed: row.smokingAllowed,
        petsAllowed: row.petsAllowed,
        partyAllowed: row.partyAllowed,
        quietHours: row.quietHours ?? null,
    };
};

/**
 * Giải thuật tổng hợp lịch trống và giá ghi đè theo ngày của một chỗ nghỉ:
 * - Ghi đè dữ liệu bảng `availability_calendar` lên bản đồ lịch kế thừa theo khóa ngày `YYYY-MM-DD`.
 * - Ngày bị khóa bởi Admin (`isBlockedByAdmin`) hoặc Chủ nhà (`isBlockedByHost`) luôn được ép `isAvailable = false`.
 */
export const getAvailabilityCalendarForListing = async (
    listing: ListingDocument,
    transaction?: Transaction,
) => {
    const rows = await AvailabilityCalendar.findAll({
        where: {
            listingId: listing.listingId,
        },
        order: [["date", "ASC"]],
        transaction,
    });

    const calendarByDate = new Map(legacyCalendar(listing).map((row) => [row.date, row] as const));

    for (const row of rows) {
        calendarByDate.set(row.date, {
            date: row.date,
            // Computed availability includes admin and host locks
            isAvailable: Boolean(row.isBlockedByAdmin) || row.isBlockedByHost ? false : row.isAvailable,
            isBlockedByHost: row.isBlockedByHost,
            isBlockedByAdmin: Boolean(row.isBlockedByAdmin),
            lockSource: row.lockSource ?? null,
            syncRevision: Number(row.syncRevision ?? 0),
            lastSheetSyncedAt: row.lastSheetSyncedAt ?? null,
            priceOverride: row.priceOverride ?? null,
            minNightsOverride: row.minNightsOverride ?? null,
            notes: row.notes ?? null,
        });
    }

    return Array.from(calendarByDate.values()).sort((left, right) => left.date.localeCompare(right.date));
};

/**
 * Giải thuật nạp hàng loạt (Batch Load chống N+1 Query) lịch trống cho danh sách chỗ nghỉ bằng một truy vấn `WHERE listing_id IN (...)`.
 */
export const getAvailabilityCalendarMap = async (
    listings: ListingDocument[],
    transaction?: Transaction,
) => {
    const listingIds = listings.map((listing) => listing.listingId);
    const rows =
        listingIds.length === 0
            ? []
            : await AvailabilityCalendar.findAll({
                where: {
                    listingId: {
                        [Op.in]: listingIds,
                    },
                },
                order: [
                    ["listingId", "ASC"],
                    ["date", "ASC"],
                ],
                transaction,
            });

    const rowsByListing = new Map<number, ListingAvailabilityDayRecord[]>();
    for (const row of rows) {
        const current = rowsByListing.get(row.listingId) ?? [];
        current.push({
            date: row.date,
            // Computed availability includes admin and host locks
            isAvailable: Boolean(row.isBlockedByAdmin) || row.isBlockedByHost ? false : row.isAvailable,
            isBlockedByHost: row.isBlockedByHost,
            isBlockedByAdmin: Boolean(row.isBlockedByAdmin),
            lockSource: row.lockSource ?? null,
            syncRevision: Number(row.syncRevision ?? 0),
            lastSheetSyncedAt: row.lastSheetSyncedAt ?? null,
            priceOverride: row.priceOverride ?? null,
            minNightsOverride: row.minNightsOverride ?? null,
            notes: row.notes ?? null,
        });
        rowsByListing.set(row.listingId, current);
    }

    return new Map(
        listings.map((listing) => {
            const calendarByDate = new Map(legacyCalendar(listing).map((row) => [row.date, row] as const));

            for (const row of rowsByListing.get(listing.listingId) ?? []) {
                calendarByDate.set(row.date, row);
            }

            return [listing.listingId, Array.from(calendarByDate.values())];
        }),
    );
};

/**
 * Giải thuật nạp hàng loạt (Batch Load chống N+1 Query) danh sách mã tiện nghi cho nhiều chỗ nghỉ.
 */
export const getListingAmenityIdsMap = async (
    listings: ListingDocument[],
    transaction?: Transaction,
) => {
    const listingIds = listings.map((listing) => listing.listingId);
    const rows =
        listingIds.length === 0
            ? []
            : await ListingAmenity.findAll({
                where: {
                    listingId: {
                        [Op.in]: listingIds,
                    },
                },
                order: [
                    ["listingId", "ASC"],
                    ["amenityId", "ASC"],
                ],
                transaction,
            });

    const rowsByListing = new Map<number, number[]>();

    for (const row of rows) {
        const current = rowsByListing.get(row.listingId) ?? [];
        current.push(row.amenityId);
        rowsByListing.set(row.listingId, current);
    }

    return new Map(
        listings.map((listing) => [
            listing.listingId,
            Array.from(new Set([...listing.amenityIds, ...(rowsByListing.get(listing.listingId) ?? [])])),
        ]),
    );
};

/**
 * Giải thuật nạp hàng loạt (Batch Load chống N+1 Query) danh sách ảnh và siêu dữ liệu AI cho nhiều chỗ nghỉ.
 */
export const getListingImagesMap = async (
    listings: ListingDocument[],
    transaction?: Transaction,
) => {
    const listingIds = listings.map((listing) => listing.listingId);
    const rows =
        listingIds.length === 0
            ? []
            : await ListingImage.findAll({
                where: {
                    listingId: {
                        [Op.in]: listingIds,
                    },
                },
                order: [
                    ["listingId", "ASC"],
                    ["isCover", "DESC"],
                    ["sortOrder", "ASC"],
                    ["id", "ASC"],
                ],
                transaction,
            });

    const rowsByListing = new Map<number, ListingImageRecord[]>();

    for (const row of rows) {
        const current = rowsByListing.get(row.listingId) ?? [];
        current.push({
            imageId: Number(row.id),
            url: row.url,
            objectKey: row.objectKey,
            key: row.objectKey,
            originalFilename: row.originalFilename,
            displayTitle: row.displayTitle,
            altText: row.altText,
            caption: row.caption,
            aiImageType: row.aiImageType,
            aiSceneTags: row.aiSceneTags,
            aiAmenityTags: row.aiAmenityTags,
            aiDescription: row.aiDescription,
            aiConfidence: row.aiConfidence,
            aiQualityWarnings: row.aiQualityWarnings,
            aiAnalysisStatus: row.aiAnalysisStatus,
            aiErrorMessage: row.aiErrorMessage,
            aiAnalyzedAt: row.aiAnalyzedAt,
            sortOrder: row.sortOrder,
            isCover: row.isCover,
        });
        rowsByListing.set(row.listingId, current);
    }

    return new Map(
        listings.map((listing) => {
            const normalizedImages = rowsByListing.get(listing.listingId) ?? [];
            const normalizedImageIds = new Set(normalizedImages.map((image) => image.imageId));

            return [
                listing.listingId,
                [
                    ...normalizedImages,
                    ...legacyImages(listing).filter((image) => !normalizedImageIds.has(image.imageId)),
                ].sort((left, right) => left.sortOrder - right.sortOrder),
            ];
        }),
    );
};
