import { createHash, randomUUID } from "node:crypto";

import { CookieOptions, Request } from "express";
import { Op, QueryTypes, type Transaction } from "sequelize";
import { logger } from "../../config/logger";
import { sendAuthOtpEmail } from "./auth-mail.service";
import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { getEnv } from "../../config/env";
import { notifyUserRegistered } from "../notifications/notification.service";
import AuthOtpToken, { AuthOtpPurpose } from "../../models/auth-otp-token";
import RefreshSession from "../../models/refresh-session";
import User, { UserDocument, UserRole, UserStatus, userRoleValues } from "../../models/user";
import {
    countRecentAuditLogsByIdentifierHash,
    createAuditLog,
} from "./auth.repository";
import { generateOtp as generateOtpValue, hashOtpToken as hashOtpTokenValue } from "./otp.service";
import {
    comparePassword as comparePasswordValue,
    hashPassword as hashPasswordValue,
    hashRandomPassword,
    passwordHashCost as passwordHashCostValue,
} from "./password.service";
import {
    hashRefreshToken as hashRefreshTokenValue,
    signAuthToken as signAuthTokenValue,
    signRefreshToken as signRefreshTokenValue,
    verifyAuthToken as verifyAuthTokenValue,
    verifyRefreshToken as verifyRefreshTokenValue,
} from "./token.service";

export const generateOtp = generateOtpValue;
export const hashOtpToken = hashOtpTokenValue;
export const comparePassword = comparePasswordValue;
export const hashPassword = hashPasswordValue;
export const passwordHashCost = passwordHashCostValue;
export const hashRefreshToken = hashRefreshTokenValue;
export const signAuthToken = signAuthTokenValue;
export const signRefreshToken = signRefreshTokenValue;
export const verifyAuthToken = verifyAuthTokenValue;
export const verifyRefreshToken = verifyRefreshTokenValue;

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const phonePattern = /^(0|\+84)[0-9]{9}$/;
const repeatedLoginFailureThreshold = 5;
const primaryRolePriority: UserRole[] = ["admin", "moderator", "host", "guest"];

export type AuthenticatedUser = {
    id: string;
    email: string;
    phone: string;
    name: string;
    username: string | null;
    status: UserStatus;
    roles: UserRole[];
};

export type AuthResponseUser = AuthenticatedUser & {
    userId: string;
    role: UserRole;
};

type RegisterUserInput = {
    name?: string;
    username?: string;
    email: string;
    phone?: string | null;
    password: string;
    firstName?: string;
    lastName?: string;
    dob?: string | Date | null;
};

type CreateSocialUserInput = {
    email: string;
    name: string;
    role?: UserRole;
    emailVerified?: boolean;
    avatarUrl?: string | null;
};

type RequestContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

export type IssueOtpInput = {
    identifier: string;
    purpose?: AuthOtpPurpose;
};

export type ResetPasswordInput = {
    identifier: string;
    otp: string;
    newPassword: string;
};

export type IssuedAuthSession = {
    accessToken: string;
    refreshToken: string;
    roles: UserRole[];
};

export const normalizeEmail = (value: string) => value.trim().toLowerCase();

export const normalizePhone = (value: string) => {
    const input = value.trim();

    if (input.startsWith("+84")) {
        return `0${input.slice(3)}`;
    }

    return input;
};

export const normalizeIdentifier = (value: string) => {
    const input = value.trim();

    if (emailPattern.test(input)) {
        return normalizeEmail(input);
    }

    if (phonePattern.test(input)) {
        return normalizePhone(input);
    }

    return input.toLowerCase();
};

export const isEmailIdentifier = (value: string) => emailPattern.test(value.trim());

export const isPhoneIdentifier = (value: string) => phonePattern.test(value.trim());

const splitName = (value: string) => {
    const parts = value.trim().split(/\s+/).filter(Boolean);

    if (parts.length === 0) {
        return {
            firstName: "Guest",
            lastName: "User",
        };
    }

    if (parts.length === 1) {
        return {
            firstName: parts[0],
            lastName: "User",
        };
    }

    return {
        firstName: parts.slice(0, -1).join(" "),
        lastName: parts[parts.length - 1],
    };
};

