import express from "express";
import { body } from "express-validator";

import { getMyHostApplication, registerHost } from "./host-onboarding.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { hostEntityTypeValues } from "../../models/host-application";

const router = express.Router();

const normalizeHostRegisterPayload: express.RequestHandler = (req, _res, next) => {
    if (req.body?.entityType === undefined) {
        req.body.entityType = req.body?.hostType ?? req.body?.businessType ?? req.body?.type;
    }

    next();
};
router.get("/application/me", authenticate, getMyHostApplication);
router.get("/register/status", authenticate, getMyHostApplication);
router.post(
    "/register",
    authenticate,
    normalizeHostRegisterPayload,
    [
        body("contactName").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("contactEmail").optional({ nullable: true }).isEmail().withMessage("contactEmail is invalid").normalizeEmail(),
        body("contactPhone")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("contactPhone is required")
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
    registerHost,
);

export default router;
