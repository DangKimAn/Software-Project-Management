import { createHmac, timingSafeEqual } from "node:crypto";
import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { getEnv } from "../../config/env";
import HostApplication, {
    HostApplicationDocument,
    HostApplicationStatus,
    HostEntityType,
    hostApplicationStatusValues,
    hostEntityTypeValues,
} from "../../models/host-application";
import HostIdentityDocument, {
    HostIdentityDocument as HostIdentityDocumentModel,
    IdentityDocumentSide,
    IdentityDocumentType,
} from "../../models/host-identity-document";
import User from "../../models/user";
import {
    assertValidPrivateIdentityFile,
    createPrivateSignedGetUrl,
    deletePrivateIdentityDocumentsQuietly,
    ensurePrivateR2StorageConfigured,
    getPrivateIdentityDocumentStream,
    getPrivateSignedUrlExpiresSeconds,
    uploadPrivateIdentityDocument,
} from "../../services/privateR2Storage.service";
import { getColumnType, getExistingColumns } from "../../services/schema-introspection-service";
import { writeAuditLog } from "../../services/audit-log-service";
import { analyzeIdentityDocument } from "../ai/identity-vision.service";
import type { AuthenticatedUser } from "../auth/auth.service";
import { ensureUserRole } from "../auth/auth.service";
import {
    notifyHostApplicationApproved,
    notifyHostApplicationRejected,
    notifyHostApplicationSubmitted,
} from "../notifications/notification.service";

const identityApplicationDocumentTypeValues = ["cccd", "cmnd", "passport", "driver_license"] as const;
type ApplicationIdentityDocumentType = (typeof identityApplicationDocumentTypeValues)[number];

type IdentityDocumentFiles = {
    identityFront?: Express.Multer.File;
    identityBack?: Express.Multer.File;
    identitySingle?: Express.Multer.File;
    businessLicense?: Express.Multer.File;
};

export type SubmitHostApplicationInput = {
    contactName?: string | null;
    contactEmail?: string | null;
    phone?: string | null;
    contactPhone?: string | null;
    profileType?: HostEntityType | string | null;
    entityType?: HostEntityType | string | null;
    businessAddress?: string | null;
    note?: string | null;
    notes?: string | null;
    documentType?: ApplicationIdentityDocumentType | string | null;
    files: IdentityDocumentFiles;
};

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

type DocumentUploadPlan = {
    file: Express.Multer.File;
    documentType: IdentityDocumentType;
    side: IdentityDocumentSide;
};

const nullableTrim = (value?: string | null) => {
    const trimmed = value?.trim();
    return trimmed ? trimmed : null;
};

const assertStringMax = (path: string, value: string | null | undefined, max: number) => {
    if (value !== undefined && value !== null && value.trim().length > max) {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} must be at most ${max} characters`,
            },
        ]);
    }
};

const assertRequiredString = (path: string, value: string | null | undefined, max: number) => {
    if (!value?.trim()) {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} is required`,
            },
        ]);
    }

    assertStringMax(path, value, max);
};

const assertEmail = (value?: string | null) => {
    const email = nullableTrim(value);

    if (!email) {
        throw new ApiError(422, "Validation error", [
            {
                path: "contactEmail",
                msg: "contactEmail is required",
            },
        ]);
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "contactEmail",
                msg: "contactEmail is invalid",
            },
        ]);
    }
};

const assertPhone = (value?: string | null) => {
    if (!value?.trim()) {
        throw new ApiError(422, "Validation error", [
            {
                path: "phone",
                msg: "phone is required",
            },
        ]);
    }

    if (!/^(0|\+84)[0-9]{9}$/.test(value.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "phone",
                msg: "phone must be a valid Vietnamese phone number",
            },
        ]);
    }
};

const normalizeProfileType = (input: SubmitHostApplicationInput): HostEntityType => {
    const value = String(input.profileType ?? input.entityType ?? "").trim();

    if ((hostEntityTypeValues as readonly string[]).includes(value)) {
        return value as HostEntityType;
    }

    throw new ApiError(422, "Validation error", [
        {
            path: "profileType",
            msg: "profileType must be individual or business",
        },
    ]);
};

