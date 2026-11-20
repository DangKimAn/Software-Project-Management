/**
 * Định tuyến HTTP dịch vụ AI đánh giá hình ảnh chỗ ở cho chủ nhà và quản trị viên:
 * - Áp dụng middleware xác thực (`authenticate`), phân quyền vai trò (`host`/`admin`) và bộ giới hạn tốc độ gọi mô hình thị giác máy tính.
 */

import express from "express";
import { body, param, query } from "express-validator";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { getAiVisionRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireHostOnly, requireRole } from "../../middlewares/require-role.middleware";
import {
    analyzeAllListingImages,
    analyzeSingleListingImage,
    deleteHostImageById,
    getHostListingImageAnalysis,
    reanalyzeAdminImage,
    updateHostImageTags,
} from "./listing-image-vision.controller";

const router = express.Router();
export const hostListingImageVisionRoutes = express.Router();
export const hostImageVisionRoutes = express.Router();
export const adminImageVisionRoutes = express.Router();
const aiVisionLimiter = getAiVisionRateLimiter();

const listingIdParamValidator = param("listingId")
    .isInt({ min: 1 })
    .withMessage("listingId must be a positive integer")
    .toInt();

const imageIdParamValidator = param("imageId")
    .isInt({ min: 1 })
    .withMessage("imageId must be a positive integer")
    .toInt();

router.use(authenticate, requireRole("host", "admin"));
hostListingImageVisionRoutes.use(authenticate, requireHostOnly);
hostImageVisionRoutes.use(authenticate, requireHostOnly);
adminImageVisionRoutes.use(authenticate, requireRole("admin"));

router.post(
    "/:listingId/images/:imageId/analyze",
    aiVisionLimiter,
    [listingIdParamValidator, imageIdParamValidator],
    analyzeSingleListingImage,
);

hostListingImageVisionRoutes.post(
    "/:listingId/images/:imageId/analyze",
    aiVisionLimiter,
    [listingIdParamValidator, imageIdParamValidator],
    analyzeSingleListingImage,
);

hostListingImageVisionRoutes.get(
    "/:listingId/images/analysis",
    [listingIdParamValidator],
    getHostListingImageAnalysis,
);

hostImageVisionRoutes.patch(
    "/:imageId/tags",
    [
        imageIdParamValidator,
        body("tags").isArray({ max: 30 }).withMessage("tags must be an array"),
        body("tags.*")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("tags must contain non-empty strings")
            .isLength({ max: 120 }),
    ],
    updateHostImageTags,
);

hostImageVisionRoutes.delete(
    "/:imageId",
    [imageIdParamValidator],
    deleteHostImageById,
);

adminImageVisionRoutes.post(
    "/:imageId/reanalyze",
    aiVisionLimiter,
    [imageIdParamValidator],
    reanalyzeAdminImage,
);

router.post(
    "/:listingId/analyze-images",
    aiVisionLimiter,
    [
        listingIdParamValidator,
        query("force")
            .optional()
            .isBoolean()
            .withMessage("force must be boolean")
            .toBoolean(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: 10 })
            .withMessage("limit must be between 1 and 10")
            .toInt(),
    ],
    analyzeAllListingImages,
);

export default router;
