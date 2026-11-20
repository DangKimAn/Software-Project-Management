import type { RequestHandler } from "express";

import { AppError } from "../common/api-error";

/**
 * Giải thuật bắt điểm cuối không tồn tại (Fallback 404 Handler) ở cuối chuỗi định tuyến Express.
 */
export const notFound: RequestHandler = (req, _res, next) => {
    next(new AppError(404, `Route ${req.method} ${req.originalUrl} not found`));
};
