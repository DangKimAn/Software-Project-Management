/**
 * Bộ điều phối HTTP giao dịch thanh toán và cổng callback VNPay/MoMo (`payments`):
 * - Điều phối tra cứu phương thức khả dụng, khởi tạo phiên thanh toán, xem lịch sử/chi tiết giao dịch,
 *   xử lý chuyển hướng Return URL về ứng dụng/web và phản hồi IPN Webhook máy chủ-máy chủ theo định dạng chuẩn của từng cổng.
 */

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

/**
 * Trả về danh sách các cổng thanh toán trực tuyến cùng trạng thái sẵn sàng cấu hình.
 */
export const getPaymentMethods: RequestHandler = asyncHandler(async (_req, res) => {
    return sendSuccess(res, {
        data: getPaymentMethodAvailability(),
    });
});

/**
 * Khởi tạo giao dịch thanh toán cho đơn đặt phòng và trả về URL chuyển hướng sang cổng thanh toán.
 */
export const createPaymentRequest: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreatePaymentInput>(req);
    const result = await createPayment(req.user!, payload, req.ip);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Payment created",
        data: result,
    });
});

/**
 * Truy vấn thông tin chi tiết và trạng thái đối soát của một giao dịch thanh toán.
 */
export const getPaymentById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ paymentId: number }>(req);
    const result = await getPaymentDetail(req.user!, params.paymentId);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Liệt kê phân trang lịch sử các giao dịch thanh toán của người dùng hiện tại.
 */
export const getMyPaymentHistory: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<ListPaymentsQuery>(req);
    const result = await getMyPayments(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Xử lý callback chuyển hướng trình duyệt Return URL từ VNPay, đối soát kết quả và điều hướng về giao diện đích.
 */
export const handleVnpayReturn: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedQuery<Record<string, string>>(req);

    const result = await processVnpayReturn(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    const clientOrigin = getEnv().clientOrigin;

    if (clientOrigin) {
        // Giải thuật điều hướng về tuyến Hash URL của Flutter Web (/#/thanh-toan/ket-qua?...) để tránh lỗi 404 SPA reload (TC-047):
        const params = new URLSearchParams({
            paymentId: String(result.paymentId),
            bookingId: String(result.bookingId),
            status: String(result.paymentResultStatus ?? result.paymentStatus),
        });

        if (result.requiresRefund) {
            params.set("requiresRefund", "true");
        }

        if (result.refundStatus) {
            params.set("refundStatus", String(result.refundStatus));
        }

        const cleanOrigin = clientOrigin.replace(/\/+$/, "");
        return res.redirect(`${cleanOrigin}/#/thanh-toan/ket-qua?${params.toString()}`);
    }

    return sendSuccess(res, {
        message: "Payment updated",
        data: result,
    });
});

/**
 * Xử lý thông báo tức thời IPN Webhook từ máy chủ VNPay và phản hồi mã `RspCode` chuẩn giao thức.
 */
export const handleVnpayWebhook: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<Record<string, string>>(req);
    const result = await processVnpayWebhook(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return res.status(200).json(result);
});

/**
 * Xử lý callback chuyển hướng Return URL từ cổng MoMo và điều hướng người dùng về trang kết quả thanh toán.
 */
export const handleMomoReturn: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedQuery<Record<string, string>>(req);

    const result = await processMomoReturn(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    const clientOrigin = getEnv().clientOrigin;

    if (clientOrigin) {
        // Giải thuật điều hướng về tuyến Hash URL của Flutter Web (/#/thanh-toan/ket-qua?...) để tránh lỗi 404 SPA reload (TC-047):
        const params = new URLSearchParams({
            paymentId: String(result.paymentId),
            bookingId: String(result.bookingId),
            status: String(result.paymentResultStatus ?? result.paymentStatus),
        });

        if (result.requiresRefund) {
            params.set("requiresRefund", "true");
        }

        if (result.refundStatus) {
            params.set("refundStatus", String(result.refundStatus));
        }

        const cleanOrigin = clientOrigin.replace(/\/+$/, "");
        return res.redirect(`${cleanOrigin}/#/thanh-toan/ket-qua?${params.toString()}`);
    }

    return sendSuccess(res, {
        message: "Payment updated",
        data: result,
    });
});

/**
 * Xử lý thông báo IPN Webhook từ máy chủ MoMo và trả về mã đối soát `resultCode` chuẩn.
 */
export const handleMomoWebhook: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<Record<string, string>>(req);
    const result = await processMomoWebhook(payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return res.status(200).json(result);
});
