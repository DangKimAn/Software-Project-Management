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
export const getMe: RequestHandler = asyncHandler(async (req, res) => {
    const user = await getCurrentUserProfile(req.user!);

    return sendSuccess(res, {
        data: {
            user,
        },
    });
});

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

export const getUserById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ userId: string }>(req);
    const user = await getUserProfileForAdmin(params.userId);

    return sendSuccess(res, {
        data: {
            user,
        },
    });
});

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
