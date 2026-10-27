import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedBody } from "../../common/validation";
import {
    createPresignedUploadUrl as createUploadUrl,
    type PresignUploadInput,
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
