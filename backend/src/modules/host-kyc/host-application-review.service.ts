// CONFLICT-RESOLVED: Tách riêng nghiệp vụ xét duyệt hồ sơ KYC dành cho Quản trị viên khỏi `host-application.service.ts`
// để giữ mỗi tệp dịch vụ dưới ngưỡng ~300 dòng theo quy tắc phân tách rõ ràng.
import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import HostApplication, {
    type HostApplicationStatus,
    type HostEntityType,
    hostApplicationStatusValues,
} from "../../models/host-application";
import HostIdentityDocument from "../../models/host-identity-document";
import User from "../../models/user";
import { writeAuditLog } from "../../services/audit-log.service";
import { getPrivateSignedUrlExpiresSeconds } from "../../services/private-r2-storage.service";
import type { AuthenticatedUser } from "../auth/auth.service";
import {
    notifyHostApplicationApproved,
    notifyHostApplicationRejected,
} from "../notifications/notification.service";
import { toKycPagination } from "./host-application.validator";
import { createHostDocStreamToken } from "./host-document-stream.service";
import { assertHostApplicationReadyForApproval } from "./host-kyc-policy";
import {
    markUserAsApprovedHost,
    updateUserHostApplicationStatus,
} from "./host-status-sync.service";

export type AdminHostApplicationsQuery = {
    status?: HostApplicationStatus | "all";
    page?: number;
    limit?: number;
};

export type RejectHostApplicationInput = {
    reason?: string | null;
};

export type AdminActionContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

/**
 * Truy vấn danh sách chứng từ định danh KYC thuộc một hồ sơ đăng ký Chủ nhà theo thứ tự thời gian tải lên tăng dần.
 */
export const getDocumentsForApplication = (applicationId: number, transaction?: Transaction) =>
    HostIdentityDocument.findAll({
        where: {
            applicationId,
        },
        order: [
            ["createdAt", "ASC"],
            ["id", "ASC"],
        ],
        transaction,
    });

/**
 * Truy vấn hồ sơ đăng ký Chủ nhà theo `applicationId` phục vụ nghiệp vụ xét duyệt của Admin hoặc ném lỗi `404` nếu không tồn tại.
 */
const getApplicationForAdminOrThrow = async (applicationId: number, transaction?: Transaction) => {
    const application = await HostApplication.findOne({
        where: {
            applicationId,
        },
        transaction,
    });

    if (!application) {
        throw new ApiError(404, "Host application not found");
    }

    return application;
};

/**
 * Giải thuật liệt kê và phân trang danh sách hồ sơ đăng ký Chủ nhà dành cho Quản trị viên:
 * 1. Kiểm tra phân quyền RBAC bắt buộc vai trò `admin`.
 * 2. Lọc trạng thái hợp lệ theo danh sách trắng `hostApplicationStatusValues` và truy vấn song song (`Promise.all`)
 *    dữ liệu kết nối `host_applications` - `users` - số lượng `host_identity_documents` cùng tổng số bản ghi bằng SQL tham số hóa.
 */
