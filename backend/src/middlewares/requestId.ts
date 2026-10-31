import { randomUUID } from "node:crypto";

import type { RequestHandler } from "express";

const safeRequestIdPattern = /^[A-Za-z0-9._-]{1,128}$/;

export const requestId: RequestHandler = (req, res, next) => {
    const incomingRequestId = req.header("x-request-id")?.trim();
    const resolvedRequestId =
        incomingRequestId && safeRequestIdPattern.test(incomingRequestId)
            ? incomingRequestId
            : randomUUID();

    req.requestId = resolvedRequestId;
    res.setHeader("X-Request-Id", resolvedRequestId);
    next();
};
