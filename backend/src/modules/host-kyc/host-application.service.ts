// CONFLICT-RESOLVED: Hợp nhất hai luồng nộp và đồng bộ đơn đăng ký chủ nhà (`host-applications` và `host-onboarding`)
// vào một dịch vụ duy nhất `host-application.service.ts` trong `modules/host-kyc/`, loại bỏ trùng lặp logic.
import { ApiError } from "../../common/api-error";
import { getExistingColumns } from "../../common/db-schema";
import sequelize from "../../config/database";
import { logger } from "../../config/logger";
import HostApplication, {
    type HostApplicationDocument,
    type HostEntityType,
} from "../../models/host-application";
import HostIdentityDocument, {
    type HostIdentityDocument as HostIdentityDocumentModel,
} from "../../models/host-identity-document";
import HostVerification from "../../models/host-verification";
import User from "../../models/user";
import {
    assertValidPrivateIdentityFile,
    deletePrivateIdentityDocumentsQuietly,
    ensurePrivateR2StorageConfigured,
    uploadPrivateIdentityDocument,
} from "../../services/private-r2-storage.service";
import { sanitizeLlmOutputText } from "../ai/ai-vision-guardrails";
import { analyzeIdentityDocument } from "../ai/identity-vision.service";
import type { AuthenticatedUser } from "../auth/auth.service";
import { notifyHostApplicationSubmitted } from "../notifications/notification.service";
import {
    type AdminActionContext,
    type AdminHostApplicationsQuery,
    approveHostApplication as approveHostApplicationImpl,
    getAdminHostApplicationDetail as getAdminHostApplicationDetailImpl,
    getDocumentsForApplication,
    listAdminHostApplications as listAdminHostApplicationsImpl,
    rejectHostApplication as rejectHostApplicationImpl,
    type RejectHostApplicationInput,
} from "./host-application-review.service";
import {
    assertSubmitInput,
    buildDocumentUploadPlan,
    normalizeDocumentType,
    normalizeProfileType,
    nullableTrim,
    serializeHostApplication,
    serializeHostDocument,
    type SubmitHostApplicationInput,
} from "./host-application.validator";
import {
    createHostDocStreamToken as createHostDocStreamTokenImpl,
    getAdminHostDocumentStream as getAdminHostDocumentStreamImpl,
    verifyHostDocStreamToken as verifyHostDocStreamTokenImpl,
} from "./host-document-stream.service";
import { validateHostKycDocumentCompleteness } from "./host-kyc-policy";
import {
    getLatestHostApplication,
    updateUserHostApplicationStatus,
} from "./host-status-sync.service";

export type {
    AdminActionContext,
    AdminHostApplicationsQuery,
    RejectHostApplicationInput,
    SubmitHostApplicationInput,
};

export type RegisterHostInput = {
    contactName?: string | null;
    contactEmail?: string | null;
    contactPhone?: string | null;
    phone?: string | null;
    businessAddress?: string;
    address?: string;
    entityType?: HostEntityType;
    notes?: string | null;
    note?: string | null;
};

/**
 * Giải thuật nộp hồ sơ KYC Chủ nhà có xác thực AI Vision hai mặt và tự động thu dọn R2 khi lỗi:
 * 1. Kiểm tra định dạng đầu vào, từ chối tệp PDF cho giấy tờ tùy thân cá nhân và đối chiếu AI Vision (nếu bật).
 * 2. Chặn trùng lặp đơn `pending` hoặc tài khoản đã là `host` (`409`).
 * 3. Tải chứng từ lên Private R2 và lưu giao dịch nguyên tử; nếu giao dịch lỗi thì xóa ngay mọi object trên R2.
 */
