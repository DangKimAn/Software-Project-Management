import type { Request } from "express";
import rateLimit from "express-rate-limit";

import { getEnv } from "../config/env";

const minutes = (value: number) => value * 60 * 1000;

/**
 * Giải thuật sinh khóa định danh Rate Limit ưu tiên theo tài khoản (`user:<id>`) trước khi rơi về địa chỉ mạng (`ip:<ip>`):
 * - Ngăn một người dùng đã xác thực dùng nhiều IP để vượt ngưỡng, đồng thời tránh khóa nhầm nhiều người dùng chung NAT khi đã đăng nhập.
 */
const getUserAwareKey = (req: Request) => {
    if (req.user?.id) {
        return `user:${req.user.id}`;
    }

    return `ip:${req.ip}`;
};

const resolveRouteMax = (defaultMax: number) =>
    getEnv().nodeEnv === "test" ? Math.max(defaultMax, 1000) : defaultMax;

/**
 * Giải thuật khởi tạo bộ giới hạn tần suất cửa sổ trượt (`express-rate-limit`) theo cấu hình từng phân hệ nghiệp vụ.
 */
const buildLimiter = (
    windowMinutes: number,
    max: number,
    message: string,
    options: { userAware?: boolean } = {},
) =>
    rateLimit({
        windowMs: minutes(windowMinutes),
        max,
        standardHeaders: true,
        legacyHeaders: false,
        keyGenerator: options.userAware ? getUserAwareKey : undefined,
        validate: { keyGeneratorIpFallback: false },
        message: {
            success: false,
            message,
            code: "RATE_LIMITED",
            details: {},
        },
    });

/** Bộ giới hạn tần suất tổng thể cho toàn bộ API. */
export const getGlobalRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.globalRateLimitWindowMinutes,
        env.globalRateLimitMax,
        "Too many requests. Please try again later.",
    );
};

/** Bộ giới hạn tần suất cho các điểm cuối đăng nhập/đăng ký chống dò mật khẩu (Brute-force). */
export const getAuthRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.authRateLimitWindowMinutes,
        env.authRateLimitMax,
        "Too many auth requests. Please try again later.",
    );
};

/** Bộ giới hạn tần suất cho yêu cầu cấp phát và xác minh mã OTP. */
export const getOtpRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.otpRateLimitWindowMinutesOverride,
        env.otpRateLimitMaxOverride,
        "Too many OTP requests. Please try again later.",
    );
};

/** Bộ giới hạn tần suất cho luồng quên mật khẩu. */
export const getForgotPasswordRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.forgotPasswordRateLimitWindowMinutes,
        env.forgotPasswordRateLimitMax,
        "Too many password reset requests. Please try again later.",
    );
};

/** Bộ giới hạn tần suất cho callback/IPN từ cổng thanh toán bên ngoài. */
export const getPaymentCallbackRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.paymentCallbackRateLimitWindowMinutes,
        env.paymentCallbackRateLimitMax,
        "Too many payment callback requests.",
    );
};

/** Bộ giới hạn tần suất tải tệp và xin chữ ký Presigned URL lên kho lưu trữ. */
export const getUploadRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(30),
        "Too many upload requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất khởi tạo đơn đặt phòng chống giữ chỗ hàng loạt. */
export const getBookingCreateRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(20),
        "Too many booking requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất gửi đánh giá chỗ nghỉ. */
export const getReviewWriteRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(20),
        "Too many review requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất thao tác quản trị Admin. */
export const getAdminActionRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(120),
        "Too many admin requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất gửi tin nhắn hội thoại chống spam. */
export const getMessageWriteRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(60),
        "Too many message requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất gửi báo cáo vi phạm Trust & Safety. */
export const getReportWriteRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(30),
        "Too many report requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất gọi mô hình AI Vision kiểm duyệt ảnh/CCCD chống lạm dụng chi phí (OWASP LLM04). */
export const getAiVisionRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(20),
        "Too many AI vision analysis requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất khởi tạo giao dịch thanh toán. */
export const getPaymentCreateRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(20),
        "Too many payment initiation requests. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất kiểm tra mã giảm giá chống dò mã hàng loạt. */
export const getCouponValidateRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(30),
        "Too many coupon validation attempts. Please try again later.",
        { userAware: true },
    );

/** Bộ giới hạn tần suất đăng ký mã thiết bị nhận thông báo đẩy FCM. */
export const getDeviceTokenRateLimiter = () =>
    buildLimiter(
        10,
        resolveRouteMax(30),
        "Too many device registration requests. Please try again later.",
        { userAware: true },
    );
