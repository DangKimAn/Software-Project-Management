import { createHmac, timingSafeEqual } from "node:crypto";

import { ApiError, AppError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { BookingDocument } from "../../models/booking";
import { PaymentDocument } from "../../models/payment";

export type MomoPayload = Record<string, string>;

type MomoCreateResponse = {
    partnerCode?: string;
    requestId?: string;
    orderId?: string;
    amount?: number;
    responseTime?: number;
    message?: string;
    resultCode?: number;
    payUrl?: string;
    deeplink?: string;
    qrCodeUrl?: string;
    shortLink?: string;
};

const requiredMomoConfigKeys = [
    "MOMO_PARTNER_CODE",
    "MOMO_ACCESS_KEY",
    "MOMO_SECRET_KEY",
    "MOMO_ENDPOINT",
    "MOMO_REDIRECT_URL",
    "MOMO_IPN_URL",
] as const;

/**
 * Giải thuật chuẩn hóa số tiền giao dịch MoMo sang số nguyên dương VND:
 * - Làm tròn số nguyên (`Math.round`), kiểm tra tính hữu hạn và giá trị lớn hơn 0,
 *   loại bỏ sai số dấu phẩy động trước khi ký số và gửi yêu cầu tới cổng MoMo.
 */
const toMomoAmount = (value: unknown) => {
    const amount = Math.round(Number(value));

    if (!Number.isFinite(amount) || amount <= 0) {
        throw new ApiError(400, "Invalid MoMo amount");
    }

    return amount;
};

/**
 * Giải thuật chuẩn hóa chuỗi thông tin đơn hàng (`orderInfo`) gửi MoMo:
 * - Loại bỏ ký tự xuống dòng (`\r`, `\n`), gộp khoảng trắng thừa và giới hạn tối đa 200 ký tự
 *   để không làm lệch cấu trúc chuỗi ký chuẩn tắc.
 */
const normalizeOrderInfo = (value: string) =>
    value
        .replace(/[\r\n]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 200);

/**
 * Giải thuật đọc và đối soát đầy đủ bộ khóa cấu hình tích hợp cổng thanh toán MoMo từ biến môi trường,
 * thu thập danh sách các khóa còn thiếu (`missingKeys`) phục vụ chẩn đoán trạng thái sẵn sàng.
 */
const readMomoConfig = () => {
    const env = getEnv();
    const config = {
        partnerCode: env.momoPartnerCode,
        accessKey: env.momoAccessKey,
        secretKey: env.momoSecretKey,
        endpoint: normalizeMomoEndpoint(env.momoEndpoint),
        redirectUrl: env.momoRedirectUrl,
        ipnUrl: env.momoIpnUrl,
        requestType: env.momoRequestType,
        lang: env.momoLang,
        orderExpireTimeMinutes: env.paymentHoldMinutes,
    };
    const missingKeys: string[] = [];

    if (!config.partnerCode) missingKeys.push("MOMO_PARTNER_CODE");
    if (!config.accessKey) missingKeys.push("MOMO_ACCESS_KEY");
    if (!config.secretKey) missingKeys.push("MOMO_SECRET_KEY");
    if (!config.endpoint) missingKeys.push("MOMO_ENDPOINT");
    if (!config.redirectUrl) missingKeys.push("MOMO_REDIRECT_URL");
    if (!config.ipnUrl) missingKeys.push("MOMO_IPN_URL");

    return {
        config,
        missingKeys,
        nodeEnv: env.nodeEnv,
    };
};

/**
 * Kiểm tra trạng thái sẵn sàng của phương thức thanh toán MoMo; ẩn danh sách tên biến môi trường thiếu
 * trên môi trường `production` để tránh rò rỉ cấu trúc cấu hình nội bộ.
 */
export const getMomoAvailability = () => {
    const { missingKeys, nodeEnv } = readMomoConfig();

    return {
        available: missingKeys.length === 0,
        missingKeys: nodeEnv === "production" ? [] : missingKeys,
    };
};

/**
 * Giải thuật chuẩn hóa URL endpoint khởi tạo giao dịch MoMo v2:
 * - Cắt dấu gạch chéo dư ở cuối và tự động bổ sung đường dẫn chuẩn `/v2/gateway/api/create`
 *   nếu cấu hình chỉ cung cấp tên miền gốc hoặc `/v2/gateway`.
 */
const normalizeMomoEndpoint = (endpoint: string) => {
    const trimmedEndpoint = endpoint.trim().replace(/\/+$/, "");

    if (!trimmedEndpoint) {
        return trimmedEndpoint;
    }

    try {
        const url = new URL(trimmedEndpoint);
        const normalizedPath = url.pathname.replace(/\/+$/, "");

        if (normalizedPath === "" || normalizedPath === "/") {
            url.pathname = "/v2/gateway/api/create";
            return url.toString();
        }

        if (normalizedPath === "/v2/gateway") {
            url.pathname = "/v2/gateway/api/create";
            return url.toString();
        }

        url.pathname = normalizedPath;
        return url.toString();
    } catch {
        return trimmedEndpoint;
    }
};

/**
 * Ràng buộc kiểm tra cấu hình MoMo bắt buộc trước khi thực hiện giao dịch;
 * ném `AppError(503)` nếu thiếu bất kỳ khóa kết nối hoặc khóa bí mật nào.
 */
const assertMomoConfigured = () => {
    const { config, missingKeys } = readMomoConfig();

    if (missingKeys.length > 0) {
        throw new AppError(503, "MoMo payment is temporarily unavailable", [
            {
                path: "momo",
                msg: `Missing backend environment variables: ${missingKeys.join(", ") || requiredMomoConfigKeys.join(", ")}`,
            },
        ], true);
    }

    return {
        partnerCode: config.partnerCode!,
        accessKey: config.accessKey!,
        secretKey: config.secretKey!,
        endpoint: config.endpoint!,
        redirectUrl: config.redirectUrl!,
        ipnUrl: config.ipnUrl!,
        requestType: config.requestType,
        lang: config.lang,
        orderExpireTimeMinutes: config.orderExpireTimeMinutes,
    };
};

/**
 * Giải thuật ghép chuỗi khóa-giá trị chuẩn tắc (Canonical Key-Value String) của MoMo:
 * - Lọc bỏ các trường `undefined`/`null`, sắp xếp tên tham số theo thứ tự từ điển tăng dần (`sort()`)
 *   và nối dạng `key=value` phân tách bởi dấu `&` (không mã hóa URL) theo đúng đặc tả chữ ký MoMo v2.
 */
const stringifyMomoParams = (params: Record<string, string | number | boolean | null | undefined>) =>
    Object.keys(params)
        .filter((key) => params[key] !== undefined && params[key] !== null)
        .sort()
        .map((key) => `${key}=${String(params[key])}`)
        .join("&");

/**
 * Giải thuật ký mật mã học thông điệp MoMo bằng `HMAC-SHA256`:
 * - Dựng chuỗi dữ liệu chuẩn tắc UTF-8 qua `stringifyMomoParams` và tính chữ ký `HMAC-SHA256`
 *   với khóa bí mật `secretKey`, xuất ra chuỗi thập lục phân (hex).
 */
const createSignature = (params: Record<string, string | number | boolean | null | undefined>, secretKey: string) =>
    createHmac("sha256", secretKey).update(stringifyMomoParams(params), "utf8").digest("hex");

/**
 * Giải thuật đối chiếu hai chữ ký hex theo thời gian hằng định (Constant-Time Signature Comparison):
 * - Kiểm tra biểu thức chính quy thập lục phân, chuyển sang `Buffer` nhị phân cùng độ dài và so sánh
 *   qua `crypto.timingSafeEqual` nhằm triệt tiêu tấn công kênh kề thời gian (Timing Attack).
 */
const safeEqual = (left: string, right: string) => {
    if (!/^[a-f0-9]+$/i.test(left) || !/^[a-f0-9]+$/i.test(right)) {
        return false;
    }

    const leftBuffer = Buffer.from(left, "hex");
    const rightBuffer = Buffer.from(right, "hex");

    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
};

/**
 * Giải thuật chuẩn hóa dữ liệu callback (Return URL / IPN Webhook) của MoMo về bản đồ chuỗi phẳng,
 * loại bỏ trường `null`/`undefined` và lấy phần tử đầu tiên nếu tham số bị truyền lặp dạng mảng.
 */
export const normalizeMomoPayload = (input: Record<string, unknown>): MomoPayload =>
    Object.entries(input).reduce<MomoPayload>((payload, [key, value]) => {
        if (value === undefined || value === null) {
            return payload;
        }

        payload[key] = Array.isArray(value) ? String(value[0] ?? "") : String(value);
        return payload;
    }, {});

/**
 * Giải thuật khởi tạo phiên thanh toán MoMo v2 và ký số yêu cầu tạo đơn:
 * 1. Chuẩn hóa số tiền nguyên VND (`toMomoAmount`), gắn `orderId = String(payment.paymentId)`,
 *    sinh `requestId` duy nhất và mã hóa Base64 ngữ cảnh đối soát vào `extraData`.
 * 2. Dựng tập tham số chuẩn tắc và ký `HMAC-SHA256` bằng `secretKey`.
 * 3. Gửi yêu cầu HTTP POST tới cổng MoMo với giới hạn thời gian chờ cứng 10 giây (`AbortSignal.timeout`),
 *    kiểm tra `resultCode === 0` và trích xuất URL thanh toán (`payUrl` / `shortLink` / `deeplink`).
 */
export const buildMomoPaymentUrl = async ({
    booking,
    payment,
}: {
    booking: BookingDocument;
    payment: PaymentDocument;
}) => {
    const config = assertMomoConfigured();
    const amount = toMomoAmount(payment.amount);
    const orderId = String(payment.paymentId);
    const requestId = `${payment.paymentId}-${Date.now()}`;

    const extraData = Buffer.from(
        JSON.stringify({
            paymentId: payment.paymentId,
            bookingId: booking.bookingId,
        }),
        "utf8",
    ).toString("base64");

    const orderInfo = normalizeOrderInfo(`Thanh toan booking ${booking.bookingId}`);

    const signatureParams = {
        accessKey: config.accessKey,
        amount,
        extraData,
        ipnUrl: config.ipnUrl,
        orderId,
        orderInfo,
        partnerCode: config.partnerCode,
        redirectUrl: config.redirectUrl,
        requestId,
        requestType: config.requestType,
    };

    const signature = createSignature(signatureParams, config.secretKey);

    const requestBody = {
        partnerCode: config.partnerCode,
        requestId,
        amount,
        orderId,
        orderInfo,
        redirectUrl: config.redirectUrl,
        ipnUrl: config.ipnUrl,
        requestType: config.requestType,
        extraData,
        lang: config.lang,
        ...(config.orderExpireTimeMinutes
            ? { orderExpireTime: config.orderExpireTimeMinutes }
            : {}),
        signature,
    };

    let response: Response;
    try {
        response = await fetch(config.endpoint, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Accept: "application/json",
            },
            body: JSON.stringify(requestBody),
            signal: AbortSignal.timeout(10_000),
        });
    } catch (error) {
        if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) {
            throw new ApiError(504, "MoMo payment gateway request timed out");
        }
        throw new ApiError(502, "Failed to reach MoMo payment gateway");
    }

    let payload: MomoCreateResponse;

    try {
        payload = (await response.json()) as MomoCreateResponse;
    } catch {
        throw new ApiError(502, "Invalid MoMo create payment response");
    }

    const paymentUrl = payload.payUrl ?? payload.shortLink ?? payload.deeplink ?? null;

    if (!response.ok || payload.resultCode !== 0 || !paymentUrl) {
        throw new ApiError(502, payload.message || "MoMo create payment failed", [
            {
                path: "momo.resultCode",
                msg: String(payload.resultCode ?? response.status),
            },
        ]);
    }

    return {
        paymentUrl,
        txnRef: orderId,
        requestId,
        responsePayload: payload as Record<string, unknown>,
    };
};

