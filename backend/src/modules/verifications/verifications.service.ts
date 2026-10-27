import type { Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import type { AuthenticatedUser } from "../auth/auth.service";
import { ensureUserRole } from "../auth/auth.service";
import HostVerification, {
    HostVerificationDocument,
    HostVerificationStatus,
    HostVerificationType,
} from "../../models/host-verification";
import { writeAuditLog } from "../../services/audit-log-service";
import {
    getLatestHostApplication,
    markLatestHostApplicationApproved,
} from "../host-onboarding/host-onboarding.service";
import { getColumnType, getExistingColumns } from "../../services/schema-introspection-service";

export type CreateVerificationInput = {
    verificationType: HostVerificationType;
    fullName: string;
    idNumber?: string | null;
    documentUrls: string[];
    notes?: string | null;
};

export type MyVerificationQuery = {
    latestOnly?: boolean;
    status?: HostVerificationStatus;
    verificationType?: HostVerificationType;
    page?: number;
    limit?: number;
};

export type AdminVerificationQuery = {
    status?: HostVerificationStatus;
    verificationType?: HostVerificationType;
    page?: number;
    limit?: number;
};

export type ApproveVerificationInput = {
    notes?: string | null;
};

export type RejectVerificationInput = {
    reason: string;
};

export type AdminActionContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

const toPagination = (page?: number, limit?: number) => ({
    page: page ?? 1,
    limit: limit ?? 10,
});

const allowedDocumentExtensions = new Set([".jpg", ".jpeg", ".png", ".webp", ".pdf"]);

const assertTextLength = (path: string, value: string | null | undefined, max: number) => {
    if (value !== undefined && value !== null && value.trim().length > max) {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} must be at most ${max} characters`,
            },
        ]);
    }
};

const isSafeDocumentUrl = (value: string) => {
    if (value.length > 1024) {
        return false;
    }

    try {
        const url = new URL(value);

        if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) {
            return false;
        }

        const decodedPath = decodeURIComponent(url.pathname);

        if (decodedPath.split("/").some((segment) => segment === "..")) {
            return false;
        }

        const lastSegment = decodedPath.split("/").pop() ?? "";
        const extension = lastSegment.includes(".")
            ? `.${lastSegment.split(".").pop()?.toLowerCase()}`
            : "";

        return Boolean(extension) && allowedDocumentExtensions.has(extension);
    } catch {
        return false;
    }
};

const assertVerificationDocumentUrls = (urls: string[]) => {
    if (!Array.isArray(urls) || urls.length < 1 || urls.length > 10) {
        throw new ApiError(422, "Validation error", [
            {
                path: "documentUrls",
                msg: "documentUrls must contain between 1 and 10 URLs",
            },
        ]);
    }

    const invalidUrl = urls.find((url) => typeof url !== "string" || !isSafeDocumentUrl(url.trim()));

    if (invalidUrl) {
        throw new ApiError(422, "Validation error", [
            {
                path: "documentUrls",
                msg: "documentUrls must be http(s) URLs with a supported document type",
            },
        ]);
    }
};

const assertCreateVerificationInput = (input: CreateVerificationInput) => {
    if (!input.fullName?.trim()) {
        throw new ApiError(422, "Validation error", [
            {
                path: "fullName",
                msg: "fullName is required",
            },
        ]);
    }

    assertTextLength("fullName", input.fullName, 255);
    assertTextLength("idNumber", input.idNumber, 100);
    assertTextLength("notes", input.notes, 2000);
    assertVerificationDocumentUrls(input.documentUrls);
};

const assertReviewNotes = (notes?: string | null) => {
    assertTextLength("notes", notes, 2000);
};

const assertRejectionReason = (reason?: string | null) => {
    if (!reason?.trim()) {
        throw new ApiError(422, "Validation error", [
            {
                path: "reason",
                msg: "reason is required",
            },
        ]);
    }

    assertTextLength("reason", reason, 2000);
};

const assertCanSubmitHostVerification = async (user: AuthenticatedUser) => {
    if (user.roles.includes("host") || user.roles.includes("admin")) {
        return;
    }

    const application = await getLatestHostApplication(Number(user.id));

    if (!application) {
        throw new ApiError(403, "Host application is required before submitting verification");
    }

    if (application.status === "rejected") {
        throw new ApiError(403, "Host application must be pending or approved before submitting verification");
    }
};

const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

export const maskIdNumber = (value?: string | null) => {
    if (!value) {
        return null;
    }

    const normalized = value.trim();

    if (normalized.length <= 4) {
        return "*".repeat(normalized.length);
    }

    return `${"*".repeat(Math.max(4, normalized.length - 4))}${normalized.slice(-4)}`;
};

const sanitizeIdNumberForStorage = (value?: string | null) => {
    const normalized = value?.trim();
    return normalized ? maskIdNumber(normalized) : null;
};

const normalizeDocumentUrls = (urls: string[]) =>
    Array.from(new Set(urls.map((url) => url.trim()))).filter(Boolean);

const serializeVerification = (verification: HostVerificationDocument) => ({
    verificationId: verification.verificationId,
    hostId: verification.hostId,
    verificationType: verification.verificationType,
    fullName: verification.fullName,
    idNumber: maskIdNumber(verification.idNumber),
    idNumberMasked: maskIdNumber(verification.idNumber),
    documentUrls: verification.documentUrls,
    notes: verification.notes ?? null,
    status: verification.status,
    reviewedByUserId: verification.reviewedByUserId ?? null,
    reviewedAt: verification.reviewedAt ?? null,
    reviewNotes: verification.reviewNotes ?? null,
    rejectionReason: verification.rejectionReason ?? null,
    createdAt: verification.createdAt,
    updatedAt: verification.updatedAt,
});

export const submitHostVerification = async (
    user: AuthenticatedUser,
    input: CreateVerificationInput,
) => {
    const hostId = Number(user.id);

    assertCreateVerificationInput(input);
    await assertCanSubmitHostVerification(user);

    const existingPending = await HostVerification.findOne({
        hostId,
        verificationType: input.verificationType,
        status: "pending",
    });

    if (existingPending) {
        throw new ApiError(409, "Pending verification already exists");
    }

    const verification = await HostVerification.create({
        hostId,
        verificationType: input.verificationType,
        fullName: input.fullName.trim(),
        idNumber: sanitizeIdNumberForStorage(input.idNumber),
        documentUrls: normalizeDocumentUrls(input.documentUrls),
        notes: input.notes?.trim() ? input.notes.trim() : null,
        status: "pending",
        reviewedByUserId: null,
        reviewedAt: null,
        reviewNotes: null,
        rejectionReason: null,
    });

    return {
        verificationId: verification.verificationId,
        status: verification.status,
    };
};

export const getMyHostVerifications = async (user: AuthenticatedUser, query: MyVerificationQuery) => {
    const filter: {
        hostId: number;
        status?: HostVerificationStatus;
        verificationType?: HostVerificationType;
    } = {
        hostId: Number(user.id),
    };

    if (query.status) {
        filter.status = query.status;
    }

    if (query.verificationType) {
        filter.verificationType = query.verificationType;
    }

    const { page, limit } = toPagination(query.page, query.limit);
    const sortedQuery = HostVerification.find(filter).sort({
        createdAt: -1,
        verificationId: -1,
    });

    const items = query.latestOnly
        ? await sortedQuery
        : await sortedQuery.skip((page - 1) * limit).limit(limit);

    if (!query.latestOnly) {
        const totalItems = await HostVerification.countDocuments(filter);

        return {
            items: items.map(serializeVerification),
            latestOnly: false,
            pagination: {
                page,
                limit,
                total: totalItems,
                totalPages: Math.max(1, Math.ceil(totalItems / limit)),
            },
        };
    }

    const latestByType = new Map<HostVerificationType, HostVerificationDocument>();

    for (const item of items) {
        if (!latestByType.has(item.verificationType)) {
            latestByType.set(item.verificationType, item);
        }
    }

    return {
        items: Array.from(latestByType.values()).map(serializeVerification),
        latestOnly: true,
        latestPolicy: "latest per verificationType",
    };
};

export const getAdminVerifications = async (admin: AuthenticatedUser, query: AdminVerificationQuery) => {
    assertAdmin(admin);

    const { page, limit } = toPagination(query.page, query.limit);
    const filter: {
        status?: HostVerificationStatus;
        verificationType?: HostVerificationType;
    } = {};

    if (query.status) {
        filter.status = query.status;
    }

    if (query.verificationType) {
        filter.verificationType = query.verificationType;
    }

    const [items, totalItems] = await Promise.all([
        HostVerification.find(filter)
            .sort({ createdAt: -1, verificationId: -1 })
            .skip((page - 1) * limit)
            .limit(limit),
        HostVerification.countDocuments(filter),
    ]);

    return {
        items: items.map(serializeVerification),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

const getVerificationOrThrow = async (verificationId: number, transaction?: Transaction) => {
    const verification = await HostVerification.findOne({
        where: {
            verificationId,
        },
        transaction,
    });

    if (!verification) {
        throw new ApiError(404, "Verification not found");
    }

    return verification;
};

const markUserAsHostAndVerified = async (
    hostId: number,
    adminId: number,
    transaction?: Transaction,
) => {
    await ensureUserRole(hostId, "host", transaction);

    const columns = await getExistingColumns(
        "users",
        ["is_host_verified", "host_verified", "is_verified", "host_application_status", "role"],
        transaction,
    );
    const assignments: string[] = [];
    const replacements: unknown[] = [];

    if (columns.has("is_host_verified")) {
        assignments.push("is_host_verified = 1");
    }

    if (columns.has("host_verified")) {
        assignments.push("host_verified = 1");
    }

    if (columns.has("is_verified")) {
        assignments.push("is_verified = 1");
    }

    if (columns.has("host_application_status")) {
        assignments.push("host_application_status = ?");
        replacements.push("approved");
    }

    if (columns.has("role")) {
        const roleColumnType = await getColumnType("users", "role", transaction);

        if (!roleColumnType || roleColumnType.includes("'host'")) {
            assignments.push("role = ?");
            replacements.push("host");
        }
    }

    if (assignments.length > 0) {
        await sequelize.query(
            `
            UPDATE users
            SET ${assignments.join(", ")}
            WHERE user_id = ?
            `,
            {
                replacements: [...replacements, hostId],
                transaction,
            },
        );
    }

    await markLatestHostApplicationApproved(hostId, adminId, transaction);
};

export const approveHostVerification = async (
    verificationId: number,
    admin: AuthenticatedUser,
    input: ApproveVerificationInput,
    context: AdminActionContext = {},
) => {
    assertAdmin(admin);
    assertReviewNotes(input.notes);

    return sequelize.transaction(async (transaction) => {
        const verification = await getVerificationOrThrow(verificationId, transaction);

        if (verification.status !== "pending") {
            throw new ApiError(409, "Verification is not pending");
        }

        verification.status = "approved";
        verification.reviewedByUserId = Number(admin.id);
        verification.reviewedAt = new Date();
        verification.reviewNotes = input.notes?.trim() ? input.notes.trim() : null;
        verification.rejectionReason = null;
        await verification.save({ transaction });

        await markUserAsHostAndVerified(verification.hostId, Number(admin.id), transaction);
        await writeAuditLog({
            actorId: Number(admin.id),
            action: "host_verification.approve",
            targetType: "host_verification",
            targetId: verification.verificationId,
            metadata: {
                hostId: verification.hostId,
                verificationType: verification.verificationType,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return {
            verificationId: verification.verificationId,
            status: verification.status,
        };
    });
};

export const rejectHostVerification = async (
    verificationId: number,
    admin: AuthenticatedUser,
    input: RejectVerificationInput,
    context: AdminActionContext = {},
) => {
    assertAdmin(admin);
    assertRejectionReason(input.reason);

    return sequelize.transaction(async (transaction) => {
        const verification = await getVerificationOrThrow(verificationId, transaction);

        if (verification.status !== "pending") {
            throw new ApiError(409, "Verification is not pending");
        }

        verification.status = "rejected";
        verification.reviewedByUserId = Number(admin.id);
        verification.reviewedAt = new Date();
        verification.reviewNotes = null;
        verification.rejectionReason = input.reason.trim();
        await verification.save({ transaction });

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "host_verification.reject",
            targetType: "host_verification",
            targetId: verification.verificationId,
            metadata: {
                hostId: verification.hostId,
                verificationType: verification.verificationType,
                rejectionReason: verification.rejectionReason,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return {
            verificationId: verification.verificationId,
            status: verification.status,
        };
    });
};
