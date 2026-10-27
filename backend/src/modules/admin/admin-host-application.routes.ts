import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import {
    approveHostApplicationController,
    getAdminHostApplicationDetailController,
    listAdminHostApplicationsController,
    rejectHostApplicationController,
} from "../host-applications/host-application.controller";

const router = express.Router();

router.use(authenticate, requireActiveUser, requireRole("admin"));

router.get("/", listAdminHostApplicationsController);
router.get("/:applicationId", getAdminHostApplicationDetailController);
router.patch("/:applicationId/approve", approveHostApplicationController);
router.patch("/:applicationId/reject", rejectHostApplicationController);

export default router;