export const listAdminHostApplications = async (
    admin: AuthenticatedUser,
    query: AdminHostApplicationsQuery,
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const status =
        query.status &&
        query.status !== "all" &&
        (hostApplicationStatusValues as readonly string[]).includes(query.status)
            ? query.status
            : undefined;
    const { page, limit } = toKycPagination(query.page, query.limit, 20);
    const offset = (page - 1) * limit;
    const whereSql = status ? "WHERE ha.status = :status" : "";
    const replacements = { status, limit, offset };

    const [items, counts] = await Promise.all([
        sequelize.query<{
            applicationId: number;
            userId: number;
            contactName: string | null;
            contactEmail: string | null;
            phone: string;
            profileType: HostEntityType;
            businessAddress: string;
            status: HostApplicationStatus;
            rejectReason: string | null;
            reviewedBy: number | null;
            reviewedAt: Date | null;
            createdAt: Date;
            updatedAt: Date;
            userName: string | null;
            userEmail: string | null;
            userPhone: string | null;
            userAvatarUrl: string | null;
            documentCount: number;
        }>(
            `
            SELECT
                ha.application_id AS applicationId,
                ha.user_id AS userId,
                ha.contact_name AS contactName,
                ha.contact_email AS contactEmail,
                ha.contact_phone AS phone,
                ha.entity_type AS profileType,
                ha.business_address AS businessAddress,
                ha.status,
                ha.rejection_reason AS rejectReason,
                ha.reviewed_by_user_id AS reviewedBy,
                ha.reviewed_at AS reviewedAt,
                ha.created_at AS createdAt,
                ha.updated_at AS updatedAt,
                u.full_name AS userName,
                u.email AS userEmail,
                u.phone AS userPhone,
                u.avatar_url AS userAvatarUrl,
                COUNT(hid.id) AS documentCount
            FROM host_applications ha
            LEFT JOIN users u ON u.user_id = ha.user_id
            LEFT JOIN host_identity_documents hid ON hid.application_id = ha.application_id
            ${whereSql}
            GROUP BY ha.application_id, u.user_id
            ORDER BY ha.created_at DESC, ha.application_id DESC
            LIMIT :limit OFFSET :offset
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
        sequelize.query<{ totalItems: number }>(
            `
            SELECT COUNT(*) AS totalItems
            FROM host_applications ha
            ${whereSql}
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
    ]);

    return {
        items: items.map((item) => ({
            id: Number(item.applicationId),
            applicationId: Number(item.applicationId),
            userId: Number(item.userId),
            contactName: item.contactName,
            contactEmail: item.contactEmail,
            phone: item.phone,
            profileType: item.profileType,
            businessAddress: item.businessAddress,
            status: item.status,
            rejectReason: item.rejectReason,
            reviewedBy: item.reviewedBy,
            reviewedAt: item.reviewedAt,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            documentCount: Number(item.documentCount ?? 0),
            user: {
                id: Number(item.userId),
                name: item.userName,
                email: item.userEmail,
                phone: item.userPhone,
                avatarUrl: item.userAvatarUrl ?? null,
            },
        })),
        pagination: {
            page,
            limit,
            total: Number(counts[0]?.totalItems ?? 0),
            totalPages: Math.max(1, Math.ceil(Number(counts[0]?.totalItems ?? 0) / limit)),
        },
    };
};

/**
 * Giải thuật trả chi tiết hồ sơ KYC cho Admin không làm lộ khóa bí mật trên URL:
 * 1. Kiểm tra quyền Admin và nạp danh sách chứng từ định danh của hồ sơ.
 * 2. Không trả `signedUrl` trực tiếp từ R2 và không nối `streamToken` vào query string của `fileUrl`/`proxyUrl`
 *    (tránh rò rỉ qua access log, trình duyệt, proxy và header `Referer`).
 * 3. Trả `fileUrl` thuần và `streamToken` tách riêng trong thân JSON để client đính kèm vào header `X-Document-Stream-Token`.
 */
export const getAdminHostApplicationDetail = async (
    admin: AuthenticatedUser,
    applicationId: number,
    _adminToken?: string,
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const application = await getApplicationForAdminOrThrow(applicationId);
    const [documents, user] = await Promise.all([
        getDocumentsForApplication(applicationId),
        User.findById(application.userId),
    ]);
    const expiresIn = getPrivateSignedUrlExpiresSeconds();
    const signedUrlExpiresAt = new Date(Date.now() + expiresIn * 1000);

    const documentsWithStreamAuth = documents.map((document) => {
        const streamToken = createHostDocStreamToken({
            applicationId,
            documentId: Number(document.id),
            adminUserId: admin.id,
        });
        const fileUrl = `/api/admin/host-applications/${applicationId}/documents/${document.id}/file`;
        return {
            id: Number(document.id),
            documentType: document.documentType,
            side: document.side,
            originalFilename: document.originalFilename,
            mimeType: document.mimeType,
            fileSize: document.fileSize,
            status: document.status,
            signedUrl: null,
            fileUrl,
            proxyUrl: fileUrl,
            streamToken,
            signedUrlExpiresAt,
            createdAt: document.createdAt,
            updatedAt: document.updatedAt,
        };
    });

    return {
        id: Number(application.applicationId),
        applicationId: Number(application.applicationId),
        userId: application.userId,
        contactName: application.contactName,
        contactEmail: application.contactEmail,
        phone: application.contactPhone,
        profileType: application.entityType,
        businessAddress: application.businessAddress,
        note: application.notes,
        status: application.status,
        rejectReason: application.rejectionReason,
        reviewedBy: application.reviewedByUserId,
        reviewedAt: application.reviewedAt,
        createdAt: application.createdAt,
        updatedAt: application.updatedAt,
        user: user
            ? {
                  id: Number(user.userId),
                  name: user.fullName,
                  email: user.email,
                  phone: user.phone,
                  avatarUrl: user.avatarUrl ?? null,
              }
            : null,
        documents: documentsWithStreamAuth,
    };
};

/**
 * Giải thuật phê duyệt hồ sơ Chủ nhà có kiểm tra toàn vẹn chứng từ KYC:
 * 1. Xác thực vai trò Admin và khóa giao dịch DB để đọc hồ sơ ở trạng thái `pending`.
 * 2. Bắt buộc truy vấn `HostIdentityDocument` của hồ sơ và gọi `assertHostApplicationReadyForApproval`:
 *    từ chối phê duyệt (`422`) nếu thiếu ảnh CCCD/CMND đủ 2 mặt, thiếu Hộ chiếu/GPLX hoặc thiếu GPKD với doanh nghiệp.
 * 3. Chỉ khi bộ chứng từ hợp lệ mới cập nhật `approved`, gán role `host`, bật `is_host_verified = 1` và ghi nhật ký kiểm toán.
 */
export const approveHostApplication = async (
    admin: AuthenticatedUser,
    applicationId: number,
    context: AdminActionContext = {},
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    return sequelize.transaction(async (transaction) => {
        const application = await getApplicationForAdminOrThrow(applicationId, transaction);
        if (application.status !== "pending") {
            throw new ApiError(409, "Host application has already been reviewed");
        }

        const documents = await getDocumentsForApplication(applicationId, transaction);
        assertHostApplicationReadyForApproval(application.entityType, documents);

        application.status = "approved";
        application.rejectionReason = null;
        application.reviewedByUserId = Number(admin.id);
        application.reviewedAt = new Date();
        await application.save({ transaction });

        await HostIdentityDocument.update(
            { status: "approved" },
            {
                where: {
                    applicationId,
                },
                transaction,
            },
        );

        await markUserAsApprovedHost(application.userId, transaction, application.contactName);
        await notifyHostApplicationApproved(applicationId, application.userId, transaction);
        await writeAuditLog({
            actorId: Number(admin.id),
            action: "host_application.approve",
            targetType: "host_application",
            targetId: applicationId,
            metadata: {
                userId: application.userId,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return {
            id: Number(application.applicationId),
            applicationId: Number(application.applicationId),
            status: application.status,
        };
    });
};

/**
 * Giải thuật từ chối hồ sơ đăng ký Chủ nhà trong giao dịch cơ sở dữ liệu nguyên tử:
 * 1. Kiểm tra phân quyền RBAC (`admin`) và xác thực lý do từ chối bắt buộc (`1..2000` ký tự).
 * 2. Chốt chặn trạng thái `pending` (`409 Conflict` nếu hồ sơ đã được xét duyệt trước đó).
 * 3. Cập nhật đồng bộ trạng thái `rejected` cho hồ sơ, toàn bộ giấy tờ định danh đính kèm và cột `host_application_status` của người dùng,
 *    đồng thời phát thông báo tới người nộp và ghi nhận nhật ký kiểm toán (`writeAuditLog`).
 */
export const rejectHostApplication = async (
    admin: AuthenticatedUser,
    applicationId: number,
    input: RejectHostApplicationInput,
    context: AdminActionContext = {},
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const reason = input.reason?.trim();

    if (!reason) {
        throw new ApiError(422, "Validation error", [
            {
                path: "reason",
                msg: "reason is required",
            },
        ]);
    }

    if (reason.length > 2000) {
        throw new ApiError(422, "Validation error", [
            {
                path: "reason",
                msg: "reason must be at most 2000 characters",
            },
        ]);
    }

    return sequelize.transaction(async (transaction) => {
        const application = await getApplicationForAdminOrThrow(applicationId, transaction);
        if (application.status !== "pending") {
            throw new ApiError(409, "Host application has already been reviewed");
        }

        application.status = "rejected";
        application.rejectionReason = reason;
        application.reviewedByUserId = Number(admin.id);
        application.reviewedAt = new Date();
        await application.save({ transaction });

        await HostIdentityDocument.update(
            { status: "rejected" },
            {
                where: {
                    applicationId,
                },
                transaction,
            },
        );

        await updateUserHostApplicationStatus(application.userId, "rejected", transaction);
        await notifyHostApplicationRejected(applicationId, application.userId, reason, transaction);
        await writeAuditLog({
            actorId: Number(admin.id),
            action: "host_application.reject",
            targetType: "host_application",
            targetId: applicationId,
            metadata: {
                userId: application.userId,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return {
            id: Number(application.applicationId),
            applicationId: Number(application.applicationId),
            status: application.status,
        };
    });
};
