import express from "express";
import multer from "multer";

import { ApiError } from "../../common/api-error";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { analyzeIdentityDocumentController } from "./identity-vision.controller";

const router = express.Router();

const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB
        files: 1,
    },
    fileFilter: (_req, file, callback) => {
        if (["image/jpeg", "image/png", "image/webp"].includes(file.mimetype)) {
            callback(null, true);
            return;
        }

        callback(
            new ApiError(422, "Validation error", [
                {
                    path: file.fieldname,
                    msg: "Chỉ hỗ trợ tệp ảnh định dạng JPG, PNG hoặc WebP.",
                },
            ]),
        );
    },
});

const uploadSingleImage: express.RequestHandler = (req, res, next) => {
    upload.fields([
        { name: "image", maxCount: 1 },
        { name: "file", maxCount: 1 },
        { name: "identityFront", maxCount: 1 },
        { name: "identityCard", maxCount: 1 },
    ])(req, res, (error) => {
        if (!error) {
            const files = req.files as Record<string, Express.Multer.File[]> | undefined;
            if (files) {
                const picked =
                    files.image?.[0] ||
                    files.file?.[0] ||
                    files.identityFront?.[0] ||
                    files.identityCard?.[0];
                if (picked) {
                    req.file = picked;
                }
            }
            next();
            return;
        }

        if (error instanceof multer.MulterError) {
            if (error.code === "LIMIT_FILE_SIZE") {
                next(
                    new ApiError(413, "Dung lượng tệp vượt quá giới hạn tối đa 10MB.", [
                        { path: "image", msg: "Dung lượng tệp vượt quá 10MB" },
                    ]),
                );
                return;
            }
        }

        next(error);
    });
};

router.use(authenticate, requireActiveUser);

router.post("/extract", uploadSingleImage, analyzeIdentityDocumentController);
router.post("/verify", uploadSingleImage, analyzeIdentityDocumentController);
router.post("/", uploadSingleImage, analyzeIdentityDocumentController);

export default router;
