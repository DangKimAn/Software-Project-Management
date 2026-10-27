import { randomUUID } from "node:crypto";

import type { RequestHandler } from "express";

export const requestId: RequestHandler = (req, res, next) => {
    const incomingRequestId = req.header("x-request-id")?.trim();
    const resolvedRequestId = incomingRequestId || randomUUID();

    req.requestId = resolvedRequestId;
    res.setHeader("X-Request-Id", resolvedRequestId);
    next();
};

