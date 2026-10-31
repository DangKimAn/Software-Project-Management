import type { RequestHandler } from "express";

import { ApiError } from "../common/api-error";

const textFieldNames = new Set([
    "accountName",
    "addressLine",
    "bankCode",
    "bankName",
    "bio",
    "businessAddress",
    "caption",
    "city",
    "comment",
    "contactName",
    "content",
    "description",
    "district",
    "firstMessage",
    "firstName",
    "fullName",
    "lastName",
    "message",
    "name",
    "notes",
    "postalCode",
    "quietHours",
    "reason",
    "reference",
    "reply",
    "reportReason",
    "stateRegion",
    "title",
    "ward",
]);

const forbiddenObjectKeys = new Set(["__proto__", "constructor", "prototype"]);
const maxPayloadDepth = 16;

const signedPaymentCallbackPrefixes = [
    "/api/payments/webhooks/",
    "/api/payments/vnpay/return",
    "/api/payments/momo/return",
];

const htmlEscapeMap: Record<string, string> = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
};

export const sanitizeText = (value: string) =>
    value
        .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
        .replace(/[&<>"']/g, (character) => htmlEscapeMap[character] ?? character);

const isRecord = (value: unknown): value is Record<string, unknown> =>
    typeof value === "object" && value !== null && !Array.isArray(value);

export const sanitizePayload = (value: unknown, key?: string, depth = 0): unknown => {
    if (depth > maxPayloadDepth) {
        throw new ApiError(400, "Request payload nesting is too deep");
    }

    if (typeof value === "string") {
        return key && textFieldNames.has(key) ? sanitizeText(value) : value;
    }

    if (Array.isArray(value)) {
        return value.map((item) => sanitizePayload(item, key, depth + 1));
    }

    if (!isRecord(value)) {
        return value;
    }

    const sanitizedEntries: Array<[string, unknown]> = [];
    for (const [entryKey, entryValue] of Object.entries(value)) {
        if (forbiddenObjectKeys.has(entryKey)) {
            continue;
        }
        sanitizedEntries.push([entryKey, sanitizePayload(entryValue, entryKey, depth + 1)]);
    }

    return Object.fromEntries(sanitizedEntries);
};

const sanitizeRecordInPlace = (target: Record<string, unknown>) => {
    for (const key of Object.keys(target)) {
        if (forbiddenObjectKeys.has(key)) {
            delete target[key];
            continue;
        }
        target[key] = sanitizePayload(target[key], key, 1);
    }
};

const isSignedPaymentCallbackRequest = (path: string) =>
    signedPaymentCallbackPrefixes.some((prefix) => path.startsWith(prefix));

export const sanitizeInput: RequestHandler = (req, _res, next) => {
    const requestPath = req.originalUrl?.split("?")[0] ?? req.path ?? "";
    if (isSignedPaymentCallbackRequest(requestPath)) {
        next();
        return;
    }

    try {
        if (req.body !== undefined && req.body !== null) {
            req.body = sanitizePayload(req.body);
        }

        if (isRecord(req.query)) {
            sanitizeRecordInPlace(req.query);
        }

        if (isRecord(req.params)) {
            sanitizeRecordInPlace(req.params);
        }

        next();
    } catch (error) {
        next(error);
    }
};
