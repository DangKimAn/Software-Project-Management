import { z } from "zod";

export const createPaymentBodySchema = z.object({
    bookingId: z.coerce.number().int().positive(),
    method: z.enum(["vnpay", "momo"]),
});

export const paymentIdParamSchema = z.object({
    paymentId: z.coerce.number().int().positive(),
});

export const paymentsQuerySchema = z.object({
    status: z.enum(["pending", "paid", "failed", "cancelled", "expired", "refunded"]).optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
});

const vnpayValueSchema = z.string().trim().min(1).max(2048);

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