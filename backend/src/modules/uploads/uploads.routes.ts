import express from "express";
import { body } from "express-validator";
import multer from "multer";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { getUploadRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { createPresignedUploadUrl, uploadDirectFile } from "./uploads.controller";

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
        body("folder")
            .isIn(allowedFolders)
            .withMessage(`folder must be one of: ${allowedFolders.join(", ")}`),
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
            .optional({ nullable: true })
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
