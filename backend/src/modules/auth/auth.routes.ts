import express from "express";
import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { authenticate } from "../../middlewares/authenticate.middleware";
import {
    getAuthRateLimiter,
    getForgotPasswordRateLimiter,
    getOtpRateLimiter,
} from "../../middlewares/rate-limit.middleware";
import { validate } from "../../middlewares/validate";
import {
    forgotPassword,
    getCurrentUser,
    login,
    loginWithGoogle,
    logout,
    refresh,
    register,
    resetPassword,
    sendOtp,
    verifyEmail,

    verifyPhone,
} from "./auth.controller";
import {
    forgotPasswordBodySchema,
    googleLoginBodySchema,
    loginBodySchema,
    refreshTokenBodySchema,
    registerBodySchema,
    resetPasswordBodySchema,
    sendOtpBodySchema,
    verifyPhoneBodySchema,
    verifyEmailBodySchema,
} from "./auth.validator";

const router = express.Router();

const requireGoogleIdToken: RequestHandler = (req, _res, next) => {
    if (req.body?.idToken === undefined) {
        return next(
            new ApiError(400, "idToken is required", [
                {
                    path: "idToken",
                    msg: "idToken is required",
                },
            ]),
        );
    }

    return next();
};

const isMissingInput = (value: unknown) =>
    value === undefined || value === null || (typeof value === "string" && value.trim() === "");

const requireBodyFields =
    (fields: string[]): RequestHandler =>
        (req, _res, next) => {
            const errors = fields
                .filter((field) => isMissingInput(req.body?.[field]))
                .map((field) => ({
                    path: field,
                    msg: `${field} is required`,
                }));

            if (errors.length > 0) {
                return next(new ApiError(400, errors[0]?.msg ?? "Missing required input", errors));
            }

            return next();
        };

const normalizeLoginIdentifier: RequestHandler = (req, _res, next) => {
    if (req.body?.identifier === undefined && req.body?.emailOrUsername !== undefined) {
        req.body.identifier = req.body.emailOrUsername;
    }

    return next();
};

const normalizeRegisterPayload: RequestHandler = (req, _res, next) => {
    if (req.body?.phone === undefined && req.body?.phoneNumber !== undefined) {
        req.body.phone = req.body.phoneNumber;
    }

    const fullName = req.body?.fullName ?? req.body?.name;

    if ((req.body?.firstName === undefined || req.body?.lastName === undefined) && typeof fullName === "string") {
        const parts = fullName.trim().split(/\s+/).filter(Boolean);

        if (parts.length === 1) {
            req.body.firstName = req.body.firstName ?? parts[0];
            req.body.lastName = req.body.lastName ?? "User";
        } else if (parts.length > 1) {
            req.body.firstName = req.body.firstName ?? parts.slice(0, -1).join(" ");
            req.body.lastName = req.body.lastName ?? parts[parts.length - 1];
        }
    }

    return next();
};

const normalizeResetPasswordPayload: RequestHandler = (req, _res, next) => {
    if (req.body?.newPassword === undefined && req.body?.password !== undefined) {
        req.body.newPassword = req.body.password;
    }

    return next();
};

router.post(
    "/register",
    getAuthRateLimiter(),
    normalizeRegisterPayload,
    requireBodyFields(["email", "password", "firstName", "lastName"]),
    validate({ body: registerBodySchema }),
    register,
);

router.post(
    "/login",
    getAuthRateLimiter(),
    normalizeLoginIdentifier,
    requireBodyFields(["identifier", "password"]),
    validate({ body: loginBodySchema }),
    login,
);

router.post("/logout", getAuthRateLimiter(), validate({ body: refreshTokenBodySchema }), logout);
router.post("/refresh", getAuthRateLimiter(), validate({ body: refreshTokenBodySchema }), refresh);
router.post(
    "/send-otp",
    getOtpRateLimiter(),
    requireBodyFields(["identifier"]),
    validate({ body: sendOtpBodySchema }),
    sendOtp,
);
router.post(
    "/forgot-password",
    getForgotPasswordRateLimiter(),
    requireBodyFields(["identifier"]),
    validate({ body: forgotPasswordBodySchema }),
    forgotPassword,
);
router.post(
    "/reset-password",
    getForgotPasswordRateLimiter(),
    normalizeResetPasswordPayload,
    requireBodyFields(["identifier", "otp", "newPassword"]),
    validate({ body: resetPasswordBodySchema }),
    resetPassword,
);
router.post(
    "/verify-email",
    getOtpRateLimiter(),
    requireBodyFields(["identifier", "otp"]),
    validate({ body: verifyEmailBodySchema }),
    verifyEmail,
);
router.post(
    "/verify-phone",
    getOtpRateLimiter(),
    requireBodyFields(["identifier", "otp"]),
    validate({ body: verifyPhoneBodySchema }),
    verifyPhone,
);

router.post(
    "/google",
    getAuthRateLimiter(),
    requireGoogleIdToken,
    validate({ body: googleLoginBodySchema }),
    loginWithGoogle,
);

router.get("/me", authenticate, getCurrentUser);

export default router;
