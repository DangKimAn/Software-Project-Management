import type { RequestHandler } from "express";

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

export const sanitizePayload = (value: unknown, key?: string): unknown => {
    if (typeof value === "string") {
        return key && textFieldNames.has(key) ? sanitizeText(value) : value;
    }

    if (Array.isArray(value)) {
        return value.map((item) => sanitizePayload(item, key));
    }

    if (!isRecord(value)) {
        return value;
    }

    return Object.fromEntries(
        Object.entries(value).map(([entryKey, entryValue]) => [
            entryKey,
            sanitizePayload(entryValue, entryKey),
        ]),
    );
};

const sanitizeRecordInPlace = (target: Record<string, unknown>) => {
    for (const [key, value] of Object.entries(target)) {
        target[key] = sanitizePayload(value, key);
    }
};

export const sanitizeInput: RequestHandler = (req, _res, next) => {
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
};
