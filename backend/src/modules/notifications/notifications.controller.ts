/**
 * Bộ điều phối HTTP quản lý hộp thư thông báo trong ứng dụng và thiết bị nhận Push Notification (`notifications`):
 * - Hỗ trợ phân trang danh sách thông báo, đánh dấu đã đọc từng mục/tất cả và đăng ký/hủy đăng ký mã FCM device token của thiết bị.
 */

import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    registerUserDeviceToken,
    unregisterUserDeviceToken,
} from "../../services/fcm-push.service";
import {
    listMyNotifications,
    markAllNotificationsRead,
    markNotificationRead,
    type ListNotificationsQuery,
} from "./notification.service";

const toPositiveInteger = (value: unknown) => {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : undefined;
};

const toBoolean = (value: unknown) =>
    value === true ||
    value === "true" ||
    value === "1" ||
    value === 1;

/**
 * Liệt kê phân trang thông báo của người dùng kèm bộ lọc chưa đọc.
 */
export const getMyNotifications: RequestHandler = asyncHandler(async (req, res) => {
    const query: ListNotificationsQuery = {
        page: toPositiveInteger(req.query.page),
        limit: toPositiveInteger(req.query.limit),
        unreadOnly: toBoolean(req.query.unreadOnly),
    };
    const result = await listMyNotifications(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Đánh dấu một thông báo cụ thể của người dùng sang trạng thái đã đọc.
 */
export const markMyNotificationRead: RequestHandler = asyncHandler(async (req, res) => {
    const notificationId = toPositiveInteger(req.params.id);

    if (!notificationId) {
        throw new ApiError(400, "notification id is invalid");
    }

    const result = await markNotificationRead(req.user!, notificationId);

    return sendSuccess(res, {
        message: "Notification marked as read",
        data: result,
    });
});

/**
 * Đánh dấu đồng loạt toàn bộ thông báo chưa đọc của người dùng thành đã đọc.
 */
export const markAllMyNotificationsRead: RequestHandler = asyncHandler(async (req, res) => {
    const result = await markAllNotificationsRead(req.user!);

    return sendSuccess(res, {
        message: "Notifications marked as read",
        data: result,
    });
});

/**
 * Đăng ký hoặc làm mới mã thiết bị FCM để nhận thông báo đẩy cho tài khoản hiện tại.
 */
export const registerMyDeviceToken: RequestHandler = asyncHandler(async (req, res) => {
    const userId = Number(req.user?.id);
    const body = (req.body ?? {}) as Record<string, unknown>;
    const result = await registerUserDeviceToken({
        userId,
        token: typeof body.token === "string" ? body.token : String(body.fcmToken ?? ""),
        platform: typeof body.platform === "string" ? body.platform : "android",
        appFlavor: typeof body.appFlavor === "string" ? body.appFlavor : null,
        deviceLabel: typeof body.deviceLabel === "string" ? body.deviceLabel : null,
    });

    return sendSuccess(res, {
        message: "Device token registered",
        data: result,
    });
});

/**
 * Hủy kích hoạt mã thiết bị FCM khi người dùng đăng xuất hoặc tắt nhận thông báo đẩy.
 */
export const unregisterMyDeviceToken: RequestHandler = asyncHandler(async (req, res) => {
    const userId = Number(req.user?.id);
    const body = (req.body ?? {}) as Record<string, unknown>;
    const rawToken = body.token ?? body.fcmToken;

    const result = await unregisterUserDeviceToken({
        userId,
        token: rawToken,
    });

    return sendSuccess(res, {
        message: "Device token unregistered",
        data: result,
    });
});
