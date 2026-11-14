import { createHash, randomUUID, timingSafeEqual } from "node:crypto";

import { CookieOptions, Request } from "express";
import { Op, QueryTypes, type Transaction } from "sequelize";
import { logger } from "../../config/logger";
import { sendAuthOtpEmail } from "./auth-mail.service";
import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { getEnv } from "../../config/env";
import { deactivateAllUserDeviceTokens } from "../../services/fcm-push.service";
import { disconnectUserSockets } from "../../socket/socket";
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
const primaryRolePriority: UserRole[] = ["admin", "host", "guest"];

export type AuthenticatedUser = {
    id: string;
    email: string;
    phone: string;
    name: string;
    username: string | null;
    avatarUrl?: string | null;
    status: UserStatus;
    roles: UserRole[];
};

export type AuthResponseUser = AuthenticatedUser & {
    userId: string;
    avatarUrl: string | null;
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

/**
 * Chuẩn hóa địa chỉ email về dạng chuẩn tắc chữ thường và cắt bỏ khoảng trắng hai đầu.
 */
export const normalizeEmail = (value: string) => value.trim().toLowerCase();

/**
 * Giải thuật chuẩn hóa số điện thoại Việt Nam:
 * - Quy đổi đầu số quốc tế `+84` về tiền tố nội địa `0` nhằm đồng nhất khóa định danh trong cơ sở dữ liệu.
 */
export const normalizePhone = (value: string) => {
    const input = value.trim();

    if (input.startsWith("+84")) {
        return `0${input.slice(3)}`;
    }

    return input;
};

/**
 * Giải thuật chuẩn hóa định danh đăng nhập đa hình (email, số điện thoại hoặc username):
 * - Phân nhánh theo biểu thức chính quy để đưa về dạng chuẩn tắc duy nhất trước khi truy vấn hoặc băm kiểm toán.
 */
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

/**
 * Kiểm tra chuỗi định danh có khớp định dạng email hợp lệ hay không.
 */
export const isEmailIdentifier = (value: string) => emailPattern.test(value.trim());

/**
 * Kiểm tra chuỗi định danh có khớp định dạng số điện thoại di động Việt Nam (`0...` hoặc `+84...`) hay không.
 */
export const isPhoneIdentifier = (value: string) => phonePattern.test(value.trim());

/**
 * Giải thuật tách chuỗi họ tên đầy đủ thành `firstName` và `lastName`,
 * cung cấp giá trị dự phòng an toàn khi chuỗi đầu vào rỗng hoặc chỉ có một từ.
 */
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

/**
 * Giải thuật tổng hợp và chuẩn hóa họ tên hiển thị từ dữ liệu đăng ký không đồng nhất
 * (`name` hoặc cặp `firstName` / `lastName`).
 */
const normalizeFullName = (input: RegisterUserInput) => {
    const name = input.name?.trim() || `${input.firstName ?? ""} ${input.lastName ?? ""}`.trim();
    const fallback = splitName(name);
    const fullName = `${input.firstName?.trim() || fallback.firstName} ${input.lastName?.trim() || fallback.lastName
        }`.trim();

    return fullName || "Guest User";
};

/**
 * Giải thuật sinh chuỗi `username` cơ sở chuẩn hóa:
 * - Chuyển chữ thường, thay thế chuỗi ký tự ngoài `[a-z0-9]` bằng dấu chấm `.` và cắt dấu chấm thừa ở hai đầu,
 *   lùi về phần local-part của email hoặc `"guest"` nếu tên không chứa ký tự ASCII hợp lệ.
 */
const createBaseUsername = (name: string, email: string) => {
    const fromName = name
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ".")
        .replace(/(^\.|\.$)/g, "");

    return fromName || email.split("@")[0].replace(/[^a-z0-9]+/g, ".") || "guest";
};

/**
 * Kiểm tra chuỗi vai trò có thuộc tập hợp vai trò hệ thống hợp lệ (`userRoleValues`) hay không.
 */
const isValidUserRole = (value: string): value is UserRole =>
    (userRoleValues as readonly string[]).includes(value);

/**
 * Giải thuật chọn vai trò chính đại diện từ danh sách vai trò của người dùng
 * theo thứ tự ưu tiên đặc quyền giảm dần (`admin` > `host` > `guest`).
 */
const selectPrimaryRole = (roles: UserRole[]) =>
    primaryRolePriority.find((role) => roles.includes(role)) ?? "guest";

