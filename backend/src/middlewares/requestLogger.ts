import type { RequestHandler } from "express";

import { logger } from "../config/logger";

const sensitiveQueryKeys = new Set([
    "vnp_SecureHash",
    "vnp_SecureHashType",
    "token",
    "accessToken",
    "refreshToken",
    "password",
]);

const sanitizeUrlForLog = (value: string) => {
    const [path, queryString] = value.split("?", 2);

    if (!queryString) {
        return path;
    }

    const params = new URLSearchParams(queryString);

    for (const key of Array.from(params.keys())) {
        if (sensitiveQueryKeys.has(key)) {
            params.set(key, "[redacted]");
        }
    }

    const sanitizedQuery = params.toString();
    return sanitizedQuery ? `${path}?${sanitizedQuery}` : path;
};

export const requestLogger: RequestHandler = (req, res, next) => {
    const startedAt = Date.now();

    res.on("finish", () => {
        logger.info("HTTP request", {
            requestId: req.requestId,
            method: req.method,
            path: sanitizeUrlForLog(req.originalUrl),
            statusCode: res.statusCode,
            durationMs: Date.now() - startedAt,
            ipAddress: req.ip,
            userAgent: req.get("user-agent") ?? null,
        });
    });

    next();
};