/**
 * Giải thuật xác thực chữ ký `HMAC-SHA256` của thông điệp Return URL / IPN từ MoMo:
 * - Trích xuất đúng danh sách 12 trường dữ liệu cố định theo đặc tả IPN MoMo v2 kết hợp `accessKey` máy chủ,
 *   sắp xếp từ điển và tính lại chữ ký `HMAC-SHA256` bằng `secretKey`.
 * - So sánh chữ ký nhận được với chữ ký tính toán bằng `safeEqual` (`timingSafeEqual`) để chống giả mạo callback.
 */
export const verifyMomoPayload = (payload: MomoPayload) => {
    const config = assertMomoConfigured();
    const signature = payload.signature;

    if (!signature) {
        return false;
    }

    const signatureFields = [
        "amount",
        "extraData",
        "message",
        "orderId",
        "orderInfo",
        "orderType",
        "partnerCode",
        "payType",
        "requestId",
        "responseTime",
        "resultCode",
        "transId",
    ];

    const params = signatureFields.reduce<Record<string, string>>((result, key) => {
        if (payload[key] !== undefined) {
            result[key] = payload[key];
        }

        return result;
    }, { accessKey: config.accessKey });

    const signed = createSignature(params, config.secretKey);

    return safeEqual(signature.toLowerCase(), signed.toLowerCase());
};

/**
 * Giải thuật đối khớp chính xác số tiền thực thu từ MoMo với số tiền gốc của giao dịch thanh toán:
 * - Ràng buộc `payload.amount` chỉ gồm các chữ số nguyên dương và bằng tuyệt đối `toMomoAmount(payment.amount)`,
 *   ngăn chặn tấn công hạ giá trị thanh toán ở phía client hoặc callback giả.
 */
export const isMomoAmountMatching = (payload: MomoPayload, payment: PaymentDocument) => {
    if (!payload.amount || !/^\d+$/.test(payload.amount)) {
        return false;
    }

    return Number(payload.amount) === toMomoAmount(payment.amount);
};
