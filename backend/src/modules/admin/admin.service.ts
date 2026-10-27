import { ApiError } from "../../common/api-error";
import { getCoverImage, serializeListingImage, toApiListingStatus } from "../../common/listing-mappers";
import {
    getListingAmenityIdsForListing,
    getListingImagesForListing,
    getListingImagesMap,
    getListingRulesForListing,
} from "../../common/listing-relations";
import { sanitizeText } from "../../common/sanitization";
import sequelize from "../../config/database";
import Amenity from "../../models/amenity";
import Listing, { ListingDocument } from "../../models/listing";
import { Op, type Transaction } from "sequelize";
import User from "../../models/user";
import type { AuthenticatedUser } from "../auth/auth.service";
import { writeAuditLog } from "../../services/audit-log-service";
import { isHostVerifiedForPublishing } from "../../services/host-verification-status-service";
import {
    notifyListingApproved,
    notifyListingRejected,
} from "../notifications/notification.service";
import { scheduleSemanticReindex } from "../semantic-search/semantic-search.indexer";

export type AdminListingQuery = {
    page?: number;
    limit?: number;
};

export type RejectListingInput = {
    reason: string;
};

export type AdminListingActionContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

export const adminListingsMaxPageLimit = 50;

const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(adminListingsMaxPageLimit, Math.max(1, limit ?? 10)),
});

const assertCanModerateListings = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin") && !user.roles.includes("moderator")) {
        throw new ApiError(403, "Forbidden");
    }
};

const serializeAdminListing = (listing: ListingDocument, images = listing.images) => {
    const coverImage = getCoverImage(images);
    const serializedCoverImage = coverImage ? serializeListingImage(coverImage) : null;

    return {
        listingId: listing.listingId,
        hostId: listing.hostId,
        title: listing.title,
        status: toApiListingStatus(listing.status),
        description: listing.description,
        addressLine: listing.addressLine,
        ward: listing.ward,
        district: listing.district,
        city: listing.city,
        propertyType: listing.propertyType,
        roomType: listing.roomType,
        basePrice: listing.basePrice,
        currency: listing.currency,
        imageUrl: serializedCoverImage?.url ?? null,
        coverImageUrl: serializedCoverImage?.url ?? null,
        coverImage: serializedCoverImage,
        images: images.map(serializeListingImage),
        rejectionReason: listing.rejectionReason ?? null,
        approvedBy: listing.approvedBy ?? null,
        approvedAt: listing.approvedAt ?? null,
        createdAt: listing.createdAt,
        updatedAt: listing.updatedAt,
    };
};

const getListingOrThrow = async (listingId: number, transaction?: Transaction) => {
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

    return listing;
};

export const listPendingAdminListings = async (actor: AuthenticatedUser, query: AdminListingQuery) => {
    assertCanModerateListings(actor);

    const { page, limit } = toPagination(query.page, query.limit);
    const filter = {
        status: "pending_approval" as const,
        deletedAt: null,
    };

    const [items, totalItems] = await Promise.all([
        Listing.find(filter)
            .sort({ createdAt: -1, listingId: -1 })
            .skip((page - 1) * limit)
            .limit(limit),
        Listing.countDocuments(filter),
    ]);

    const imageMap = await getListingImagesMap(items);

    return {
        items: items.map((listing) => serializeAdminListing(listing, imageMap.get(listing.listingId) ?? listing.images)),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

export const approveAdminListing = async (
    listingId: number,
    admin: AuthenticatedUser,
    context: AdminListingActionContext = {},
) => {
    const result = await sequelize.transaction(async (transaction) => {
        assertCanModerateListings(admin);

        const listing = await getListingOrThrow(listingId, transaction);

        if (listing.status !== "pending_approval") {
            throw new ApiError(409, "Listing is not pending approval");
        }

        if (!(await isHostVerifiedForPublishing(Number(listing.hostId), transaction))) {
            throw new ApiError(422, "Host must be verified before listing can be published");
        }

        listing.status = "active";
        listing.approvedBy = Number(admin.id);
        listing.approvedAt = new Date();
        listing.rejectionReason = null;
        await listing.save({ transaction });

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "listing.approve",
            targetType: "listing",
            targetId: listing.listingId,
            metadata: {
                hostId: listing.hostId,
                fromStatus: "pending_approval",
                toStatus: "published",
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
        await notifyListingApproved(listing.listingId, transaction);

        return serializeAdminListing(listing);
    });

    scheduleSemanticReindex(listingId, "listing_approved");
    return result;
};

export const rejectAdminListing = async (
    listingId: number,
    admin: AuthenticatedUser,
    input: RejectListingInput,
    context: AdminListingActionContext = {},
) =>
    sequelize.transaction(async (transaction) => {
        assertCanModerateListings(admin);

        const listing = await getListingOrThrow(listingId, transaction);

        if (listing.status !== "pending_approval") {
            throw new ApiError(409, "Listing is not pending approval");
        }

        const rejectionReason = sanitizeText(input.reason);

        if (!rejectionReason) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "reason",
                    msg: "reason cannot be empty after sanitization",
                },
            ]);
        }

        listing.status = "rejected";
        listing.rejectionReason = rejectionReason;
        listing.approvedBy = null;
        listing.approvedAt = null;
        await listing.save({ transaction });

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "listing.reject",
            targetType: "listing",
            targetId: listing.listingId,
            metadata: {
                hostId: listing.hostId,
                fromStatus: "pending_approval",
                toStatus: "rejected",
                rejectionReason: listing.rejectionReason,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
        await notifyListingRejected(listing.listingId, transaction);

        return serializeAdminListing(listing);
    });

