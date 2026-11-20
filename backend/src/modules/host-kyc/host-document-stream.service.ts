// CONFLICT-RESOLVED: Tách riêng dịch vụ phát hành token HMAC và truyền phát luồng tài liệu định danh riêng tư R2
// khỏi `host-application.service.ts` để đảm bảo nguyên tắc đơn trách nhiệm (~130 dòng).
import { createHmac, timingSafeEqual } from "node:crypto";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import HostIdentityDocument from "../../models/host-identity-document";
import { getPrivateIdentityDocumentStream } from "../../services/private-r2-storage.service";
import type { AuthenticatedUser } from "../auth/auth.service";

const HOST_DOC_STREAM_TOKEN_TTL_SECONDS = 300;

/**
 * Giải thuật phát hành & xác thực mã ủy quyền xem tài liệu KYC ngắn hạn (HMAC-SHA256):
 * 1. Đóng gói phạm vi truy cập chặt chẽ (`applicationId`, `documentId`, `adminUserId`, `exp` 300s) thành Base64URL.
 * 2. Ký HMAC-SHA256 bằng `tokenHashSecret` và đối chiếu chữ ký bằng `timingSafeEqual` để chống timing attack.
 * 3. Mã này chỉ được truyền qua HTTP Header `X-Document-Stream-Token` (tuyệt đối không đính kèm trên URL query string).
 */
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

/**
 * Giải thuật xác thực mã ủy quyền xem luồng tài liệu định danh KYC (`verifyHostDocStreamToken`):
 * 1. Tách cấu trúc `payload.signature`, tính toán lại chữ ký HMAC-SHA256 với `tokenHashSecret` và so sánh hằng thời gian bằng `timingSafeEqual` để chống tấn công đo thời gian (timing attack).
 * 2. Giải mã payload Base64URL và kiểm tra ràng buộc phạm vi nghiêm ngặt: đúng loại token `host_doc_stream`, khớp chính xác `applicationId` và `documentId` đang truy cập, có `uid` quản trị viên hợp lệ và chưa quá hạn `exp`.
 */
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

/**
 * Giải thuật mở luồng đọc trực tiếp chứng từ định danh KYC từ kho lưu trữ riêng tư Cloudflare R2 cho Quản trị viên:
 * 1. Thực thi kiểm soát phân quyền RBAC: bắt buộc người gọi có vai trò `admin` (`403 Forbidden` nếu vi phạm).
 * 2. Đối chiếu cặp khóa `(id = documentId, applicationId)` trong bảng `HostIdentityDocument` để chống truy cập chéo hồ sơ (BOLA/IDOR).
 * 3. Đọc luồng nhị phân từ bucket Private R2 qua `objectKey` mà không tạo đường dẫn công khai.
 */
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
