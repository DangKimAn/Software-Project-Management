import crypto from "crypto";
import path from "path";

import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import Listing from "../../models/listing";

// CONFLICT-RESOLVED: Cho phép thư mục công khai `listings`, `avatars`, `misc`, `chat` (phục vụ tin nhắn thoại/ảnh R2 từ `origin/develop`) nhưng tiếp tục cấm tuyệt đối `verifications` trên bucket công khai.
export const allowedPublicUploadFolders = ["listings", "avatars", "misc", "chat"] as const;
export type UploadFolder = (typeof allowedPublicUploadFolders)[number];

export type PresignUploadInput = {
    folder: UploadFolder;
    filename: string;
    contentType: string;
    listingId?: number | null;
    size: number;
};

export type UploadActor = {
    userId: string;
    isAdmin: boolean;
    isHost: boolean;
};

const uploadUrlExpiresInSeconds = 300;
const maxUploadSizeBytes = 25 * 1024 * 1024;

const mediaExtensionsByContentType: Record<string, string> = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/gif": "gif",
    "audio/mpeg": "mp3",
    "audio/mp3": "mp3",
    "audio/m4a": "m4a",
    "audio/x-m4a": "m4a",
    "audio/mp4": "m4a",
    "audio/aac": "aac",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/ogg": "ogg",
    "audio/webm": "webm",
};

// CONFLICT-RESOLVED: Hợp nhất tập MIME ảnh/âm thanh từ `origin/develop` với tập thư mục công khai an toàn `allowedFoldersSet`.
const imageContentTypes = new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
]);

const allowedContentTypes = new Set(Object.keys(mediaExtensionsByContentType));
const allowedFoldersSet = new Set<string>(allowedPublicUploadFolders);

/**
 * Giải thuật kiểm tra cấu hình biến môi trường bắt buộc của kho lưu trữ công khai Cloudflare R2:
 * Rà soát toàn bộ thông số kết nối (`R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL`),
 * chuẩn hóa cắt dấu gạch chéo dư ở cuối `publicBaseUrl` hoặc ném lỗi `500` nếu thiếu cấu hình.
 */
const assertRequiredR2Env = () => {
    const env = getEnv();
    const missing = [
        ["R2_ACCOUNT_ID", env.r2AccountId],
        ["R2_ACCESS_KEY_ID", env.r2AccessKeyId],
        ["R2_SECRET_ACCESS_KEY", env.r2SecretAccessKey],
        ["R2_BUCKET", env.r2Bucket],
        ["R2_PUBLIC_BASE_URL", env.r2PublicBaseUrl],
    ]
        .filter(([, value]) => !value)
        .map(([name]) => name);

    if (missing.length > 0) {
        logger.error(`Missing R2 env: ${missing.join(", ")}`);
        throw new ApiError(500, `R2 upload is not configured. Missing ${missing.join(", ")}`);
    }

    return {
        accountId: env.r2AccountId!,
        accessKeyId: env.r2AccessKeyId!,
        secretAccessKey: env.r2SecretAccessKey!,
        bucket: env.r2Bucket!,
        publicBaseUrl: env.r2PublicBaseUrl!.replace(/\/+$/, ""),
    };
};

/**
 * Giải thuật kiểm tra tên tệp tải lên chống tấn công Path Traversal và CRLF/Null-Byte Injection:
 * Đối chiếu `path.basename(trimmed) === trimmed`, giới hạn độ dài `1..255` ký tự và cấm tuyệt đối ký tự `\0`, `\r`, `\n`.
 */
const validateFilename = (filename: string) => {
    const trimmed = filename.trim();
    const basename = path.basename(trimmed);

    if (
        trimmed.length === 0 ||
        trimmed.length > 255 ||
        basename !== trimmed ||
        /[\0\r\n]/.test(trimmed)
    ) {
        throw new ApiError(422, "Validation error", [
            {
                path: "filename",
                msg: "filename is invalid",
            },
        ]);
    }
};

