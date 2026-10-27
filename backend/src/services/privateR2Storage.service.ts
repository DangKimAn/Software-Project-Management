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

const createPrivateR2Client = (config: PrivateR2Config) =>
    new S3Client({
        region: config.region,
        endpoint: config.endpoint,
        credentials: {
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
        },
    });

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

const assertValidPrivateIdentityFile = (file: Express.Multer.File) => {
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

export const ensurePrivateR2StorageConfigured = () => {
    assertRequiredPrivateR2Env();
};

export const getPrivateSignedUrlExpiresSeconds = () =>
    assertRequiredPrivateR2Env().signedUrlExpiresSeconds;

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

export const deletePrivateIdentityDocumentsQuietly = async (objectKeys: string[]) => {
    for (const objectKey of objectKeys) {
        try {
            await deletePrivateIdentityDocument(objectKey);
        } catch {
            // Best-effort rollback cleanup. Do not log private object keys.
        }
    }
};
