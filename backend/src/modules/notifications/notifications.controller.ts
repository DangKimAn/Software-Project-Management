import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
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

export const markAllMyNotificationsRead: RequestHandler = asyncHandler(async (req, res) => {
    const result = await markAllNotificationsRead(req.user!);

    return sendSuccess(res, {
        message: "Notifications marked as read",
        data: result,
    });
});
