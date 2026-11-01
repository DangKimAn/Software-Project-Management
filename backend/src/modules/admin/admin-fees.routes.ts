import express from "express";
import { body } from "express-validator";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import {
    cancelScheduledPlatformFeeHandler,
    getCurrentPlatformFeeStatusHandler,
    schedulePlatformFeeChangeHandler,
} from "./admin-fees.controller";

const router = express.Router();

// Only admin role is authorized to view and manage platform fees
const requireAdmin = [authenticate, requireRole("admin")];

router.get("/current", requireAdmin, getCurrentPlatformFeeStatusHandler);

router.post(
    "/schedule",
    requireAdmin,
    [
        body("feePct")
            .isFloat({ min: 0, max: 100 })
            .withMessage("feePct must be a number between 0 and 100"),
        body("reason")
            .optional({ nullable: true })
            .isString()
            .trim()
            .isLength({ max: 500 })
            .withMessage("reason must be less than 500 characters"),
    ],
    schedulePlatformFeeChangeHandler,
);

router.post("/cancel", requireAdmin, cancelScheduledPlatformFeeHandler);

export default router;
