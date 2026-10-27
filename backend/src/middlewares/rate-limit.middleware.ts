import type { Request } from "express";
import rateLimit from "express-rate-limit";

import { getEnv } from "../config/env";

const minutes = (value: number) => value * 60 * 1000;

const getUserAwareKey = (req: Request) => {
    if (req.user?.id) {
        return `user:${req.user.id}`;
    }

    return `ip:${req.ip}`;
};

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

export const getGlobalRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.globalRateLimitWindowMinutes,
        env.globalRateLimitMax,
        "Too many requests. Please try again later.",
    );
};

export const getAuthRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.authRateLimitWindowMinutes,
        env.authRateLimitMax,
        "Too many auth requests. Please try again later.",
    );
};

export const getOtpRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.otpRateLimitWindowMinutesOverride,
        env.otpRateLimitMaxOverride,
        "Too many OTP requests. Please try again later.",
    );
};

export const getForgotPasswordRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.forgotPasswordRateLimitWindowMinutes,
        env.forgotPasswordRateLimitMax,
        "Too many password reset requests. Please try again later.",
    );
};

export const getPaymentCallbackRateLimiter = () => {
    const env = getEnv();

    return buildLimiter(
        env.paymentCallbackRateLimitWindowMinutes,
        env.paymentCallbackRateLimitMax,
        "Too many payment callback requests.",
    );
};

export const getUploadRateLimiter = () =>
    buildLimiter(10, 30, "Too many upload requests. Please try again later.", { userAware: true });

export const getBookingCreateRateLimiter = () =>
    buildLimiter(10, 20, "Too many booking requests. Please try again later.", { userAware: true });

export const getReviewWriteRateLimiter = () =>
    buildLimiter(10, 20, "Too many review requests. Please try again later.", { userAware: true });

export const getAdminActionRateLimiter = () =>
    buildLimiter(10, 120, "Too many admin requests. Please try again later.", { userAware: true });
export const getMessageWriteRateLimiter = () =>
    buildLimiter(10, 60, "Too many message requests. Please try again later.", { userAware: true });

export const getReportWriteRateLimiter = () =>
    buildLimiter(10, 30, "Too many report requests. Please try again later.", { userAware: true });
