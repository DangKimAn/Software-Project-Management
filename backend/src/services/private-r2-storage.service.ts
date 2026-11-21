/**
 * Adapter hạ tầng kết nối lưu trữ riêng tư Cloudflare R2 (giao thức S3) phục vụ lưu trữ chứng từ KYC chủ nhà.
 */
// CONFLICT-RESOLVED: Chuẩn hóa đặt tên kebab-case quốc tế từ `privateR2Storage.service.ts` sang `private-r2-storage.service.ts`.
import { randomUUID } from "node:crypto";

import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

import { ApiError } from "../common/api-error";
import { getEnv } from "../config/env";

type PrivateR2Config = {
    accessKeyId: string;
    secretAccessKey: string;
    bucket: string;
    endpoint: string;
    region: string;
    signedUrlExpiresSeconds: number;
};

export type PrivateIdentityUploadParams = {
    userId: number;
    applicationId: number;
};

export type PrivateIdentityUploadResult = {
    objectKey: string;
    mimeType: string;
    fileSize: number;
    originalFilename: string | null;
};

const allowedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]);

const extensionByMimeType: Record<string, string> = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "application/pdf": "pdf",
};

const maxIdentityDocumentSizeBytes = 5 * 1024 * 1024;

/**
 * Giải thuật làm sạch tên tệp gốc đính kèm siêu dữ liệu KYC chống Path Traversal và Header Injection:
 * - Tách bỏ toàn bộ phân đoạn thư mục (`/` và `\`) để chỉ lấy tên tệp cuối cùng (`basename`).
 * - Từ chối tên tệp quá 255 ký tự hoặc chứa byte rỗng `\0`, ký tự điều khiển xuống dòng `\r`, `\n`.
 */
const sanitizeOriginalFilename = (filename?: string | null) => {
    const value = filename?.trim();

    if (!value) {
        return null;
    }

    const basename = value.split(/[\\/]/).pop() ?? "";

    if (!basename || basename.length > 255 || /[\0\r\n]/.test(basename)) {
        return null;
    }

    return basename;
};

/**
 * Kiểm tra đầy đủ cấu hình xác thực và endpoint của kho đối tượng riêng tư Cloudflare R2 (`R2_PRIVATE_*`),
 * ném `ApiError(503)` nếu thiếu bất kỳ biến môi trường bắt buộc nào.
 */
const assertRequiredPrivateR2Env = (): PrivateR2Config => {
    const env = getEnv();
    const missing = [
        ["R2_PRIVATE_ACCESS_KEY_ID", env.r2PrivateAccessKeyId],
        ["R2_PRIVATE_SECRET_ACCESS_KEY", env.r2PrivateSecretAccessKey],
        ["R2_PRIVATE_BUCKET", env.r2PrivateBucket],
        ["R2_PRIVATE_ENDPOINT", env.r2PrivateEndpoint],
    ]
        .filter(([, value]) => !value)
        .map(([name]) => name);

    if (missing.length > 0) {
        throw new ApiError(
            503,
            `Private R2 identity document storage is not configured. Missing ${missing.join(", ")}`,
        );
    }

    return {
        accessKeyId: env.r2PrivateAccessKeyId!,
        secretAccessKey: env.r2PrivateSecretAccessKey!,
        bucket: env.r2PrivateBucket!,
        endpoint: env.r2PrivateEndpoint!.replace(/\/+$/, ""),
        region: env.r2PrivateRegion,
        signedUrlExpiresSeconds: env.r2PrivateSignedUrlExpiresSeconds,
    };
};

/**
 * Khởi tạo trình khách AWS S3 tương thích (`S3Client`) trỏ về endpoint Cloudflare R2 riêng tư lưu hồ sơ KYC.
 */
const createPrivateR2Client = (config: PrivateR2Config) =>
    new S3Client({
        region: config.region,
        endpoint: config.endpoint,
        credentials: {
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
        },
    });

