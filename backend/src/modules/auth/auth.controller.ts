/**
 * Bộ điều phối HTTP xác thực và quản lý phiên đăng nhập (`auth`):
 * - Điều phối đăng ký, đăng nhập mật khẩu/Google OAuth, xoay vòng Refresh Token qua HttpOnly Cookie,
 *   đăng xuất thu hồi phiên, cấp phát/xác thực OTP (đặt lại mật khẩu, xác minh email/số điện thoại) và tra cứu thông tin người dùng hiện tại.
 */

import type { Request, RequestHandler, Response } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedBody } from "../../common/validation";
import { getEnv } from "../../config/env";
import { authenticateWithGoogleIdToken } from "./google-auth.service";
import {
    buildAuthCookieOptions,
    buildRefreshCookieOptions,
    comparePassword,
    extractRefreshToken,
    findUserForLogin,
    issueAuthOtp,
    issueAuthSession,
    isLoginTemporarilyLocked,
    recordFailedLoginAttempt,
    refreshAuthSession,
    registerUser,
    resetPasswordWithOtp,
    revokeRefreshSessionByToken,
    toAuthResponseUser,
    verifyPhoneWithOtp,
    verifyEmailWithOtp,
} from "./auth.service";

const authContextFromRequest = (req: Request) => ({
    ipAddress: req.ip,
    userAgent: req.get("user-agent") ?? null,
});

const writeAuthCookies = (res: Response, session: { accessToken: string; refreshToken: string }) => {
    res.cookie(getEnv().refreshCookieName, session.refreshToken, buildRefreshCookieOptions());
};

/**
 * Xử lý đăng ký tài khoản mới, khởi tạo phiên xác thực và thiết lập HttpOnly Cookie cho cặp token.
 */
export const register: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{
        email: string;
        password: string;
        username?: string;
        firstName: string;
        lastName: string;
        phone?: string | null;
        dob?: string | null;
    }>(req);
    const user = await registerUser(payload);
    const session = await issueAuthSession(user, authContextFromRequest(req));

    writeAuthCookies(res, session);

    // Fire-and-forget: send email verification OTP without blocking the response
    let emailVerificationOtp: unknown = null;
    issueAuthOtp(
        {
            identifier: user.email,
            purpose: "verify_email",
        },
        authContextFromRequest(req),
    ).then((result) => {
        emailVerificationOtp = result;
    }).catch(() => {
        // Silently ignore — user is already registered, OTP can be re-requested later
    });

    return sendSuccess(res, {
        statusCode: 201,
        message: "Registration successful",
        data: {
            token: session.accessToken,
            accessToken: session.accessToken,
            user: await toAuthResponseUser(user, session.roles),
            ...(getEnv().authDebugOtp && emailVerificationOtp ? { emailVerificationOtp } : {}),

        },
    });
});

/**
 * Xác thực thông tin đăng nhập cục bộ, kiểm tra khóa tạm thời chống Brute-Force và cấp phiên đăng nhập mới.
 */
export const login: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{ identifier: string; password: string }>(req);

    if (await isLoginTemporarilyLocked(payload.identifier)) {
        throw new ApiError(423, "Tài khoản tạm thời bị khóa. Vui lòng thử lại sau.");
    }

    const user = await findUserForLogin(payload.identifier);
    const isPasswordValid = await comparePassword(payload.password, user?.passwordHash);

    if (!user || !isPasswordValid) {
        const failedCount = await recordFailedLoginAttempt(payload.identifier, authContextFromRequest(req), user);

        if (failedCount >= 5) {
            throw new ApiError(423, "Tài khoản tạm thời bị khóa. Vui lòng thử lại sau.");
        }

        throw new ApiError(401, "Email/SĐT hoặc mật khẩu không đúng.");
    }

    const session = await issueAuthSession(user, authContextFromRequest(req));

    writeAuthCookies(res, session);

    return sendSuccess(res, {
        message: "Login successful",
        data: {
            token: session.accessToken,
            accessToken: session.accessToken,
            user: await toAuthResponseUser(user, session.roles),

        },
    });
});

/**
 * Thu hồi phiên Refresh Token hiện tại trong cơ sở dữ liệu và xóa toàn bộ cookie xác thực trên trình duyệt.
 */
