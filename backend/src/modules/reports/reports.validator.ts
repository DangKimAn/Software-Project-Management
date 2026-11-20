/**
 * Lược đồ kiểm chứng khoảng thời gian truy vấn thống kê (`reportRangeQuerySchema`) bằng Zod cho phân hệ báo cáo (`reports`).
 */

import { z } from "zod";

const isoDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "date must use YYYY-MM-DD format");

/**
 * Schema kiểm chứng khoảng ngày bắt đầu/kết thúc và chu kỳ gộp nhóm cho truy vấn báo cáo thống kê.
 */
export const reportRangeQuerySchema = z
    .object({
        from: isoDateSchema.optional(),
        to: isoDateSchema.optional(),
    })
    .refine((value) => !value.from || !value.to || value.from <= value.to, {
        message: "to must be greater than or equal to from",
        path: ["to"],
    });
