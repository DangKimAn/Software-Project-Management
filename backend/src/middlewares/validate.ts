import type { RequestHandler } from "express";
import type { ZodType } from "zod";

import { AppError, AppErrorDetail } from "../common/api-error";

type RequestSchemas = {
    body?: ZodType;
    query?: ZodType;
    params?: ZodType;
};

const toValidationErrors = (issues: Array<{ path: PropertyKey[]; message: string }>): AppErrorDetail[] =>
    issues.map((issue) => ({
        path: issue.path.join(".") || undefined,
        msg: issue.message,
    }));

/**
 * Giải thuật xác thực lược đồ nghiêm ngặt bằng Zod cho `body`, `query` và `params`:
 * - Áp dụng `safeParse` trên từng phân vùng dữ liệu và lưu kết quả đã chuẩn hóa vào `req.validatedData` để chặn trường lạ (Mass Assignment).
 * - Trả về lỗi `AppError(422)` kèm danh sách đường dẫn trường vi phạm nếu kiểm tra thất bại.
 */
export const validate = (schemas: RequestSchemas): RequestHandler => {
    return (req, _res, next) => {
        const validatedData = {
            ...(req.validatedData ?? {}),
        };

        for (const [location, schema] of Object.entries(schemas) as Array<
            [keyof RequestSchemas, ZodType | undefined]
        >) {
            if (!schema) {
                continue;
            }

            const parsed = schema.safeParse(req[location]);

            if (!parsed.success) {
                const details = toValidationErrors(parsed.error.issues);
                const firstMessage = details[0]?.msg || "Validation error";
                return next(new AppError(422, firstMessage, details));
            }

            validatedData[location] = parsed.data;
        }

        req.validatedData = validatedData;
        return next();
    };
};