export async function getAdminListingDetail(listingId: number) {
    const listing = await Listing.findOne({
        where: {
            listingId,
            deletedAt: null,
        },
    });

    if (!listing) {
        throw new ApiError(404, "Không tìm thấy căn cần kiểm duyệt");
    }

    const [host, amenityIds, images, rules] = await Promise.all([
        User.findByPk(listing.hostId, {
            attributes: [
                "userId",
                "fullName",
                "email",
                "phone",
                "isHostVerified",
                "hostApplicationStatus",
            ],
        }),
        getListingAmenityIdsForListing(listing),
        getListingImagesForListing(listing),
        getListingRulesForListing(listing),
    ]);

    const amenities = amenityIds.length
        ? await Amenity.findAll({
            where: {
                amenityId: {
                    [Op.in]: amenityIds,
                },
            },
            order: [["amenityId", "ASC"]],
        })
        : [];
    const serializedImages = images.map(serializeListingImage);
    const coverImage = getCoverImage(images);
    const serializedCoverImage = coverImage ? serializeListingImage(coverImage) : null;

    return {
        listingId: listing.listingId,
        hostId: listing.hostId,
        host: host
            ? {
                userId: host.userId,
                fullName: host.fullName,
                email: host.email,
                phone: host.phone,
                isHostVerified: host.isHostVerified,
                hostApplicationStatus: host.hostApplicationStatus,
            }
            : null,
        title: listing.title,
        description: listing.description,
        addressLine: listing.addressLine,
        ward: listing.ward,
        district: listing.district,
        city: listing.city,
        propertyType: listing.propertyType,
        roomType: listing.roomType,
        maxGuests: listing.maxGuests,
        bedrooms: listing.bedrooms,
        beds: listing.beds,
        bathrooms: listing.bathrooms,
        basePrice: listing.basePrice,
        weekendPrice: listing.weekendPrice,
        cleaningFee: listing.cleaningFee,
        serviceFeePct: listing.serviceFeePct,
        currency: listing.currency,
        minNights: listing.minNights,
        maxNights: listing.maxNights,
        checkInFrom: listing.checkInFrom,
        checkOutBefore: listing.checkOutBefore,
        cancellationPolicy: listing.cancellationPolicy,
        instantBookEnabled: listing.instantBookEnabled,
        amenities: amenities.map((amenity) => amenity.get({ plain: true })),
        amenityIds,
        images: serializedImages,
        imageUrl: serializedCoverImage?.url ?? null,
        coverImageUrl: serializedCoverImage?.url ?? null,
        coverImage: serializedCoverImage,
        rules,
        status: listing.status,
        apiStatus: toApiListingStatus(listing.status),
        rejectionReason: listing.rejectionReason,
        approvedBy: listing.approvedBy,
        approvedAt: listing.approvedAt,
        createdAt: listing.createdAt,
        updatedAt: listing.updatedAt,
    };
}
