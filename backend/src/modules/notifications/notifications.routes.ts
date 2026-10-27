import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import {
    getMyNotifications,
    markAllMyNotificationsRead,
    markMyNotificationRead,
} from "./notifications.controller";

const router = express.Router();

router.use(authenticate);

router.get("/", getMyNotifications);
router.patch("/read-all", markAllMyNotificationsRead);
router.patch("/:id/read", markMyNotificationRead);

export default router;
