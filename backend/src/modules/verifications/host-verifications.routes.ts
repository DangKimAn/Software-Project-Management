import express from "express";
import { body, query } from "express-validator";

import { getMyVerifications, submitVerification } from "./verifications.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import {
    hostVerificationStatusValues,
    hostVerificationTypeValues,
} from "../../models/host-verification";

const router = express.Router();

const allowedDocumentExtensions = new Set([".jpg", ".jpeg", ".png", ".webp", ".pdf"]);

const isSafeDocumentUrl = (value: string) => {
    try {
        const url = new URL(value);
        const decodedPath = decodeURIComponent(url.pathname);

        if (decodedPath.split("/").some((segment) => segment === "..")) {
            return false;
        }

        const lastSegment = decodedPath.split("/").pop() ?? "";
        const extension = lastSegment.includes(".")
            ? `.${lastSegment.split(".").pop()?.toLowerCase()}`
            : "";

        return !extension || allowedDocumentExtensions.has(extension);
    } catch {
        return false;
    }
};

router.use(authenticate, requireActiveUser);

router.post(
    "/",
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
            .custom(isSafeDocumentUrl)
            .withMessage("documentUrls must reference a supported document type"),
        body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 2000 }),
    ],
    submitVerification,
);

router.get(
    "/me",
    [
        query("latestOnly").optional().isBoolean().withMessage("latestOnly must be boolean").toBoolean(),
        query("status").optional().isIn(hostVerificationStatusValues).withMessage("status is invalid"),
        query("verificationType")
            .optional()
            .isIn(hostVerificationTypeValues)
            .withMessage("verificationType is invalid"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("limit must be between 1 and 100").toInt(),
    ],
    getMyVerifications,
);

export default router;
