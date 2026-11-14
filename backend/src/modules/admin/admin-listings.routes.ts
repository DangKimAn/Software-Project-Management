/**
 * Định tuyến HTTP kiểm duyệt và quản trị chỗ ở (`/api/admin/listings`):
 * - Áp dụng middleware xác thực (`authenticate`), phân quyền `admin` và kiểm tra tham số định danh chỗ ở.
 * - Hỗ trợ duyệt danh sách chờ duyệt (`GET /pending`), xem chi tiết, phê duyệt, từ chối và chuyển quyền sở hữu chủ nhà (`transfer-host`).
 */

import express from "express";
import { body, param, query } from "express-validator";

import {
    approveListing,
    transferListingHostHandler,
    getAdminListingDetailHandler,
    listPendingListings,
    rejectListing,
} from "./admin.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { adminListingsMaxPageLimit } from "./admin.service";

const router = express.Router();

const listingIdParamValidator = param("listingId")
    .isInt({ min: 1 })
    .withMessage("listingId must be a positive integer")
    .toInt();

const requireAdmin = [authenticate, requireRole("admin")];

router.get(
    "/pending",
    requireAdmin,
    [
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: adminListingsMaxPageLimit })
            .withMessage(`limit must be between 1 and ${adminListingsMaxPageLimit}`)
            .toInt(),
    ],
    listPendingListings,
);

router.get("/:listingId", requireAdmin, [listingIdParamValidator], getAdminListingDetailHandler);

router.patch("/:listingId/approve", requireAdmin, [listingIdParamValidator], approveListing);

router.patch(
    "/:listingId/reject",
    requireAdmin,
    [
        listingIdParamValidator,
        body("reason")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("reason is required")
            .isLength({ max: 2000 }),
    ],
    rejectListing,
);

router.patch(
    "/:listingId/transfer-host",
    [authenticate, requireRole("admin")],
    [
        listingIdParamValidator,
        body("newHostId")
            .isInt({ min: 1 })
            .withMessage("newHostId must be a positive integer")
            .toInt(),
    ],
    transferListingHostHandler,
);

export default router;
