import express from "express";
import { body, param, query } from "express-validator";

import {
    createNewPayoutAccount,
    deleteExistingPayoutAccount,
    listHostPayouts,
    listPayoutAccounts,
    updateExistingPayoutAccount,
} from "./payouts.controller";
import { isValidIsoDate } from "../../common/validation";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireHostOnly } from "../../middlewares/require-role.middleware";
import { hostPayoutStatusValues } from "../../models/host-payout-batch";

const router = express.Router();

const payoutAccountIdParamValidator = param("payoutAccountId")
    .isInt({ min: 1 })
    .withMessage("payoutAccountId must be a positive integer")
    .toInt();

const payoutListValidators = [
    query("status").optional().isIn(hostPayoutStatusValues).withMessage("status is invalid"),
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
];

router.use(authenticate, requireHostOnly);

router.get("/payout-accounts", listPayoutAccounts);

router.post(
    "/payout-accounts",
    [
        body("bankName").isString().trim().notEmpty().withMessage("bankName is required").isLength({ max: 150 }),
        body("bankCode").optional({ nullable: true }).isString().trim().isLength({ max: 32 }),
        body("accountName")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("accountName is required")
            .isLength({ max: 255 }),
        body("accountNumber")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("accountNumber is required")
            .matches(/^\d{4,32}$/)
            .withMessage("accountNumber must contain 4 to 32 digits"),
        body("isDefault").optional().isBoolean().withMessage("isDefault must be boolean").toBoolean(),
    ],
    createNewPayoutAccount,
);

router.patch(
    "/payout-accounts/:payoutAccountId",
    [
        payoutAccountIdParamValidator,
        body("bankName").optional().isString().trim().notEmpty().isLength({ max: 150 }),
        body("bankCode").optional({ nullable: true }).isString().trim().isLength({ max: 32 }),
        body("accountName").optional().isString().trim().notEmpty().isLength({ max: 255 }),
        body("accountNumber")
            .optional()
            .isString()
            .trim()
            .matches(/^\d{4,32}$/)
            .withMessage("accountNumber must contain 4 to 32 digits"),
        body("isDefault").optional().isBoolean().withMessage("isDefault must be boolean").toBoolean(),
    ],
    updateExistingPayoutAccount,
);

router.delete(
    "/payout-accounts/:payoutAccountId",
    [payoutAccountIdParamValidator],
    deleteExistingPayoutAccount,
);

router.get("/payouts", payoutListValidators, listHostPayouts);

export default router;