/**
 * Giải thuật phân tích cú pháp chuỗi header `Cookie` HTTP thô:
 * - Tách cặp `key=value` theo dấu `;`, bảo toàn dấu `=` bên trong giá trị và giải mã `decodeURIComponent`
 *   có bắt ngoại lệ an toàn đối với chuỗi phần trăm dị dạng.
 */
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

/**
 * Giải thuật trích xuất JWT Access Token từ request HTTP theo thứ tự ưu tiên:
 * 1. Header chuẩn `Authorization: Bearer <token>`.
 * 2. Cookie `auth_token` đã xác thực chữ ký (`signedCookies`) hoặc cookie đã parse (`cookies`).
 * 3. Phân tích trực tiếp từ header `Cookie` thô.
 */
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

/**
 * Giải thuật trích xuất JWT Refresh Token an toàn theo chính sách cấu hình môi trường:
 * - Ưu tiên đọc từ HttpOnly Cookie (`signedCookies` -> `cookies` -> header `Cookie` thô).
 * - Chỉ cho phép đọc dự phòng từ `req.body.refreshToken` hoặc header `x-refresh-token`
 *   khi cờ môi trường tương ứng (`allowRefreshTokenInBody` / `allowRefreshTokenInHeader`) được bật tường minh.
 */
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

/**
 * Khởi tạo tùy chọn bảo mật HttpOnly Cookie cho Access Token (`httpOnly`, `secure`, `sameSite`),
 * ngăn mã JavaScript phía trình duyệt đọc token khi xảy ra XSS.
 */
export const buildAuthCookieOptions = (): CookieOptions => ({
    httpOnly: true,
    secure: getEnv().refreshCookieSecure,
    sameSite: getEnv().refreshCookieSameSite,
    maxAge: getEnv().accessTokenTtlMinutes * 60 * 1000,
    path: "/",
});

/**
 * Khởi tạo tùy chọn bảo mật HttpOnly Cookie cho Refresh Token:
 * - Giới hạn phạm vi đường dẫn (`refreshCookiePath`), bật `httpOnly`, `secure`, `sameSite`
 *   và kích hoạt ký HMAC cookie (`signed`) khi có `cookieSecret`.
 */
export const buildRefreshCookieOptions = (): CookieOptions => ({
    httpOnly: true,
    secure: getEnv().refreshCookieSecure,
    sameSite: getEnv().refreshCookieSameSite,
    maxAge: getEnv().refreshTokenTtlMs,
    path: getEnv().refreshCookiePath,
    signed: Boolean(getEnv().cookieSecret),
});

/**
 * Giải thuật phân giải và khởi tạo bất biến (Idempotent Upsert) mã định danh vai trò `role_id`:
 * - Thực thi `INSERT ... ON DUPLICATE KEY UPDATE` để đảm bảo dòng vai trò luôn tồn tại an toàn dưới truy cập đồng thời,
 *   sau đó truy vấn khóa chính `role_id` trong cùng ngữ cảnh giao dịch (`transaction`).
 */
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

/**
 * Giải thuật truy vấn và đồng bộ danh sách vai trò của người dùng từ bảng liên kết `user_role` - `roles`:
 * - Sắp xếp kết quả trực tiếp bằng `ORDER BY FIELD(r.code, 'admin', 'host', 'guest')`,
 *   lọc qua type guard hợp lệ và luôn trả về mặc định `["guest"]` nếu tài khoản chưa có bản ghi gán quyền.
 */
