import express from "express";
import { param, query, body } from "express-validator";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { refundStatusValues } from "../../models/refund";
import {
    listAdminRefundsHandler,
    approveRefundHandler,
    rejectRefundHandler,
} from "./refunds.controller";

const router = express.Router();

const refundIdParamValidator = param("refundId")
    .isInt({ min: 1 })
    .withMessage("refundId must be a positive integer")
    .toInt();

router.use(authenticate, requireRole("admin"));

router.get(
    "/",
    [
        query("status").optional().isIn(refundStatusValues).withMessage("status is invalid"),
        query("bookingId").optional().isInt({ min: 1 }).toInt(),
        query("page").optional().isInt({ min: 1 }).toInt(),
        query("limit").optional().isInt({ min: 1, max: 100 }).toInt(),
    ],
    listAdminRefundsHandler,
);

router.post(
    "/:refundId/approve",
    [
        refundIdParamValidator,
        body("bankName").optional().isString().trim(),
        body("accountNumber").optional().isString().trim(),
        body("accountName").optional().isString().trim(),
        body("notes").optional().isString().trim(),
    ],
    approveRefundHandler,
);

router.post(
    "/:refundId/reject",
    [
        refundIdParamValidator,
        body("reason").isString().trim().notEmpty().withMessage("reason is required").isLength({ max: 2000 }),
    ],
    rejectRefundHandler,
);

export default router;
