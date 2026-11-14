import { ApiError } from "../../common/api-error";
import { getCoverImage, serializeListingImage, toApiListingStatus } from "../listings/listing-mappers";
import {
    getListingAmenityIdsForListing,
    getListingImagesForListing,
    getListingImagesMap,
    getListingRulesForListing,
} from "../listings/listing-relations";
import { sanitizeText } from "../../common/sanitization";
import sequelize from "../../config/database";
import Amenity from "../../models/amenity";
import Listing, { ListingDocument } from "../../models/listing";
import { Op, type Transaction } from "sequelize";
import User from "../../models/user";
import type { AuthenticatedUser } from "../auth/auth.service";
import { writeAuditLog } from "../../services/audit-log.service";
import { isHostVerifiedForPublishing } from "../host-kyc/host-status-sync.service";
import {
    notifyListingApproved,
    notifyListingRejected,
} from "../notifications/notification.service";
import { enqueueHostSheetSyncJobSafe } from "../host-sheet-sync/host-sheet-sync.service";

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

/**
 * Giải thuật chuẩn hóa và kẹp biên tham số phân trang cho trang kiểm duyệt Admin (`page >= 1`, `1 <= limit <= 50`).
 */
const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(adminListingsMaxPageLimit, Math.max(1, limit ?? 10)),
});

/**
 * Giải thuật kiểm tra đặc quyền kiểm duyệt chỗ nghỉ (RBAC Guard): chỉ cho phép tài khoản có vai trò `admin` thao tác; ném lỗi 403 nếu vi phạm.
 */
const assertCanModerateListings = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật tuần tự hóa hồ sơ chỗ nghỉ phục vụ hàng đợi kiểm duyệt của Admin, trích xuất ảnh bìa (`getCoverImage`) và ánh xạ trạng thái API hiển thị.
 */
const serializeAdminListing = (listing: ListingDocument, images = listing.images ?? []) => {
    const safeImages = Array.isArray(images) ? images : [];
    const coverImage = getCoverImage(safeImages);
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
        images: safeImages.map(serializeListingImage),
        rejectionReason: listing.rejectionReason ?? null,
        approvedBy: listing.approvedBy ?? null,
        approvedAt: listing.approvedAt ?? null,
        createdAt: listing.createdAt,
        updatedAt: listing.updatedAt,
    };
};

/**
 * Giải thuật truy vấn chỗ nghỉ chưa xóa mềm trong phạm vi giao dịch kiểm duyệt; ném lỗi 404 nếu bản ghi không tồn tại.
 */
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

/**
 * Giải thuật truy vấn phân trang hàng đợi các chỗ nghỉ đang chờ kiểm duyệt (`status = "pending_approval"`, `deletedAt = null`):
 * Tải song song danh sách bản ghi và tổng số dòng, đồng thời gom nạp hàng loạt hình ảnh qua `getListingImagesMap` để khử truy vấn N+1.
 */
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

/**
 * Giải thuật phê duyệt xuất bản chỗ nghỉ trong giao dịch CSDL:
 * - Xác thực quyền Admin, kiểm tra bất biến trạng thái hiện tại bắt buộc là `pending_approval` (lỗi 409 nếu sai lệch) và tài khoản Chủ nhà đã được xác minh hợp lệ (`isHostVerifiedForPublishing`, lỗi 422 nếu chưa).
 * - Chuyển trạng thái sang `active`, ghi dấu `approvedBy`/`approvedAt`, xóa lý do từ chối cũ, ghi audit log, phát thông báo duyệt thành công cho Host và đẩy đồng bộ Google Sheet.
 */
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

    enqueueHostSheetSyncJobSafe({
        hostUserId: Number(result.hostId),
        jobType: "listing_updated",
        listingId,
    });
    return result;
};

/**
 * Giải thuật từ chối kiểm duyệt chỗ nghỉ trong giao dịch CSDL:
 * - Xác thực quyền Admin, trạng thái `pending_approval` và làm sạch chống XSS lý do từ chối (ném lỗi 422 nếu rỗng sau làm sạch).
 * - Chuyển trạng thái sang `rejected`, lưu lý do từ chối, xóa dấu phê duyệt cũ, ghi audit log, gửi thông báo chỉnh sửa cho Host và kích hoạt đồng bộ Google Sheet bất đồng bộ.
 */
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
        const rejectedHostId = Number(listing.hostId);
        setImmediate(() => {
            enqueueHostSheetSyncJobSafe({
                hostUserId: rejectedHostId,
                jobType: "listing_updated",
                listingId: listing.listingId,
            });
        });

        return serializeAdminListing(listing);
    });

/**
 * Giải thuật chuyển nhượng quyền sở hữu chỗ nghỉ sang tài khoản Chủ nhà mới bởi Quản trị viên:
 * - Kiểm tra quyền Admin, xác thực tài khoản Host đích tồn tại và đang `active`, trả về sớm nếu trùng chủ cũ (idempotent).
 * - Cập nhật `listing.hostId`, ghi nhật ký kiểm toán đối chứng `(previousHostId, newHostId)` trong giao dịch CSDL và phát tác vụ đồng bộ Google Sheet cho cả chủ cũ lẫn chủ mới.
 */
export const transferAdminListingHost = async (
    listingId: number,
    newHostId: number,
    admin: AuthenticatedUser,
    context: AdminListingActionContext = {},
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Only administrators can transfer listing ownership");
    }

    let previousHostId = 0;

    const result = await sequelize.transaction(async (transaction) => {
        const listing = await getListingOrThrow(listingId, transaction);
        previousHostId = Number(listing.hostId);

        if (previousHostId === Number(newHostId)) {
            return serializeAdminListing(listing);
        }

        const targetHost = await User.findByPk(newHostId, { transaction });
        if (!targetHost || targetHost.status !== "active") {
            throw new ApiError(404, "Target host account not found or inactive");
        }

        listing.hostId = Number(newHostId);
        await listing.save({ transaction });

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "listing.transfer_host",
            targetType: "listing",
            targetId: listing.listingId,
            metadata: {
                previousHostId,
                newHostId: Number(newHostId),
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return serializeAdminListing(listing);
    });

    if (previousHostId && previousHostId !== Number(newHostId)) {
        enqueueHostSheetSyncJobSafe({
            hostUserId: previousHostId,
            jobType: "listing_transferred",
            listingId,
        });
        enqueueHostSheetSyncJobSafe({
            hostUserId: Number(newHostId),
            jobType: "listing_transferred",
            listingId,
        });
    }

    return result;
};

/**
 * Giải thuật tổng hợp hồ sơ thẩm định chi tiết một chỗ nghỉ cho Quản trị viên:
 * Nạp song song (`Promise.all`) thông tin xác minh của Chủ nhà, danh sách tiện ích, hình ảnh chuẩn hóa và nội quy lưu trú.
 */
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
    const safeImages = Array.isArray(images) ? images : [];
    const serializedImages = safeImages.map(serializeListingImage);
    const coverImage = getCoverImage(safeImages);
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