const normalizeFullName = (input: RegisterUserInput) => {
    const name = input.name?.trim() || `${input.firstName ?? ""} ${input.lastName ?? ""}`.trim();
    const fallback = splitName(name);
    const fullName = `${input.firstName?.trim() || fallback.firstName} ${input.lastName?.trim() || fallback.lastName
        }`.trim();

    return fullName || "Guest User";
};

const createBaseUsername = (name: string, email: string) => {
    const fromName = name
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ".")
        .replace(/(^\.|\.$)/g, "");

    return fromName || email.split("@")[0].replace(/[^a-z0-9]+/g, ".") || "guest";
};

const isValidUserRole = (value: string): value is UserRole =>
    (userRoleValues as readonly string[]).includes(value);

const selectPrimaryRole = (roles: UserRole[]) =>
    primaryRolePriority.find((role) => roles.includes(role)) ?? "guest";

export const parseCookieHeader = (value?: string) => {
    if (!value) {
        return {};
    }

    return value.split(";").reduce<Record<string, string>>((cookies, chunk) => {
        const [key, ...rest] = chunk.split("=");
        const normalizedKey = key?.trim();

        if (!normalizedKey) {
            return cookies;
        }

        const rawValue = rest.join("=").trim();

        try {
            cookies[normalizedKey] = decodeURIComponent(rawValue);
        } catch {
            cookies[normalizedKey] = rawValue;
        }

        return cookies;
    }, {});
};

export const extractAuthToken = (req: Request) => {
    const authorization = req.header("authorization");

    if (authorization?.startsWith("Bearer ")) {
        return authorization.slice("Bearer ".length).trim();
    }

    const parsedCookieToken =
        typeof req.signedCookies?.auth_token === "string"
            ? req.signedCookies.auth_token
            : typeof req.cookies?.auth_token === "string"
                ? req.cookies.auth_token
                : undefined;

    if (parsedCookieToken) {
        return parsedCookieToken;
    }

    const cookies = parseCookieHeader(req.header("cookie"));
    return cookies.auth_token;
};

export const extractRefreshToken = (req: Request) => {
    const cookieName = getEnv().refreshCookieName;
    const parsedCookieToken =
        typeof req.signedCookies?.[cookieName] === "string"
            ? req.signedCookies[cookieName]
            : typeof req.cookies?.[cookieName] === "string"
                ? req.cookies[cookieName]
                : undefined;

    if (parsedCookieToken) {
        return parsedCookieToken;
    }

    const cookies = parseCookieHeader(req.header("cookie"));
    const headerCookieToken = cookies[cookieName];

    if (headerCookieToken) {
        return headerCookieToken;
    }

    const bodyRefreshToken =
        typeof req.body?.refreshToken === "string" ? req.body.refreshToken.trim() : undefined;

    if (bodyRefreshToken && getEnv().allowRefreshTokenInBody) {
        return bodyRefreshToken;
    }

    const headerRefreshToken = req.header("x-refresh-token")?.trim();

    if (headerRefreshToken && getEnv().allowRefreshTokenInHeader) {
        return headerRefreshToken;
    }

    return undefined;
};

export const buildAuthCookieOptions = (): CookieOptions => ({
    httpOnly: true,
    secure: getEnv().refreshCookieSecure,
    sameSite: getEnv().refreshCookieSameSite,
    maxAge: getEnv().accessTokenTtlMinutes * 60 * 1000,
    path: "/",
});

export const buildRefreshCookieOptions = (): CookieOptions => ({
    httpOnly: true,
    secure: getEnv().refreshCookieSecure,
    sameSite: getEnv().refreshCookieSameSite,
    maxAge: getEnv().refreshTokenTtlMs,
    path: getEnv().refreshCookiePath,
    signed: Boolean(getEnv().cookieSecret),
});

