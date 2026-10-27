import express from "express";
import { body, param } from "express-validator";

import {
    createGuestReview,
    createHostReviewReply,
    deleteGuestReview,
    updateGuestReview,
} from "./reviews.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { getReviewWriteRateLimiter } from "../../middlewares/rate-limit.middleware";

const router = express.Router();

const reviewIdParamValidator = param("reviewId")
    .isInt({ min: 1 })
    .withMessage("reviewId must be a positive integer")
    .toInt();

router.use(authenticate, requireActiveUser);

router.post(
    "/",
    getReviewWriteRateLimiter(),
    [
        body("bookingId").isInt({ min: 1 }).withMessage("bookingId must be a positive integer").toInt(),
        body("rating").isInt({ min: 1, max: 5 }).withMessage("rating must be between 1 and 5").toInt(),
        body("comment").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    createGuestReview,
);

router.post(
    "/:reviewId/reply",
    getReviewWriteRateLimiter(),
    [
        reviewIdParamValidator,
        body("reply")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("reply is required")
            .isLength({ max: 2000 })
            .withMessage("reply must be at most 2000 characters"),
    ],
    requireRole("host", "admin"),
    createHostReviewReply,
);

router.patch(
    "/:reviewId",
    [
        reviewIdParamValidator,
        body("rating").optional().isInt({ min: 1, max: 5 }).withMessage("rating must be between 1 and 5").toInt(),
        body("comment").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    updateGuestReview,
);

router.delete("/:reviewId", [reviewIdParamValidator], deleteGuestReview);

export default router;
