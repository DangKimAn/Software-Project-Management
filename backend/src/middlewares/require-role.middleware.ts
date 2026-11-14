import { RequestHandler } from "express";

import { ApiError } from "../common/api-error";
import { UserRole } from "../models/user";

/**
 * Giải thuật phân quyền theo vai trò RBAC chống leo thang đặc quyền mức hàm (BFLA):
 * - Chỉ cho phép tiếp tục khi `req.user.roles` giao với ít nhất một vai trò trong danh sách `roles` yêu cầu; ngược lại từ chối `403`.
 */
export const requireRole = (...roles: UserRole[]): RequestHandler => {
    return (req, _res, next) => {
        if (!req.user) {
            return next(new ApiError(401, "Unauthorized"));
        }

        const hasAllowedRole = roles.some((role) => req.user?.roles.includes(role));

        if (!hasAllowedRole) {
            return next(new ApiError(403, "Forbidden"));
        }

        return next();
    };
};

/**
 * Giải thuật tách biệt chức trách (Separation of Duties) dành riêng cho cổng Host:
 * - Bắt buộc người dùng mang vai trò `host` và đồng thời không mang vai trò `admin` để ngăn tài khoản quản trị thao tác nhầm luồng chủ nhà.
 */
export const requireHostOnly: RequestHandler = (req, _res, next) => {
    if (!req.user) {
        return next(new ApiError(401, "Unauthorized"));
    }

    if (req.user.roles.includes("admin") || !req.user.roles.includes("host")) {
        return next(new ApiError(403, "Forbidden"));
    }

    return next();
};
