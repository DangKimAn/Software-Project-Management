/**
 * Định tuyến HTTP hợp nhất cho quy trình đăng ký chủ nhà, tiếp nhận hồ sơ và xác minh danh tính KYC (`host-kyc`):
 * - Bao gồm các nhánh router `hostApplicationsRouter`, `hostOnboardingRouter`, `hostVerificationsRouter`, `adminHostApplicationsRouter` và `adminVerificationsRouter`.
 * - Tích hợp chuỗi middleware xác thực (`authenticate`), kiểm tra tài khoản hoạt động (`requireActiveUser`), phân quyền `admin`,
 *   giới hạn tần suất tải lên (`getUploadRateLimiter`), bộ lọc tệp `multer` bộ nhớ (tối đa 5MB, JPG/PNG/WebP/PDF) và kiểm chứng đầu vào `express-validator`.
 */

// CONFLICT-RESOLVED: Hợp nhất định tuyến từ `host-applications`, `host-onboarding`, `verifications`
// và `admin/admin-host-application.routes.ts` vào `modules/host-kyc/host-kyc.routes.ts` mà không đổi bất kỳ URL API nào.
import express from "express";
import { body, param, query } from "express-validator";
import multer from "multer";

import { ApiError } from "../../common/api-error";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { getUploadRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { hostEntityTypeValues } from "../../models/host-application";
import {
    hostVerificationStatusValues,
    hostVerificationTypeValues,
} from "../../models/host-verification";
import {
    approveHostApplicationController,
    approveVerificationController,
    authenticateAdminHostDocumentStream,
    cancelHostApplicationController,
    getAdminHostApplicationDetailController,
    getCurrentHostOnboardingController,
    getMyHostApplicationController,
    getMyVerificationsController,
    listAdminHostApplicationsController,
    listAdminVerificationsController,
    registerHostOnboardingController,
    rejectHostApplicationController,
    rejectVerificationController,
    requestMoreInfoHostApplicationController,
    streamAdminHostDocumentController,
    submitHostApplicationController,
    submitVerificationController,
} from "./host-kyc.controller";
import { isSafeVerificationDocumentUrl } from "./host-verification.service";

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

export const hostApplicationsRouter = express.Router();
hostApplicationsRouter.use(authenticate, requireActiveUser);
hostApplicationsRouter.get("/me", getMyHostApplicationController);
hostApplicationsRouter.post("/", uploadIdentityDocuments, submitHostApplicationController);
hostApplicationsRouter.post("/cancel", cancelHostApplicationController);
hostApplicationsRouter.post("/me/cancel", cancelHostApplicationController);
hostApplicationsRouter.delete("/me", cancelHostApplicationController);

const normalizeHostRegisterPayload: express.RequestHandler = (req, _res, next) => {
    if (req.body?.entityType === undefined) {
        req.body.entityType = req.body?.hostType ?? req.body?.businessType ?? req.body?.type;
    }

    next();
};

export const hostOnboardingRouter = express.Router();
hostOnboardingRouter.get("/application/me", authenticate, getCurrentHostOnboardingController);
hostOnboardingRouter.get("/register/status", authenticate, getCurrentHostOnboardingController);
hostOnboardingRouter.post(
    "/register",
    authenticate,
    normalizeHostRegisterPayload,
    [
        body("contactName").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("contactEmail")
            .optional({ nullable: true })
            .isEmail()
            .withMessage("contactEmail is invalid")
            .normalizeEmail(),
        body("contactPhone")
            .optional({ nullable: true })
            .matches(/^(0|\+84)[0-9]{9}$/)
            .withMessage("contactPhone must be a valid Vietnamese phone number"),
        body("businessAddress")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("businessAddress is required")
            .isLength({ max: 500 }),
        body("entityType").isIn(hostEntityTypeValues).withMessage("entityType is invalid"),
        body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    registerHostOnboardingController,
);

export const hostVerificationsRouter = express.Router();
hostVerificationsRouter.use(authenticate, requireActiveUser);
hostVerificationsRouter.post(
    "/",
    getUploadRateLimiter(),
    [
        body("verificationType").isIn(hostVerificationTypeValues).withMessage("verificationType is invalid"),
        body("fullName").isString().trim().notEmpty().withMessage("fullName is required").isLength({ max: 255 }),
        body("idNumber").optional({ nullable: true }).isString().trim().isLength({ max: 100 }),
        body("documentUrls")
            .isArray({ min: 1, max: 10 })
            .withMessage("documentUrls must be a non-empty array"),
        body("documentUrls.*")
            .isURL({ protocols: ["http", "https"], require_protocol: true })
            .withMessage("documentUrls must contain valid URLs")
            .isLength({ max: 1024 })
            .custom(isSafeVerificationDocumentUrl)
            .withMessage("documentUrls must reference a supported public document URL"),
        body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    submitVerificationController,
);
hostVerificationsRouter.get(
    "/me",
    [
        query("latestOnly").optional().isBoolean().withMessage("latestOnly must be boolean").toBoolean(),
        query("status").optional().isIn(hostVerificationStatusValues).withMessage("status is invalid"),
        query("verificationType")
            .optional()
            .isIn(hostVerificationTypeValues)
            .withMessage("verificationType is invalid"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: 100 })
            .withMessage("limit must be between 1 and 100")
            .toInt(),
    ],
    getMyVerificationsController,
);

export const adminHostApplicationsRouter = express.Router();
adminHostApplicationsRouter.get(
    "/documents/:documentId/view",
    authenticateAdminHostDocumentStream,
    streamAdminHostDocumentController,
);
adminHostApplicationsRouter.get(
    "/:applicationId/documents/:documentId/file",
    authenticateAdminHostDocumentStream,
    streamAdminHostDocumentController,
);
adminHostApplicationsRouter.get(
    "/:applicationId/documents/:documentId/view",
    authenticateAdminHostDocumentStream,
    streamAdminHostDocumentController,
);
adminHostApplicationsRouter.use(authenticate, requireActiveUser, requireRole("admin"));
adminHostApplicationsRouter.get("/", listAdminHostApplicationsController);
adminHostApplicationsRouter.get("/:applicationId", getAdminHostApplicationDetailController);
adminHostApplicationsRouter.patch("/:applicationId/approve", approveHostApplicationController);
adminHostApplicationsRouter.patch("/:applicationId/reject", rejectHostApplicationController);
adminHostApplicationsRouter.patch("/:applicationId/request-more-info", requestMoreInfoHostApplicationController);
adminHostApplicationsRouter.post("/:applicationId/request-more-info", requestMoreInfoHostApplicationController);

const verificationIdParamValidator = param("verificationId")
    .isInt({ min: 1 })
    .withMessage("verificationId must be a positive integer")
    .toInt();

export const adminVerificationsRouter = express.Router();
adminVerificationsRouter.use(authenticate, requireActiveUser, requireRole("admin"));
adminVerificationsRouter.get(
    "/",
    [
        query("status").optional().isIn(hostVerificationStatusValues).withMessage("status is invalid"),
        query("verificationType")
            .optional()
            .isIn(hostVerificationTypeValues)
            .withMessage("verificationType is invalid"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: 100 })
            .withMessage("limit must be between 1 and 100")
            .toInt(),
    ],
    listAdminVerificationsController,
);
adminVerificationsRouter.patch(
    "/:verificationId/approve",
    [verificationIdParamValidator, body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 2000 })],
    approveVerificationController,
);
adminVerificationsRouter.patch(
    "/:verificationId/reject",
    [
        verificationIdParamValidator,
        body("reason")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("reason is required")
            .isLength({ max: 2000 }),
    ],
    rejectVerificationController,
);
