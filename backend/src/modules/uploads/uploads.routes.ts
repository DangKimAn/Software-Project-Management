/**
 * Định tuyến HTTP cấp phát đường dẫn tải tệp trực tiếp có chữ ký trước (`POST /presign`) cho phân hệ lưu trữ đối tượng công khai (`uploads`):
 * - Yêu cầu xác thực người dùng (`authenticate`), giới hạn tần suất sinh Presigned URL (`Limiter`) và kiểm tra định dạng/dung lượng tệp khai báo.
 */

import express from "express";
import { body } from "express-validator";
import multer from "multer";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { getUploadRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
// CONFLICT-RESOLVED: Hợp nhất danh sách thư mục công khai an toàn (`allowedPublicUploadFolders` không chứa `verifications`) với endpoint tải tệp trực tiếp `uploadDirectFile` của `origin/develop`.
import { createPresignedUploadUrl, uploadDirectFile } from "./uploads.controller";
import { allowedPublicUploadFolders } from "./uploads.service";

const router = express.Router();

const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 25 * 1024 * 1024,
    },
});

router.use(authenticate, requireActiveUser);

const allowedFolders = ["listings", "avatars", "verifications", "misc", "chat"];
const allowedContentTypes = [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "audio/mpeg",
    "audio/mp3",
    "audio/m4a",
    "audio/x-m4a",
    "audio/mp4",
    "audio/aac",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "audio/webm",
];

router.post(
    "/presign",
    getUploadRateLimiter(),
    [
        // CONFLICT-RESOLVED: Chặn tuyệt đối thư mục nhạy cảm `verifications` trên endpoint công khai R2, đồng thời hỗ trợ `chat` cho âm thanh/ảnh tin nhắn và bắt buộc truyền `size` hợp lệ (tối đa 25MB).
        body("folder")
            .isIn([...allowedPublicUploadFolders])
            .withMessage(`folder must be one of: ${allowedPublicUploadFolders.join(", ")}`),
        body("filename").isString().trim().notEmpty().withMessage("filename is required").isLength({ max: 255 }),
        body("contentType")
            .isIn(allowedContentTypes)
            .withMessage("contentType must be a supported image or audio format"),
        body("listingId")
            .optional({ nullable: true })
            .isInt({ min: 1 })
            .withMessage("listingId must be a positive integer")
            .toInt(),
        body("size")
            .exists({ values: "null" })
            .withMessage("size is required")
            .bail()
            .isInt({ min: 1, max: 25 * 1024 * 1024 })
            .withMessage("size must be between 1 byte and 25MB")
            .toInt(),
    ],
    createPresignedUploadUrl,
);

router.post(
    "/direct",
    getUploadRateLimiter(),
    upload.single("file"),
    uploadDirectFile,
);

export default router;
