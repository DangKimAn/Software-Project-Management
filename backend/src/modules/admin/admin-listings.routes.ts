import express from "express";
import { body, param, query } from "express-validator";

import {
    approveListing,
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

const requireModerator = [authenticate, requireRole("admin", "moderator")];

router.get(
    "/pending",
    requireModerator,
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

router.get("/:listingId", requireModerator, [listingIdParamValidator], getAdminListingDetailHandler);

router.patch("/:listingId/approve", requireModerator, [listingIdParamValidator], approveListing);

router.patch(
    "/:listingId/reject",
    requireModerator,
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

export default router;