/**
 * Giải thuật đối chiếu chữ ký byte định danh nhị phân đầu tệp (`Magic Bytes`) chống giả mạo MIME/đuôi tệp:
 * - `image/jpeg`: đối chiếu 3 byte đầu `FF D8 FF`.
 * - `image/png`: đối chiếu chuỗi 8 byte chuẩn PNG `89 50 4E 47 0D 0A 1A 0A`.
 * - `image/webp`: kiểm tra cấu trúc khung RIFF tối thiểu 12 byte với `[0..3] === "RIFF"` và `[8..11] === "WEBP"`.
 * - `application/pdf`: đối chiếu 5 byte tiêu đề ASCII `"%PDF-"`.
 * Ngăn chặn triệt để hành vi tải lên tệp thực thi, web shell hoặc HTML/SVG độc hại ngụy trang dưới phần mở rộng ảnh/PDF.
 */
const matchesMagicBytes = (buffer: Buffer, mimeType: string) => {
    if (mimeType === "image/jpeg") {
        return buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
    }

    if (mimeType === "image/png") {
        return (
            buffer.length >= 8 &&
            buffer[0] === 0x89 &&
            buffer[1] === 0x50 &&
            buffer[2] === 0x4e &&
            buffer[3] === 0x47 &&
            buffer[4] === 0x0d &&
            buffer[5] === 0x0a &&
            buffer[6] === 0x1a &&
            buffer[7] === 0x0a
        );
    }

    if (mimeType === "image/webp") {
        return (
            buffer.length >= 12 &&
            buffer.subarray(0, 4).toString("ascii") === "RIFF" &&
            buffer.subarray(8, 12).toString("ascii") === "WEBP"
        );
    }

    if (mimeType === "application/pdf") {
        return buffer.length >= 5 && buffer.subarray(0, 5).toString("ascii") === "%PDF-";
    }

    return false;
};

/**
 * Giải thuật kiểm định an toàn đa lớp tệp giấy tờ tùy thân KYC trước khi tải lên kho riêng tư:
 * 1. Kiểm tra `mimetype` thuộc danh sách trắng (`image/jpeg`, `image/png`, `image/webp`, `application/pdf`).
 * 2. Kiểm tra bộ đệm nhị phân khác rỗng và dung lượng không vượt trần 5MB (`413 Payload Too Large`).
 * 3. Đối chiếu chữ ký nhị phân đầu tệp (`matchesMagicBytes`) khớp tuyệt đối với `mimetype` khai báo.
 */
export const assertValidPrivateIdentityFile = (file: Express.Multer.File) => {
    if (!allowedMimeTypes.has(file.mimetype)) {
        throw new ApiError(422, "Validation error", [
            {
                path: file.fieldname,
                msg: "Only JPG, PNG, WebP, or PDF files are allowed",
            },
        ]);
    }

    if (!file.buffer || file.buffer.length === 0) {
        throw new ApiError(422, "Validation error", [
            {
                path: file.fieldname,
                msg: "File is empty",
            },
        ]);
    }

    if (file.size > maxIdentityDocumentSizeBytes) {
        throw new ApiError(413, "Each identity document file must be 5MB or smaller");
    }

    if (!matchesMagicBytes(file.buffer, file.mimetype)) {
        throw new ApiError(422, "Validation error", [
            {
                path: file.fieldname,
                msg: "File content does not match its declared file type",
            },
        ]);
    }
};

/**
 * Đảm bảo kho lưu trữ Private R2 đã được cấu hình hợp lệ trước khi tiếp nhận quy trình nộp hồ sơ KYC.
 */
export const ensurePrivateR2StorageConfigured = () => {
    assertRequiredPrivateR2Env();
};

/**
 * Trả về thời gian sống (giây) của Presigned URL truy cập tạm thời tài liệu định danh trên Private R2.
 */
export const getPrivateSignedUrlExpiresSeconds = () =>
    assertRequiredPrivateR2Env().signedUrlExpiresSeconds;

