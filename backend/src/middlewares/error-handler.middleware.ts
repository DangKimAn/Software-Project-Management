import type { ErrorRequestHandler } from "express";
import { DatabaseError, UniqueConstraintError, ValidationError } from "sequelize";

import { logger } from "../config/logger";
import { AppError } from "../common/api-error";
import { sendError } from "../common/http";

const isProduction = () => process.env.NODE_ENV === "production";

const getHttpErrorStatus = (error: unknown) => {
    if (!error || typeof error !== "object") {
        return undefined;
    }

    const statusCode =
        (error as { statusCode?: unknown }).statusCode ?? (error as { status?: unknown }).status;

    if (typeof statusCode !== "number" || !Number.isInteger(statusCode)) {
        return undefined;
    }

    return statusCode >= 400 && statusCode < 600 ? statusCode : undefined;
};

const getHttpErrorMessage = (error: unknown, statusCode: number) => {
    const type = error && typeof error === "object" ? (error as { type?: unknown }).type : undefined;

    if (statusCode === 413 || type === "entity.too.large") {
        return "Payload too large";
    }

    if (statusCode === 400 && type === "entity.parse.failed") {
        return "Invalid request body";
    }

    if (statusCode === 415) {
        return "Unsupported media type";
    }

    return statusCode < 500 ? "Bad request" : "Internal server error";
};

export const errorHandler: ErrorRequestHandler = (error, req, res, _next) => {
    if (error instanceof AppError) {
        if (error.statusCode >= 500) {
            logger.error("Application error", error, {
                requestId: req.requestId,
                method: req.method,
                path: req.originalUrl,
            });
        }

        const message = error.expose || !isProduction() ? error.message : "Internal server error";

        return sendError(res, error.statusCode, message, error.errors);
    }

    if (error instanceof UniqueConstraintError) {
        return sendError(res, 409, "Conflict");
    }

    if (error instanceof ValidationError) {
        const details = error.errors.map((item) => ({
            path: item.path ?? undefined,
            msg: item.message,
        }));

        return sendError(res, 422, "Validation error", details);
    }

    if (error instanceof DatabaseError) {
        logger.error("Database error", error, {
            requestId: req.requestId,
            method: req.method,
            path: req.originalUrl,
        });

        return sendError(res, 500, isProduction() ? "Internal server error" : "Database error");
    }

    const httpStatus = getHttpErrorStatus(error);

    if (httpStatus) {
        if (httpStatus >= 500) {
            logger.error("HTTP server error", error, {
                requestId: req.requestId,
                method: req.method,
                path: req.originalUrl,
            });
        }

        return sendError(res, httpStatus, getHttpErrorMessage(error, httpStatus));
    }

    logger.error("Unhandled error", error, {
        requestId: req.requestId,
        method: req.method,
        path: req.originalUrl,
    });

    return sendError(
        res,
        500,
        "Internal server error",
        isProduction() || !(error instanceof Error) ? undefined : [{ msg: error.message }],
    );
};
