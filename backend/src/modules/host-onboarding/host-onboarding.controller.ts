import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedBody } from "../../common/validation";
import {
    getCurrentHostApplication,
    RegisterHostInput,
    registerHostApplication,
} from "./host-onboarding.service";
export const getMyHostApplication: RequestHandler = asyncHandler(async (req, res) => {
    const result = await getCurrentHostApplication(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});
export const registerHost: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<RegisterHostInput>(req);
    const result = await registerHostApplication(req.user!, payload);

    return sendSuccess(res, {
        statusCode: result.created ? 201 : 200,
        message: result.created ? "Host application submitted" : "Host application updated",
        data: result,
    });
});
