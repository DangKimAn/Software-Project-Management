/**
 * Định tuyến HTTP thanh toán và cổng tiếp nhận callback VNPay/MoMo (`/api/payments`):
 * - Phân tách rõ nhóm endpoint công khai có xác thực chữ ký mật mã HMAC (`return` và `webhooks` kết hợp `Limiter` + `validate` payload)
 *   và nhóm endpoint người dùng yêu cầu xác thực JWT (`authenticate`).
 */

import express from "express";
import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import {
    createPaymentRequest,
    getMyPaymentHistory,
    getPaymentMethods,
    getPaymentById,
    handleMomoReturn,
    handleMomoWebhook,
    handleVnpayReturn,
    handleVnpayWebhook,
} from "./payments.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import {
    getPaymentCallbackRateLimiter,
    getPaymentCreateRateLimiter,
} from "../../middlewares/rate-limit.middleware";
import { validate } from "../../middlewares/validate";
import {
    createPaymentBodySchema,
    momoCallbackPayloadSchema,
    paymentIdParamSchema,
    paymentsQuerySchema,
    vnpayCallbackPayloadSchema,
} from "./payments.validator";

const router = express.Router();

const validateVnpayWebhookPayload: RequestHandler = (req, _res, next) => {
    const parsed = vnpayCallbackPayloadSchema.safeParse({
        ...req.query,
        ...req.body,
    });

    if (!parsed.success) {
        return next(
            new ApiError(
                422,
                "Validation error",
                parsed.error.issues.map((issue) => ({
                    path: issue.path.join(".") || undefined,
                    msg: issue.message,
                })),
            ),
        );
    }

    req.validatedData = {
        ...(req.validatedData ?? {}),
        body: parsed.data,
    };

    return next();
};

const validateMomoWebhookPayload: RequestHandler = (req, _res, next) => {
    const parsed = momoCallbackPayloadSchema.safeParse({
        ...req.query,
        ...req.body,
    });

    if (!parsed.success) {
        return next(
            new ApiError(
                422,
                "Validation error",
                parsed.error.issues.map((issue) => ({
                    path: issue.path.join(".") || undefined,
                    msg: issue.message,
                })),
            ),
        );
    }

    req.validatedData = {
        ...(req.validatedData ?? {}),
        body: parsed.data,
    };

    return next();
};

router.get(
    "/vnpay/return",
    getPaymentCallbackRateLimiter(),
    validate({ query: vnpayCallbackPayloadSchema }),
    handleVnpayReturn,
);

router.post(
    "/webhooks/vnpay",
    getPaymentCallbackRateLimiter(),
    validateVnpayWebhookPayload,
    handleVnpayWebhook,
);

router.get(
    "/webhooks/vnpay",
    getPaymentCallbackRateLimiter(),
    validateVnpayWebhookPayload,
    handleVnpayWebhook,
);

router.get(
    "/momo/return",
    getPaymentCallbackRateLimiter(),
    validate({ query: momoCallbackPayloadSchema }),
    handleMomoReturn,
);

router.post(
    "/webhooks/momo",
    getPaymentCallbackRateLimiter(),
    validateMomoWebhookPayload,
    handleMomoWebhook,
);

router.get("/methods", getPaymentMethods);

router.use(authenticate);

router.post(
    "/",
    getPaymentCreateRateLimiter(),
    validate({ body: createPaymentBodySchema }),
    createPaymentRequest,
);

router.get(
    "/my",
    validate({ query: paymentsQuerySchema }),
    getMyPaymentHistory,
);

router.get("/:paymentId", validate({ params: paymentIdParamSchema }), getPaymentById);

export default router;