const getRoleId = async (role: UserRole, transaction?: Transaction) => {
    await sequelize.query(
        `
        INSERT INTO roles (code, name, created_at, updated_at)
        VALUES (?, ?, NOW(), NOW())
        ON DUPLICATE KEY UPDATE updated_at = updated_at
        `,
        {
            replacements: [role, role.charAt(0).toUpperCase() + role.slice(1)],
            transaction,
        },
    );

    const rows = await sequelize.query<{ roleId: number }>(
        `
        SELECT role_id AS roleId
        FROM roles
        WHERE code = ?
        LIMIT 1
        `,
        {
            replacements: [role],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    const roleId = rows[0]?.roleId;

    if (!roleId) {
        throw new ApiError(500, "Unable to resolve user role");
    }

    return Number(roleId);
};

export const getUserRoles = async (userId: string | number, transaction?: Transaction): Promise<UserRole[]> => {
    const rows = await sequelize.query<{ code: string }>(
        `
        SELECT r.code
        FROM user_role ur
        INNER JOIN roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = ?
        ORDER BY FIELD(r.code, 'admin', 'moderator', 'host', 'guest')
        `,
        {
            replacements: [Number(userId)],
            type: QueryTypes.SELECT,
            transaction,
        },
    );
    const roles = rows.map((row) => row.code).filter(isValidUserRole);

    return roles.length > 0 ? roles : ["guest"];
};

export const ensureUserRole = async (
    userId: string | number,
    role: UserRole,
    transaction?: Transaction,
) => {
    const roleId = await getRoleId(role, transaction);

    await sequelize.query(
        `
        INSERT IGNORE INTO user_role (user_id, role_id, assigned_at)
        VALUES (?, ?, NOW())
        `,
        {
            replacements: [Number(userId), roleId],
            transaction,
        },
    );
};

export const toAuthenticatedUser = async (user: UserDocument): Promise<AuthenticatedUser> => {
    const roles = await getUserRoles(user._id);

    return {
        id: String(user._id),
        email: user.email,
        phone: user.phone ?? "",
        name: user.fullName,
        username: user.username ?? null,
        status: user.status,
        roles,
    };
};

export const toAuthResponseUser = async (
    user: UserDocument,
    roles?: UserRole[],
): Promise<AuthResponseUser> => {
    const resolvedRoles = roles ?? (await getUserRoles(user._id));

    return {
        id: String(user._id),
        userId: String(user._id),
        email: user.email,
        phone: user.phone ?? "",
        name: user.fullName,
        username: user.username ?? null,
        status: user.status,
        roles: resolvedRoles,
        role: selectPrimaryRole(resolvedRoles),
    };
};

export const findUserForLogin = async (identifier: string) => {
    const normalizedIdentifier = normalizeIdentifier(identifier);

    return User.findOne({
        $or: [
            { email: normalizeEmail(normalizedIdentifier) },
            { username: normalizedIdentifier.toLowerCase() },
            { phone: normalizePhone(normalizedIdentifier) },
        ],
    });
};

const createUniqueUsername = async (name: string, email: string, preferredUsername?: string) => {
    if (preferredUsername?.trim()) {
        const normalizedUsername = preferredUsername.trim().toLowerCase();

        if (await User.exists({ username: normalizedUsername })) {
            throw new ApiError(409, "Tài khoản đã tồn tại", [
                {
                    path: "username",
                    msg: "Tên người dùng đã được sử dụng",
                },
            ]);
        }

        return normalizedUsername;
    }

    const baseUsername = createBaseUsername(name, email);
    let candidate = baseUsername;
    let sequence = 1;

    while (await User.exists({ username: candidate })) {
        candidate = `${baseUsername}.${sequence}`;
        sequence += 1;
    }

    return candidate;
};

export const createSocialUser = async (input: CreateSocialUserInput) => {
    const email = normalizeEmail(input.email);
    const name = input.name.trim() || email.split("@")[0] || "Guest User";
    const username = await createUniqueUsername(name, email);
    const passwordHash = await hashRandomPassword();

    return sequelize.transaction(async (transaction) => {
        const user = await User.create(
            {
                email,
                username,
                passwordHash,
                fullName: name,
                phone: null,
                dateOfBirth: null,
                bio: null,
                avatarUrl: input.avatarUrl ?? null,
                isEmailVerified: Boolean(input.emailVerified),
                status: "active",
            },
            { transaction },
        );

        await ensureUserRole(user._id, input.role ?? "guest", transaction);
        await notifyUserRegistered(Number(user._id), transaction);
        return user;
    });
};

export const registerUser = async (input: RegisterUserInput) => {
    const email = normalizeEmail(input.email);
    const phone = input.phone?.trim() ? normalizePhone(input.phone) : null;
    const fullName = normalizeFullName(input);
    const username = await createUniqueUsername(fullName, email, input.username);
    const [existingEmail, existingPhone] = await Promise.all([
        User.findOne({ email }),
        phone ? User.findOne({ phone }) : Promise.resolve(null),
    ]);

    if (existingEmail || existingPhone) {
        throw new ApiError(409, "Tài khoản đã tồn tại. Email hoặc số điện thoại đã được sử dụng.", [
            {
                path: existingEmail ? "email" : "phone",
                msg: existingEmail ? "Email đã được sử dụng" : "Số điện thoại đã được sử dụng",
            },
        ]);
    }

    const passwordHash = await hashPassword(input.password);

    return sequelize.transaction(async (transaction) => {
        const user = await User.create(
            {
                email,
                username,
                passwordHash,
                fullName,
                phone,
                dateOfBirth: input.dob ? new Date(input.dob) : null,
                bio: null,
                status: "active",
            },
            { transaction },
        );

        await ensureUserRole(user._id, "guest", transaction);
        await notifyUserRegistered(Number(user._id), transaction);
        return user;
    });
};

const hashValue = (value: string) =>
    createHash("sha256").update(value).digest("hex");

export const assertUserCanAuthenticate = (user: UserDocument) => {
    switch (user.status) {
        case "active":
            return;
        case "inactive":
            throw new ApiError(403, "Account is inactive");
        case "blocked":
            throw new ApiError(423, "Account is blocked");
        case "locked":
            throw new ApiError(423, "Account is locked");
        case "suspended":
            throw new ApiError(403, "Account is suspended");
        case "deleted":
            throw new ApiError(403, "Account is deleted");
        default:
            throw new ApiError(403, "Account is unavailable");
    }
};

export const issueAuthSession = async (
    user: UserDocument,
    input: RequestContext = {},
    transaction?: Transaction,
): Promise<IssuedAuthSession> => {
    assertUserCanAuthenticate(user);

    const roles = await getUserRoles(user._id, transaction);
    const accessToken = signAuthToken(String(user._id), selectPrimaryRole(roles));
    const sessionId = randomUUID();
    const refreshToken = signRefreshToken(String(user._id), sessionId);
    const refreshExpiresAt = new Date(Date.now() + getEnv().refreshTokenTtlMs);

    await RefreshSession.create(
        {
            sessionId,
            userId: Number(user._id),
            tokenHash: hashRefreshToken(refreshToken),
            expiresAt: refreshExpiresAt,
            revokedAt: null,
            ipAddress: input.ipAddress ?? null,
            userAgent: input.userAgent ?? null,
        },
        { transaction },
    );

    return {
        accessToken,
        refreshToken,
        roles,
    };
};

export const refreshAuthSession = async (
    refreshToken: string,
    input: RequestContext = {},
): Promise<IssuedAuthSession & { user: AuthResponseUser }> => {
    const payload = verifyRefreshToken(refreshToken);
    const tokenHash = hashRefreshToken(refreshToken);

    return sequelize.transaction(async (transaction) => {
        const session = await RefreshSession.findOne({
            where: {
                sessionId: payload.sessionId,
                userId: Number(payload.userId),
                tokenHash,
                revokedAt: null,
                expiresAt: {
                    [Op.gte]: new Date(),
                },
            },
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!session) {
            const reusedOrRevokedSession = await RefreshSession.findOne({
                where: {
                    sessionId: payload.sessionId,
                    userId: Number(payload.userId),
                },
                transaction,
                lock: transaction.LOCK.UPDATE,
            });

            if (reusedOrRevokedSession?.revokedAt) {
                await RefreshSession.update(
                    {
                        revokedAt: new Date(),
                    },
                    {
                        where: {
                            userId: Number(payload.userId),
                            revokedAt: null,
                        },
                        transaction,
                    },
                );
            }

            throw new ApiError(403, "Invalid or expired refresh token");
        }

        const user = await User.findOne({
            where: {
                userId: Number(payload.userId),
            },
            transaction,
        });

        if (!user) {
            throw new ApiError(403, "Invalid or expired refresh token");
        }

        assertUserCanAuthenticate(user);

        session.revokedAt = new Date();
        await session.save({ transaction });

        const nextSession = await issueAuthSession(user, input, transaction);

        return {
            ...nextSession,
            user: await toAuthResponseUser(user, nextSession.roles),
        };
    });
};

export const revokeRefreshSessionByToken = async (token: string) => {
    await RefreshSession.update(
        {
            revokedAt: new Date(),
        },
        {
            where: {
                tokenHash: hashRefreshToken(token),
                revokedAt: null,
            },
        },
    );
};

const maskIdentifier = (identifier: string) => {
    if (isEmailIdentifier(identifier)) {
        const [localPart, domain] = identifier.split("@");
        const visible = localPart.slice(0, 2);
        return `${visible}${"*".repeat(Math.max(2, localPart.length - visible.length))}@${domain}`;
    }

    const normalizedPhone = normalizePhone(identifier);

    if (isPhoneIdentifier(normalizedPhone)) {
        return `******${normalizedPhone.slice(-4)}`;
    }

    return `${identifier.slice(0, 2)}****`;
};

const buildOtpResponse = (identifier: string, otp: string | null, expiresAt: Date) => ({
    maskedDestination: maskIdentifier(identifier),
    expiresAt,
    ...(otp && getEnv().authDebugOtp ? { debugOtp: otp } : {}),
});

export const issueAuthOtp = async (
    input: IssueOtpInput,
    context: RequestContext = {},
) => {
    const purpose = input.purpose ?? "sign_up";
    const normalizedIdentifier = normalizeIdentifier(input.identifier);
    const identifierHash = hashValue(normalizedIdentifier);
    const expiresAt = new Date(Date.now() + getEnv().otpTtlMinutes * 60 * 1000);
    const sentAfter = new Date(Date.now() - getEnv().otpRateLimitWindowMinutes * 60 * 1000);

    const [recentOtpCount, recentAuditCount] = await Promise.all([
        AuthOtpToken.countDocuments({
            identifier: normalizedIdentifier,
            purpose,
            sentAt: { $gte: sentAfter },
        }),
        countRecentAuditLogsByIdentifierHash("auth.otp.issue", identifierHash, sentAfter),
    ]);

    const effectiveRequestCount = Math.max(recentOtpCount, recentAuditCount);

    if (effectiveRequestCount >= getEnv().otpRateLimitMax) {
        throw new ApiError(429, "Too many OTP requests. Please try again later.");
    }

    const latestOtp = await AuthOtpToken.findOne({
        where: {
            identifier: normalizedIdentifier,
            purpose,
        },
        order: [["sentAt", "DESC"]],
    });

    if (
        latestOtp &&
        Date.now() - latestOtp.sentAt.getTime() < getEnv().otpResendCooldownSeconds * 1000
    ) {
        throw new ApiError(429, "Please wait before requesting another OTP.");
    }

    const user = await findUserForLogin(normalizedIdentifier);

    /**
     * Trường hợp quên mật khẩu:
     * - Nếu user tồn tại và tài khoản active thì gửi OTP.
     * - Nếu user không tồn tại thì vẫn trả response giả để tránh lộ email có tồn tại hay không.
     */
    if (purpose === "forgot_password" && user) {
        try {
            assertUserCanAuthenticate(user);
        } catch {
            return buildOtpResponse(normalizedIdentifier, null, expiresAt);
        }
    }

    if (purpose === "forgot_password" && !user) {
        await createAuditLog({
            action: "auth.otp.issue",
            targetType: "auth_otp",
            metadata: {
                purpose,
                identifierHash,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
        });

        return buildOtpResponse(normalizedIdentifier, null, expiresAt);
    }

    /**
     * Trường hợp đăng ký:
     * - Nếu email đã tồn tại thì không gửi OTP thật.
     * - Vẫn trả response chung để tránh lộ tài khoản.
     */
    if (purpose === "sign_up" && user) {
        await createAuditLog({
            actorId: Number(user._id),
            action: "auth.otp.issue",
            targetType: "auth_otp",
            metadata: {
                purpose,
                identifierHash,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
        });

        return buildOtpResponse(normalizedIdentifier, null, expiresAt);
    }

    /**
     * Tạo OTP thật.
     */
    const otp = generateOtp();

    await AuthOtpToken.create({
        userId: user ? Number(user._id) : null,
        identifier: normalizedIdentifier,
        purpose,
        tokenHash: hashOtpToken(normalizedIdentifier, purpose, otp),
        expiresAt,
        consumedAt: null,
        usedAt: null,
        attemptCount: 0,
        sentAt: new Date(),
        ipAddress: context.ipAddress ?? null,
        userAgent: context.userAgent ?? null,
    });

    await createAuditLog({
        actorId: user ? Number(user._id) : null,
        action: "auth.otp.issue",
        targetType: "auth_otp",
        metadata: {
            purpose,
            identifierHash,
        },
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
    });

    /**
     * Gửi OTP qua email.
     * Hiện tại project chỉ có mail service, chưa có SMS service.
     */
    if (isEmailIdentifier(normalizedIdentifier)) {
        try {
            await sendAuthOtpEmail({
                to: normalizedIdentifier,
                otp,
                purpose,
                expiresAt,
            });
        } catch (error) {
            logger.error("Failed to send OTP email", error, {
                purpose,
                identifierHash,
            });

            throw new ApiError(503, "Could not send OTP email. Please try again later.");
        }
    } else if (isPhoneIdentifier(normalizedIdentifier)) {
        logger.warn("OTP was generated but SMS sender is not configured", {
            purpose,
            identifierHash,
        });
    }

    return buildOtpResponse(normalizedIdentifier, otp, expiresAt);
};

export const resetPasswordWithOtp = async (
    input: ResetPasswordInput,
    context: RequestContext = {},
) => {
    const normalizedIdentifier = normalizeIdentifier(input.identifier);
    const normalizedOtp = input.otp.trim();
    const user = await findUserForLogin(normalizedIdentifier);

    if (!user) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    assertUserCanAuthenticate(user);

    const tokenHash = hashOtpToken(normalizedIdentifier, "forgot_password", normalizedOtp);
    const otpToken = await AuthOtpToken.findOne({
        where: {
            userId: Number(user._id),
            identifier: normalizedIdentifier,
            purpose: "forgot_password",
        },
        order: [["sentAt", "DESC"]],
    });

    if (!otpToken) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    if (otpToken.consumedAt || otpToken.usedAt) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    if (otpToken.expiresAt.getTime() < Date.now()) {
        throw new ApiError(410, "Reset token expired");
    }

    if (otpToken.attemptCount >= getEnv().otpMaxAttempts) {
        throw new ApiError(429, "Too many OTP attempts. Please request a new code.");
    }

    otpToken.attemptCount += 1;

    if (otpToken.tokenHash !== tokenHash) {
        await otpToken.save();
        throw new ApiError(400, "Invalid OTP");
    }

    const passwordHash = await hashPassword(input.newPassword);

    await sequelize.transaction(async (transaction) => {
        user.passwordHash = passwordHash;
        await user.save({ transaction });

        const usedAt = new Date();
        otpToken.usedAt = usedAt;
        otpToken.consumedAt = usedAt;
        await otpToken.save({ transaction });

        await RefreshSession.update(
            {
                revokedAt: new Date(),
            },
            {
                where: {
                    userId: Number(user._id),
                    revokedAt: null,
                },
                transaction,
            },
        );

        await createAuditLog({
            actorId: Number(user._id),
            action: "auth.password.reset",
            targetType: "user",
            targetId: Number(user._id),
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
    });

    return {
        userId: String(user._id),
    };
};

export const verifyPhoneWithOtp = async (
    input: { identifier: string; otp: string },
    context: RequestContext = {},
) => {
    const normalizedIdentifier = normalizeIdentifier(input.identifier);
    const normalizedOtp = input.otp.trim();
    const user = await findUserForLogin(normalizedIdentifier);

    if (!user) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    assertUserCanAuthenticate(user);

    const tokenHash = hashOtpToken(normalizedIdentifier, "verify_phone", normalizedOtp);
    const otpToken = await AuthOtpToken.findOne({
        where: {
            userId: Number(user._id),
            identifier: normalizedIdentifier,
            purpose: "verify_phone",
        },
        order: [["sentAt", "DESC"]],
    });

    if (!otpToken) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    if (otpToken.consumedAt || otpToken.usedAt) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    if (otpToken.expiresAt.getTime() < Date.now()) {
        throw new ApiError(410, "Verification code expired");
    }

    if (otpToken.attemptCount >= getEnv().otpMaxAttempts) {
        throw new ApiError(429, "Too many verification attempts. Please request a new code.");
    }

    otpToken.attemptCount += 1;

    if (otpToken.tokenHash !== tokenHash) {
        await otpToken.save();
        throw new ApiError(400, "Invalid verification code");
    }

    await sequelize.transaction(async (transaction) => {
        user.isPhoneVerified = true;
        await user.save({ transaction });

        const usedAt = new Date();
        otpToken.usedAt = usedAt;
        otpToken.consumedAt = usedAt;
        await otpToken.save({ transaction });

        await createAuditLog({
            actorId: Number(user._id),
            action: "auth.phone.verified",
            targetType: "user",
            targetId: Number(user._id),
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
    });

    return {
        userId: String(user._id),
        phone: user.phone,
        isPhoneVerified: true,
    };
};
export const verifyEmailWithOtp = async (
    input: { identifier: string; otp: string },
    context: RequestContext = {},
) => {
    const normalizedIdentifier = normalizeIdentifier(input.identifier);
    const normalizedOtp = input.otp.trim();

    if (!isEmailIdentifier(normalizedIdentifier)) {
        throw new ApiError(400, "identifier must be an email address");
    }

    const user = await findUserForLogin(normalizedIdentifier);

    if (!user) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    assertUserCanAuthenticate(user);

    const tokenHash = hashOtpToken(normalizedIdentifier, "verify_email", normalizedOtp);

    const otpToken = await AuthOtpToken.findOne({
        where: {
            userId: Number(user._id),
            identifier: normalizedIdentifier,
            purpose: "verify_email",
        },
        order: [["sentAt", "DESC"]],
    });

    if (!otpToken) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    if (otpToken.consumedAt || otpToken.usedAt) {
        throw new ApiError(400, "Invalid or expired OTP");
    }

    if (otpToken.expiresAt.getTime() < Date.now()) {
        throw new ApiError(410, "Verification code expired");
    }

    if (otpToken.attemptCount >= getEnv().otpMaxAttempts) {
        throw new ApiError(429, "Too many verification attempts. Please request a new code.");
    }

    otpToken.attemptCount += 1;

    if (otpToken.tokenHash !== tokenHash) {
        await otpToken.save();
        throw new ApiError(400, "Invalid verification code");
    }

    await sequelize.transaction(async (transaction) => {
        user.isEmailVerified = true;
        await user.save({ transaction });

        const usedAt = new Date();
        otpToken.usedAt = usedAt;
        otpToken.consumedAt = usedAt;
        await otpToken.save({ transaction });

        await createAuditLog({
            actorId: Number(user._id),
            action: "auth.email.verified",
            targetType: "user",
            targetId: Number(user._id),
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
    });

    return {
        userId: String(user._id),
        email: user.email,
        isEmailVerified: true,
    };
};
const getLoginFailureWindowStart = () =>
    new Date(Date.now() - getEnv().authRateLimitWindowMinutes * 60 * 1000);

export const countRecentFailedLoginAttempts = async (identifier: string) =>
    countRecentAuditLogsByIdentifierHash(
        "auth.login.failed",
        hashValue(normalizeIdentifier(identifier)),
        getLoginFailureWindowStart(),
    );

export const isLoginTemporarilyLocked = async (identifier: string) =>
    (await countRecentFailedLoginAttempts(identifier)) >= repeatedLoginFailureThreshold;

export const recordFailedLoginAttempt = async (
    identifier: string,
    context: RequestContext = {},
    user?: UserDocument | null,
) => {
    const identifierHash = hashValue(normalizeIdentifier(identifier));

    await createAuditLog({
        actorId: user ? Number(user._id) : null,
        action: "auth.login.failed",
        targetType: "user",
        targetId: user ? Number(user._id) : null,
        metadata: {
            identifierHash,
        },
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
    });

    const failedCount = await countRecentAuditLogsByIdentifierHash(
        "auth.login.failed",
        identifierHash,
        getLoginFailureWindowStart(),
    );

    if (failedCount >= repeatedLoginFailureThreshold) {
        await createAuditLog({
            actorId: user ? Number(user._id) : null,
            action: "auth.login.failed_many",
            targetType: "user",
            targetId: user ? Number(user._id) : null,
            metadata: {
                identifierHash,
                failedCount,
                windowMinutes: getEnv().authRateLimitWindowMinutes,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
        });
    }

    return failedCount;
};
