import { Op, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import { getTodayInVietnamDateString } from "../../common/date-time";
import {
    alwaysBlockingBookingStatuses,
    buildActiveBookingStatusWhere,
    checkedOutBlockingStatus,
    pendingPaymentBlockingStatus,
} from "../../common/booking-availability";
import {
    getAvailabilityCalendarForListing,
    getListingAmenityIdsForListing,
    getListingImagesForListing,
    getListingRulesForListing,
} from "../../common/listing-relations";
import {
    ListingApiStatus,
    getCoverImage,
    getDefaultDailyPrice,
    serializeListingImage,
    toApiListingStatus,
    toInternalListingStatus,
} from "../../common/listing-mappers";
import {
    sanitizeNullableSingleLineText,
    sanitizeSingleLineText,
    sanitizeText,
} from "../../common/sanitization";
import { isValidIsoDate } from "../../common/validation";
import { isCoordinateInVungTauBounds } from "../../common/vung-tau-location-groups";
import sequelize from "../../config/database";
import Amenity from "../../models/amenity";
import AvailabilityCalendar from "../../models/availability-calendar";
import Booking from "../../models/booking";
import { getNextSequence } from "../../models/counter";
import Listing, {
    ListingAvailabilityDayRecord,
    ListingDocument,
    ListingImageRecord,
    ListingStatus,
} from "../../models/listing";
import ListingAmenity from "../../models/listing-amenity";
import ListingImage from "../../models/listing-image";
import ListingRule from "../../models/listing-rule";
import type { AuthenticatedUser } from "../auth/auth.service";
import { writeAuditLog } from "../../services/audit-log-service";
import { isHostVerifiedForPublishing } from "../../services/host-verification-status-service";
import { notifyListingSubmitted } from "../notifications/notification.service";
import { scheduleSemanticReindex } from "../semantic-search/semantic-search.indexer";

export type CreateListingInput = {
    title: string;
    description: string;
    addressLine: string;
    ward: string;
    district: string;
    city: string;
    stateRegion?: string | null;
    country: string;
    postalCode?: string | null;
    latitude: number;
    longitude: number;
    propertyType: "apartment" | "villa" | "hotel" | "homestay";
    roomType: "entire_place" | "private_room" | "shared_room";
    maxGuests: number;
    includedGuests?: number | null;
    bedrooms: number;
    beds: number;
    bathrooms: number;
    basePrice: number;
    weekendPrice?: number | null;
    cleaningFee?: number | null;
    surchargeAmount?: number | null;
    serviceFeePct?: number | null;
    extraGuestFee?: number | null;
    currency: "VND";
    minNights: number;
    maxNights?: number | null;
    checkInFrom: string;
    checkOutBefore: string;
    cancellationPolicy: "flexible" | "moderate" | "strict";
    instantBookEnabled: boolean;
    amenityIds?: number[];
    status?: "draft" | "pending_approval";
};

export type UpdateListingInput = Partial<
    Pick<
        CreateListingInput,
        | "title"
        | "description"
        | "addressLine"
        | "ward"
        | "district"
        | "city"
        | "stateRegion"
        | "country"
        | "postalCode"
        | "latitude"
        | "longitude"
        | "propertyType"
        | "roomType"
        | "basePrice"
        | "weekendPrice"
        | "cleaningFee"
        | "surchargeAmount"
        | "serviceFeePct"
        | "extraGuestFee"
        | "maxGuests"
        | "includedGuests"
        | "bedrooms"
        | "beds"
        | "bathrooms"
        | "minNights"
        | "maxNights"
        | "cancellationPolicy"
        | "instantBookEnabled"
    >
> & {
    status?: ListingApiStatus;
};

type AddListingImageItem = {
    url: string;
    key?: string | null;
    objectKey?: string | null;
    originalFilename?: string | null;
    displayTitle?: string | null;
    altText?: string | null;
    caption?: string | null;
    sortOrder?: number;
    isCover?: boolean;
};

export type AddListingImagesInput = Partial<AddListingImageItem> & {
    images?: AddListingImageItem[];
};

export type ReplaceAmenitiesInput = {
    amenityIds: number[];
};

export type UpdateRulesInput = {
    checkInFrom?: string;
    checkOutBefore?: string;
    smokingAllowed?: boolean;
    petsAllowed?: boolean;
    partyAllowed?: boolean;
    quietHours?: string | null;
};

export type ListMineQuery = {
    status?: ListingApiStatus;
    page?: number;
    limit?: number;
};

export type GetCalendarQuery = {
    month?: number;
    year?: number;
};

export type BulkCalendarUpdateInput = {
    dates: string[];
    isAvailable?: boolean;
    isBlockedByHost?: boolean;
    priceOverride?: number | null;
    minNightsOverride?: number | null;
    notes?: string | null;
};

export type HostActor = {
    userId: string;
    isAdmin: boolean;
};

const maxImagesPerListing = 30;
export const hostListingsMaxPageLimit = 50;
const bookingBlockingStatuses = [
    pendingPaymentBlockingStatus,
    ...alwaysBlockingBookingStatuses,
    checkedOutBlockingStatus,
] as const;

const uniqueNumbers = (values: number[] = []) => Array.from(new Set(values));
const hasOwn = <T extends object>(value: T, key: keyof T) =>
    Object.prototype.hasOwnProperty.call(value, key);
const defaultListingCity = "Vũng Tàu";
const assertCoordinateInDefaultListingCity = (latitude: number, longitude: number) => {
    if (isCoordinateInVungTauBounds(latitude, longitude)) {
        return;
    }

    throw new ApiError(422, "Tọa độ chỗ nghỉ phải nằm trong khu vực Vũng Tàu", [
        {
            path: "latitude",
            msg: "coordinates must be inside Vung Tau",
        },
        {
            path: "longitude",
            msg: "coordinates must be inside Vung Tau",
        },
    ]);
};
const normalizeCoordinateValue = (path: "latitude" | "longitude", value: unknown) => {
    const normalizedValue = typeof value === "string" ? value.trim().replace(",", ".") : value;
    const coordinate = Number(normalizedValue);
    const min = path === "latitude" ? -90 : -180;
    const max = path === "latitude" ? 90 : 180;

    if (!Number.isFinite(coordinate) || coordinate < min || coordinate > max) {
        throw new ApiError(422, "Tọa độ chỗ nghỉ không hợp lệ", [
            {
                path,
                msg: `${path} is invalid`,
            },
        ]);
    }

    return coordinate;
};
const normalizeCreateListingLocationInput = (input: CreateListingInput): CreateListingInput => {
    const rawInput = input as CreateListingInput & {
        city?: unknown;
        district?: unknown;
        latitude?: unknown;
        longitude?: unknown;
    };
    const district = typeof rawInput.district === "string" && rawInput.district.trim()
        ? rawInput.district
        : defaultListingCity;
    const latitude = normalizeCoordinateValue("latitude", rawInput.latitude);
    const longitude = normalizeCoordinateValue("longitude", rawInput.longitude);

    assertCoordinateInDefaultListingCity(latitude, longitude);

    return {
        ...input,
        city: defaultListingCity,
        district,
        latitude,
        longitude,
    };
};
const normalizeUpdateListingLocationInput = (input: UpdateListingInput): UpdateListingInput => {
    const rawInput = input as UpdateListingInput & {
        city?: unknown;
        district?: unknown;
        latitude?: unknown;
        longitude?: unknown;
    };
    const hasLocationField =
        hasOwn(input, "addressLine") ||
        hasOwn(input, "ward") ||
        hasOwn(input, "district") ||
        hasOwn(input, "city") ||
        hasOwn(input, "latitude") ||
        hasOwn(input, "longitude");
    const normalized: UpdateListingInput = {
        ...input,
    };

    if (hasLocationField) {
        normalized.city = defaultListingCity;
    }

    if (hasOwn(input, "district") || hasLocationField) {
        normalized.district =
            typeof rawInput.district === "string" && rawInput.district.trim()
                ? rawInput.district
                : defaultListingCity;
    }

    if (hasOwn(input, "latitude")) {
        normalized.latitude = normalizeCoordinateValue("latitude", rawInput.latitude);
    }

    if (hasOwn(input, "longitude")) {
        normalized.longitude = normalizeCoordinateValue("longitude", rawInput.longitude);
    }

    return normalized;
};

const sensitiveListingFields = new Set<keyof UpdateListingInput>([
    "description",
    "addressLine",
    "ward",
    "district",
    "city",
    "stateRegion",
    "country",
    "postalCode",
    "latitude",
    "longitude",
    "basePrice",
    "weekendPrice",
    "cleaningFee",
    "surchargeAmount",
    "serviceFeePct",
    "extraGuestFee",
    "includedGuests",
]);

type CreateListingOptions = {
    isAdmin?: boolean;
};

export const toHostActor = (user: AuthenticatedUser): HostActor => ({
    userId: user.id,
    isAdmin: user.roles.includes("admin"),
});

export const checkListingOwner = (listing: ListingDocument, actor: HostActor) => {
    if (!actor.isAdmin && String(listing.hostId) !== actor.userId) {
        throw new ApiError(403, "Forbidden");
    }
};

const assertAmenityIdsExist = async (amenityIds: number[]) => {
    const uniqueAmenityIds = uniqueNumbers(amenityIds);

    if (uniqueAmenityIds.length === 0) {
        return;
    }

    const existingAmenityCount = await Amenity.countDocuments({
        amenityId: { $in: uniqueAmenityIds },
        active: true,
        isActive: true,
        deletedAt: null,
    });

    if (existingAmenityCount !== uniqueAmenityIds.length) {
        throw new ApiError(422, "Validation error", [
            {
                path: "amenityIds",
                msg: "One or more amenityIds are invalid",
            },
        ]);
    }
};

const assertNightsRange = (minNights: number, maxNights?: number | null) => {
    if (maxNights !== undefined && maxNights !== null && maxNights < minNights) {
        throw new ApiError(422, "Validation error", [
            {
                path: "maxNights",
                msg: "maxNights must be greater than or equal to minNights",
            },
        ]);
    }
};

const assertNonEmptyText = (path: string, value: string) => {
    if (value.length === 0) {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} cannot be empty after sanitization`,
            },
        ]);
    }
};

const sanitizeCreateListingInput = (input: CreateListingInput): CreateListingInput => {
    const sanitized: CreateListingInput = {
        ...input,
        title: sanitizeSingleLineText(input.title),
        description: sanitizeText(input.description),
        addressLine: sanitizeSingleLineText(input.addressLine),
        ward: sanitizeSingleLineText(input.ward),
        district: sanitizeSingleLineText(input.district),
        city: sanitizeSingleLineText(input.city),
        stateRegion: sanitizeNullableSingleLineText(input.stateRegion),
        postalCode: sanitizeNullableSingleLineText(input.postalCode),
    };

    assertNonEmptyText("title", sanitized.title);
    assertNonEmptyText("description", sanitized.description);
    assertNonEmptyText("addressLine", sanitized.addressLine);
    assertNonEmptyText("ward", sanitized.ward);
    assertNonEmptyText("district", sanitized.district);
    assertNonEmptyText("city", sanitized.city);

    return sanitized;
};

const sanitizeUpdateListingInput = (input: UpdateListingInput): UpdateListingInput => {
    const sanitized: UpdateListingInput = {
        ...input,
    };

    if (input.title !== undefined) {
        sanitized.title = sanitizeSingleLineText(input.title);
        assertNonEmptyText("title", sanitized.title);
    }

    if (input.description !== undefined) {
        sanitized.description = sanitizeText(input.description);
        assertNonEmptyText("description", sanitized.description);
    }

    if (input.addressLine !== undefined) {
        sanitized.addressLine = sanitizeSingleLineText(input.addressLine);
        assertNonEmptyText("addressLine", sanitized.addressLine);
    }

    if (input.ward !== undefined) {
        sanitized.ward = sanitizeSingleLineText(input.ward);
        assertNonEmptyText("ward", sanitized.ward);
    }

    if (input.district !== undefined) {
        sanitized.district = sanitizeSingleLineText(input.district);
        assertNonEmptyText("district", sanitized.district);
    }

    if (input.city !== undefined) {
        sanitized.city = sanitizeSingleLineText(input.city);
        assertNonEmptyText("city", sanitized.city);
    }

    if (hasOwn(input, "stateRegion")) {
        sanitized.stateRegion = sanitizeNullableSingleLineText(input.stateRegion);
    }

    if (hasOwn(input, "postalCode")) {
        sanitized.postalCode = sanitizeNullableSingleLineText(input.postalCode);
    }

    return sanitized;
};

const assertHostCanRequestReview = async (
    listingHostId: number,
    requestedStatus: ListingStatus,
    actor: HostActor,
    transaction?: Transaction,
) => {
    if (actor.isAdmin || (requestedStatus !== "active" && requestedStatus !== "pending_approval")) {
        return;
    }

    if (!(await isHostVerifiedForPublishing(listingHostId, transaction))) {
        throw new ApiError(422, "Host must be verified before listing can be published");
    }
};

const assertStatusTransition = (
    currentStatus: ListingStatus,
    requestedStatus: ListingStatus,
    actor: HostActor,
) => {
    if (actor.isAdmin) {
        return;
    }

    const transitions: Record<ListingStatus, ListingStatus[]> = {
        draft: ["draft", "pending_approval"],
        pending_approval: ["draft", "pending_approval"],
        active: ["active", "inactive"],
        approved: ["approved", "inactive"],
        published: ["published", "inactive"],
        inactive: ["active", "inactive"],
        rejected: ["draft"],
        suspended: ["inactive"],
    };

    if (!transitions[currentStatus].includes(requestedStatus)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "status",
                msg: `Status transition from ${currentStatus} to ${requestedStatus} is not allowed`,
            },
        ]);
    }
};

const getListingForHost = async (listingId: number, actor: HostActor, transaction?: Transaction) => {
    const listing = await Listing.findOne({
        where: {
            listingId,
            deletedAt: null,
        },
        transaction,
    });

    if (!listing) {
        throw new ApiError(404, "Listing not found");
    }

    checkListingOwner(listing, actor);
    return listing;
};

const findBookedCalendarDates = async (listingId: number, dates: string[], transaction?: Transaction) => {
    const bookings = await Booking.findAll({
        where: {
            listingId,
            ...buildActiveBookingStatusWhere(),
        },
        transaction,
    });

    const blockedDates = dates.filter((date) =>
        bookings.some((booking) => booking.checkInDate <= date && date < booking.checkOutDate),
    );

    return Array.from(new Set(blockedDates));
};

const normalizeCalendarRow = (row: ListingAvailabilityDayRecord) => {
    const trimmedNotes = row.notes?.trim();
    const normalizedRow: ListingAvailabilityDayRecord = {
        date: row.date,
        isAvailable: row.isBlockedByHost ? false : row.isAvailable,
        isBlockedByHost: row.isBlockedByHost,
        priceOverride: row.priceOverride ?? null,
        minNightsOverride: row.minNightsOverride ?? null,
        notes: trimmedNotes ? trimmedNotes : null,
    };

    const isDefaultState =
        normalizedRow.isAvailable &&
        !normalizedRow.isBlockedByHost &&
        normalizedRow.priceOverride === null &&
        normalizedRow.minNightsOverride === null &&
        normalizedRow.notes === null;

    return {
        normalizedRow,
        isDefaultState,
    };
};

const assertSafeImageUrl = (url: string) => {
    try {
        const parsed = new URL(url);

        if (!["http:", "https:"].includes(parsed.protocol) || parsed.username || parsed.password) {
            throw new Error("Invalid image URL");
        }
    } catch {
        throw new ApiError(422, "Validation error", [
            {
                path: "images.url",
                msg: "images.url must be a valid http(s) URL",
            },
        ]);
    }
};

const replaceListingAmenityRows = async (listingId: number, amenityIds: number[], transaction?: Transaction) => {
    await ListingAmenity.destroy({
        where: {
            listingId,
        },
        transaction,
    });

    if (amenityIds.length > 0) {
        await ListingAmenity.bulkCreate(
            amenityIds.map((amenityId) => ({
                listingId,
                amenityId,
            })),
            {
                transaction,
                ignoreDuplicates: true,
            },
        );
    }
};

const upsertListingRules = async (
    listingId: number,
    values: {
        checkInFrom: string;
        checkOutBefore: string;
        smokingAllowed: boolean;
        petsAllowed: boolean;
        partyAllowed: boolean;
        quietHours: string | null;
    },
    transaction?: Transaction,
) => {
    const existing = await ListingRule.findOne({
        where: {
            listingId,
        },
        transaction,
    });

    if (!existing) {
        await ListingRule.create(
            {
                listingId,
                ...values,
                extraRules: null,
            },
            { transaction },
        );
        return;
    }

    await existing.update(values, { transaction });
};

const markPublishedListingPendingIfSensitive = (listing: ListingDocument, actor: HostActor, changed: boolean) => {
    if (!actor.isAdmin && changed && listing.status === "active") {
        listing.status = "pending_approval";
        return true;
    }

    return false;
};

const writeListingAudit = async (
    actor: HostActor,
    action: string,
    listingId: number,
    metadata?: Record<string, unknown>,
    transaction?: Transaction,
) => {
    await writeAuditLog({
        actorId: Number(actor.userId),
        action,
        targetType: "listing",
        targetId: listingId,
        metadata,
        transaction,
    });
};

const serializeHostListingSummary = async (listing: ListingDocument) => {
    const images = await getListingImagesForListing(listing);

    return {
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
        extraGuestFee: listing.extraGuestFee ?? null,
        currency: listing.currency,
        imageUrl: getCoverImage(images)?.url ?? null,
        coverImage: getCoverImage(images) ? serializeListingImage(getCoverImage(images)!) : null,
        images: images.map(serializeListingImage),
    };
};

const serializeHostListingDetail = async (listing: ListingDocument) => {
    const [amenityIds, images, rules] = await Promise.all([
        getListingAmenityIdsForListing(listing),
        getListingImagesForListing(listing),
        getListingRulesForListing(listing),
    ]);

    return {
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
        includedGuests: listing.includedGuests ?? null,
        bedrooms: listing.bedrooms,
        beds: listing.beds,
        bathrooms: listing.bathrooms,
        basePrice: listing.basePrice,
        weekendPrice: listing.weekendPrice ?? null,
        cleaningFee: listing.cleaningFee ?? null,
        surchargeAmount: listing.surchargeAmount ?? null,
        serviceFeePct: listing.serviceFeePct ?? null,
        extraGuestFee: listing.extraGuestFee ?? null,
        currency: listing.currency,
        minNights: listing.minNights,
        maxNights: listing.maxNights ?? null,
        checkInFrom: rules.checkInFrom,
        checkOutBefore: rules.checkOutBefore,
        cancellationPolicy: listing.cancellationPolicy,
        instantBookEnabled: listing.instantBookEnabled,
        amenityIds,
        images: images.map(serializeListingImage),
        smokingAllowed: rules.smokingAllowed,
        petsAllowed: rules.petsAllowed,
        partyAllowed: rules.partyAllowed,
        quietHours: rules.quietHours,
        createdAt: listing.createdAt,
        updatedAt: listing.updatedAt,
    };
};

export const createListing = async (
    userId: string,
    input: CreateListingInput,
    options: CreateListingOptions = {},
) => {
    const actor: HostActor = {
        userId,
        isAdmin: Boolean(options.isAdmin),
    };
    const sanitizedInput = sanitizeCreateListingInput(normalizeCreateListingLocationInput(input));
    const amenityIds = uniqueNumbers(input.amenityIds ?? []);
    const nextStatus = input.status === "pending_approval" ? "pending_approval" : "draft";

    await assertAmenityIdsExist(amenityIds);
    assertNightsRange(sanitizedInput.minNights, sanitizedInput.maxNights);

    const listing = await sequelize.transaction(async (transaction) => {
        await assertHostCanRequestReview(Number(userId), nextStatus, actor, transaction);

        const createdListing = new Listing({
            listingId: await getNextSequence("listing", 101),
            hostId: Number(userId),
            ...sanitizedInput,
            amenityIds,
            status: nextStatus,
            rejectionReason: null,
            approvedBy: null,
            approvedAt: null,
            smokingAllowed: false,
            petsAllowed: false,
            partyAllowed: false,
            quietHours: null,
            images: [],
            availabilityCalendar: [],
            deletedAt: null,
        });

        await createdListing.save({ transaction });
        await replaceListingAmenityRows(createdListing.listingId, amenityIds, transaction);
        await upsertListingRules(
            createdListing.listingId,
            {
                checkInFrom: createdListing.checkInFrom,
                checkOutBefore: createdListing.checkOutBefore,
                smokingAllowed: false,
                petsAllowed: false,
                partyAllowed: false,
                quietHours: null,
            },
            transaction,
        );
        await writeListingAudit(actor, "host_listing.create", createdListing.listingId, {
            status: toApiListingStatus(createdListing.status),
        }, transaction);

        if (createdListing.status === "pending_approval") {
            await notifyListingSubmitted(createdListing.listingId, transaction);
        }

        return createdListing;
    });

    scheduleSemanticReindex(listing.listingId, "listing_create");

    return {
        listingId: listing.listingId,
        status: toApiListingStatus(listing.status),
    };
};

export const getMyListings = async (actor: HostActor, query: ListMineQuery) => {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(hostListingsMaxPageLimit, Math.max(1, query.limit ?? 10));
    const filter: {
        hostId?: number;
        deletedAt: null;
        status?: ListingStatus;
    } = {
        deletedAt: null,
    };

    if (!actor.isAdmin) {
        filter.hostId = Number(actor.userId);
    }

    if (query.status) {
        filter.status = toInternalListingStatus(query.status);
    }

    const [items, totalItems] = await Promise.all([
        Listing.find(filter)
            .sort({ createdAt: -1, listingId: -1 })
            .skip((page - 1) * limit)
            .limit(limit),
        Listing.countDocuments(filter),
    ]);

    return {
        items: await Promise.all(items.map(serializeHostListingSummary)),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

export const getListingDetail = async (listingId: number, actor: HostActor) => {
    const listing = await getListingForHost(listingId, actor);
    return serializeHostListingDetail(listing);
};

export const updateListing = async (listingId: number, actor: HostActor, input: UpdateListingInput) => {
    const sanitizedInput = sanitizeUpdateListingInput(normalizeUpdateListingLocationInput(input));
    const updated = await sequelize.transaction(async (transaction) => {
        const listing = await getListingForHost(listingId, actor, transaction);
        const hasCoordinateChange = hasOwn(sanitizedInput, "latitude") || hasOwn(sanitizedInput, "longitude");

        if (hasCoordinateChange) {
            assertCoordinateInDefaultListingCity(
                sanitizedInput.latitude ?? listing.latitude,
                sanitizedInput.longitude ?? listing.longitude,
            );
        }

        const previousStatus = listing.status;
        const nextMinNights = sanitizedInput.minNights ?? listing.minNights;
        const nextMaxNights = hasOwn(sanitizedInput, "maxNights")
            ? sanitizedInput.maxNights ?? null
            : listing.maxNights;
        const changedFields = Object.keys(sanitizedInput).filter((key) => key !== "status");
        const hasSensitiveChange = changedFields.some((field) =>
            sensitiveListingFields.has(field as keyof UpdateListingInput),
        );

        assertNightsRange(nextMinNights, nextMaxNights);

        if (sanitizedInput.status) {
            const requestedStatus = toInternalListingStatus(sanitizedInput.status);
            assertStatusTransition(listing.status, requestedStatus, actor);
            await assertHostCanRequestReview(Number(listing.hostId), requestedStatus, actor, transaction);

            listing.status = requestedStatus;
        }

        if (sanitizedInput.title !== undefined) listing.title = sanitizedInput.title;
        if (sanitizedInput.description !== undefined) listing.description = sanitizedInput.description;
        if (sanitizedInput.addressLine !== undefined) listing.addressLine = sanitizedInput.addressLine;
        if (sanitizedInput.ward !== undefined) listing.ward = sanitizedInput.ward;
        if (sanitizedInput.district !== undefined) listing.district = sanitizedInput.district;
        if (sanitizedInput.city !== undefined) listing.city = sanitizedInput.city;
        if (hasOwn(sanitizedInput, "stateRegion")) listing.stateRegion = sanitizedInput.stateRegion ?? null;
        if (sanitizedInput.country !== undefined) listing.country = sanitizedInput.country;
        if (hasOwn(sanitizedInput, "postalCode")) listing.postalCode = sanitizedInput.postalCode ?? null;
        if (sanitizedInput.latitude !== undefined) listing.latitude = sanitizedInput.latitude;
        if (sanitizedInput.longitude !== undefined) listing.longitude = sanitizedInput.longitude;
        if (sanitizedInput.propertyType !== undefined) listing.propertyType = sanitizedInput.propertyType;
        if (sanitizedInput.roomType !== undefined) listing.roomType = sanitizedInput.roomType;
        if (sanitizedInput.basePrice !== undefined) listing.basePrice = sanitizedInput.basePrice;
        if (hasOwn(sanitizedInput, "weekendPrice")) listing.weekendPrice = sanitizedInput.weekendPrice ?? null;
        if (hasOwn(sanitizedInput, "cleaningFee")) listing.cleaningFee = sanitizedInput.cleaningFee ?? null;
        if (hasOwn(sanitizedInput, "surchargeAmount")) listing.surchargeAmount = sanitizedInput.surchargeAmount ?? null;
        if (hasOwn(sanitizedInput, "serviceFeePct")) listing.serviceFeePct = sanitizedInput.serviceFeePct ?? null;
        if (hasOwn(sanitizedInput, "extraGuestFee")) listing.extraGuestFee = sanitizedInput.extraGuestFee ?? null;
        if (sanitizedInput.maxGuests !== undefined) listing.maxGuests = sanitizedInput.maxGuests;
        if (hasOwn(sanitizedInput, "includedGuests")) listing.includedGuests = sanitizedInput.includedGuests ?? null;
        if (sanitizedInput.bedrooms !== undefined) listing.bedrooms = sanitizedInput.bedrooms;
        if (sanitizedInput.beds !== undefined) listing.beds = sanitizedInput.beds;
        if (sanitizedInput.bathrooms !== undefined) listing.bathrooms = sanitizedInput.bathrooms;
        if (sanitizedInput.minNights !== undefined) listing.minNights = sanitizedInput.minNights;
        if (hasOwn(sanitizedInput, "maxNights")) listing.maxNights = sanitizedInput.maxNights ?? null;
        if (sanitizedInput.cancellationPolicy !== undefined) {
            listing.cancellationPolicy = sanitizedInput.cancellationPolicy;
        }
        if (sanitizedInput.instantBookEnabled !== undefined) {
            listing.instantBookEnabled = sanitizedInput.instantBookEnabled;
        }

        const forcedPendingApproval = markPublishedListingPendingIfSensitive(listing, actor, hasSensitiveChange);
        await listing.save({ transaction });
        await writeListingAudit(actor, "host_listing.update", listing.listingId, {
            changedFields,
            forcedPendingApproval,
            fromStatus: toApiListingStatus(previousStatus),
            status: toApiListingStatus(listing.status),
        }, transaction);

        if (previousStatus !== listing.status && listing.status === "pending_approval") {
            await notifyListingSubmitted(listing.listingId, transaction);
        }

        if (previousStatus !== listing.status && listing.status === "inactive") {
            await writeListingAudit(actor, "host_listing.hide", listing.listingId, {
                fromStatus: toApiListingStatus(previousStatus),
                toStatus: "hidden",
            }, transaction);
        }

        return listing;
    });

    scheduleSemanticReindex(updated.listingId, "listing_update");

    return {
        listingId: updated.listingId,
        status: toApiListingStatus(updated.status),
    };
};

export const deleteListing = async (listingId: number, actor: HostActor) => {
    await sequelize.transaction(async (transaction) => {
        const listing = await getListingForHost(listingId, actor, transaction);
        listing.deletedAt = new Date();
        listing.status = "inactive";
        await listing.save({ transaction });
        await writeListingAudit(actor, "host_listing.delete", listing.listingId, undefined, transaction);
    });

    scheduleSemanticReindex(listingId, "listing_delete");
};

export const addListingImages = async (listingId: number, actor: HostActor, input: AddListingImagesInput) => {
    const inputImages: AddListingImageItem[] = Array.isArray(input.images)
        ? input.images
        : input.url
            ? [
                  {
                      url: input.url,
                      key: input.key,
                      objectKey: input.objectKey,
                      originalFilename: input.originalFilename,
                      displayTitle: input.displayTitle,
                      altText: input.altText,
                      caption: input.caption,
                      sortOrder: input.sortOrder,
                      isCover: input.isCover,
                  },
              ]
            : [];

    if (inputImages.length === 0) {
        throw new ApiError(422, "Validation error", [
            {
                path: "images",
                msg: "At least one image is required",
            },
        ]);
    }

    const result = await sequelize.transaction(async (transaction) => {
        const listing = await getListingForHost(listingId, actor, transaction);
        const currentImages = await getListingImagesForListing(listing, transaction);
        const existingSortOrders = new Set(currentImages.map((image) => image.sortOrder));
        const inputSortOrders = new Set<number>();
        let nextSortOrder = currentImages.reduce((max, image) => Math.max(max, image.sortOrder), -1) + 1;

        if (currentImages.length + inputImages.length > maxImagesPerListing) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "images",
                    msg: `A listing can have at most ${maxImagesPerListing} images`,
                },
            ]);
        }

        if (inputImages.filter((image) => image.isCover).length > 1) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "images.isCover",
                    msg: "Only one image can be marked as cover",
                },
            ]);
        }

        const normalizedImages = inputImages.map((image) => {
            assertSafeImageUrl(image.url);
            const sortOrder = image.sortOrder ?? nextSortOrder++;
            const objectKey = image.objectKey ?? image.key ?? null;

            if (existingSortOrders.has(sortOrder) || inputSortOrders.has(sortOrder)) {
                throw new ApiError(422, "Validation error", [
                    {
                        path: "images",
                        msg: "sortOrder must be unique per listing",
                    },
                ]);
            }

            inputSortOrders.add(sortOrder);

            return {
                ...image,
                objectKey,
                originalFilename: sanitizeNullableSingleLineText(image.originalFilename),
                displayTitle: sanitizeNullableSingleLineText(image.displayTitle),
                altText: sanitizeNullableSingleLineText(image.altText) ?? listing.title ?? "Ảnh chỗ nghỉ",
                caption: sanitizeNullableSingleLineText(image.caption),
                sortOrder,
            };
        });

        const hasNewCoverImage = normalizedImages.some((image) => image.isCover);

        if (hasNewCoverImage) {
            await ListingImage.update(
                {
                    isCover: false,
                },
                {
                    where: {
                        listingId: listing.listingId,
                    },
                    transaction,
                },
            );
        }

        const createdRows = await ListingImage.bulkCreate(
            normalizedImages.map((image) => ({
                listingId: listing.listingId,
                url: image.url,
                objectKey: image.objectKey,
                originalFilename: image.originalFilename,
                displayTitle: image.displayTitle,
                altText: image.altText,
                caption: image.caption,
                sortOrder: image.sortOrder,
                isCover: Boolean(image.isCover),
            })),
            { transaction },
        );

        const appendedImages: ListingImageRecord[] = createdRows.map((row) => ({
            imageId: Number(row.id),
            url: row.url,
            objectKey: row.objectKey,
            key: row.objectKey,
            originalFilename: row.originalFilename,
            displayTitle: row.displayTitle,
            altText: row.altText,
            caption: row.caption,
            sortOrder: row.sortOrder,
            isCover: row.isCover,
        }));

        const existingImagesForListingJson = hasNewCoverImage
            ? currentImages.map((image) => ({ ...image, isCover: false }))
            : currentImages;

        listing.images = [...existingImagesForListingJson, ...appendedImages].sort(
            (left, right) => left.sortOrder - right.sortOrder,
        );
        const forcedPendingApproval = markPublishedListingPendingIfSensitive(listing, actor, true);
        await listing.save({ transaction });
        await writeListingAudit(actor, "host_listing.images.add", listing.listingId, {
            count: appendedImages.length,
            forcedPendingApproval,
        }, transaction);

        if (forcedPendingApproval) {
            await notifyListingSubmitted(listing.listingId, transaction);
        }

        return {
            count: appendedImages.length,
            status: toApiListingStatus(listing.status),
            images: appendedImages.map(serializeListingImage),
        };
    });

    return result;
};

export const deleteListingImage = async (listingId: number, imageId: number, actor: HostActor) => {
    await sequelize.transaction(async (transaction) => {
        const listing = await getListingForHost(listingId, actor, transaction);
        const currentImages = await getListingImagesForListing(listing, transaction);
        const image = currentImages.find((item) => item.imageId === imageId);

        if (!image) {
            throw new ApiError(404, "Image not found");
        }

        await ListingImage.destroy({
            where: {
                listingId: listing.listingId,
                id: imageId,
            },
            transaction,
        });

        listing.images = currentImages.filter((item) => item.imageId !== imageId);
        const forcedPendingApproval = markPublishedListingPendingIfSensitive(listing, actor, true);
        await listing.save({ transaction });
        await writeListingAudit(actor, "host_listing.images.delete", listing.listingId, {
            imageId,
            forcedPendingApproval,
        }, transaction);

        if (forcedPendingApproval) {
            await notifyListingSubmitted(listing.listingId, transaction);
        }
    });
};

export const setListingImageCover = async (listingId: number, imageId: number, actor: HostActor) => {
    const updatedImage = await sequelize.transaction(async (transaction) => {
        const listing = await getListingForHost(listingId, actor, transaction);
        const image = await ListingImage.findOne({
            where: {
                listingId: listing.listingId,
                id: imageId,
            },
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!image) {
            throw new ApiError(404, "Image not found");
        }

        await ListingImage.update(
            {
                isCover: false,
            },
            {
                where: {
                    listingId: listing.listingId,
                },
                transaction,
            },
        );

        await image.update({ isCover: true }, { transaction });

        const currentImages = await getListingImagesForListing(listing, transaction);
        listing.images = currentImages.map((item) => ({
            ...item,
            isCover: item.imageId === imageId,
        }));
        const forcedPendingApproval = markPublishedListingPendingIfSensitive(listing, actor, true);
        await listing.save({ transaction });
        await writeListingAudit(actor, "host_listing.images.set_cover", listing.listingId, {
            imageId,
            forcedPendingApproval,
        }, transaction);

        if (forcedPendingApproval) {
            await notifyListingSubmitted(listing.listingId, transaction);
        }

        return image;
    });

    return {
        image: serializeListingImage({
            imageId: Number(updatedImage.id),
            url: updatedImage.url,
            objectKey: updatedImage.objectKey,
            key: updatedImage.objectKey,
            originalFilename: updatedImage.originalFilename,
            displayTitle: updatedImage.displayTitle,
            altText: updatedImage.altText,
            caption: updatedImage.caption,
            sortOrder: updatedImage.sortOrder,
            isCover: true,
        }),
    };
};

export const replaceListingAmenities = async (listingId: number, actor: HostActor, input: ReplaceAmenitiesInput) => {
    const amenityIds = uniqueNumbers(input.amenityIds);

    await assertAmenityIdsExist(amenityIds);

    const listing = await sequelize.transaction(async (transaction) => {
        const existingListing = await getListingForHost(listingId, actor, transaction);
        existingListing.amenityIds = amenityIds;
        await replaceListingAmenityRows(existingListing.listingId, amenityIds, transaction);
        await existingListing.save({ transaction });
        await writeListingAudit(actor, "host_listing.amenities.replace", existingListing.listingId, {
            amenityIds,
        }, transaction);
        return existingListing;
    });

    scheduleSemanticReindex(listing.listingId, "listing_amenities_replace");

    return {
        listingId: listing.listingId,
        amenityCount: amenityIds.length,
    };
};

export const updateListingRules = async (listingId: number, actor: HostActor, input: UpdateRulesInput) => {
    const listing = await sequelize.transaction(async (transaction) => {
        const existingListing = await getListingForHost(listingId, actor, transaction);

        if (input.checkInFrom !== undefined) existingListing.checkInFrom = input.checkInFrom;
        if (input.checkOutBefore !== undefined) existingListing.checkOutBefore = input.checkOutBefore;
        if (input.smokingAllowed !== undefined) existingListing.smokingAllowed = input.smokingAllowed;
        if (input.petsAllowed !== undefined) existingListing.petsAllowed = input.petsAllowed;
        if (input.partyAllowed !== undefined) existingListing.partyAllowed = input.partyAllowed;
        if (hasOwn(input, "quietHours")) {
            existingListing.quietHours = sanitizeNullableSingleLineText(input.quietHours);
        }

        await upsertListingRules(
            existingListing.listingId,
            {
                checkInFrom: existingListing.checkInFrom,
                checkOutBefore: existingListing.checkOutBefore,
                smokingAllowed: existingListing.smokingAllowed,
                petsAllowed: existingListing.petsAllowed,
                partyAllowed: existingListing.partyAllowed,
                quietHours: existingListing.quietHours ?? null,
            },
            transaction,
        );
        await existingListing.save({ transaction });
        await writeListingAudit(actor, "host_listing.rules.update", existingListing.listingId, {
            changedFields: Object.keys(input),
        }, transaction);

        return existingListing;
    });

    scheduleSemanticReindex(listing.listingId, "listing_rules_update");

    return {
        listingId: listing.listingId,
    };
};

export const getListingCalendar = async (listingId: number, actor: HostActor, query: GetCalendarQuery) => {
    const listing = await getListingForHost(listingId, actor);
    const now = new Date();
    const month = query.month ?? now.getUTCMonth() + 1;
    const year = query.year ?? now.getUTCFullYear();
    const totalDays = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const todayVN = getTodayInVietnamDateString(now);
    const calendarRows = await getAvailabilityCalendarForListing(listing);
    const availabilityMap = new Map(calendarRows.map((item) => [item.date, item] as const));

    // Find all active bookings that overlap this month so we can mark booked dates
    const monthStart = `${year}-${String(month).padStart(2, "0")}-01`;
    const monthEnd = new Date(Date.UTC(year, month, 1)).toISOString().slice(0, 10); // first day of NEXT month
    const activeBookings = await Booking.findAll({
        where: {
            listingId: listing.listingId,
            ...buildActiveBookingStatusWhere(),
            checkInDate: { [Op.lt]: monthEnd },
            checkOutDate: { [Op.gt]: monthStart },
        },
        attributes: ["checkInDate", "checkOutDate"],
    });

    const bookedDateSet = new Set<string>();
    for (const booking of activeBookings) {
        const cursor = new Date(`${booking.checkInDate}T00:00:00.000Z`);
        const end = new Date(`${booking.checkOutDate}T00:00:00.000Z`);

        while (cursor < end) {
            bookedDateSet.add(cursor.toISOString().slice(0, 10));
            cursor.setUTCDate(cursor.getUTCDate() + 1);
        }
    }

    const days = Array.from({ length: totalDays }, (_, index) => {
        const day = String(index + 1).padStart(2, "0");
        const monthValue = String(month).padStart(2, "0");
        const date = `${year}-${monthValue}-${day}`;
        const existing = availabilityMap.get(date);
        const isPast = date < todayVN;
        const isBooked = bookedDateSet.has(date);

        return {
            date,
            isAvailable: existing ? (existing.isBlockedByHost ? false : existing.isAvailable) : true,
            isBlockedByHost: existing?.isBlockedByHost ?? false,
            /** True when an active guest booking covers this date — host cannot close it */
            isBooked,
            /** True when the date is before today in Vietnam timezone */
            isPast,
            /** True when the host is allowed to modify this date */
            canEdit: !isPast && !isBooked,
            price: existing?.priceOverride ?? getDefaultDailyPrice(listing, date),
            minNights: existing?.minNightsOverride ?? listing.minNights,
            priceOverride: existing?.priceOverride ?? null,
            minNightsOverride: existing?.minNightsOverride ?? null,
            notes: existing?.notes ?? null,
            defaultPrice: getDefaultDailyPrice(listing, date),
            defaultMinNights: listing.minNights,
        };
    });

    return {
        listingId: listing.listingId,
        month,
        year,
        days,
    };
};

export const bulkUpdateListingCalendar = async (
    listingId: number,
    actor: HostActor,
    input: BulkCalendarUpdateInput,
) => {
    if (
        input.isAvailable === undefined &&
        input.isBlockedByHost === undefined &&
        !hasOwn(input, "priceOverride") &&
        !hasOwn(input, "minNightsOverride") &&
        !hasOwn(input, "notes")
    ) {
        throw new ApiError(422, "Validation error", [
            {
                path: "dates",
                msg: "At least one calendar field must be provided",
            },
        ]);
    }

    const invalidDate = input.dates.find((date) => !isValidIsoDate(date));

    if (invalidDate) {
        throw new ApiError(422, "Validation error", [
            {
                path: "dates",
                msg: `Invalid date: ${invalidDate}`,
            },
        ]);
    }

    const uniqueDates = Array.from(new Set(input.dates)).sort();

    // Reject any request containing past dates (Vietnam timezone UTC+7)
    const todayVN = getTodayInVietnamDateString();
    const pastDates = uniqueDates.filter((date) => date < todayVN);

    if (pastDates.length > 0) {
        throw new ApiError(422, "Cannot update past calendar dates", [
            {
                path: "dates",
                msg: `Cannot update past dates: ${pastDates.join(", ")}`,
            },
        ]);
    }

    return sequelize.transaction(async (transaction) => {
        const listing = await getListingForHost(listingId, actor, transaction);

        if (input.isBlockedByHost === true || input.isAvailable === false) {
            const bookedDates = await findBookedCalendarDates(listing.listingId, uniqueDates, transaction);

            if (bookedDates.length > 0) {
                throw new ApiError(409, "Cannot block dates with active bookings", [
                    {
                        path: "dates",
                        msg: `Dates already have active bookings: ${bookedDates.join(", ")}`,
                    },
                ]);
            }
        }

        const calendarRows = await getAvailabilityCalendarForListing(listing, transaction);
        const availabilityMap = new Map(calendarRows.map((item) => [item.date, item] as const));

        for (const date of uniqueDates) {
            const current =
                availabilityMap.get(date) ?? ({
                    date,
                    isAvailable: true,
                    isBlockedByHost: false,
                    priceOverride: null,
                    minNightsOverride: null,
                    notes: null,
                } satisfies ListingAvailabilityDayRecord);

            const nextRow: ListingAvailabilityDayRecord = {
                ...current,
            };

            if (input.isBlockedByHost !== undefined) {
                nextRow.isBlockedByHost = input.isBlockedByHost;

                if (input.isBlockedByHost) {
                    nextRow.isAvailable = false;
                } else if (input.isAvailable === undefined) {
                    nextRow.isAvailable = true;
                }
            }

            if (input.isAvailable !== undefined) {
                nextRow.isAvailable = input.isAvailable;
            }

            if (nextRow.isBlockedByHost) {
                nextRow.isAvailable = false;
            }

            if (hasOwn(input, "priceOverride")) nextRow.priceOverride = input.priceOverride ?? null;
            if (hasOwn(input, "minNightsOverride")) nextRow.minNightsOverride = input.minNightsOverride ?? null;
            if (hasOwn(input, "notes")) nextRow.notes = sanitizeNullableSingleLineText(input.notes);

            const { normalizedRow, isDefaultState } = normalizeCalendarRow(nextRow);

            if (isDefaultState) {
                availabilityMap.delete(date);
                await AvailabilityCalendar.destroy({
                    where: {
                        listingId: listing.listingId,
                        date,
                    },
                    transaction,
                });
            } else {
                availabilityMap.set(date, normalizedRow);
                const existing = await AvailabilityCalendar.findOne({
                    where: {
                        listingId: listing.listingId,
                        date,
                    },
                    transaction,
                });

                const values = {
                    listingId: listing.listingId,
                    date,
                    isAvailable: normalizedRow.isAvailable,
                    isBlockedByHost: normalizedRow.isBlockedByHost,
                    priceOverride: normalizedRow.priceOverride ?? null,
                    minNightsOverride: normalizedRow.minNightsOverride ?? null,
                    notes: normalizedRow.notes ?? null,
                };

                if (existing) {
                    await existing.update(values, { transaction });
                } else {
                    await AvailabilityCalendar.create(values, { transaction });
                }
            }
        }

        listing.availabilityCalendar = Array.from(availabilityMap.values()).sort((left, right) =>
            left.date.localeCompare(right.date),
        );
        await listing.save({ transaction });
        await writeListingAudit(actor, "host_listing.calendar.bulk_update", listing.listingId, {
            updatedDates: uniqueDates,
        }, transaction);

        return {
            listingId: listing.listingId,
            updatedDates: uniqueDates,
        };
    });
};

export const getBookingBlockingStatuses = () => [...bookingBlockingStatuses];
