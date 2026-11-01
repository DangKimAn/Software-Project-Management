import express from "express";
import { body } from "express-validator";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { getUploadRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { createPresignedUploadUrl } from "./uploads.controller";

const router = express.Router();

router.use(authenticate, requireActiveUser);

router.post(
    "/presign",
    getUploadRateLimiter(),
    [
        body("folder")
            .isIn(["listings", "avatars", "verifications", "misc"])
            .withMessage("folder must be listings, avatars, verifications, or misc"),
        body("filename").isString().trim().notEmpty().withMessage("filename is required").isLength({ max: 255 }),
        body("contentType")
            .isIn(["image/jpeg", "image/png", "image/webp", "image/gif"])
            .withMessage("Only JPG, PNG, WebP, or GIF image files are allowed"),
        body("listingId")
            .optional({ nullable: true })
            .isInt({ min: 1 })
            .withMessage("listingId must be a positive integer")
            .toInt(),
        body("size")
            .optional({ nullable: true })
            .isInt({ min: 1, max: 10 * 1024 * 1024 })
            .withMessage("size must be between 1 byte and 10MB")
            .toInt(),
    ],
    createPresignedUploadUrl,
);

export default router;
