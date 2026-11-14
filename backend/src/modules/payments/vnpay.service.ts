import { createHmac, timingSafeEqual } from "node:crypto";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { BookingDocument } from "../../models/booking";
import { PaymentDocument } from "../../models/payment";
import { toVnpayAmount } from "../../common/money";

export type VnpayPayload = Record<string, string>;

const vnpayVersion = "2.1.0";
const gmt7OffsetMs = 7 * 60 * 60 * 1000;

/**
 * Đệm chữ số `0` bên trái để đảm bảo thành phần ngày/giờ luôn gồm 2 chữ số.
 */
const pad = (value: number) => String(value).padStart(2, "0");

/**
 * Giải thuật chuyển đổi mốc thời gian sang định dạng `yyyyMMddHHmmss` theo múi giờ chuẩn Việt Nam (`GMT+7`):
 * - Dịch mốc Epoch cộng thêm `7 * 3600 * 1000 ms` rồi đọc các thành phần UTC để độc lập hoàn toàn
 *   với múi giờ cục bộ của máy chủ chạy ứng dụng.
 */
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

/**
 * Giải thuật chuẩn hóa địa chỉ IP khách hàng gửi sang cổng VNPay (`vnp_IpAddr`):
 * - Trích IP đầu tiên trong chuỗi `X-Forwarded-For`, quy đổi loopback IPv6 `::1` về `127.0.0.1`
 *   và gỡ tiền tố ánh xạ IPv4-mapped IPv6 `::ffff:` để tuân thủ định dạng IPv4 của VNPay.
 */
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

/**
 * Giải thuật chuẩn hóa chuỗi mô tả đơn hàng (`vnp_OrderInfo`) tương thích chuẩn VNPay 2.1.0:
 * - Phân rã tổ hợp Unicode NFD để loại bỏ toàn bộ dấu tiếng Việt (`\p{Diacritic}`), chỉ giữ ký tự
 *   ASCII an toàn `[a-zA-Z0-9 .:_-]`, gộp khoảng trắng thừa và giới hạn tối đa 255 ký tự.
 */
const normalizeOrderInfo = (value: string) =>
    value
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .replace(/[^a-zA-Z0-9 .:_-]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 255);

/**
 * Giải thuật lọc và sắp xếp từ điển (lexicographical sort) các khóa tham số `vnp_*`:
 * - Loại bỏ các trường rỗng (`undefined`, `null`, `""`), sắp xếp tên khóa tăng dần theo bảng mã ASCII
 *   và cắt khoảng trắng hai đầu giá trị nhằm tạo đầu vào tất định (deterministic canonical input) trước khi ký HMAC.
 */
const sortVnpayParams = (params: VnpayPayload) =>
    Object.keys(params)
        .filter((key) => params[key] !== undefined && params[key] !== null && params[key] !== "")
        .sort()
        .reduce<VnpayPayload>((result, key) => {
            result[key] = String(params[key]).trim();
            return result;
        }, {});

/**
 * Giải thuật mã hóa thành phần URL theo đặc tả `application/x-www-form-urlencoded` của VNPay:
 * - Áp dụng `encodeURIComponent` chuẩn RFC 3986 sau đó thay thế `%20` bằng dấu cộng `+` để khớp
 *   tuyệt đối thuật toán dựng chuỗi ký phía máy chủ VNPay.
 */
const encodeVnpayComponent = (value: string) => encodeURIComponent(value).replace(/%20/g, "+");

/**
 * Giải thuật dựng chuỗi truy vấn chuẩn tắc (Canonical Query String) cho VNPay:
 * - Sắp xếp từ điển các khóa tham số qua `sortVnpayParams`, mã hóa URL từng khóa-giá trị bằng
 *   `encodeVnpayComponent` và nối bằng ký tự `&` phục vụ cả bước ký số lẫn tạo URL thanh toán.
 */
const buildVnpayQueryString = (params: VnpayPayload) =>
    Object.entries(sortVnpayParams(params))
        .map(([key, value]) => `${encodeVnpayComponent(key)}=${encodeVnpayComponent(value)}`)
        .join("&");

/**
 * Giải thuật tách bỏ các trường chữ ký (`vnp_SecureHash`, `vnp_SecureHashType`) khỏi dữ liệu callback
 * và sắp xếp từ điển phần tham số gốc còn lại để tái tạo chuỗi đầu vào kiểm chứng chữ ký.
 */
