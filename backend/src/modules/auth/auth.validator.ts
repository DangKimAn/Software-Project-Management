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

export const registerBodySchema = z.object({
    email: z.string().trim().email("email is invalid").max(255, "email must be at most 255 characters").transform((value) => value.toLowerCase()),
    password: passwordSchema,
    username: usernameSchema,
    firstName: z.string().trim().min(1, "firstName is required"),
    lastName: z.string().trim().min(1, "lastName is required"),
    phone: z.preprocess(
        (value) => (value === "" || value === null ? undefined : value),
        phoneSchema.optional(),
    ),
    dob: dobSchema,
});

export const loginBodySchema = z.object({
    identifier: identifierSchema,
    password: z.string().trim().min(8, "Mật khẩu phải có ít nhất 8 ký tự"),
});

export const forgotPasswordBodySchema = z.object({
    identifier: identifierSchema,
});

export const identifierBodySchema = forgotPasswordBodySchema;

export const sendOtpBodySchema = z.object({
    identifier: identifierSchema,
    purpose: z.enum(["sign_up", "forgot_password", "verify_email", "verify_phone"]).default("sign_up"),
});

export const resetPasswordBodySchema = z.object({
    identifier: identifierSchema,
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6 digit code"),
    newPassword: passwordSchema,
});

export const verifyPhoneBodySchema = z.object({
    identifier: identifierSchema,
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6 digit code"),
});
export const verifyEmailBodySchema = z.object({
    identifier: identifierSchema,
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6 digit code"),
});

export const googleLoginBodySchema = z.object({
    idToken: z.string().trim().min(1, "idToken is required"),
});

export const refreshTokenBodySchema = z
    .object({
        refreshToken: z.string().trim().min(1, "refreshToken is required").optional(),
    })
    .strip()
    .default({});
