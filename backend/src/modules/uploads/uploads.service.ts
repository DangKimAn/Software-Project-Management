import crypto from "crypto";
import path from "path";

import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import Listing from "../../models/listing";

export type UploadFolder = "listings" | "avatars" | "verifications" | "misc";

export type PresignUploadInput = {
    folder: UploadFolder;
    filename: string;
    contentType: string;
    listingId?: number | null;
};

export type UploadActor = {
    userId: string;
    isAdmin: boolean;
    isHost: boolean;
};

const uploadUrlExpiresInSeconds = 300;

const imageExtensionsByContentType: Record<string, string> = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/gif": "gif",
};

const allowedContentTypes = new Set(Object.keys(imageExtensionsByContentType));

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

const createR2Client = (config: ReturnType<typeof assertRequiredR2Env>) =>
    new S3Client({
        region: "auto",
        endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
        credentials: {
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
        },
    });

export const createPresignedUploadUrl = async (
    actor: UploadActor,
    input: PresignUploadInput,
) => {
    validateFilename(input.filename);
    assertFolderListingId(input);

    if (!allowedContentTypes.has(input.contentType)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "contentType",
                msg: "Only JPG, PNG, WebP, or GIF image files are allowed",
            },
        ]);
    }

    const r2Config = assertRequiredR2Env();
    const extension = imageExtensionsByContentType[input.contentType];
    const uuid = crypto.randomUUID();
    const objectKey =
        input.folder === "listings"
            ? await assertListingUploadAccess(input.listingId, actor).then(
                  ({ userPathSegment, listingPathSegment }) =>
                      `listings/${userPathSegment}/${listingPathSegment}/${uuid}.${extension}`,
              )
            : `${input.folder}/${actor.userId}/${uuid}.${extension}`;
    const client = createR2Client(r2Config);
    const command = new PutObjectCommand({
        Bucket: r2Config.bucket,
        Key: objectKey,
        ContentType: input.contentType,
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
