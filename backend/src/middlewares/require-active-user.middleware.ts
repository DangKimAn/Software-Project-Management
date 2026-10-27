import type { RequestHandler } from "express";

import { ApiError } from "../common/api-error";

export const requireActiveUser: RequestHandler = (req, _res, next) => {
    if (!req.user) {
        return next(new ApiError(401, "Unauthorized"));
    }

    if (req.user.status !== "active") {
        return next(new ApiError(403, "Account is not active"));
    }

    return next();
};
