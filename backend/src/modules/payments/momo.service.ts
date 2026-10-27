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

const toMomoAmount = (value: unknown) => {
    const amount = Math.round(Number(value));

    if (!Number.isFinite(amount) || amount <= 0) {
        throw new ApiError(400, "Invalid MoMo amount");
    }

    return amount;
};

const normalizeOrderInfo = (value: string) =>
    value
        .replace(/[\r\n]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 200);

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

export const getMomoAvailability = () => {
    const { missingKeys, nodeEnv } = readMomoConfig();

    return {
        available: missingKeys.length === 0,
        missingKeys: nodeEnv === "production" ? [] : missingKeys,
    };
};

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

const stringifyMomoParams = (params: Record<string, string | number | boolean | null | undefined>) =>
    Object.keys(params)
        .filter((key) => params[key] !== undefined && params[key] !== null)
        .sort()
        .map((key) => `${key}=${String(params[key])}`)
        .join("&");

const createSignature = (params: Record<string, string | number | boolean | null | undefined>, secretKey: string) =>
    createHmac("sha256", secretKey).update(stringifyMomoParams(params), "utf8").digest("hex");

const safeEqual = (left: string, right: string) => {
    if (!/^[a-f0-9]+$/i.test(left) || !/^[a-f0-9]+$/i.test(right)) {
        return false;
    }

    const leftBuffer = Buffer.from(left, "hex");
    const rightBuffer = Buffer.from(right, "hex");

    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
};

export const normalizeMomoPayload = (input: Record<string, unknown>): MomoPayload =>
    Object.entries(input).reduce<MomoPayload>((payload, [key, value]) => {
        if (value === undefined || value === null) {
            return payload;
        }

        payload[key] = Array.isArray(value) ? String(value[0] ?? "") : String(value);
        return payload;
    }, {});

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

    const response = await fetch(config.endpoint, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
        },
        body: JSON.stringify(requestBody),
    });

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

export const isMomoAmountMatching = (payload: MomoPayload, payment: PaymentDocument) => {
    if (!payload.amount || !/^\d+$/.test(payload.amount)) {
        return false;
    }

    return Number(payload.amount) === toMomoAmount(payment.amount);
};
