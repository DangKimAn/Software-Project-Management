import express from "express";
import multer from "multer";

import { ApiError } from "../../common/api-error";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import {
    getMyHostApplicationController,
    submitHostApplicationController,
} from "./host-application.controller";

const router = express.Router();

const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024,
        files: 4,
    },
    fileFilter: (_req, file, callback) => {
        if (["image/jpeg", "image/png", "image/webp", "application/pdf"].includes(file.mimetype)) {
            callback(null, true);
            return;
        }

        callback(
            new ApiError(422, "Validation error", [
                {
                    path: file.fieldname,
                    msg: "Only JPG, PNG, WebP, or PDF files are allowed",
                },
            ]),
        );
    },
});

const uploadIdentityDocuments: express.RequestHandler = (req, res, next) => {
    upload.fields([
        { name: "identityFront", maxCount: 1 },
        { name: "identityBack", maxCount: 1 },
        { name: "identitySingle", maxCount: 1 },
        { name: "businessLicense", maxCount: 1 },
    ])(req, res, (error) => {
        if (!error) {
            next();
            return;
        }

        if (error instanceof multer.MulterError) {
            if (error.code === "LIMIT_FILE_SIZE") {
                next(new ApiError(413, "Each identity document file must be 5MB or smaller"));
                return;
            }

            if (error.code === "LIMIT_FILE_COUNT" || error.code === "LIMIT_UNEXPECTED_FILE") {
                next(new ApiError(422, "Unexpected identity document file field"));
                return;
            }
        }

        next(error);
    });
};

router.use(authenticate, requireActiveUser);

router.get("/me", getMyHostApplicationController);
router.post("/", uploadIdentityDocuments, submitHostApplicationController);

export default router;