export const getUserRoles = async (userId: string | number, transaction?: Transaction): Promise<UserRole[]> => {
    const rows = await sequelize.query<{ code: string }>(
        `
        SELECT r.code
        FROM user_role ur
        INNER JOIN roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = ?
        ORDER BY FIELD(r.code, 'admin', 'host', 'guest')
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

/**
 * Giải thuật gán vai trò bất biến (Idempotent Role Assignment) cho người dùng:
 * - Phân giải `role_id` và chèn vào bảng `user_role` bằng `INSERT IGNORE` trong giao dịch DB,
 *   đảm bảo gọi lặp lại nhiều lần không gây lỗi trùng khóa chính/khóa duy nhất.
 */
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

/**
 * Ánh xạ thực thể `UserDocument` sang đối tượng người dùng đã xác thực (`AuthenticatedUser`)
 * kèm danh sách vai trò thực tế đồng bộ từ bảng phân quyền.
 */
export const toAuthenticatedUser = async (user: UserDocument): Promise<AuthenticatedUser> => {
    const roles = await getUserRoles(user._id);

    return {
        id: String(user._id),
        email: user.email,
        phone: user.phone ?? "",
        name: user.fullName,
        username: user.username ?? null,
        avatarUrl: user.avatarUrl ?? null,
        status: user.status,
        roles,
    };
};

/**
 * Ánh xạ thực thể `UserDocument` sang cấu trúc dữ liệu phản hồi xác thực (`AuthResponseUser`),
 * tái sử dụng danh sách vai trò truyền vào (nếu có) và suy diễn vai trò chính qua `selectPrimaryRole`.
 */
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
        avatarUrl: user.avatarUrl ?? null,
        status: user.status,
        roles: resolvedRoles,
        role: selectPrimaryRole(resolvedRoles),
    };
};

/**
 * Giải thuật tra cứu người dùng đăng nhập đa định danh:
 * - Chuẩn hóa đầu vào và truy vấn điều kiện hợp (`$or`) trên cả 3 khóa định danh (`email`, `username`, `phone`).
 */
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

/**
 * Giải thuật cấp phát `username` duy nhất không trùng lặp:
 * - Nếu người dùng tự chọn `preferredUsername`, kiểm tra tồn tại trực tiếp và ném lỗi `409` nếu đã bị chiếm.
 * - Nếu sinh tự động, khởi tạo từ `createBaseUsername` rồi tăng tuần tự hậu tố số (`base.1`, `base.2`, ...)
 *   cho tới khi tìm được giá trị chưa tồn tại trong bảng `users`.
 */
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

/**
 * Giải thuật khởi tạo nguyên tử tài khoản người dùng mạng xã hội (Social OAuth User):
 * - Sinh `username` duy nhất và mật khẩu ngẫu nhiên băm `bcrypt` không thể đoán trước (`hashRandomPassword`).
 * - Thực thi trong một giao dịch DB (`sequelize.transaction`) để đảm bảo tính nguyên tử giữa tạo bản ghi `User`,
 *   đồng bộ vai trò mặc định (`ensureUserRole`) và tạo thông báo chào mừng.
 */
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

/**
 * Giải thuật đăng ký tài khoản cục bộ mới an toàn:
 * - Chuẩn hóa email/số điện thoại, kiểm tra trùng lặp song song (`Promise.all`) để phản hồi sớm lỗi xung đột `409`.
 * - Băm mật khẩu bằng `bcrypt` (cost 12) và thực thi giao dịch nguyên tử khởi tạo `User`, gán vai trò `"guest"`
 *   và ghi thông báo hệ thống.
 */
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

/**
 * Giải thuật băm ẩn danh định danh bằng `SHA-256`:
 * - Chuyển chuỗi định danh nhạy cảm (email/số điện thoại) thành mã băm cố định 64 ký tự hex để lưu trữ
 *   và truy vấn tần suất trong `audit_logs` mà không làm lộ dữ liệu cá nhân thuần (PII).
 */
const hashValue = (value: string) =>
    createHash("sha256").update(value).digest("hex");

/**
 * Giải thuật kiểm tra chốt chặn trạng thái tài khoản trước khi xác thực hoặc làm mới phiên:
 * - Chỉ cho phép tài khoản ở trạng thái `"active"` tiếp tục; phân loại chính xác mã lỗi HTTP (`403` hoặc `423 Locked`)
 *   cho các trạng thái bị vô hiệu hóa, khóa, đình chỉ hoặc đã xóa.
 */
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

/**
 * Giải thuật phát hành phiên xác thực mới (Access Token + Refresh Session):
 * - Kiểm tra trạng thái hoạt động của tài khoản và đồng bộ danh sách vai trò hiện hành.
 * - Ký Access Token theo vai trò ưu tiên cao nhất, sinh mã phiên ngẫu nhiên `sessionId` (`UUIDv4`)
 *   và ký Refresh Token tương ứng.
 * - Chỉ lưu bản băm `HMAC-SHA256` (`hashRefreshToken`) cùng siêu dữ liệu thiết bị/IP vào bảng `refresh_sessions`.
 */
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

/**
 * Giải thuật xoay vòng phiên làm mới một lần (Single-Use Refresh Token Rotation) và phát hiện đánh cắp phiên:
 * 1. Xác thực chữ ký mật mã của `refreshToken` (khóa riêng `jwtRefreshSecret`) và tính bản băm `HMAC-SHA256`.
 * 2. Mở giao dịch DB kèm khóa bi quan mức dòng (`SELECT ... FOR UPDATE` / `transaction.LOCK.UPDATE`)
 *    trên bản ghi `RefreshSession` để tuần tự hóa các yêu cầu làm mới đồng thời (chống Race Condition).
 * 3. Phát hiện tái sử dụng token cũ (Token Reuse Detection / Replay Defense): nếu không còn phiên hợp lệ
 *    nhưng tìm thấy phiên cùng `sessionId` đã có `revokedAt != null`, hệ thống xác định Refresh Token cũ bị
 *    phát lại (nghi vấn lộ lọt/đánh cắp token) và lập tức thu hồi toàn bộ các phiên đang hoạt động của `userId` đó.
 * 4. Thu hồi phiên hiện tại (`revokedAt = new Date()`) và cấp mới nguyên tử cặp Access/Refresh Token kế tiếp.
 */
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

/**
 * Giải thuật thu hồi phiên đăng nhập bất biến (Idempotent Session Revocation):
 * - Tính bản băm `HMAC-SHA256` của Refresh Token và cập nhật `revokedAt` cho các bản ghi chưa thu hồi,
 *   đảm bảo gọi đăng xuất lặp lại nhiều lần vẫn an toàn và nhất quán.
 */
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

/**
 * Giải thuật che giấu một phần định danh nhận OTP (Data Masking):
 * - Ẩn ký tự giữa của email hoặc 6 chữ số đầu của số điện thoại để phản hồi giao diện mà không lộ toàn bộ PII.
 */
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

/**
 * Đóng gói dữ liệu phản hồi cấp phát OTP chuẩn hóa, chỉ đính kèm `debugOtp` khi cờ môi trường thử nghiệm cho phép.
 */
const buildOtpResponse = (identifier: string, otp: string | null, expiresAt: Date) => ({
    maskedDestination: maskIdentifier(identifier),
    expiresAt,
    ...(otp && getEnv().authDebugOtp ? { debugOtp: otp } : {}),
});

/**
 * Giải thuật cấp phát mã OTP xác thực chống lạm dụng tần suất và chống dò tìm tài khoản (Anti-Enumeration):
 * 1. Giới hạn tần suất kép: lấy giá trị cực đại giữa số bản ghi `AuthOtpToken` và số bản ghi `audit_logs`
 *    (tra theo `identifierHash`) trong cửa sổ trượt `otpRateLimitWindowMinutes`, kết hợp kiểm tra thời gian
 *    chờ gửi lại tối thiểu (`otpResendCooldownSeconds`) để chặn spam SMS/Email.
 * 2. Chống lộ trạng thái tồn tại tài khoản: với các nhánh không đủ điều kiện nghiệp vụ (`forgot_password`
 *    cho tài khoản không tồn tại/bị khóa, `sign_up` cho email đã đăng ký, `verify_*` khi thiếu tài khoản),
 *    vẫn ghi nhật ký kiểm toán và trả về cấu trúc phản hồi giả lập đồng nhất mà không sinh/gửi OTP thật.
 * 3. Sinh mã OTP ngẫu nhiên mật mã học (`generateOtp`), chỉ lưu bản băm một chiều gắn ngữ cảnh (`hashOtpToken`)
 *    vào DB và chuyển phát qua dịch vụ thư điện tử.
 */
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

    if ((purpose === "verify_email" || purpose === "verify_phone") && !user) {
        await createAuditLog({
            actorId: null,
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

/**
 * Giải thuật so sánh hai chuỗi băm theo thời gian hằng định (Constant-Time Hash Comparison):
 * - Chuyển hai chuỗi sang `Buffer` UTF-8, kiểm tra độ dài byte bằng nhau trước rồi đối chiếu qua
 *   nguyên hàm `crypto.timingSafeEqual`, triệt tiêu rò rỉ thông tin từng ký tự qua kênh kề thời gian.
 */
const isConstantTimeEqualHash = (storedHash: string, candidateHash: string) => {
    const storedBuf = Buffer.from(String(storedHash), "utf8");
    const candidateBuf = Buffer.from(String(candidateHash), "utf8");
    if (storedBuf.length !== candidateBuf.length) {
        return false;
    }
    return timingSafeEqual(storedBuf, candidateBuf);
};

/**
 * Giải thuật xác thực OTP đặt lại mật khẩu một lần và thu hồi toàn bộ phiên hiện hữu:
 * 1. Truy xuất mã OTP `forgot_password` mới nhất của người dùng; kiểm tra tính bất biến tiêu thụ một lần
 *    (`consumedAt` / `usedAt`), hạn hiệu lực (`expiresAt`) và ngưỡng thử sai tối đa (`otpMaxAttempts`) chống vét cạn.
 * 2. Tăng `attemptCount` và đối chiếu bản băm OTP bằng `isConstantTimeEqualHash` (`timingSafeEqual`);
 *    nếu sai, lưu ngay lượt thử thất bại xuống DB trước khi từ chối.
 * 3. Thực thi giao dịch nguyên tử: cập nhật `passwordHash` (`bcrypt`), đánh dấu tiêu thụ OTP, thu hồi toàn bộ
 *    `RefreshSession` đang hoạt động và ghi `audit_logs`; sau khi commit, hủy toàn bộ FCM device tokens
 *    và ngắt các kết nối WebSocket đang mở của tài khoản.
 */
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

    if (!isConstantTimeEqualHash(otpToken.tokenHash, tokenHash)) {
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

    await deactivateAllUserDeviceTokens(Number(user._id));
    disconnectUserSockets(user._id);

    return {
        userId: String(user._id),
    };
};

/**
 * Giải thuật xác thực mã OTP một lần cho số điện thoại (`verify_phone`):
 * - Kiểm tra trạng thái chưa sử dụng, thời hạn sống và giới hạn số lần nhập sai (`otpMaxAttempts`).
 * - Đối chiếu bản băm OTP bằng `timingSafeEqual`; khi hợp lệ, cập nhật nguyên tử cờ `isPhoneVerified = true`,
 *   đánh dấu tiêu thụ OTP và ghi nhật ký kiểm toán trong cùng một giao dịch DB.
 */
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

    if (!isConstantTimeEqualHash(otpToken.tokenHash, tokenHash)) {
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

/**
 * Giải thuật xác thực mã OTP một lần cho địa chỉ email (`verify_email`):
 * - Ràng buộc định dạng email hợp lệ, kiểm tra trạng thái chưa tiêu thụ, hạn hiệu lực và trần thử sai (`otpMaxAttempts`).
 * - So sánh thời gian hằng định bản băm OTP qua `timingSafeEqual`; khi khớp, cập nhật nguyên tử
 *   `isEmailVerified = true`, đánh dấu tiêu thụ OTP một lần và lưu nhật ký kiểm toán.
 */
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

    if (!isConstantTimeEqualHash(otpToken.tokenHash, tokenHash)) {
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

/**
 * Tính mốc thời gian bắt đầu của cửa sổ trượt kiểm soát tần suất đăng nhập sai (`authRateLimitWindowMinutes`).
 */
const getLoginFailureWindowStart = () =>
    new Date(Date.now() - getEnv().authRateLimitWindowMinutes * 60 * 1000);

/**
 * Giải thuật đếm số lần đăng nhập thất bại gần đây trên cửa sổ trượt:
 * - Chuẩn hóa và băm SHA-256 định danh (`identifierHash`) để đếm các sự kiện `"auth.login.failed"`
 *   trong bảng `audit_logs` kể từ mốc `getLoginFailureWindowStart()`, hoạt động đồng nhất cho cả tài khoản
 *   tồn tại lẫn không tồn tại.
 */
export const countRecentFailedLoginAttempts = async (identifier: string) =>
    countRecentAuditLogsByIdentifierHash(
        "auth.login.failed",
        hashValue(normalizeIdentifier(identifier)),
        getLoginFailureWindowStart(),
    );

/**
 * Giải thuật kiểm tra khóa đăng nhập tạm thời chống tấn công vét cạn mật khẩu (Brute-Force Lockout):
 * - Khóa tạm thời định danh khi tổng số lần thử mật khẩu sai trong cửa sổ trượt chạm hoặc vượt ngưỡng
 *   `repeatedLoginFailureThreshold` (5 lần).
 */
export const isLoginTemporarilyLocked = async (identifier: string) =>
    (await countRecentFailedLoginAttempts(identifier)) >= repeatedLoginFailureThreshold;

/**
 * Giải thuật ghi nhận sự kiện đăng nhập thất bại và kích hoạt cảnh báo ngưỡng Brute-Force:
 * - Ghi nhật ký kiểm toán `"auth.login.failed"` gắn với `identifierHash` ẩn danh cùng IP/User-Agent.
 * - Truy vấn lại tổng số lần thất bại trong cửa sổ trượt hiện hành; nếu chạm ngưỡng `repeatedLoginFailureThreshold`,
 *   phát sinh thêm bản ghi cảnh báo mức cao `"auth.login.failed_many"` phục vụ giám sát an ninh và khóa tạm thời.
 */
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
