import { createHash, randomInt } from "node:crypto";

import { getEnv } from "../../config/env";
import { AuthOtpPurpose } from "../../models/auth-otp-token";

export const generateOtp = () => String(randomInt(0, 1_000_000)).padStart(6, "0");

export const hashOtpToken = (identifier: string, purpose: AuthOtpPurpose, otp: string) =>
    createHash("sha256")
        .update(getEnv().otpHashSecret)
        .update(":")
        .update(identifier)
        .update(":")
        .update(purpose)
        .update(":")
        .update(otp)
        .digest("hex");
