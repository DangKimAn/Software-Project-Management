import { createHmac, timingSafeEqual } from "node:crypto";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { BookingDocument } from "../../models/booking";
import { PaymentDocument } from "../../models/payment";
import { toVnpayAmount } from "../../utils/money";

export type VnpayPayload = Record<string, string>;

const vnpayVersion = "2.1.0";
const gmt7OffsetMs = 7 * 60 * 60 * 1000;

const pad = (value: number) => String(value).padStart(2, "0");

const toVnpayDate = (date: Date) => {
    const gmt7Date = new Date(date.getTime() + gmt7OffsetMs);

    return [
        gmt7Date.getUTCFullYear(),
        pad(gmt7Date.getUTCMonth() + 1),
        pad(gmt7Date.getUTCDate()),
        pad(gmt7Date.getUTCHours()),
        pad(gmt7Date.getUTCMinutes()),
        pad(gmt7Date.getUTCSeconds()),
    ].join("");
};

const normalizeIpAddress = (ipAddress?: string | null) => {
    const firstIp = ipAddress?.split(",")[0]?.trim();

    if (!firstIp || firstIp === "::1") {
        return "127.0.0.1";
    }

    if (firstIp.startsWith("::ffff:")) {
        return firstIp.replace("::ffff:", "");
    }

    return firstIp;
};

const normalizeOrderInfo = (value: string) =>
    value
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .replace(/[^a-zA-Z0-9 .:_-]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 255);

const sortVnpayParams = (params: VnpayPayload) =>
    Object.keys(params)
        .filter((key) => params[key] !== undefined && params[key] !== null && params[key] !== "")
        .sort()
        .reduce<VnpayPayload>((result, key) => {
            result[key] = String(params[key]).trim();
            return result;
        }, {});

const encodeVnpayComponent = (value: string) => encodeURIComponent(value).replace(/%20/g, "+");

const buildVnpayQueryString = (params: VnpayPayload) =>
    Object.entries(sortVnpayParams(params))
        .map(([key, value]) => `${encodeVnpayComponent(key)}=${encodeVnpayComponent(value)}`)
        .join("&");

const toUnsignedPayload = (payload: VnpayPayload) => {
    const {
        vnp_SecureHash: _secureHash,
        vnp_SecureHashType: _secureHashType,
        ...unsigned
    } = payload;

    return sortVnpayParams(unsigned);
};

const createSecureHash = (payload: VnpayPayload, secret: string) => {
    const signData = buildVnpayQueryString(payload);

    return createHmac("sha512", secret.trim())
        .update(Buffer.from(signData, "utf-8"))
        .digest("hex");
};

const safeEqual = (left: string, right: string) => {
    if (!/^[a-f0-9]+$/i.test(left) || !/^[a-f0-9]+$/i.test(right)) {
        return false;
    }

    const leftBuffer = Buffer.from(left, "hex");
    const rightBuffer = Buffer.from(right, "hex");

    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
};

const assertVnpayConfigured = () => {
    const env = getEnv();

    if (!env.vnpayTmnCode || !env.vnpayHashSecret || !env.vnpayReturnUrl) {
        throw new ApiError(503, "VNPay is not configured", [
            {
                path: "VNPAY_TMN_CODE",
                msg: "Set VNPAY_TMN_CODE, VNPAY_HASH_SECRET, and VNPAY_RETURN_URL in backend environment",
            },
        ]);
    }

    return {
        paymentUrl: env.vnpayPaymentUrl.trim(),
        returnUrl: env.vnpayReturnUrl.trim(),
        tmnCode: env.vnpayTmnCode.trim(),
        hashSecret: env.vnpayHashSecret.trim(),
        locale: env.vnpayLocale.trim() || "vn",
    };
};

export const normalizeVnpayPayload = (input: Record<string, unknown>): VnpayPayload =>
    Object.entries(input).reduce<VnpayPayload>((payload, [key, value]) => {
        if (!key.startsWith("vnp_") || value === undefined || value === null) {
            return payload;
        }

        payload[key] = Array.isArray(value) ? String(value[0] ?? "") : String(value);
        return payload;
    }, {});

export const buildVnpayPaymentUrl = ({
    booking,
    payment,
    ipAddress,
    createdAt: inputCreatedAt,
}: {
    booking: BookingDocument;
    payment: PaymentDocument;
    ipAddress: string;
    createdAt?: Date;
}) => {
    const config = assertVnpayConfigured();
    const env = getEnv();

    const createdAt = inputCreatedAt ?? payment.createdAt ?? new Date();
    const expireDate =
        payment.expiresAt ??
        booking.lockedUntil ??
        new Date(createdAt.getTime() + env.paymentHoldMinutes * 60 * 1000);
    const txnRef = String(payment.paymentId);

    const params: VnpayPayload = {
        vnp_Amount: String(toVnpayAmount(payment.amount)),
        vnp_Command: "pay",
        vnp_CreateDate: toVnpayDate(createdAt),
        vnp_CurrCode: "VND",
        vnp_ExpireDate: toVnpayDate(expireDate),
        vnp_IpAddr: normalizeIpAddress(ipAddress),
        vnp_Locale: config.locale,
        vnp_OrderInfo: normalizeOrderInfo(`Thanh toan booking ${booking.bookingId}`),
        vnp_OrderType: "other",
        vnp_ReturnUrl: config.returnUrl,
        vnp_TmnCode: config.tmnCode,
        vnp_TxnRef: txnRef,
        vnp_Version: vnpayVersion,
    };

    const secureHash = createSecureHash(params, config.hashSecret);

    const paymentUrlParams = buildVnpayQueryString({
        ...params,
        vnp_SecureHash: secureHash,
    });

    return {
        paymentUrl: `${config.paymentUrl}?${paymentUrlParams}`,
        txnRef,
    };
};

export const verifyVnpayPayload = (payload: VnpayPayload) => {
    const config = assertVnpayConfigured();
    const secureHash = payload.vnp_SecureHash;

    if (!secureHash) {
        return false;
    }

    const signed = createSecureHash(toUnsignedPayload(payload), config.hashSecret);

    return safeEqual(secureHash.toLowerCase(), signed.toLowerCase());
};
