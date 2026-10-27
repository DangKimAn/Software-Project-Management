import { ListingDocument, ListingImageRecord, ListingStatus } from "../models/listing";

export const listingApiStatuses = ["draft", "pending_approval", "published", "hidden"] as const;
export type ListingApiStatus = (typeof listingApiStatuses)[number];

const internalToApiStatus: Record<ListingStatus, string> = {
    draft: "draft",
    pending_approval: "pending_approval",
    active: "published",
    approved: "published",
    published: "published",
    inactive: "hidden",
    rejected: "hidden",
    suspended: "hidden",
};
const parseArrayValue = (value: unknown): string[] => {
    if (Array.isArray(value)) {
        return value.map(String).filter(Boolean);
    }

    if (typeof value === "string") {
        try {
            const parsed = JSON.parse(value) as unknown;
            return Array.isArray(parsed) ? parsed.map(String).filter(Boolean) : [];
        } catch {
            return [];
        }
    }

    return [];
};
const apiToInternalStatus: Record<ListingApiStatus, ListingStatus> = {
    draft: "draft",
    pending_approval: "pending_approval",
    published: "active",
    hidden: "inactive",
};

export const toApiListingStatus = (status: ListingStatus) => internalToApiStatus[status];

export const toInternalListingStatus = (status: ListingApiStatus) => apiToInternalStatus[status];

const getStringValue = (value: unknown) => {
    if (typeof value !== "string") {
        return null;
    }

    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
};

export const getListingImageUrl = (image: ListingImageRecord) => {
    const rawImage = image as ListingImageRecord & Record<string, unknown>;

    return (
        getStringValue(rawImage.url) ??
        getStringValue(rawImage.imageUrl) ??
        getStringValue(rawImage.image_url) ??
        getStringValue(rawImage.secureUrl) ??
        getStringValue(rawImage.publicUrl)
    );
};

const getListingImageId = (image: ListingImageRecord) => {
    const rawImage = image as ListingImageRecord & Record<string, unknown>;
    const rawId = rawImage.imageId ?? rawImage.id ?? rawImage.listingImageId;
    const imageId = Number(rawId);

    return Number.isFinite(imageId) ? imageId : undefined;
};

const getListingImageSortOrder = (image: ListingImageRecord) => {
    const rawImage = image as ListingImageRecord & Record<string, unknown>;
    const sortOrder = Number(rawImage.sortOrder ?? rawImage.sort_order ?? 0);

    return Number.isFinite(sortOrder) ? sortOrder : 0;
};

const isTruthyFlag = (value: unknown) =>
    value === true ||
    value === 1 ||
    value === "1" ||
    (typeof value === "string" && value.toLowerCase() === "true");

const hasCoverFlag = (image: ListingImageRecord) => {
    const rawImage = image as ListingImageRecord & Record<string, unknown>;

    return isTruthyFlag(rawImage.isCover) || isTruthyFlag(rawImage.is_cover);
};

export const serializeListingImage = (image: ListingImageRecord) => ({
    imageId: getListingImageId(image),
    id: getListingImageId(image),
    listingImageId: getListingImageId(image),
    url: getListingImageUrl(image) ?? "",
    imageUrl: getListingImageUrl(image) ?? null,
    image_url: getListingImageUrl(image) ?? null,
    secureUrl: image.secureUrl ?? null,
    publicUrl: image.publicUrl ?? null,
    key: image.key ?? image.objectKey ?? null,
    objectKey: image.objectKey ?? image.key ?? null,
    caption: image.caption ?? image.aiDescription ?? image.altText ?? null,
    displayTitle: image.displayTitle ?? null,
    altText: image.altText ?? image.aiDescription ?? null,
    aiImageType: image.aiImageType ?? null,
    aiSceneTags: parseArrayValue(image.aiSceneTags),
    aiAmenityTags: parseArrayValue(image.aiAmenityTags),
    aiDescription: image.aiDescription ?? null,
    aiConfidence: image.aiConfidence === undefined || image.aiConfidence === null ? null : Number(image.aiConfidence),
    aiQualityWarnings: parseArrayValue(image.aiQualityWarnings),
    aiAnalysisStatus: image.aiAnalysisStatus ?? "pending",
    aiErrorMessage: image.aiErrorMessage ?? null,
    aiAnalyzedAt: image.aiAnalyzedAt ?? null,
    sortOrder: getListingImageSortOrder(image),
    sort_order: getListingImageSortOrder(image),
    isCover: hasCoverFlag(image),
    is_cover: hasCoverFlag(image),
});

