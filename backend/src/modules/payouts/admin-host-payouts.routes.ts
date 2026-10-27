import express from "express";
import { body, param, query } from "express-validator";

import { isValidIsoDate } from "../../common/validation";
import {
    approveHostPayoutHandler,
    createAdminHostPayout,
    listAdminHostPayouts,
    markHostPayoutPaidHandler,
    rejectHostPayoutHandler,
} from "./payouts.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { hostPayoutStatusValues } from "../../models/host-payout-batch";

const router = express.Router();

const payoutIdParamValidator = param("payoutId")
    .isInt({ min: 1 })
    .withMessage("payoutId must be a positive integer")
    .toInt();

router.use(authenticate, requireRole("admin"));

router.get(
    "/",
    [
        query("status").optional().isIn(hostPayoutStatusValues).withMessage("status is invalid"),
        query("hostId").optional().isInt({ min: 1 }).withMessage("hostId must be a positive integer").toInt(),
        query("from")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("from must use YYYY-MM-DD format"),
        query("to")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("to must use YYYY-MM-DD format")
            .custom((value, { req }) => !req.query?.from || String(req.query.from) <= String(value))
            .withMessage("to must be greater than or equal to from"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("limit must be between 1 and 100").toInt(),
    ],
    listAdminHostPayouts,
);

router.post(
    "/",
    [
        body("hostId").isInt({ min: 1 }).withMessage("hostId must be a positive integer").toInt(),
        body("bookingIds").isArray({ min: 1 }).withMessage("bookingIds must be a non-empty array"),
        body("bookingIds.*").isInt({ min: 1 }).withMessage("bookingIds must contain positive integers").toInt(),
        body("payoutAccountId")
            .isInt({ min: 1 })
            .withMessage("payoutAccountId must be a positive integer")
            .toInt(),
        body("amount").isInt({ min: 1 }).withMessage("amount must be a positive integer VND amount").toInt(),
        body("currency").equals("VND").withMessage("currency must be VND"),
        body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    createAdminHostPayout,
);

router.patch("/:payoutId/approve", [payoutIdParamValidator], approveHostPayoutHandler);

router.patch(
    "/:payoutId/reject",
    [
        payoutIdParamValidator,
        body("reason").isString().trim().notEmpty().withMessage("reason is required").isLength({ max: 2000 }),
    ],
    rejectHostPayoutHandler,
);

router.patch(
    "/:payoutId/paid",
    [
        payoutIdParamValidator,
        body("transferReference")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("transferReference is required")
            .isLength({ max: 255 }),
    ],
    markHostPayoutPaidHandler,
);

export default router;
