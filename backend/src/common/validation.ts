import { Request } from "express";
import { matchedData, validationResult } from "express-validator";

import { ApiError, ApiErrorDetail } from "./api-error";

export const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;
export const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Giải thuật kiểm tra định dạng giờ 24h (`HH:mm`):
 * - Chấp nhận giờ từ `00` đến `23` và phút từ `00` đến `59`.
 */
export const isValidTime = (value: string) => timePattern.test(value);

/**
 * Giải thuật xác thực ngày lịch chuẩn ISO (`YYYY-MM-DD`) chống tràn lịch (ví dụ `2026-02-31`):
 * - Kiểm tra biểu thức chính quy trước, sau đó dựng đối tượng `Date` ở mốc UTC 00:00:00 và đối chiếu ngược chuỗi `toISOString().slice(0, 10)` để phát hiện ngày không tồn tại.
 */
export const isValidIsoDate = (value: string) => {
    if (!isoDatePattern.test(value)) {
        return false;
    }

    const date = new Date(`${value}T00:00:00.000Z`);
    return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
};

/**
 * Giải thuật thu thập và chuẩn hóa lỗi kiểm tra đầu vào từ `express-validator`:
 * - Chỉ giữ lỗi đầu tiên trên mỗi trường (`onlyFirstError: true`) để tránh phản hồi trùng lặp và ném `ApiError(422)` theo chuẩn hợp đồng API.
 */
export const assertValidRequest = (req: Request) => {
    const errors = validationResult(req);

    if (errors.isEmpty()) {
        return;
    }

    const details = errors.array({ onlyFirstError: true }).map<ApiErrorDetail>((item) => ({
        path: "path" in item ? item.path : undefined,
        msg: item.msg,
    }));

    throw new ApiError(422, "Validation error", details);
};

/**
 * Giải thuật trích xuất dữ liệu `body` đã qua kiểm duyệt lược đồ (Allowlist Extraction):
 * - Ưu tiên dữ liệu đã chuẩn hóa tại `req.validatedData.body`, nếu chưa có thì chỉ lấy các trường khớp schema từ `matchedData` nhằm chống Mass Assignment (BOPLA).
 */
export const getValidatedBody = <T>(req: Request) =>
    (req.validatedData?.body ??
        matchedData(req, {
            includeOptionals: true,
            locations: ["body"],
        })) as T;

/**
 * Giải thuật trích xuất tham số đường dẫn (`params`) đã qua kiểm duyệt lược đồ.
 */
export const getValidatedParams = <T>(req: Request) =>
    (req.validatedData?.params ??
        matchedData(req, {
            includeOptionals: true,
            locations: ["params"],
        })) as T;

/**
 * Giải thuật trích xuất tham số truy vấn (`query`) đã qua kiểm duyệt lược đồ.
 */
export const getValidatedQuery = <T>(req: Request) =>
    (req.validatedData?.query ??
        matchedData(req, {
            includeOptionals: true,
            locations: ["query"],
        })) as T;
