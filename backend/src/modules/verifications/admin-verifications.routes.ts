import express from "express";
import { body, param, query } from "express-validator";

import {
    approveVerification,
    listAdminVerifications,
    rejectVerification,
} from "./verifications.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import {
    hostVerificationStatusValues,
    hostVerificationTypeValues,
} from "../../models/host-verification";

const router = express.Router();

const verificationIdParamValidator = param("verificationId")
    .isInt({ min: 1 })
    .withMessage("verificationId must be a positive integer")
    .toInt();

router.use(authenticate, requireActiveUser, requireRole("admin"));

router.get(
    "/",
    [
        query("status").optional().isIn(hostVerificationStatusValues).withMessage("status is invalid"),
        query("verificationType")
            .optional()
            .isIn(hostVerificationTypeValues)
            .withMessage("verificationType is invalid"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("limit must be between 1 and 100").toInt(),
    ],
    listAdminVerifications,
);

router.patch(
    "/:verificationId/approve",
    [verificationIdParamValidator, body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 2000 })],
    approveVerification,
);

router.patch(
    "/:verificationId/reject",
    [
        verificationIdParamValidator,
        body("reason")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("reason is required")
            .isLength({ max: 2000 }),
    ],
    rejectVerification,
);

export default router;
