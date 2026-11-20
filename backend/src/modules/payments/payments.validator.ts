/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ thanh toán (`payments`):
 * - Kiểm tra yêu cầu tạo giao dịch (`bookingId`, `method`), bộ lọc lịch sử và cấu trúc tham số callback bắt buộc từ VNPay (`vnp_*`) cũng như MoMo.
 */

import { z } from "zod";

/**
 * Schema kiểm chứng yêu cầu khởi tạo thanh toán gồm `bookingId` và phương thức `method` (`vnpay` / `momo`).
 */
export const createPaymentBodySchema = z.object({
    bookingId: z.coerce.number().int().positive(),
    method: z.enum(["vnpay", "momo"]),
});

/**
 * Schema kiểm chứng tham số đường dẫn `paymentId` nguyên dương.
 */
export const paymentIdParamSchema = z.object({
    paymentId: z.coerce.number().int().positive(),
});

/**
 * Schema kiểm chứng bộ lọc trạng thái và phân trang lịch sử thanh toán.
 */
export const paymentsQuerySchema = z.object({
    status: z.enum(["pending", "paid", "failed", "cancelled", "expired", "refunded"]).optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
});

const vnpayValueSchema = z.string().trim().min(1).max(2048);

/**
 * Schema kiểm chứng sự hiện diện của các trường đối soát và chữ ký bắt buộc trong callback VNPay.
 */
export const vnpayCallbackPayloadSchema = z
    .record(z.string().regex(/^vnp_[A-Za-z0-9_]+$/, "VNPay parameter name is invalid"), vnpayValueSchema)
    .superRefine((payload, context) => {
        const requiredFields = ["vnp_TxnRef", "vnp_Amount", "vnp_ResponseCode", "vnp_SecureHash"];

        for (const field of requiredFields) {
            if (!payload[field]) {
                context.addIssue({
                    code: "custom",
                    path: [field],
                    message: `${field} is required`,
                });
            }
        }

        if (payload.vnp_Amount && !/^\d+$/.test(payload.vnp_Amount)) {
            context.addIssue({
                code: "custom",
                path: ["vnp_Amount"],
                message: "vnp_Amount must be numeric",
            });
        }
    });

const momoValueSchema = z.union([z.string().trim().max(2048), z.number(), z.boolean(), z.null()]);

/**
 * Schema kiểm chứng cấu trúc dữ liệu và chữ ký trong callback Return/IPN của MoMo.
 */
export const momoCallbackPayloadSchema = z
    .record(z.string().trim().min(1).max(128), momoValueSchema)
    .superRefine((payload, context) => {
        const requiredFields = ["partnerCode", "orderId", "requestId", "amount", "resultCode", "signature"];

        for (const field of requiredFields) {
            if (payload[field] === undefined || payload[field] === null || String(payload[field]).trim() === "") {
                context.addIssue({
                    code: "custom",
                    path: [field],
                    message: `${field} is required`,
                });
            }
        }

        if (payload.amount !== undefined && !/^\d+$/.test(String(payload.amount))) {
            context.addIssue({
                code: "custom",
                path: ["amount"],
                message: "amount must be numeric",
            });
        }
    });