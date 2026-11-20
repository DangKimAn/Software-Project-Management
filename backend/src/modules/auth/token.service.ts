
import { createHmac } from "node:crypto";
import jwt from "jsonwebtoken";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { UserRole, userRoleValues } from "../../models/user";

const jwtAlgorithm = "HS256" as const;

/**
 * Giải thuật kiểm tra tính hợp lệ của vai trò người dùng (Type Guard):
 * - Đối chiếu chuỗi vai trò giải mã từ JWT payload với tập hằng số `userRoleValues` được phép,
 *   ngăn chặn leo thang đặc quyền từ dữ liệu claims không hợp lệ.
 */
const isValidUserRole = (value: string): value is UserRole =>
    (userRoleValues as readonly string[]).includes(value);

/**
 * Giải thuật băm một chiều Refresh Token bằng `HMAC-SHA256`:
 * - Sử dụng khóa bí mật máy chủ tách biệt (`tokenHashSecret`) để tính mã xác thực thông điệp HMAC
 *   trước khi lưu trữ vào bảng `refresh_sessions`.
 * - Đảm bảo ngay cả khi cơ sở dữ liệu bị rò rỉ, kẻ tấn công không thể khôi phục chuỗi JWT
 *   Refresh Token gốc để mạo danh phiên đăng nhập.
 */
export const hashRefreshToken = (token: string) =>
    createHmac("sha256", getEnv().tokenHashSecret)
        .update(token)
        .digest("hex");

/**
 * Giải thuật ký phát hành JWT Access Token ngắn hạn:
 * - Ký số bằng thuật toán đối xứng `HS256` với khóa bí mật chuyên biệt `jwtAccessSecret`
 *   (tách biệt hoàn toàn với `jwtRefreshSecret` để chống tấn công hoán đổi loại token).
 * - Đóng gói định danh chủ thể `sub: userId`, vai trò `role`, nhãn phân loại `type: "access"`
 *   và thời hạn sống ngắn (`accessTokenTtlMinutes`) nhằm giới hạn cửa sổ rủi ro khi lộ token.
 */
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

/**
 * Giải thuật ký phát hành JWT Refresh Token gắn định danh phiên:
 * - Ký số bằng thuật toán `HS256` với khóa bí mật độc lập `jwtRefreshSecret`.
 * - Nhúng định danh chủ thể `sub: userId`, mã phiên duy nhất `jti: sessionId` và nhãn `type: "refresh"`
 *   phục vụ đối chiếu bản ghi phiên trong DB và cơ chế xoay vòng một lần (Single-Use Rotation).
 */
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

/**
 * Giải thuật xác thực chữ ký và toàn vẹn ngữ nghĩa của JWT Access Token:
 * - Xác minh chữ ký HMAC và hạn sử dụng (`exp`) bằng khóa `jwtAccessSecret`, đồng thời khóa cứng
 *   danh sách trắng `algorithms: ["HS256"]` để triệt tiêu lỗ hổng `alg: none` và tấn công nhầm lẫn
 *   thuật toán/khóa (algorithm/key confusion).
 * - Kiểm tra nghiêm ngặt nhãn `type === "access"`, định danh `sub` và tính hợp lệ của `role`,
 *   chuẩn hóa mọi lỗi giải mã về `ApiError(401)` đồng nhất.
 */
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
            ...(typeof decoded.exp === "number" ? { exp: decoded.exp } : {}),
        };
    } catch {
        throw new ApiError(401, "Unauthorized");
    }
};

/**
 * Giải thuật xác thực chữ ký và cấu trúc phiên của JWT Refresh Token:
 * - Xác minh chữ ký HMAC và thời hạn bằng khóa riêng `jwtRefreshSecret` kèm ràng buộc cứng
 *   `algorithms: ["HS256"]` chống giả mạo header `alg: none` hoặc dùng chéo Access Token.
 * - Đảm bảo sự hiện diện đầy đủ của bộ ba claims bắt buộc (`sub`, `jti` tương ứng `sessionId`,
 *   và `type === "refresh"`), ném lỗi đồng nhất `ApiError(403)` nếu bất kỳ điều kiện nào thất bại.
 */
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