const normalizeDocumentType = (input: SubmitHostApplicationInput): ApplicationIdentityDocumentType => {
    const value = String(input.documentType ?? "").trim();

    if ((identityApplicationDocumentTypeValues as readonly string[]).includes(value)) {
        return value as ApplicationIdentityDocumentType;
    }

    throw new ApiError(422, "Validation error", [
        {
            path: "documentType",
            msg: "documentType must be cccd, cmnd, passport, or driver_license",
        },
    ]);
};

const assertNoUnexpectedFile = (path: keyof IdentityDocumentFiles, file?: Express.Multer.File) => {
    if (!file) {
        return;
    }

    throw new ApiError(422, "Validation error", [
        {
            path,
            msg: `${path} is not allowed for the selected document type`,
        },
    ]);
};

const requireFile = (path: keyof IdentityDocumentFiles, file?: Express.Multer.File) => {
    if (!file) {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} is required`,
            },
        ]);
    }

    return file;
};

const buildDocumentUploadPlan = (
    profileType: HostEntityType,
    documentType: ApplicationIdentityDocumentType,
    files: IdentityDocumentFiles,
): DocumentUploadPlan[] => {
    const plan: DocumentUploadPlan[] = [];

    if (documentType === "cccd" || documentType === "cmnd") {
        plan.push({
            file: requireFile("identityFront", files.identityFront),
            documentType,
            side: "front",
        });
        plan.push({
            file: requireFile("identityBack", files.identityBack),
            documentType,
            side: "back",
        });
        assertNoUnexpectedFile("identitySingle", files.identitySingle);
    }

    if (documentType === "passport") {
        plan.push({
            file: requireFile("identitySingle", files.identitySingle),
            documentType,
            side: "single",
        });
        assertNoUnexpectedFile("identityFront", files.identityFront);
        assertNoUnexpectedFile("identityBack", files.identityBack);
    }

    if (documentType === "driver_license") {
        plan.push({
            file: requireFile("identityFront", files.identityFront),
            documentType,
            side: "front",
        });

        if (files.identityBack) {
            plan.push({
                file: files.identityBack,
                documentType,
                side: "back",
            });
        }

        assertNoUnexpectedFile("identitySingle", files.identitySingle);
    }

    if (profileType === "business") {
        plan.push({
            file: requireFile("businessLicense", files.businessLicense),
            documentType: "business_license",
            side: "business_license",
        });
    } else {
        assertNoUnexpectedFile("businessLicense", files.businessLicense);
    }

    return plan;
};

const assertSubmitInput = (input: SubmitHostApplicationInput) => {
    assertStringMax("contactName", input.contactName, 120);
    assertEmail(input.contactEmail);
    assertPhone(input.phone ?? input.contactPhone);
    assertRequiredString("businessAddress", input.businessAddress, 500);
    assertStringMax("note", input.note ?? input.notes, 2000);
};

const serializeHostDocument = (document: HostIdentityDocumentModel) => ({
    id: Number(document.id),
    documentType: document.documentType,
    side: document.side,
    status: document.status,
    originalFilename: document.originalFilename,
    createdAt: document.createdAt,
});

const serializeHostApplication = (
    application: HostApplicationDocument,
    documents: HostIdentityDocumentModel[] = [],
) => ({
    id: Number(application.applicationId),
    applicationId: Number(application.applicationId),
    status: application.status,
    hostApplicationStatus: application.status,
    contactName: application.contactName,
    contactEmail: application.contactEmail,
    phone: application.contactPhone,
    contactPhone: application.contactPhone,
    profileType: application.entityType,
    entityType: application.entityType,
    businessAddress: application.businessAddress,
    note: application.notes,
    notes: application.notes,
    rejectReason: application.rejectionReason,
    rejectionReason: application.rejectionReason,
    reviewedAt: application.reviewedAt,
    createdAt: application.createdAt,
    updatedAt: application.updatedAt,
    documents: documents.map(serializeHostDocument),
});

const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(100, Math.max(1, limit ?? 20)),
});

const getLatestHostApplication = async (userId: number, transaction?: Transaction) =>
    HostApplication.findOne({
        where: {
            userId,
        },
        order: [
            ["createdAt", "DESC"],
            ["applicationId", "DESC"],
        ],
        transaction,
    });

const updateUserHostApplicationStatus = async (
    userId: number,
    status: HostApplicationStatus | null,
    transaction?: Transaction,
) => {
    const columns = await getExistingColumns("users", ["host_application_status"], transaction);

    if (!columns.has("host_application_status")) {
        return;
    }

    await sequelize.query("UPDATE users SET host_application_status = ? WHERE user_id = ?", {
        replacements: [status, userId],
        transaction,
    });
};

const markUserAsApprovedHost = async (
    userId: number,
    transaction?: Transaction,
    contactName?: string | null,
) => {
    await ensureUserRole(userId, "host", transaction);

    const columns = await getExistingColumns(
        "users",
        ["is_host_verified", "host_application_status", "role", "full_name"],
        transaction,
    );
    const assignments: string[] = [];
    const replacements: unknown[] = [];

    if (columns.has("is_host_verified")) {
        assignments.push("is_host_verified = 1");
    }

    if (columns.has("host_application_status")) {
        assignments.push("host_application_status = ?");
        replacements.push("approved");
    }

    if (columns.has("role")) {
        const roleColumnType = await getColumnType("users", "role", transaction);

        if (!roleColumnType || roleColumnType.includes("'host'")) {
            assignments.push("role = CASE WHEN role = 'admin' THEN role ELSE 'host' END");
        }
    }

    if (columns.has("full_name") && contactName && contactName.trim().length > 0) {
        assignments.push("full_name = ?");
        replacements.push(contactName.trim());
    }

    if (assignments.length > 0) {
        await sequelize.query(
            `
            UPDATE users
            SET ${assignments.join(", ")}
            WHERE user_id = ?
            `,
            {
                replacements: [...replacements, userId],
                transaction,
            },
        );
    }
};

const getDocumentsForApplication = (applicationId: number, transaction?: Transaction) =>
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

export const submitHostApplication = async (
    user: AuthenticatedUser,
    input: SubmitHostApplicationInput,
) => {
    const userId = Number(user.id);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    // Auto-populate contact email and phone from account profile if not provided
    if (!nullableTrim(input.contactEmail) && existingUser.email) {
        input.contactEmail = existingUser.email;
    }
    const enteredPhone = input.phone ?? input.contactPhone;
    if (!nullableTrim(enteredPhone) && existingUser.phone) {
        input.phone = existingUser.phone;
        input.contactPhone = existingUser.phone;
    }

    assertSubmitInput(input);
    const profileType = normalizeProfileType(input);
    const documentType = normalizeDocumentType(input);
    const uploadPlan = buildDocumentUploadPlan(profileType, documentType, input.files);

    for (const item of uploadPlan) {
        assertValidPrivateIdentityFile(item.file);
    }

    const preCheckLatestApplication = await getLatestHostApplication(userId);
    if (preCheckLatestApplication?.status === "pending") {
        throw new ApiError(409, "Pending host application already exists");
    }
    if (
        user.roles.includes("host") ||
        (preCheckLatestApplication?.status === "approved" && user.roles.includes("host"))
    ) {
        throw new ApiError(409, "Host application is already approved");
    }

    // Tier 2: Server-side AI Content Verification for Identity Documents
    const identityFrontItem = uploadPlan.find(
        (item) => item.side === "front" || item.documentType === "passport",
    );
    const identityBackItem = uploadPlan.find(
        (item) => item.side === "back",
    );

    if (identityFrontItem && !identityFrontItem.file.mimetype.startsWith("image/")) {
        throw new ApiError(422, "Validation error", [
            {
                path: "identityFront",
                msg: "Giấy tờ tùy thân (CCCD/CMND/Hộ chiếu) bắt buộc phải là ảnh chụp (JPG, PNG, WebP), không chấp nhận tệp tài liệu PDF.",
            },
        ]);
    }

    if (identityBackItem && !identityBackItem.file.mimetype.startsWith("image/")) {
        throw new ApiError(422, "Validation error", [
            {
                path: "identityBack",
                msg: "Mặt sau CCCD bắt buộc phải là ảnh chụp (JPG, PNG, WebP), không chấp nhận tệp tài liệu PDF.",
            },
        ]);
    }

    if (process.env.OPENAI_API_KEY && process.env.NODE_ENV !== "test") {
        let frontAiResult: any = null;
        let backAiResult: any = null;

        if (identityFrontItem) {
            try {
                frontAiResult = await analyzeIdentityDocument({
                    fileBuffer: identityFrontItem.file.buffer,
                    mimeType: identityFrontItem.file.mimetype,
                });

                if (!frontAiResult.isDocumentValid || frontAiResult.documentType === "unknown") {
                    const reason =
                        frontAiResult.warnings?.[0] || "Tệp tải lên không phải là giấy tờ tùy thân hợp lệ.";
                    throw new ApiError(422, "Validation error", [
                        {
                            path: "identityFront",
                            msg: `Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ: ${reason}. Vui lòng tải lên ảnh chụp giấy tờ tùy thân gốc.`,
                        },
                    ]);
                }
            } catch (error: any) {
                if (error instanceof ApiError && error.statusCode === 422) {
                    throw error;
                }
            }
        }

        if (identityBackItem) {
            try {
                backAiResult = await analyzeIdentityDocument({
                    fileBuffer: identityBackItem.file.buffer,
                    mimeType: identityBackItem.file.mimetype,
                });

                if (!backAiResult.isDocumentValid || backAiResult.documentType === "unknown") {
                    const reason =
                        backAiResult.warnings?.[0] || "Tệp mặt sau không phải là CCCD hợp lệ.";
                    throw new ApiError(422, "Validation error", [
                        {
                            path: "identityBack",
                            msg: `Tệp mặt sau không phải là CCCD hợp lệ: ${reason}. Vui lòng tải lên ảnh chụp mặt sau CCCD gốc.`,
                        },
                    ]);
                }
            } catch (error: any) {
                if (error instanceof ApiError && error.statusCode === 422) {
                    throw error;
                }
            }
        }

        if (frontAiResult && backAiResult) {
            const frontId = (frontAiResult.idNumber || "").trim();
            const backId = (backAiResult.idNumber || "").trim();
            if (frontId && backId && frontId !== backId) {
                throw new ApiError(422, "Validation error", [
                    {
                        path: "identityBack",
                        msg: `Số CCCD ở mặt sau (${backId}) không trùng khớp với số CCCD ở mặt trước (${frontId}). Vui lòng tải lên 2 mặt của cùng một thẻ CCCD.`,
                    },
                ]);
            }
        }
    }

    ensurePrivateR2StorageConfigured();

    const uploadedObjectKeys: string[] = [];

    try {
        const result = await sequelize.transaction(async (transaction) => {
            const latestApplication = await getLatestHostApplication(userId, transaction);

            if (latestApplication?.status === "pending") {
                throw new ApiError(409, "Pending host application already exists");
            }

            if (user.roles.includes("host") || (latestApplication?.status === "approved" && user.roles.includes("host"))) {
                throw new ApiError(409, "Host application is already approved");
            }

            const application = await HostApplication.create(
                {
                    userId,
                    contactName: nullableTrim(input.contactName),
                    contactEmail: nullableTrim(input.contactEmail) ?? existingUser.email,
                    contactPhone: (input.phone ?? input.contactPhone)!.trim(),
                    businessAddress: input.businessAddress!.trim(),
                    entityType: profileType,
                    notes: nullableTrim(input.note ?? input.notes),
                    status: "pending",
                    reviewedByUserId: null,
                    reviewedAt: null,
                    rejectionReason: null,
                },
                { transaction },
            );

            const savedDocuments: HostIdentityDocumentModel[] = [];

            for (const item of uploadPlan) {
                const uploaded = await uploadPrivateIdentityDocument(item.file, {
                    userId,
                    applicationId: Number(application.applicationId),
                });
                uploadedObjectKeys.push(uploaded.objectKey);

                const document = await HostIdentityDocument.create(
                    {
                        applicationId: Number(application.applicationId),
                        userId,
                        documentType: item.documentType,
                        side: item.side,
                        originalFilename: uploaded.originalFilename,
                        objectKey: uploaded.objectKey,
                        mimeType: uploaded.mimeType,
                        fileSize: uploaded.fileSize,
                        status: "pending",
                    },
                    { transaction },
                );
                savedDocuments.push(document);
            }

            await updateUserHostApplicationStatus(userId, "pending", transaction);

            // Notify admin users about the new host application
            await notifyHostApplicationSubmitted(
                Number(application.applicationId),
                userId,
                transaction,
            );

            return {
                id: Number(application.applicationId),
                applicationId: Number(application.applicationId),
                status: application.status,
                hostApplicationStatus: application.status,
                documents: savedDocuments.map(serializeHostDocument),
            };
        });

        return result;
    } catch (error) {
        await deletePrivateIdentityDocumentsQuietly(uploadedObjectKeys);
        throw error;
    }
};

export const getMyHostApplication = async (user: AuthenticatedUser) => {
    const userId = Number(user.id);
    const [existingUser, application] = await Promise.all([
        User.findById(userId),
        getLatestHostApplication(userId),
    ]);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    const isCurrentHost = user.roles.includes("host");

    if (!application) {
        const effectiveUserStatus =
            existingUser.hostApplicationStatus === "approved" && !isCurrentHost
                ? "rejected"
                : (existingUser.hostApplicationStatus ?? null);
        return {
            status: effectiveUserStatus,
            hostApplicationStatus: effectiveUserStatus,
            application: null,
        };
    }

    const documents = await getDocumentsForApplication(Number(application.applicationId));
    const serialized = serializeHostApplication(application, documents);

    if (application.status === "approved" && !isCurrentHost) {
        serialized.status = "rejected";
        serialized.hostApplicationStatus = "rejected";
        serialized.rejectReason = serialized.rejectReason || "Quyền Host đã được quản trị viên điều chỉnh về Guest.";
        serialized.rejectionReason = serialized.rejectionReason || "Quyền Host đã được quản trị viên điều chỉnh về Guest.";

        return {
            status: "rejected",
            hostApplicationStatus: "rejected",
            application: serialized,
        };
    }

    return {
        status: application.status,
        hostApplicationStatus: application.status,
        application: serialized,
    };
};

export const cancelHostApplication = async (user: AuthenticatedUser) => {
    const userId = Number(user.id);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    const application = await getLatestHostApplication(userId);

    if (!application) {
        throw new ApiError(404, "Không tìm thấy hồ sơ đăng ký Host để hủy");
    }

    if (application.status === "approved" || user.roles.includes("host")) {
        throw new ApiError(400, "Không thể hủy hồ sơ đã được phê duyệt");
    }

    if (application.status === "rejected") {
        throw new ApiError(400, "Không thể hủy hồ sơ đã bị từ chối");
    }

    const documents = await getDocumentsForApplication(Number(application.applicationId));
    const objectKeys = documents.map((doc) => doc.objectKey).filter(Boolean);

    await sequelize.transaction(async (transaction) => {
        await HostIdentityDocument.destroy({
            where: {
                applicationId: Number(application.applicationId),
            },
            transaction,
        });

        await HostApplication.destroy({
            where: {
                applicationId: Number(application.applicationId),
            },
            transaction,
        });

        await updateUserHostApplicationStatus(userId, null, transaction);
    });

    if (objectKeys.length > 0) {
        await deletePrivateIdentityDocumentsQuietly(objectKeys);
    }

    return {
        message: "Đã hủy đơn đăng ký Host thành công.",
        status: null,
    };
};

export const listAdminHostApplications = async (
    admin: AuthenticatedUser,
    query: AdminHostApplicationsQuery,
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const status =
        query.status && query.status !== "all" && (hostApplicationStatusValues as readonly string[]).includes(query.status)
            ? query.status
            : undefined;
    const { page, limit } = toPagination(query.page, query.limit);
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

const HOST_DOC_STREAM_TOKEN_TTL_SECONDS = 300;

export const createHostDocStreamToken = (params: {
    applicationId: number;
    documentId: number;
    adminUserId: string | number;
    ttlSeconds?: number;
}) => {
    const ttl = params.ttlSeconds ?? HOST_DOC_STREAM_TOKEN_TTL_SECONDS;
    const exp = Math.floor(Date.now() / 1000) + ttl;
    const payload = Buffer.from(
        JSON.stringify({
            typ: "host_doc_stream",
            appId: Number(params.applicationId),
            docId: Number(params.documentId),
            uid: String(params.adminUserId),
            exp,
        }),
        "utf8",
    ).toString("base64url");
    const signature = createHmac("sha256", getEnv().tokenHashSecret)
        .update(payload)
        .digest("base64url");

    return `${payload}.${signature}`;
};

export const verifyHostDocStreamToken = (
    token: string,
    expected: { applicationId: number; documentId: number },
) => {
    const trimmed = token.trim();
    const dotIndex = trimmed.indexOf(".");

    if (dotIndex <= 0 || dotIndex !== trimmed.lastIndexOf(".")) {
        throw new ApiError(401, "Invalid or expired document stream token");
    }

    const payloadPart = trimmed.slice(0, dotIndex);
    const sigPart = trimmed.slice(dotIndex + 1);
    const expectedSig = createHmac("sha256", getEnv().tokenHashSecret)
        .update(payloadPart)
        .digest("base64url");

    const actualBuf = Buffer.from(sigPart, "utf8");
    const expectedBuf = Buffer.from(expectedSig, "utf8");

    if (actualBuf.length !== expectedBuf.length || !timingSafeEqual(actualBuf, expectedBuf)) {
        throw new ApiError(401, "Invalid or expired document stream token");
    }

    let decoded: {
        typ?: unknown;
        appId?: unknown;
        docId?: unknown;
        uid?: unknown;
        exp?: unknown;
    };

    try {
        decoded = JSON.parse(Buffer.from(payloadPart, "base64url").toString("utf8"));
    } catch {
        throw new ApiError(401, "Invalid or expired document stream token");
    }

    const nowSec = Math.floor(Date.now() / 1000);
    if (
        decoded.typ !== "host_doc_stream" ||
        Number(decoded.appId) !== Number(expected.applicationId) ||
        Number(decoded.docId) !== Number(expected.documentId) ||
        typeof decoded.uid !== "string" ||
        !decoded.uid.trim() ||
        typeof decoded.exp !== "number" ||
        decoded.exp <= nowSec
    ) {
        throw new ApiError(401, "Invalid or expired document stream token");
    }

    return {
        adminUserId: decoded.uid,
        expiresAt: decoded.exp,
    };
};

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

    const documentsWithSignedUrls = await Promise.all(
        documents.map(async (document) => {
            const streamToken = createHostDocStreamToken({
                applicationId,
                documentId: Number(document.id),
                adminUserId: admin.id,
            });
            const fileUrl = `/api/admin/host-applications/${applicationId}/documents/${document.id}/file?streamToken=${encodeURIComponent(streamToken)}`;
            return {
                id: Number(document.id),
                documentType: document.documentType,
                side: document.side,
                originalFilename: document.originalFilename,
                mimeType: document.mimeType,
                fileSize: document.fileSize,
                status: document.status,
                signedUrl: await createPrivateSignedGetUrl(document.objectKey),
                fileUrl,
                proxyUrl: fileUrl,
                signedUrlExpiresAt,
                createdAt: document.createdAt,
                updatedAt: document.updatedAt,
            };
        }),
    );

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
              }
            : null,
        documents: documentsWithSignedUrls,
    };
};

export const getAdminHostDocumentStream = async (
    admin: AuthenticatedUser,
    applicationId: number,
    documentId: number,
) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const document = await HostIdentityDocument.findOne({
        where: {
            id: documentId,
            applicationId,
        },
    });

    if (!document) {
        throw new ApiError(404, "Identity document not found");
    }

    const s3Response = await getPrivateIdentityDocumentStream(document.objectKey);
    if (!s3Response.Body) {
        throw new ApiError(404, "Identity document file body not found");
    }

    return {
        document,
        stream: s3Response.Body,
    };
};

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
