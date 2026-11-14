/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ đánh giá (`reviews`), ràng buộc `reviewId`, thang điểm đánh giá và nội dung nhận xét.
 */

import { z } from "zod";

/**
 * Schema kiểm chứng tham số đường dẫn `reviewId` nguyên dương.
 */
export const reviewIdParamSchema = z.object({
    reviewId: z.coerce.number().int().positive(),
});

/**
 * Schema kiểm chứng dữ liệu tạo đánh giá gồm `bookingId`, điểm số trong thang hợp lệ và nội dung nhận xét.
 */
export const createReviewBodySchema = z.object({
    bookingId: z.coerce.number().int().positive(),
    rating: z.coerce.number().int().min(1).max(5),
    comment: z.string().trim().max(2000).optional().nullable(),
});

