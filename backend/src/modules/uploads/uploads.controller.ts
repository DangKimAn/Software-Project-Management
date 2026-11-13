import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedBody } from "../../common/validation";
import {
    createPresignedUploadUrl as createUploadUrl,
    type PresignUploadInput,
    uploadBufferToR2,
    type UploadFolder,
} from "./uploads.service";

export const createPresignedUploadUrl: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<PresignUploadInput>(req);
    const result = await createUploadUrl(
        {
            userId: req.user!.id,
            isAdmin: req.user!.roles.includes("admin"),
            isHost: req.user!.roles.includes("host"),
        },
        payload,
    );

    return sendSuccess(res, {
        data: result,
    });
});

export const uploadDirectFile: RequestHandler = asyncHandler(async (req, res) => {
    if (!req.file) {
        throw new ApiError(400, "No file uploaded");
    }

    const folder = (req.body.folder as UploadFolder) || "chat";
    const result = await uploadBufferToR2({
        userId: req.user!.id,
        buffer: req.file.buffer,
        filename: req.file.originalname,
        contentType: req.file.mimetype,
        folder,
    });

    return sendSuccess(res, {
        statusCode: 201,
        message: "File uploaded successfully to R2",
        data: result,
    });
});
