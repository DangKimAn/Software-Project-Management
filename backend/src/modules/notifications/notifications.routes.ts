import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { getDeviceTokenRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import {
    getMyNotifications,
    markAllMyNotificationsRead,
    markMyNotificationRead,
    registerMyDeviceToken,
    unregisterMyDeviceToken,
} from "./notifications.controller";

const router = express.Router();
const deviceTokenRateLimiter = getDeviceTokenRateLimiter();

router.use(authenticate, requireActiveUser);

router.get("/", getMyNotifications);
router.post("/devices", deviceTokenRateLimiter, registerMyDeviceToken);
router.delete("/devices", deviceTokenRateLimiter, unregisterMyDeviceToken);
router.post("/devices/unregister", deviceTokenRateLimiter, unregisterMyDeviceToken);
router.patch("/read-all", markAllMyNotificationsRead);
router.patch("/:id/read", markMyNotificationRead);

export default router;
