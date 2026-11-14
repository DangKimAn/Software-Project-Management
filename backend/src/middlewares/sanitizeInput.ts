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

/**
 * Giải thuật làm sạch chuỗi văn bản đầu vào chống XSS và tiêm ký tự điều khiển:
 * - Loại bỏ các ký tự điều khiển ASCII không in được (`\u0000-\u0008`, `\u000B`, `\u000C`, `\u000E-\u001F`, `\u007F`),
 *   giữ nguyên tab/xuống dòng hợp lệ.
 * - Mã hóa thực thể HTML cho các ký tự đặc biệt (`&`, `<`, `>`, `"`, `'`) để vô hiệu hóa kịch bản chèn mã độc.
 */
export const sanitizeText = (value: string) =>
    value
        .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
        .replace(/[&<>"']/g, (character) => htmlEscapeMap[character] ?? character);

/**
 * Kiểm tra giá trị là bản ghi đối tượng thuần (khác `null` và không phải mảng) phục vụ duyệt đệ quy.
 */
const isRecord = (value: unknown): value is Record<string, unknown> =>
    typeof value === "object" && value !== null && !Array.isArray(value);

/**
 * Giải thuật duyệt đệ quy cây dữ liệu đầu vào (`body`/mảng/đối tượng lồng nhau) chống Prototype Pollution và XSS:
 * 1. Giới hạn độ sâu đệ quy tối đa `maxPayloadDepth` (16 cấp) để chặn tấn công JSON lồng sâu gây tràn ngăn xếp (DoS).
 * 2. Loại bỏ triệt để các khóa nguy hiểm gây ô nhiễm nguyên mẫu đối tượng (`__proto__`, `constructor`, `prototype`).
 * 3. Áp dụng khử chuỗi `sanitizeText` có mục tiêu trên tập trường văn bản hiển thị (`textFieldNames`),
 *    tránh biến đổi ngoài ý muốn các trường mật khẩu, chữ ký số hoặc mã token.
 */
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

/**
 * Giải thuật làm sạch tại chỗ (in-place) cho các đối tượng tham chiếu cố định của Express (`req.query`, `req.params`):
 * - Xóa trực tiếp các thuộc tính nằm trong `forbiddenObjectKeys` và làm sạch đệ quy từng giá trị con.
 */
const sanitizeRecordInPlace = (target: Record<string, unknown>) => {
    for (const key of Object.keys(target)) {
        if (forbiddenObjectKeys.has(key)) {
            delete target[key];
            continue;
        }
        target[key] = sanitizePayload(target[key], key, 1);
    }
};

/**
 * Nhận diện các đường dẫn callback thanh toán có chữ ký mật mã (VNPay/MoMo Return & Webhook)
 * để bỏ qua bước biến đổi ký tự HTML, bảo toàn nguyên vẹn dữ liệu gốc phục vụ kiểm chứng chữ ký HMAC.
 */
const isSignedPaymentCallbackRequest = (path: string) =>
    signedPaymentCallbackPrefixes.some((prefix) => path.startsWith(prefix));

/**
 * Middleware Express làm sạch toàn diện dữ liệu đầu vào (`req.body`, `req.query`, `req.params`):
 * - Bỏ qua nguyên trạng các request callback cổng thanh toán có ký số HMAC; với mọi request khác,
 *   duyệt cây khử khóa Prototype Pollution và làm sạch chuỗi văn bản trước khi vào controller.
 */
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
