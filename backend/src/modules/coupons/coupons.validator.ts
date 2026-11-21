/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ mã giảm giá (`coupons`):
 * - Ràng buộc quy tắc mã code chuẩn hóa, loại giảm giá (phần trăm/số tiền cố định), ngưỡng đơn tối thiểu, giới hạn lượt dùng và tính hợp lệ của khoảng ngày hiệu lực.
 */

import { z } from "zod";

const decimalStringSchema = z
    .union([z.string(), z.number()])
    .transform((value) => String(value).trim())
    .refine((value) => /^\d+(?:\.\d{1,2})?$/.test(value), "amount must be a non-negative DECIMAL value");

const couponCodeSchema = z
    .string()
    .trim()
    .min(1)
    .max(64)
    .transform((value) => value.toUpperCase())
    .refine((value) => /^[A-Z0-9_-]+$/.test(value), "code may only contain letters, numbers, underscore, and hyphen");

const isoDateTimeSchema = z
    .string()
    .trim()
    .refine((value) => !Number.isNaN(new Date(value).getTime()), "date must be a valid ISO datetime");

/**
 * Schema kiểm chứng tham số truy vấn khi khách kiểm tra mã giảm giá trên giá trị đơn hàng.
 */
export const validateCouponQuerySchema = z.object({
    code: couponCodeSchema,
    bookingAmount: decimalStringSchema,
    listingId: z.coerce.number().int().positive().optional(),
});

/**
 * Schema kiểm chứng bộ lọc tìm kiếm và phân trang danh sách mã giảm giá quản trị.
 */
export const couponListQuerySchema = z.object({
    active: z
        .enum(["true", "false"])
        .transform((value) => value === "true")
        .optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
});

const couponWritableFields = {
    code: couponCodeSchema,
    title: z.string().trim().min(1).max(255),
    description: z.string().trim().max(2000).nullable().optional(),
    type: z.enum(["percent", "fixed_amount"]),
    discountValue: decimalStringSchema,
    maxDiscountAmount: decimalStringSchema.nullable().optional(),
    minOrderValue: decimalStringSchema.nullable().optional(),
    startDate: isoDateTimeSchema,
    endDate: isoDateTimeSchema,
    totalLimit: z.coerce.number().int().positive().nullable().optional(),
    limitPerUser: z.coerce.number().int().positive().nullable().optional(),
    isActive: z.boolean().optional(),
};

const validateCouponShape = <T extends z.ZodRawShape>(schema: z.ZodObject<T>) =>
    schema.superRefine((value, context) => {
        if ("startDate" in value && "endDate" in value) {
            const startDate = new Date(String(value.startDate));
            const endDate = new Date(String(value.endDate));

            if (startDate >= endDate) {
                context.addIssue({
                    code: "custom",
                    path: ["endDate"],
                    message: "endDate must be after startDate",
                });
            }
        }

        if ("type" in value && "discountValue" in value && value.type === "percent") {
            const percentValue = Number(value.discountValue);

            if (!Number.isFinite(percentValue) || percentValue <= 0 || percentValue > 100) {
                context.addIssue({
                    code: "custom",
                    path: ["discountValue"],
                    message: "percent discountValue must be between 0 and 100",
                });
            }
        }
    });

/**
 * Schema kiểm chứng toàn vẹn dữ liệu tạo mới mã giảm giá (mức giảm, trần giảm, ngày bắt đầu/kết thúc, giới hạn lượt dùng).
 */
export const createCouponBodySchema = validateCouponShape(z.object(couponWritableFields));

/**
 * Schema kiểm chứng dữ liệu cập nhật mã giảm giá đảm bảo tính nhất quán giữa loại giảm giá và khoảng thời gian hiệu lực.
 */
export const updateCouponBodySchema = validateCouponShape(
    z
        .object(couponWritableFields)
        .partial()
        .refine((value) => Object.keys(value).length > 0, {
            message: "At least one coupon field must be provided",
        }),
);

/**
 * Schema kiểm chứng tham số đường dẫn `couponId` nguyên dương.
 */
export const couponIdParamSchema = z.object({
    couponId: z.coerce.number().int().positive(),
});
