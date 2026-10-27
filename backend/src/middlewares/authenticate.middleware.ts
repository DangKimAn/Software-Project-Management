import { RequestHandler } from "express";

import { ApiError } from "../common/api-error";
import { asyncHandler } from "../common/async-handler";
import User from "../models/user";
import {
    assertUserCanAuthenticate,
    extractAuthToken,
    toAuthenticatedUser,
    verifyAuthToken,
} from "../modules/auth/auth.service";

export const authenticate: RequestHandler = asyncHandler(async (req, _res, next) => {
    const token = extractAuthToken(req);

    if (!token) {
        throw new ApiError(401, "Unauthorized");
    }

    const payload = verifyAuthToken(token);
    const user = await User.findById(payload.userId);

    if (!user) {
        throw new ApiError(401, "Unauthorized");
    }

    assertUserCanAuthenticate(user);
    req.user = await toAuthenticatedUser(user);
    next();
});
