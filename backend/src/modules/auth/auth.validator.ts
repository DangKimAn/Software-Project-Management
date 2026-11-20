/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ xác thực (`auth`):
 * - Ràng buộc chặt định dạng định danh (email/số điện thoại/username), độ mạnh mật khẩu, mã OTP 6 chữ số, ngày sinh hợp lệ và tham số Google ID Token / Refresh Token.
 */

import { z } from "zod";

import {
    isEmailIdentifier,
    isPhoneIdentifier,
    normalizeIdentifier,
} from "./auth.service";

const phoneSchema = z
    .string()
    .trim()
    .regex(/^(0|\+84)[0-9]{9}$/, "phone must be a valid Vietnamese phone number");

const passwordSchema = z
    .string()
    .trim()
    .min(8, "password must be at least 8 characters")
    .max(128, "password must be at most 128 characters")
    .regex(/[A-Za-z]/, "password must contain at least one letter")
    .regex(/[0-9]/, "password must contain at least one number");

const optionalText = (max = 255) =>
    z.preprocess(
        (value) => (value === "" || value === null ? undefined : value),
        z.string().trim().max(max).optional(),
    );

const usernameSchema = z.preprocess(
    (value) => (value === "" || value === null ? undefined : value),
    z
        .string()
        .trim()
        .min(3, "username must be at least 3 characters")
        .max(30, "username must be at most 30 characters")
        .regex(/^[a-zA-Z0-9._-]+$/, "username may only contain letters, numbers, dots, underscores, or hyphens")
        .optional(),
);

const dateOnlyPattern = /^\d{4}-\d{2}-\d{2}$/;

const isValidDateOnly = (value: string) => {
    if (!dateOnlyPattern.test(value)) {
        return false;
    }

    const [year, month, day] = value.split("-").map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));

    return (
        date.getUTCFullYear() === year &&
        date.getUTCMonth() === month - 1 &&
        date.getUTCDate() === day
    );
};

const dobSchema = z.preprocess(
    (value) => (value === "" || value === null ? undefined : value),
    z
        .string()
        .trim()
        .refine(isValidDateOnly, "dob must be a valid date in YYYY-MM-DD format")
        .refine((value) => new Date(value).getTime() <= Date.now(), "dob cannot be in the future")
        .optional(),
);

/**
 * Schema kiểm chứng chuỗi định danh đăng nhập hợp lệ (email, số điện thoại Việt Nam hoặc username).
 */
export const identifierSchema = z
    .string()
    .trim()
    .min(1, "identifier is required")
    .refine((value) => {
        const normalizedValue = normalizeIdentifier(value);

        return (
            isEmailIdentifier(normalizedValue) ||
            isPhoneIdentifier(normalizedValue) ||
            /^[a-z0-9._-]{3,255}$/i.test(normalizedValue)
        );
    }, "identifier must be a valid email, username, or phone number");

/**
 * Schema kiểm chứng dữ liệu đăng ký tài khoản mới (email, mật khẩu đủ độ mạnh, họ tên, số điện thoại, ngày sinh).
 */
export const registerBodySchema = z.object({
    email: z.string().trim().email("email is invalid").max(255, "email must be at most 255 characters").transform((value) => value.toLowerCase()),
    password: passwordSchema,
    username: usernameSchema,
    firstName: z.string().trim().min(1, "firstName is required"),
    lastName: z.string().trim().min(1, "lastName is required"),
    phone: phoneSchema,
    dob: dobSchema,
});

/**
 * Schema kiểm chứng dữ liệu yêu cầu đăng nhập gồm định danh và mật khẩu.
 */
export const loginBodySchema = z.object({
    identifier: identifierSchema,
    password: z
        .string()
        .trim()
        .min(8, "Mật khẩu phải có ít nhất 8 ký tự")
        .max(128, "Mật khẩu tối đa 128 ký tự"),
});

/**
 * Schema kiểm chứng dữ liệu yêu cầu khôi phục mật khẩu theo định danh tài khoản.
 */
export const forgotPasswordBodySchema = z.object({
    identifier: identifierSchema,
});

/**
 * Schema dùng chung cho các yêu cầu chỉ nhận trường định danh `identifier`.
 */
export const identifierBodySchema = forgotPasswordBodySchema;

/**
 * Schema kiểm chứng yêu cầu gửi mã OTP gồm định danh nhận mã và mục đích sử dụng (`purpose`).
 */
export const sendOtpBodySchema = z.object({
    identifier: identifierSchema,
    purpose: z.enum(["sign_up", "forgot_password", "verify_email", "verify_phone"]).default("sign_up"),
});

/**
 * Schema kiểm chứng yêu cầu đặt lại mật khẩu gồm định danh, mã OTP 6 chữ số và mật khẩu mới.
 */
export const resetPasswordBodySchema = z.object({
    identifier: identifierSchema,
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6 digit code"),
    newPassword: passwordSchema,
});

/**
 * Schema kiểm chứng yêu cầu xác minh số điện thoại bằng mã OTP.
 */
export const verifyPhoneBodySchema = z.object({
    identifier: identifierSchema,
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6 digit code"),
});
/**
 * Schema kiểm chứng yêu cầu xác minh địa chỉ email bằng mã OTP.
 */
export const verifyEmailBodySchema = z.object({
    identifier: identifierSchema,
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6 digit code"),
});

/**
 * Schema kiểm chứng yêu cầu đăng nhập OAuth bằng chuỗi `idToken` hoặc `accessToken` dự phòng (Flutter Web GIS) do Google cấp.
 */
export const googleLoginBodySchema = z
    .object({
        idToken: z.string().trim().min(1, "idToken is required").optional(),
        accessToken: z.string().trim().min(1, "accessToken is required").optional(),
    })
    .refine((data) => Boolean(data.idToken || data.accessToken), {
        message: "idToken is required",
        path: ["idToken"],
    });

/**
 * Schema kiểm chứng dữ liệu làm mới phiên đăng nhập với trường `refreshToken` tùy chọn (khi không truyền qua cookie).
 */
export const refreshTokenBodySchema = z
    .object({
        refreshToken: z.string().trim().min(1, "refreshToken is required").optional(),
    })
    .strip()
    .default({});