/**
 * Giải thuật lưu trữ an toàn tài liệu định danh KYC lên kho Cloudflare R2 riêng tư:
 * - Kiểm định tính hợp lệ và `Magic Bytes` của tệp qua `assertValidPrivateIdentityFile`.
 * - Sinh khóa lưu trữ phân cấp cô lập `identity-docs/users/<userId>/applications/<applicationId>/<timestamp>-<UUIDv4>.<ext>`
 *   (dùng phần mở rộng chuẩn hóa từ MIME và UUID ngẫu nhiên mật mã, không bao giờ dùng tên tệp người dùng làm khóa lưu trữ).
 * - Đẩy nội dung nhị phân lên bucket riêng tư bằng `PutObjectCommand`.
 */
export const uploadPrivateIdentityDocument = async (
    file: Express.Multer.File,
    params: PrivateIdentityUploadParams,
): Promise<PrivateIdentityUploadResult> => {
    assertValidPrivateIdentityFile(file);

    const config = assertRequiredPrivateR2Env();
    const client = createPrivateR2Client(config);
    const extension = extensionByMimeType[file.mimetype];
    const objectKey = [
        "identity-docs",
        "users",
        String(params.userId),
        "applications",
        String(params.applicationId),
        `${Date.now()}-${randomUUID()}.${extension}`,
    ].join("/");

    await client.send(
        new PutObjectCommand({
            Bucket: config.bucket,
            Key: objectKey,
            Body: file.buffer,
            ContentType: file.mimetype,
        }),
    );

    return {
        objectKey,
        mimeType: file.mimetype,
        fileSize: file.size,
        originalFilename: sanitizeOriginalFilename(file.originalname),
    };
};

/**
 * Giải thuật tạo URL truy cập tạm thời có chữ ký mật mã AWS SigV4 (`getSignedUrl` + `GetObjectCommand`)
 * với thời hạn ngắn (`signedUrlExpiresSeconds`) để cấp quyền đọc có kiểm soát cho tài liệu KYC riêng tư.
 */
export const createPrivateSignedGetUrl = async (objectKey: string) => {
    if (!objectKey?.trim()) {
        throw new ApiError(404, "Identity document object not found");
    }

    const config = assertRequiredPrivateR2Env();
    const client = createPrivateR2Client(config);

    return getSignedUrl(
        client,
        new GetObjectCommand({
            Bucket: config.bucket,
            Key: objectKey,
        }),
        {
            expiresIn: config.signedUrlExpiresSeconds,
        },
    );
};

/**
 * Giải thuật mở luồng đọc trực tiếp đối tượng tài liệu KYC từ Private R2 (`GetObjectCommand`)
 * phục vụ cơ chế truyền tải luồng có kiểm tra phân quyền phía máy chủ mà không lộ khóa bucket.
 */
export const getPrivateIdentityDocumentStream = async (objectKey: string) => {
    if (!objectKey?.trim()) {
        throw new ApiError(404, "Identity document object not found");
    }

    const config = assertRequiredPrivateR2Env();
    const client = createPrivateR2Client(config);

    return client.send(
        new GetObjectCommand({
            Bucket: config.bucket,
            Key: objectKey,
        }),
    );
};

/**
 * Xóa vĩnh viễn một đối tượng tài liệu định danh KYC khỏi bucket Private R2 qua `DeleteObjectCommand`.
 */
export const deletePrivateIdentityDocument = async (objectKey: string) => {
    const config = assertRequiredPrivateR2Env();
    const client = createPrivateR2Client(config);

    await client.send(
        new DeleteObjectCommand({
            Bucket: config.bucket,
            Key: objectKey,
        }),
    );
};

/**
 * Giải thuật thu dọn bù trừ không chặn (Best-Effort Compensating Cleanup) các tệp KYC trên Private R2
 * khi giao dịch DB thất bại; bắt mọi ngoại lệ và không ghi `objectKey` nhạy cảm ra log.
 */
export const deletePrivateIdentityDocumentsQuietly = async (objectKeys: string[]) => {
    for (const objectKey of objectKeys) {
        try {
            await deletePrivateIdentityDocument(objectKey);
        } catch {
            // Best-effort rollback cleanup. Do not log private object keys.
        }
    }
};
