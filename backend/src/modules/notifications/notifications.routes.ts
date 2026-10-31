import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import {
    getMyNotifications,
    markAllMyNotificationsRead,
    markMyNotificationRead,
    registerMyDeviceToken,
    unregisterMyDeviceToken,
} from "./notifications.controller";

const router = express.Router();

router.use(authenticate);

router.get("/", getMyNotifications);
router.post("/devices", registerMyDeviceToken);
router.delete("/devices", unregisterMyDeviceToken);
router.post("/devices/unregister", unregisterMyDeviceToken);
router.patch("/read-all", markAllMyNotificationsRead);
router.patch("/:id/read", markMyNotificationRead);

export default router;
