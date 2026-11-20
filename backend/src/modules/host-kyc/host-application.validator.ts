// CONFLICT-RESOLVED: Tách riêng tầng chuẩn hóa dữ liệu và lập kế hoạch tải chứng từ KYC khỏi `host-application.service.ts`
// để giữ kích thước mỗi tệp nhỏ gọn và dễ kiểm thử độc lập.
import { ApiError } from "../../common/api-error";
import {
    type HostApplicationDocument,
    type HostEntityType,
    hostEntityTypeValues,
} from "../../models/host-application";
import type {
    HostIdentityDocument as HostIdentityDocumentModel,
    IdentityDocumentSide,
    IdentityDocumentType,
} from "../../models/host-identity-document";

export const identityApplicationDocumentTypeValues = [
    "cccd",
    "cmnd",
    "passport",
    "driver_license",
] as const;

export type ApplicationIdentityDocumentType = (typeof identityApplicationDocumentTypeValues)[number];

export type IdentityDocumentFiles = {
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

export type DocumentUploadPlan = {
    file: Express.Multer.File;
    documentType: IdentityDocumentType;
    side: IdentityDocumentSide;
};

export const nullableTrim = (value?: string | null) => {
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

export const normalizeProfileType = (input: SubmitHostApplicationInput): HostEntityType => {
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

export const normalizeDocumentType = (
    input: SubmitHostApplicationInput,
): ApplicationIdentityDocumentType => {
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

/**
 * Giải thuật lập kế hoạch nạp chứng từ định danh theo ma trận `(profileType, documentType)`:
 * Bắt buộc đủ mặt trước/mặt sau với CCCD/CMND, ảnh đơn với Hộ chiếu, mặt trước với GPLX,
 * và Giấy phép kinh doanh với pháp nhân `business`, đồng thời từ chối mọi trường tệp dư thừa.
 */
export const buildDocumentUploadPlan = (
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

export const assertSubmitInput = (input: SubmitHostApplicationInput) => {
    assertStringMax("contactName", input.contactName, 120);
    assertEmail(input.contactEmail);
    assertPhone(input.phone ?? input.contactPhone);
    assertRequiredString("businessAddress", input.businessAddress, 500);
    assertStringMax("note", input.note ?? input.notes, 2000);
};

export const serializeHostDocument = (document: HostIdentityDocumentModel) => ({
    id: Number(document.id),
    documentType: document.documentType,
    side: document.side,
    status: document.status,
    originalFilename: document.originalFilename,
    createdAt: document.createdAt,
});

export const serializeHostApplication = (
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

export const toKycPagination = (page?: number, limit?: number, defaultLimit = 20) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(100, Math.max(1, limit ?? defaultLimit)),
});
