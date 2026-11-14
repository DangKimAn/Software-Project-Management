import { randomUUID } from "node:crypto";

import type { RequestHandler } from "express";

const safeRequestIdPattern = /^[A-Za-z0-9._-]{1,128}$/;

/**
 * Giải thuật cấp phát và lan truyền mã định danh truy vết yêu cầu (`X-Request-Id`):
 * - Chấp nhận `X-Request-Id` do cổng ngược (Reverse Proxy) truyền vào nếu khớp danh sách ký tự an toàn (chống HTTP Response Splitting / Log Injection); ngược lại sinh UUID v4 mới bằng CSPRNG.
 */
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