// CONFLICT-RESOLVED: Khai báo bằng từ khóa `function` tường minh để thỏa ràng buộc TypeScript TS2775 cho hàm `asserts`.
/**
 * Giải thuật kiểm soát danh sách trắng thư mục tải lên công khai (`listings`, `avatars`, `misc`):
 * Ngăn chặn tuyệt đối việc tải giấy tờ định danh nhạy cảm (KYC) lên bucket công khai R2.
 */
function assertPublicUploadFolderAllowed(folder: unknown): asserts folder is UploadFolder {
    if (typeof folder !== "string" || !allowedFoldersSet.has(folder)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "folder",
                msg: "folder must be listings, avatars, or misc (identity verification files must use private KYC storage)",
            },
        ]);
    }
}

/**
 * Giải thuật kiểm tra phân quyền vai trò (RBAC) và quyền sở hữu chỗ ở (chống BOLA/IDOR) khi tải ảnh `listings`:
 * 1. Chỉ cho phép người dùng có vai trò `host` hoặc `admin`.
 * 2. Nếu chưa có `listingId`, phân vùng đường dẫn tạm vào nhánh `draft` của chính người dùng.
 * 3. Nếu truyền `listingId`, truy vấn bảng `Listing` và xác minh `listing.hostId === actor.userId` (trừ `admin`).
 */
const assertListingUploadAccess = async (listingId: number | null | undefined, actor: UploadActor) => {
    if (!actor.isAdmin && !actor.isHost) {
        throw new ApiError(403, "Forbidden");
    }

    if (!listingId) {
        return {
            listingPathSegment: "draft",
            userPathSegment: actor.userId,
        };
    }

    const listing = await Listing.findOne({
        where: {
            listingId,
            deletedAt: null,
        },
    });

    if (!listing) {
        throw new ApiError(404, "Listing not found");
    }

    if (!actor.isAdmin && String(listing.hostId) !== actor.userId) {
        throw new ApiError(403, "Forbidden");
    }

    return {
        userPathSegment: String(listing.hostId),
        listingPathSegment: String(listing.listingId),
    };
};

/**
 * Ràng buộc tính nhất quán tham số: chỉ cho phép đính kèm `listingId` khi thư mục đích là `listings`.
 */
const assertFolderListingId = (input: PresignUploadInput) => {
    if (input.folder === "listings") {
        return;
    }

    if (input.listingId !== undefined && input.listingId !== null) {
        throw new ApiError(422, "Validation error", [
            {
                path: "listingId",
                msg: "listingId is only allowed for listing uploads",
            },
        ]);
    }
};

/**
 * Giải thuật kiểm tra kích thước tệp bắt buộc chống tấn công cạn kiệt dung lượng lưu trữ (Storage DoS):
 * Yêu cầu `size` là số nguyên dương nằm trong ngưỡng từ 1 byte đến tối đa 10MB (`maxUploadSizeBytes`).
 */
const assertMandatoryUploadSize = (size: unknown): number => {
    if (size === undefined || size === null) {
        throw new ApiError(422, "Validation error", [
            {
                path: "size",
                msg: "size is required when requesting a presigned upload URL",
            },
        ]);
    }

    if (typeof size !== "number" || !Number.isInteger(size) || size < 1 || size > maxUploadSizeBytes) {
        throw new ApiError(413, "Upload file size must be between 1 byte and 10MB");
    }

    return size;
};

/**
 * Khởi tạo S3Client tương thích giao thức Cloudflare R2 (`region: "auto"`) từ cấu hình môi trường đã xác thực.
 */
const createR2Client = (config: ReturnType<typeof assertRequiredR2Env>) =>
    new S3Client({
        region: "auto",
        endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
        credentials: {
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
        },
    });