export const getCoverImage = (images: ListingImageRecord[]) => {
    const sortedImages = images
        .filter((image) => Boolean(getListingImageUrl(image)))
        .sort((left, right) => getListingImageSortOrder(left) - getListingImageSortOrder(right));

    return sortedImages.find(hasCoverFlag) ?? sortedImages[0] ?? null;
};

export const serializeListingSummary = (listing: ListingDocument) => ({
    listingId: listing.listingId,
    title: listing.title,
    status: toApiListingStatus(listing.status),
    description: listing.description,
    addressLine: listing.addressLine,
    ward: listing.ward,
    district: listing.district,
    city: listing.city,
    propertyType: listing.propertyType,
    roomType: listing.roomType,
    maxGuests: listing.maxGuests,
    includedGuests: listing.includedGuests ?? null,
    bedrooms: listing.bedrooms,
    beds: listing.beds,
    bathrooms: listing.bathrooms,
    basePrice: listing.basePrice,
    currency: listing.currency,
    imageUrl: getCoverImage(listing.images)?.url ?? null,
    coverImage: getCoverImage(listing.images) ? serializeListingImage(getCoverImage(listing.images)!) : null,
    images: listing.images.map(serializeListingImage),
    aiImageTags: listing.aiImageTags ?? null,
    aiImageSummary: listing.aiImageSummary ?? null,
});

export const serializeListingDetail = (listing: ListingDocument) => ({
    listingId: listing.listingId,
    status: toApiListingStatus(listing.status),
    hostId: String(listing.hostId),
    title: listing.title,
    description: listing.description,
    addressLine: listing.addressLine,
    ward: listing.ward,
    district: listing.district,
    city: listing.city,
    stateRegion: listing.stateRegion ?? null,
    country: listing.country,
    postalCode: listing.postalCode ?? null,
    latitude: listing.latitude,
    longitude: listing.longitude,
    propertyType: listing.propertyType,
    roomType: listing.roomType,
    maxGuests: listing.maxGuests,
    bedrooms: listing.bedrooms,
    beds: listing.beds,
    bathrooms: listing.bathrooms,
    basePrice: listing.basePrice,
    weekendPrice: listing.weekendPrice ?? null,
    cleaningFee: listing.cleaningFee ?? null,
    serviceFeePct: listing.serviceFeePct ?? null,
    extraGuestFee: listing.extraGuestFee ?? null,
    currency: listing.currency,
    minNights: listing.minNights,
    maxNights: listing.maxNights ?? null,
    checkInFrom: listing.checkInFrom,
    checkOutBefore: listing.checkOutBefore,
    cancellationPolicy: listing.cancellationPolicy,
    instantBookEnabled: listing.instantBookEnabled,
    amenityIds: listing.amenityIds,
    images: listing.images.map(serializeListingImage),
    smokingAllowed: listing.smokingAllowed,
    petsAllowed: listing.petsAllowed,
    partyAllowed: listing.partyAllowed,
    quietHours: listing.quietHours ?? null,
    createdAt: listing.createdAt,
    updatedAt: listing.updatedAt,
    aiImageTags: listing.aiImageTags ?? null,
    aiImageSummary: listing.aiImageSummary ?? null,
});

export const getDefaultDailyPrice = (listing: ListingDocument, date: string) => {
    const weekday = new Date(`${date}T00:00:00.000Z`).getUTCDay();
    const isWeekend = weekday === 0 || weekday === 6;

    if (isWeekend && listing.weekendPrice) {
        return listing.weekendPrice;
    }

    return listing.basePrice;
};