export const logout: RequestHandler = asyncHandler(async (req, res) => {
    const refreshToken = extractRefreshToken(req);

    if (refreshToken) {
        await revokeRefreshSessionByToken(refreshToken);
    }

    res.clearCookie("auth_token", buildAuthCookieOptions());
    res.clearCookie(getEnv().refreshCookieName, buildRefreshCookieOptions());

    return sendSuccess(res, {
        message: "Logout successful",
    });
});

/**
 * Thực hiện xoay vòng Refresh Token một lần (Single-Use Rotation) và cấp lại cặp Access/Refresh Token mới.
 */
export const refresh: RequestHandler = asyncHandler(async (req, res) => {
    const refreshToken = extractRefreshToken(req);

    if (!refreshToken) {
        throw new ApiError(403, "Invalid or expired refresh token");
    }

    const result = await refreshAuthSession(refreshToken, authContextFromRequest(req));

    writeAuthCookies(res, result);

    return sendSuccess(res, {
        message: "Token refreshed",
        data: {
            token: result.accessToken,
            accessToken: result.accessToken,
            user: result.user,
        },
    });
});

/**
 * Tiếp nhận yêu cầu cấp phát mã OTP theo mục đích xác thực kèm giới hạn tần suất gửi.
 */
export const sendOtp: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{
        identifier: string;
        purpose?: "sign_up" | "forgot_password" | "verify_email" | "verify_phone";
    }>(req);
    const result = await issueAuthOtp(payload, authContextFromRequest(req));

    return sendSuccess(res, {
        message: "OTP sent if the destination can receive it",
        data: result,
    });
});

/**
 * Khởi tạo luồng quên mật khẩu bằng cách phát hành mã OTP đặt lại mật khẩu một cách chống dò tìm tài khoản.
 */
export const forgotPassword: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{ identifier: string }>(req);
    const result = await issueAuthOtp(
        {
            ...payload,
            purpose: "forgot_password",
        },
        authContextFromRequest(req),
    );

    return sendSuccess(res, {
        message: "Password reset OTP sent if the account exists",
        data: result,
    });
});

/**
 * Xác thực mã OTP một lần để đặt mật khẩu mới và thu hồi toàn diện các phiên đăng nhập cũ.
 */
export const resetPassword: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{
        identifier: string;
        otp: string;
        newPassword: string;
    }>(req);
    const result = await resetPasswordWithOtp(payload, authContextFromRequest(req));

    res.clearCookie("auth_token", buildAuthCookieOptions());
    res.clearCookie(getEnv().refreshCookieName, buildRefreshCookieOptions());

    return sendSuccess(res, {
        message: "Password reset successful",
        data: result,
    });
});

/**
 * Xác thực mã OTP để đánh dấu số điện thoại của tài khoản đã được xác minh.
 */
export const verifyPhone: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{ identifier: string; otp: string }>(req);
    const result = await verifyPhoneWithOtp(payload, authContextFromRequest(req));

    return sendSuccess(res, {
        message: "Phone number verified successfully",
        data: result,
    });
});
/**
 * Xác thực mã OTP để đánh dấu địa chỉ email của tài khoản đã được xác minh.
 */
export const verifyEmail: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{ identifier: string; otp: string }>(req);
    const result = await verifyEmailWithOtp(payload, authContextFromRequest(req));

    return sendSuccess(res, {
        message: "Email verified successfully",
        data: result,
    });
});

/**
 * Xác thực Google ID Token, liên kết hoặc tạo tài khoản xã hội an toàn và cấp phiên đăng nhập.
 */
export const loginWithGoogle: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<{ idToken: string }>(req);
    const result = await authenticateWithGoogleIdToken(payload.idToken, authContextFromRequest(req));

    writeAuthCookies(res, result);

    return sendSuccess(res, {
        message: "Google login successfully",
        data: {
            token: result.accessToken,
            accessToken: result.accessToken,
            user: result.user,
        },
    });
});

/**
 * Trả về thông tin hồ sơ và vai trò đã đồng bộ của người dùng đang đăng nhập hiện tại.
 */
export const getCurrentUser: RequestHandler = (req, res) => {
    const user = req.user!;
    const role = user.roles.includes("admin")
        ? "admin"
        : user.roles.includes("host")
            ? "host"
            : "guest";

    return sendSuccess(res, {
        data: {
            user: {
                ...user,
                userId: user.id,
                role,
            },
        },
    });
};