const toUnsignedPayload = (payload: VnpayPayload) => {
    const {
        vnp_SecureHash: _secureHash,
        vnp_SecureHashType: _secureHashType,
        ...unsigned
    } = payload;

    return sortVnpayParams(unsigned);
};

/**
 * Giải thuật ký mật mã học thông điệp thanh toán VNPay bằng `HMAC-SHA512`:
 * - Chuyển bản đồ tham số thành chuỗi truy vấn chuẩn tắc UTF-8 qua `buildVnpayQueryString`,
 *   sau đó tính mã xác thực `HMAC-SHA512` với khóa bí mật `vnpayHashSecret` (xuất dạng hex).
 */
const createSecureHash = (payload: VnpayPayload, secret: string) => {
    const signData = buildVnpayQueryString(payload);

    return createHmac("sha512", secret.trim())
        .update(Buffer.from(signData, "utf-8"))
        .digest("hex");
};

/**
 * Giải thuật so sánh hai chữ ký hex theo thời gian hằng định (Constant-Time Signature Comparison):
 * - Kiểm tra định dạng thập lục phân hợp lệ trước khi giải mã sang `Buffer` nhị phân, kiểm tra cùng độ dài byte
 *   và đối chiếu bằng `crypto.timingSafeEqual` để chống tấn công giả mạo chữ ký qua kênh kề thời gian.
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
 * Kiểm tra sự hiện diện đầy đủ của cấu hình kết nối cổng VNPay (`vnpayTmnCode`, `vnpayHashSecret`, `vnpayReturnUrl`),
 * chặn sớm bằng lỗi `503` nếu hệ thống chưa cấu hình khóa tích hợp.
 */
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

/**
 * Giải thuật lọc và chuẩn hóa dữ liệu đầu vào từ query/body của callback VNPay:
 * - Chỉ giữ lại các tham số mang tiền tố không gian tên `vnp_` khác `null`/`undefined` (ngăn tham số lạ
 *   lọt vào tập dữ liệu ký số) và ép kiểu phần tử đầu tiên nếu query bị truyền lặp dạng mảng.
 */
export const normalizeVnpayPayload = (input: Record<string, unknown>): VnpayPayload =>
    Object.entries(input).reduce<VnpayPayload>((payload, [key, value]) => {
        if (!key.startsWith("vnp_") || value === undefined || value === null) {
            return payload;
        }

        payload[key] = Array.isArray(value) ? String(value[0] ?? "") : String(value);
        return payload;
    }, {});

/**
 * Giải thuật khởi tạo URL chuyển hướng thanh toán VNPay có chữ ký số `HMAC-SHA512`:
 * 1. Quy đổi số tiền thanh toán sang đơn vị VNPay (nhân 100 thành số nguyên không phần thập phân qua `toVnpayAmount`).
 * 2. Thiết lập mốc khởi tạo và mốc hết hạn phiên giữ chỗ (`vnp_CreateDate`, `vnp_ExpireDate` chuẩn GMT+7)
 *    cùng mã tham chiếu giao dịch duy nhất `vnp_TxnRef = String(payment.paymentId)`.
 * 3. Sắp xếp từ điển các tham số `vnp_*`, ký `HMAC-SHA512` với `hashSecret` và gắn `vnp_SecureHash` vào URL đích.
 */
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

/**
 * Giải thuật xác thực tính toàn vẹn và nguồn gốc của IPN Webhook / Return URL từ VNPay:
 * - Trích xuất `vnp_SecureHash`, loại bỏ các trường hash khỏi payload gốc, sắp xếp từ điển và tính lại
 *   chữ ký `HMAC-SHA512` bằng `hashSecret` máy chủ.
 * - Đối chiếu chữ ký nhận được và chữ ký tự tính bằng `safeEqual` (`timingSafeEqual`) không phân biệt hoa/thường,
 *   chặn đứng mọi hành vi giả mạo tham số kết quả hoặc chỉnh sửa số tiền trên URL/IPN.
 */
export const verifyVnpayPayload = (payload: VnpayPayload) => {
    const config = assertVnpayConfigured();
    const secureHash = payload.vnp_SecureHash;

    if (!secureHash) {
        return false;
    }

    const signed = createSecureHash(toUnsignedPayload(payload), config.hashSecret);

    return safeEqual(secureHash.toLowerCase(), signed.toLowerCase());
};
