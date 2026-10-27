import express from "express";
import { body, param, query } from "express-validator";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { isValidIsoDate } from "../../common/validation";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireHostOnly, requireRole } from "../../middlewares/require-role.middleware";
import { getReportWriteRateLimiter } from "../../middlewares/rate-limit.middleware";
import { reportStatusValues, reportTargetTypeValues } from "../../models/report";
import {
    createUserReport,
    getAdminBookingsAnalytics,
    getAdminHostsAnalytics,
    getAdminListingsAnalytics,
    getAdminRevenueAnalytics,
    getHostRevenueAnalytics,
    listAdminReports,
    listMyReports,
    rejectAdminReport,
    resolveAdminReport,
} from "./reports.controller";

const router = express.Router();
export const adminReportsRouter = express.Router();
export const hostReportsRouter = express.Router();

const reportIdParamValidator = param("reportId")
    .isInt({ min: 1 })
    .withMessage("reportId must be a positive integer")
    .toInt();

const listQueryValidators = () => [
    query("status").optional().isIn(reportStatusValues).withMessage("status is invalid"),
    query("targetType").optional().isIn(reportTargetTypeValues).withMessage("targetType is invalid"),
    query("type").optional().isIn(reportTargetTypeValues).withMessage("type is invalid"),
    query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
    query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("limit must be between 1 and 100").toInt(),
];

const analyticsQueryValidators = () => [
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
    query("group").optional().isIn(["day", "month", "year"]).withMessage("group is invalid"),
];

router.use(authenticate, requireActiveUser);

router.post(
    "/",
    getReportWriteRateLimiter(),
    [
        body("targetType").isIn(reportTargetTypeValues).withMessage("targetType is invalid"),
        body("targetId").isInt({ min: 1 }).withMessage("targetId must be a positive integer").toInt(),
        body("reason")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("reason is required")
            .isLength({ max: 255 })
            .withMessage("reason must be at most 255 characters"),
        body("description")
            .optional({ nullable: true })
            .isString()
            .trim()
            .isLength({ max: 2000 })
            .withMessage("description must be at most 2000 characters"),
    ],
    createUserReport,
);

router.get("/mine", listQueryValidators(), listMyReports);

adminReportsRouter.use(authenticate, requireActiveUser, requireRole("admin"));

adminReportsRouter.get("/revenue", analyticsQueryValidators(), getAdminRevenueAnalytics);
adminReportsRouter.get("/bookings", analyticsQueryValidators(), getAdminBookingsAnalytics);
adminReportsRouter.get("/listings", analyticsQueryValidators(), getAdminListingsAnalytics);
adminReportsRouter.get("/hosts", analyticsQueryValidators(), getAdminHostsAnalytics);

adminReportsRouter.get(
    "/",
    [
        ...listQueryValidators(),
        query("reporterId")
            .optional()
            .isInt({ min: 1 })
            .withMessage("reporterId must be a positive integer")
            .toInt(),
    ],
    listAdminReports,
);

adminReportsRouter.patch(
    "/:reportId/resolve",
    [
        reportIdParamValidator,
        body("resolution").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
        body("note").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
        body("reason").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    resolveAdminReport,
);

adminReportsRouter.patch(
    "/:reportId/reject",
    [
        reportIdParamValidator,
        body("reason").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
        body("note").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    rejectAdminReport,
);

hostReportsRouter.use(authenticate, requireActiveUser, requireHostOnly);
hostReportsRouter.get("/revenue", analyticsQueryValidators(), getHostRevenueAnalytics);

export default router;
