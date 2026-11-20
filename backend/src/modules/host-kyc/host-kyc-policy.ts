/**
 * Chính sách kiểm định tính đầy đủ của bộ chứng từ định danh chủ nhà (`host-kyc-policy`).
 */
// CONFLICT-RESOLVED: Hợp nhất chính sách kiểm duyệt chứng từ định danh KYC vào module chuẩn `modules/host-kyc/`
// để dùng chung nhất quán giữa luồng nộp đơn, đăng ký chủ nhà và phê duyệt quản trị.
import { ApiError } from "../../common/api-error";
import type { HostEntityType } from "../../models/host-application";
import type {
    IdentityDocumentSide,
    IdentityDocumentType,
} from "../../models/host-identity-document";

export type KycDocumentSummaryItem = {
    documentType?: IdentityDocumentType | string | null;
    side: IdentityDocumentSide | string;
    objectKey?: string | null;
    storageKey?: string | null;
    status?: string | null;
};

export type KycCompletenessResult = {
    valid: boolean;
    isComplete: boolean;
    reason?: string;
};

/**
 * Giải thuật kiểm tra tính đầy đủ của bộ hồ sơ giấy tờ định danh KYC Chủ nhà:
 * 1. Bắt buộc danh sách tài liệu đính kèm không được rỗng và mỗi tài liệu phải có khóa lưu trữ riêng tư (`objectKey` / `storageKey`).
 * 2. Đối chiếu quy tắc nghiệp vụ định danh cá nhân:
 *    - Nếu dùng CCCD hoặc CMND: bắt buộc có đủ cả mặt trước ('front') và mặt sau ('back') cùng loại.
 *    - Nếu dùng Hộ chiếu ('passport'): bắt buộc có tệp 'single' hoặc 'front'.
 *    - Nếu dùng Giấy phép lái xe ('driver_license'): bắt buộc có mặt trước ('front').
 * 3. Nếu loại hình đăng ký là Doanh nghiệp / Hộ kinh doanh (`entityType === 'business'`),
 *    bắt buộc phải có thêm Giấy phép kinh doanh ('business_license').
 */
export const validateHostKycDocumentCompleteness = (
    entityTypeOrDocuments: HostEntityType | string | KycDocumentSummaryItem[],
    maybeDocuments?: KycDocumentSummaryItem[],
): KycCompletenessResult => {
    const entityType = Array.isArray(entityTypeOrDocuments)
        ? "individual"
        : (entityTypeOrDocuments || "individual");
    const documents = Array.isArray(entityTypeOrDocuments)
        ? entityTypeOrDocuments
        : (maybeDocuments ?? []);

    if (!Array.isArray(documents) || documents.length === 0) {
        return {
            valid: false,
            isComplete: false,
            reason: "Host application has no uploaded KYC identity documents",
        };
    }

    const normalizedDocs = documents
        .filter((doc) => {
            if (!doc || typeof doc.side !== "string") {
                return false;
            }
            const refKey = doc.objectKey !== undefined ? doc.objectKey : doc.storageKey;
            return refKey === undefined || Boolean(refKey && refKey.trim());
        })
        .map((doc) => ({
            documentType:
                typeof doc.documentType === "string" && doc.documentType.trim()
                    ? doc.documentType.trim()
                    : "cccd",
            side: doc.side,
        }));

    if (normalizedDocs.length !== documents.length) {
        return {
            valid: false,
            isComplete: false,
            reason: "One or more KYC identity documents are missing private storage references",
        };
    }

    const hasDoc = (type: string, sides: string[]) =>
        normalizedDocs.some((doc) => doc.documentType === type && sides.includes(doc.side));

    const hasCompleteCccd = hasDoc("cccd", ["front"]) && hasDoc("cccd", ["back"]);
    const hasCompleteCmnd = hasDoc("cmnd", ["front"]) && hasDoc("cmnd", ["back"]);
    const hasCompletePassport = hasDoc("passport", ["single", "front"]);
    const hasCompleteDriverLicense = hasDoc("driver_license", ["front"]);

    if (!hasCompleteCccd && !hasCompleteCmnd && !hasCompletePassport && !hasCompleteDriverLicense) {
        return {
            valid: false,
            isComplete: false,
            reason: "Host application is missing required personal identity documents (CCCD/CMND front & back, Passport, or Driver License)",
        };
    }

    if (entityType === "business" && !hasDoc("business_license", ["business_license", "single", "front"])) {
        return {
            valid: false,
            isComplete: false,
            reason: "Business host application requires a valid business license document",
        };
    }

    return { valid: true, isComplete: true };
};

/**
 * Giải thuật chặn phê duyệt hồ sơ Chủ nhà thiếu xác minh KYC (BFLA / Business Logic Guard):
 * Ném lỗi HTTP 422 ngay lập tức nếu Admin hoặc luồng nội bộ cố gắng phê duyệt một bản ghi
 * `host_applications` không có đủ bộ giấy tờ định danh hợp lệ, ngăn chặn cấp quyền host trái phép.
 */
export const assertHostApplicationReadyForApproval = (
    entityTypeOrApplicationId: HostEntityType | string | number,
    documents: KycDocumentSummaryItem[],
    maybeEntityType?: HostEntityType | string | null,
): void => {
    const entityType =
        typeof entityTypeOrApplicationId === "number"
            ? (maybeEntityType ?? "individual")
            : entityTypeOrApplicationId;
    const check = validateHostKycDocumentCompleteness(entityType, documents);
    if (!check.valid) {
        throw new ApiError(422, check.reason ?? "Missing required KYC identity documents", [
            {
                path: "documents",
                msg: check.reason ?? "Required KYC identity documents must be uploaded before approval",
            },
        ]);
    }
};