export const submitHostApplication = async (
    user: AuthenticatedUser,
    input: SubmitHostApplicationInput,
) => {
    const userId = Number(user.id);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

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

    const identityFrontItem = uploadPlan.find(
        (item) => item.side === "front" || item.documentType === "passport",
    );
    const identityBackItem = uploadPlan.find((item) => item.side === "back");

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
        let frontAiResult: Awaited<ReturnType<typeof analyzeIdentityDocument>> | null = null;
        let backAiResult: Awaited<ReturnType<typeof analyzeIdentityDocument>> | null = null;

        if (identityFrontItem) {
            try {
                frontAiResult = await analyzeIdentityDocument({
                    fileBuffer: identityFrontItem.file.buffer,
                    mimeType: identityFrontItem.file.mimetype,
                });

                if (!frontAiResult.isDocumentValid || frontAiResult.documentType === "unknown") {
                    const reason =
                        sanitizeLlmOutputText(frontAiResult.warnings?.[0] ?? "", 180) ||
                        "Tệp tải lên không phải là giấy tờ tùy thân hợp lệ.";
                    throw new ApiError(422, "Validation error", [
                        {
                            path: "identityFront",
                            msg: `Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ: ${reason}. Vui lòng tải lên ảnh chụp giấy tờ tùy thân gốc.`,
                        },
                    ]);
                }
            } catch (error) {
                if (error instanceof ApiError && error.statusCode === 422) {
                    throw error;
                }
                logger.warn("AI Vision check skipped for identityFront due to transient provider error", {
                    message: error instanceof Error ? error.message : String(error),
                });
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
                        sanitizeLlmOutputText(backAiResult.warnings?.[0] ?? "", 180) ||
                        "Tệp mặt sau không phải là CCCD hợp lệ.";
                    throw new ApiError(422, "Validation error", [
                        {
                            path: "identityBack",
                            msg: `Tệp mặt sau không phải là CCCD hợp lệ: ${reason}. Vui lòng tải lên ảnh chụp mặt sau CCCD gốc.`,
                        },
                    ]);
                }
            } catch (error) {
                if (error instanceof ApiError && error.statusCode === 422) {
                    throw error;
                }
                logger.warn("AI Vision check skipped for identityBack due to transient provider error", {
                    message: error instanceof Error ? error.message : String(error),
                });
            }
        }

        if (frontAiResult && backAiResult) {
            const frontId = sanitizeLlmOutputText(frontAiResult.idNumber ?? "", 32);
            const backId = sanitizeLlmOutputText(backAiResult.idNumber ?? "", 32);
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
        return await sequelize.transaction(async (transaction) => {
            const latestApplication = await getLatestHostApplication(userId, transaction);

            if (latestApplication?.status === "pending") {
                throw new ApiError(409, "Pending host application already exists");
            }

            if (
                user.roles.includes("host") ||
                (latestApplication?.status === "approved" && user.roles.includes("host"))
            ) {
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
            await notifyHostApplicationSubmitted(Number(application.applicationId), userId, transaction);

            return {
                id: Number(application.applicationId),
                applicationId: Number(application.applicationId),
                status: application.status,
                hostApplicationStatus: application.status,
                documents: savedDocuments.map(serializeHostDocument),
            };
        });
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
        serialized.rejectReason =
            serialized.rejectReason || "Quyền Host đã được quản trị viên điều chỉnh về Guest.";
        serialized.rejectionReason =
            serialized.rejectionReason || "Quyền Host đã được quản trị viên điều chỉnh về Guest.";

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
            where: { applicationId: Number(application.applicationId) },
            transaction,
        });
        await HostApplication.destroy({
            where: { applicationId: Number(application.applicationId) },
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

const serializeOnboardingSummary = (application: HostApplicationDocument, created: boolean) => ({
    applicationId: application.applicationId,
    status: application.status,
    hostApplicationStatus: application.status,
    contactName: application.contactName,
    contactEmail: application.contactEmail,
    contactPhone: application.contactPhone,
    businessAddress: application.businessAddress,
    entityType: application.entityType,
    notes: application.notes,
    created,
});

/**
 * Giải thuật kiểm tra bằng chứng KYC bắt buộc trước khi đồng bộ thông tin Chủ nhà qua `/api/host/register`:
 * 1. Hỗ trợ chuẩn hóa đầu vào người gọi (`AuthenticatedUser` hoặc định danh số/chuỗi) và kiểm tra nhanh chứng từ KYC trước khi mở giao dịch ghi DB.
 * 2. Chặn tạo mới đơn `pending` hoặc `approved` nếu chưa có bộ giấy tờ KYC hợp lệ trong `host_identity_documents`
 *    hoặc bản ghi `host_verifications` đã duyệt (`422 Validation error`).
 */
export const registerHostApplication = async (
    userOrId: AuthenticatedUser | string | number,
    input: RegisterHostInput,
) => {
    const actor: AuthenticatedUser =
        typeof userOrId === "object" && userOrId !== null
            ? userOrId
            : {
                  id: String(userOrId),
                  email: "",
                  phone: "",
                  name: "",
                  username: null,
                  roles: ["guest"],
                  status: "active",
              };
    const userId = Number(actor.id);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    const effectiveEntityType: HostEntityType = input.entityType ?? "individual";
    const resolvedAddress = (input.businessAddress ?? input.address ?? "").trim();
    const preLatestApplication = await getLatestHostApplication(userId);
    const preExistingDocuments = preLatestApplication
        ? await HostIdentityDocument.findAll({
              where: { applicationId: Number(preLatestApplication.applicationId) },
          })
        : [];
    const preKycCompleteness = validateHostKycDocumentCompleteness(
        effectiveEntityType,
        preExistingDocuments,
    );
    const preApprovedVerification = await HostVerification.findOne({
        where: { hostId: userId, status: "approved" },
    });
    const preHasApprovedVerificationDocs = Boolean(
        preApprovedVerification &&
            Array.isArray(preApprovedVerification.documentUrls) &&
            preApprovedVerification.documentUrls.length > 0,
    );

    if (!preKycCompleteness.valid && !preHasApprovedVerificationDocs) {
        logger.warn("Blocked KYC-less host registration attempt via /api/host/register", {
            userId,
            entityType: effectiveEntityType,
            hasLatestApplication: Boolean(preLatestApplication),
            documentCount: preExistingDocuments.length,
        });

        throw new ApiError(422, "Validation error", [
            {
                path: "documents",
                msg: "Vui lòng nộp hồ sơ kèm ảnh chụp giấy tờ tùy thân (CCCD/CMND/Hộ chiếu) qua cổng xác minh KYC (/api/host/applications) trước khi đăng ký Chủ nhà.",
            },
        ]);
    }

    return sequelize.transaction(async (transaction) => {
        const latestApplication = await getLatestHostApplication(userId, transaction);
        const contactEmail = nullableTrim(input.contactEmail) ?? existingUser.email;
        const contactPhone = (
            nullableTrim(input.contactPhone ?? input.phone) ?? existingUser.phone
        )?.trim();

        if (!contactEmail) {
            throw new ApiError(422, "contactEmail is required");
        }
        if (!contactPhone) {
            throw new ApiError(422, "contactPhone is required");
        }
        if (!resolvedAddress) {
            throw new ApiError(422, "businessAddress is required");
        }

        const applicationPayload = {
            contactName: nullableTrim(input.contactName),
            contactEmail,
            contactPhone,
            businessAddress: resolvedAddress,
            entityType: effectiveEntityType,
            notes: nullableTrim(input.notes ?? input.note),
        };

        const existingDocuments = latestApplication
            ? await HostIdentityDocument.findAll({
                  where: { applicationId: Number(latestApplication.applicationId) },
                  transaction,
              })
            : [];
        const kycCompleteness = validateHostKycDocumentCompleteness(
            effectiveEntityType,
            existingDocuments,
        );
        const approvedVerification = await HostVerification.findOne({
            where: { hostId: userId, status: "approved" },
            transaction,
        });
        const hasApprovedVerificationDocs = Boolean(
            approvedVerification &&
                Array.isArray(approvedVerification.documentUrls) &&
                approvedVerification.documentUrls.length > 0,
        );

        if (latestApplication?.status === "approved" && (kycCompleteness.valid || hasApprovedVerificationDocs)) {
            await updateUserHostApplicationStatus(userId, "approved", transaction);
            return serializeOnboardingSummary(latestApplication, false);
        }

        if (Array.isArray(actor.roles) && actor.roles.includes("host") && (kycCompleteness.valid || hasApprovedVerificationDocs)) {
            const application =
                latestApplication ??
                (await HostApplication.create(
                    {
                        userId,
                        ...applicationPayload,
                        status: "approved",
                        reviewedByUserId: null,
                        reviewedAt: null,
                        rejectionReason: null,
                    },
                    { transaction },
                ));

            if (application.status !== "approved") {
                application.set({ ...applicationPayload, status: "approved", rejectionReason: null });
                await application.save({ transaction });
            }

            await updateUserHostApplicationStatus(userId, "approved", transaction);
            if (applicationPayload.contactName && applicationPayload.contactName.trim().length > 0) {
                const userColumns = await getExistingColumns("users", ["full_name"], transaction);
                if (userColumns.has("full_name")) {
                    await sequelize.query("UPDATE users SET full_name = ? WHERE user_id = ?", {
                        replacements: [applicationPayload.contactName.trim(), userId],
                        transaction,
                    });
                }
            }
            return serializeOnboardingSummary(application, latestApplication === null);
        }

        if (latestApplication?.status === "pending" && kycCompleteness.valid) {
            latestApplication.set(applicationPayload);
            await latestApplication.save({ transaction });
            await updateUserHostApplicationStatus(userId, "pending", transaction);
            await notifyHostApplicationSubmitted(Number(latestApplication.applicationId), userId, transaction);
            return serializeOnboardingSummary(latestApplication, false);
        }

        logger.warn("Blocked KYC-less host registration attempt via /api/host/register", {
            userId,
            entityType: effectiveEntityType,
            hasLatestApplication: Boolean(latestApplication),
            documentCount: existingDocuments.length,
        });

        throw new ApiError(422, "Validation error", [
            {
                path: "documents",
                msg: "Vui lòng nộp hồ sơ kèm ảnh chụp giấy tờ tùy thân (CCCD/CMND/Hộ chiếu) qua cổng xác minh KYC (/api/host/applications) trước khi đăng ký Chủ nhà.",
            },
        ]);
    });
};

export const getCurrentHostApplication = async (user: AuthenticatedUser) => {
    const userId = Number(user.id);
    const [application, existingUser] = await Promise.all([
        getLatestHostApplication(userId),
        User.findById(userId),
    ]);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    const isCurrentHost = Array.isArray(user.roles) && user.roles.includes("host");
    let status = application?.status ?? existingUser.hostApplicationStatus ?? null;
    let rejectionReason = application?.rejectionReason ?? null;

    if (status === "approved" && !isCurrentHost) {
        status = "rejected";
        rejectionReason = rejectionReason || "Quyền Host đã được quản trị viên điều chỉnh về Guest.";
    }

    return {
        status,
        hostApplicationStatus: status,
        application: application
            ? {
                  applicationId: application.applicationId,
                  status,
                  hostApplicationStatus: status,
                  contactName: application.contactName,
                  contactEmail: application.contactEmail,
                  contactPhone: application.contactPhone,
                  businessAddress: application.businessAddress,
                  entityType: application.entityType,
                  notes: application.notes,
                  rejectionReason,
                  reviewedAt: application.reviewedAt,
                  createdAt: application.createdAt,
                  updatedAt: application.updatedAt,
              }
            : null,
    };
};

export const listAdminHostApplications = (
    admin: AuthenticatedUser,
    query: AdminHostApplicationsQuery,
) => listAdminHostApplicationsImpl(admin, query);

export const getAdminHostApplicationDetail = (
    admin: AuthenticatedUser,
    applicationId: number,
    adminToken?: string,
) => getAdminHostApplicationDetailImpl(admin, applicationId, adminToken);

export const approveHostApplication = (
    admin: AuthenticatedUser,
    applicationId: number,
    context?: AdminActionContext,
) => approveHostApplicationImpl(admin, applicationId, context);

export const rejectHostApplication = (
    admin: AuthenticatedUser,
    applicationId: number,
    input: RejectHostApplicationInput,
    context?: AdminActionContext,
) => rejectHostApplicationImpl(admin, applicationId, input, context);

export const createHostDocStreamToken = (params: Parameters<typeof createHostDocStreamTokenImpl>[0]) =>
    createHostDocStreamTokenImpl(params);

export const verifyHostDocStreamToken = (
    token: string,
    expected: Parameters<typeof verifyHostDocStreamTokenImpl>[1],
) => verifyHostDocStreamTokenImpl(token, expected);

export const getAdminHostDocumentStream = (
    admin: AuthenticatedUser,
    applicationId: number,
    documentId: number,
) => getAdminHostDocumentStreamImpl(admin, applicationId, documentId);
