/**
 * Định tuyến HTTP cấp phát đường dẫn tải tệp trực tiếp có chữ ký trước (`POST /presign`) cho phân hệ lưu trữ đối tượng công khai (`uploads`):
 * - Yêu cầu xác thực người dùng (`authenticate`), giới hạn tần suất sinh Presigned URL (`Limiter`) và kiểm tra định dạng/dung lượng tệp khai báo.
 */

import express from "express";
import { body } from "express-validator";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { getUploadRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { createPresignedUploadUrl } from "./uploads.controller";
import { allowedPublicUploadFolders } from "./uploads.service";

const router = express.Router();

router.use(authenticate, requireActiveUser);

router.post(
    "/presign",
    getUploadRateLimiter(),
    [
        body("folder")
            .isIn([...allowedPublicUploadFolders])
            .withMessage("folder must be listings, avatars, or misc"),
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
            .exists({ values: "null" })
            .withMessage("size is required")
            .bail()
            .isInt({ min: 1, max: 10 * 1024 * 1024 })
            .withMessage("size must be between 1 byte and 10MB")
            .toInt(),
    ],
    createPresignedUploadUrl,
);

export default router;
