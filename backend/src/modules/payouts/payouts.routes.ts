/**
 * Định tuyến HTTP hợp nhất cho danh mục ngân hàng (`/api/banks`), tài khoản thụ hưởng Chủ nhà (`/api/host/bank-account`),
 * tài khoản & lịch sử chi trả Chủ nhà (`/api/host/payout-accounts`, `/api/host/payouts`) và quản trị giải ngân (`/api/admin/host-payouts`).
 */
// CONFLICT-RESOLVED: Hợp nhất định tuyến từ `banks.routes.ts`, `host-bank-account.routes.ts`, `host-payouts.routes.ts`
// và `admin-host-payouts.routes.ts` vào `modules/payouts/payouts.routes.ts`, giữ nguyên 100% URL và middleware phân quyền.
import express from "express";
import { body, param, query } from "express-validator";

import { isValidIsoDate } from "../../common/validation";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireHostOnly, requireRole } from "../../middlewares/require-role.middleware";
import { hostPayoutStatusValues } from "../../models/host-payout-batch";
import {
    approveHostPayoutHandler,
    createAdminHostPayout,
    createNewPayoutAccount,
    deleteExistingPayoutAccount,
    getMyHostBankAccount,
    listAdminHostPayouts,
    listHostPayouts,
    listPayoutAccounts,
    listVietnamBanks,
    markHostPayoutPaidHandler,
    rejectHostPayoutHandler,
    saveMyHostBankAccount,
    updateExistingPayoutAccount,
} from "./payouts.controller";

export const banksRouter = express.Router();
banksRouter.get("/vn", listVietnamBanks);

export const hostBankAccountRouter = express.Router();
const requireHostBankAccountAuth = [authenticate, requireRole("host")];
hostBankAccountRouter.get("/bank-account", requireHostBankAccountAuth, getMyHostBankAccount);
hostBankAccountRouter.put("/bank-account", requireHostBankAccountAuth, saveMyHostBankAccount);
hostBankAccountRouter.post("/bank-account", requireHostBankAccountAuth, saveMyHostBankAccount);

const payoutAccountIdParamValidator = param("payoutAccountId")
    .isInt({ min: 1 })
    .withMessage("payoutAccountId must be a positive integer")
    .toInt();

const payoutIdParamValidator = param("payoutId")
    .isInt({ min: 1 })
    .withMessage("payoutId must be a positive integer")
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
    query("limit")
        .optional()
        .isInt({ min: 1, max: 100 })
        .withMessage("limit must be between 1 and 100")
        .toInt(),
];

export const hostPayoutsRouter = express.Router();
hostPayoutsRouter.use(authenticate, requireHostOnly);
hostPayoutsRouter.get("/payout-accounts", listPayoutAccounts);
hostPayoutsRouter.post(
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
hostPayoutsRouter.patch(
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
hostPayoutsRouter.delete(
    "/payout-accounts/:payoutAccountId",
    [payoutAccountIdParamValidator],
    deleteExistingPayoutAccount,
);
hostPayoutsRouter.get("/payouts", payoutListValidators, listHostPayouts);

export const adminHostPayoutsRouter = express.Router();
adminHostPayoutsRouter.use(authenticate, requireRole("admin"));
adminHostPayoutsRouter.get(
    "/",
    [
        query("status").optional().isIn(hostPayoutStatusValues).withMessage("status is invalid"),
        query("hostId").optional().isInt({ min: 1 }).withMessage("hostId must be a positive integer").toInt(),
        ...payoutListValidators.slice(1),
    ],
    listAdminHostPayouts,
);
adminHostPayoutsRouter.post(
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
adminHostPayoutsRouter.patch("/:payoutId/approve", [payoutIdParamValidator], approveHostPayoutHandler);
adminHostPayoutsRouter.patch(
    "/:payoutId/reject",
    [
        payoutIdParamValidator,
        body("reason").isString().trim().notEmpty().withMessage("reason is required").isLength({ max: 2000 }),
    ],
    rejectHostPayoutHandler,
);
adminHostPayoutsRouter.patch(
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

const router = express.Router();
router.use("/host", hostPayoutsRouter);
router.use("/admin", adminHostPayoutsRouter);

export default router;
