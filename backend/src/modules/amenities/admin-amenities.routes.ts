import express from "express";
import { body, param } from "express-validator";

import {
    createAdminAmenity,
    deleteAdminAmenity,
    getAdminAmenities,
    updateAdminAmenity,
} from "./amenities.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";

const router = express.Router();

const amenityIdParamValidator = param("amenityId")
    .isInt({ min: 1 })
    .withMessage("amenityId must be a positive integer")
    .toInt();

router.use(authenticate, requireRole("admin"));

router.get("/", getAdminAmenities);

router.post(
    "/",
    [
        body("name").isString().trim().notEmpty().withMessage("name is required").isLength({ max: 255 }),
        body("icon").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("isActive").optional().isBoolean().withMessage("isActive must be boolean").toBoolean(),
    ],
    createAdminAmenity,
);

router.patch(
    "/:amenityId",
    [
        amenityIdParamValidator,
        body("name").optional().isString().trim().notEmpty().withMessage("name cannot be empty").isLength({ max: 255 }),
        body("icon").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("isActive").optional().isBoolean().withMessage("isActive must be boolean").toBoolean(),
    ],
    updateAdminAmenity,
);

router.delete("/:amenityId", [amenityIdParamValidator], deleteAdminAmenity);

export default router;
