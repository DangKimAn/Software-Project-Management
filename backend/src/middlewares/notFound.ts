import type { RequestHandler } from "express";

import { AppError } from "../common/api-error";

export const notFound: RequestHandler = (req, _res, next) => {
    next(new AppError(404, `Route ${req.method} ${req.originalUrl} not found`));
};
