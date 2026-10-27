
import { createHmac } from "node:crypto";
import jwt from "jsonwebtoken";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { UserRole, userRoleValues } from "../../models/user";

const jwtAlgorithm = "HS256" as const;

const isValidUserRole = (value: string): value is UserRole =>
    (userRoleValues as readonly string[]).includes(value);

export const hashRefreshToken = (token: string) =>
    createHmac("sha256", getEnv().tokenHashSecret)
        .update(token)
        .digest("hex");

export const signAuthToken = (userId: string, role: UserRole) =>
    jwt.sign(
        {
            role,
            type: "access",
        },
        getEnv().jwtAccessSecret,
        {
            algorithm: jwtAlgorithm,
            subject: userId,
            expiresIn: `${getEnv().accessTokenTtlMinutes}m`,
        },
    );

export const signRefreshToken = (userId: string, sessionId: string) =>
    jwt.sign(
        {
            type: "refresh",
        },
        getEnv().jwtRefreshSecret,
        {
            algorithm: jwtAlgorithm,
            subject: userId,
            jwtid: sessionId,
            expiresIn: `${getEnv().refreshTokenTtlDays}d`,
        },
    );

export const verifyAuthToken = (token: string) => {
    try {
        const decoded = jwt.verify(token, getEnv().jwtAccessSecret, {
            algorithms: [jwtAlgorithm],
        });

        if (!decoded || typeof decoded === "string") {
            throw new ApiError(401, "Unauthorized");
        }

        const subject = decoded.sub;
        const role = decoded.role;
        const type = decoded.type;

        if (typeof subject !== "string" || type !== "access" || !isValidUserRole(String(role))) {
            throw new ApiError(401, "Unauthorized");
        }

        return {
            userId: subject,
            role: role as UserRole,
        };
    } catch {
        throw new ApiError(401, "Unauthorized");
    }
};

export const verifyRefreshToken = (token: string) => {
    try {
        const decoded = jwt.verify(token, getEnv().jwtRefreshSecret, {
            algorithms: [jwtAlgorithm],
        });

        if (!decoded || typeof decoded === "string") {
            throw new ApiError(403, "Invalid or expired refresh token");
        }

        const subject = decoded.sub;
        const jwtId = decoded.jti;
        const type = decoded.type;

        if (typeof subject !== "string" || typeof jwtId !== "string" || type !== "refresh") {
            throw new ApiError(403, "Invalid or expired refresh token");
        }

        return {
            userId: subject,
            sessionId: jwtId,
        };
    } catch {
        throw new ApiError(403, "Invalid or expired refresh token");
    }
};
