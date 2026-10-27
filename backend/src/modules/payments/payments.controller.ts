import { getEnv } from "../../config/env";
import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    createPayment,
    CreatePaymentInput,
    getPaymentMethodAvailability,
    getMyPayments,
    getPaymentDetail,
    ListPaymentsQuery,
    processMomoReturn,
    processMomoWebhook,
    processVnpayReturn,
    processVnpayWebhook,
} from "./payments.service";

export const getPaymentMethods: RequestHandler = asyncHandler(async (_req, res) => {
    return sendSuccess(res, {
        data: getPaymentMethodAvailability(),
    });
});

export const createPaymentRequest: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreatePaymentInput>(req);
    const result = await createPayment(req.user!, payload, req.header("x-forwarded-for") ?? req.ip);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Payment created",
        data: result,
    });
});

export const getPaymentById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ paymentId: number }>(req);
    const result = await getPaymentDetail(req.user!, params.paymentId);

    return sendSuccess(res, {
        data: result,
    });
});

export const getMyPaymentHistory: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<ListPaymentsQuery>(req);
    const result = await getMyPayments(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const handleVnpayReturn: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedQuery<Record<string, string>>(req);

    const result = await processVnpayReturn(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    const clientOrigin = getEnv().clientOrigin;

    if (clientOrigin) {
        const redirectUrl = new URL("/thanh-toan/ket-qua", clientOrigin);

        redirectUrl.searchParams.set("paymentId", String(result.paymentId));
        redirectUrl.searchParams.set("bookingId", String(result.bookingId));
        redirectUrl.searchParams.set("status", String(result.paymentResultStatus ?? result.paymentStatus));

        if (result.requiresRefund) {
            redirectUrl.searchParams.set("requiresRefund", "true");
        }

        if (result.refundStatus) {
            redirectUrl.searchParams.set("refundStatus", String(result.refundStatus));
        }

        return res.redirect(redirectUrl.toString());
    }

    return sendSuccess(res, {
        message: "Payment updated",
        data: result,
    });
});

export const handleVnpayWebhook: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<Record<string, string>>(req);
    const result = await processVnpayWebhook(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return res.status(200).json(result);
});

export const handleMomoReturn: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedQuery<Record<string, string>>(req);

    const result = await processMomoReturn(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    const clientOrigin = getEnv().clientOrigin;

    if (clientOrigin) {
        const redirectUrl = new URL("/thanh-toan/ket-qua", clientOrigin);

        redirectUrl.searchParams.set("paymentId", String(result.paymentId));
        redirectUrl.searchParams.set("bookingId", String(result.bookingId));
        redirectUrl.searchParams.set("status", String(result.paymentResultStatus ?? result.paymentStatus));

        if (result.requiresRefund) {
            redirectUrl.searchParams.set("requiresRefund", "true");
        }

        if (result.refundStatus) {
            redirectUrl.searchParams.set("refundStatus", String(result.refundStatus));
        }

        return res.redirect(redirectUrl.toString());
    }

    return sendSuccess(res, {
        message: "Payment updated",
        data: result,
    });
});

export const handleMomoWebhook: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<Record<string, string>>(req);
    const result = await processMomoWebhook(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return res.status(200).json(result);
});