/**
 * Giải thuật cấp Presigned URL an toàn cho bucket công khai Cloudflare R2:
 * 1. Cấm tuyệt đối thư mục nhạy cảm `verifications` trên bucket công khai (chứng từ KYC bắt buộc đi qua Private R2).
 * 2. Kiểm tra quyền sở hữu listing (`403`/`404`) và danh sách trắng MIME ảnh (`JPG`, `PNG`, `WebP`, `GIF`).
 * 3. Bắt buộc truyền `size` hợp lệ (`1B..10MB`) và khóa cứng `ContentLength` vào chữ ký `PutObjectCommand`
 *    để ngăn tải tệp dung lượng không giới hạn.
 */
export const createPresignedUploadUrl = async (
    actor: UploadActor,
    input: PresignUploadInput,
) => {
    validateFilename(input.filename);
    assertPublicUploadFolderAllowed(input.folder);
    assertFolderListingId(input);

    const isChatFolder = input.folder === "chat";
    const isImage = imageContentTypes.has(input.contentType);

    if (isChatFolder) {
        if (!allowedContentTypes.has(input.contentType)) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "contentType",
                    msg: "Unsupported media type. Allowed images: JPG, PNG, WebP, GIF. Allowed audio: MP3, M4A, AAC, WAV, OGG, WebM.",
                },
            ]);
        }
    } else {
        if (!isImage) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "contentType",
                    msg: "Unsupported media type. Only JPG, PNG, WebP, or GIF are allowed.",
                },
            ]);
        }
    }

    // CONFLICT-RESOLVED: Giữ kiểm tra phân quyền sở hữu listing (`assertListingUploadAccess`) kết hợp kiểm tra kích thước bắt buộc `assertMandatoryUploadSize` (1B..25MB).
    const listingAccess =
        input.folder === "listings"
            ? await assertListingUploadAccess(input.listingId, actor)
            : null;

    const enforcedSizeBytes = assertMandatoryUploadSize(input.size);
    const r2Config = assertRequiredR2Env();
    const extension = mediaExtensionsByContentType[input.contentType] ?? "bin";
    const uuid = crypto.randomUUID();
    const objectKey = listingAccess
        ? `listings/${listingAccess.userPathSegment}/${listingAccess.listingPathSegment}/${uuid}.${extension}`
        : `${input.folder}/${actor.userId}/${uuid}.${extension}`;
    const client = createR2Client(r2Config);
    const command = new PutObjectCommand({
        Bucket: r2Config.bucket,
        Key: objectKey,
        ContentType: input.contentType,
        ContentLength: enforcedSizeBytes,
    });
    const uploadUrl = await getSignedUrl(client, command, {
        expiresIn: uploadUrlExpiresInSeconds,
    });

    return {
        uploadUrl,
        publicUrl: `${r2Config.publicBaseUrl}/${objectKey}`,
        key: objectKey,
        expiresIn: uploadUrlExpiresInSeconds,
    };
};

export const uploadBufferToR2 = async ({
    userId,
    buffer,
    filename,
    contentType,
    folder = "chat",
}: {
    userId: string;
    buffer: Buffer;
    filename: string;
    contentType: string;
    folder?: UploadFolder;
}) => {
    validateFilename(filename);
    assertPublicUploadFolderAllowed(folder);
    if (!allowedContentTypes.has(contentType)) {
        throw new ApiError(422, "Unsupported media type");
    }
    const r2Config = assertRequiredR2Env();
    const extension = mediaExtensionsByContentType[contentType] ?? "bin";
    const uuid = crypto.randomUUID();
    const objectKey = `${folder}/${userId}/${uuid}.${extension}`;
    const client = createR2Client(r2Config);
    const command = new PutObjectCommand({
        Bucket: r2Config.bucket,
        Key: objectKey,
        ContentType: contentType,
        Body: buffer,
    });
    await client.send(command);

    return {
        publicUrl: `${r2Config.publicBaseUrl}/${objectKey}`,
        key: objectKey,
        filename,
        contentType,
        size: buffer.length,
    };
};
