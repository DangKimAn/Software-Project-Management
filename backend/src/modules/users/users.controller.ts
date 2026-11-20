/**
 * Bộ điều phối HTTP quản lý hồ sơ cá nhân và quản trị tài khoản người dùng (`users`):
 * - Phục vụ xem/cập nhật hồ sơ và ảnh đại diện của chính người dùng (`/me`), đồng thời hỗ trợ quản trị viên tìm kiếm, cập nhật thông tin và khóa/mở khóa trạng thái tài khoản.
 */

import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { getValidatedBody, getValidatedParams, getValidatedQuery } from "../../common/validation";
import {
    getCurrentUserProfile,
    getUserProfileForAdmin,
    listUserProfilesForAdmin,
    updateCurrentUserAvatar,
    updateCurrentUserProfile,
    updateUserAvatarForAdmin,
    updateUserForAdmin,
    updateUserStatusForAdmin,
} from "./users.service";
import { UserRole, UserStatus } from "../../models/user";

const requestContext = (req: Parameters<RequestHandler>[0]) => ({
    ipAddress: req.ip,
    userAgent: req.get("user-agent") ?? null,
});
/**
 * Truy vấn phân trang và lọc danh sách tài khoản người dùng dành cho quản trị viên.
 */
export const listUsers: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<{
        page: number;
        limit: number;
        search?: string;
        role?: UserRole;
        status?: UserStatus;
    }>(req);

    const result = await listUserProfilesForAdmin(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});
/**
 * Trả về thông tin hồ sơ chi tiết của người dùng đang xác thực.
 */
export const getMe: RequestHandler = asyncHandler(async (req, res) => {
    const user = await getCurrentUserProfile(req.user!);

    return sendSuccess(res, {
        data: {
            user,
        },
    });
});

/**
 * Cập nhật thông tin hồ sơ cá nhân của chính người dùng đang đăng nhập.
 */
export const updateMe: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<Record<string, unknown>>(req);
    const user = await updateCurrentUserProfile(req.user!, payload);

    return sendSuccess(res, {
        message: "Profile updated",
        data: {
            user,
        },
    });
});

/**
 * Cập nhật đường dẫn ảnh đại diện mới cho tài khoản hiện tại.
 */
export const updateMyAvatar: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<{ url: string; key?: string | null }>(req);
    const user = await updateCurrentUserAvatar(req.user!, payload);

    return sendSuccess(res, {
        message: "Avatar updated",
        data: {
            user,
        },
    });
});

/**
 * Truy vấn thông tin chi tiết một người dùng theo `userId` dành cho quản trị viên.
 */
export const getUserById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ userId: string }>(req);
    const user = await getUserProfileForAdmin(params.userId);

    return sendSuccess(res, {
        data: {
            user,
        },
    });
});

/**
 * Cập nhật thông tin hồ sơ người dùng từ phía quản trị viên kèm nhật ký kiểm toán.
 */
export const updateUserById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ userId: string }>(req);
    const payload = getValidatedBody<Record<string, unknown>>(req);
    const user = await updateUserForAdmin(req.user!, params.userId, payload, requestContext(req));

    return sendSuccess(res, {
        message: "User updated",
        data: {
            user,
        },
    });
});

/**
 * Cập nhật ảnh đại diện của một người dùng cụ thể bởi quản trị viên.
 */
export const updateAdminUserAvatar: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ userId: string }>(req);
    const payload = getValidatedBody<{ url: string; key?: string | null }>(req);
    const user = await updateUserAvatarForAdmin(req.user!, params.userId, payload, requestContext(req));

    return sendSuccess(res, {
        message: "User avatar updated",
        data: {
            user,
        },
    });
});

/**
 * Thay đổi trạng thái hoạt động/khóa/đình chỉ của tài khoản người dùng và thu hồi phiên khi cần.
 */
export const updateUserStatus: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ userId: string }>(req);
    const payload = getValidatedBody<{ status: UserStatus }>(req);
    const user = await updateUserStatusForAdmin(
        req.user!,
        params.userId,
        payload.status,
        requestContext(req),
    );

    return sendSuccess(res, {
        message: "User status updated",
        data: {
            user,
        },
    });
});
