import express from "express";
import { body } from "express-validator";

import { isValidIsoDate } from "../../common/validation";
import {
    aiListingSearch,
    semanticSearchListings,
} from "./semantic-search.controller";

const router = express.Router();
export const aiListingSearchRouter = express.Router();

router.post(
    "/semantic",
    [
        body("query")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("query is required")
            .isLength({ max: 500 })
            .withMessage("query must be at most 500 characters"),

        body("checkIn")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("checkIn must use YYYY-MM-DD format"),

        body("checkOut")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("checkOut must use YYYY-MM-DD format")
            .custom((value, { req }) => !req.body?.checkIn || String(req.body.checkIn) < String(value))
            .withMessage("checkOut must be after checkIn"),

        body("guests")
            .optional()
            .isInt({ min: 1 })
            .withMessage("guests must be at least 1")
            .toInt(),

        body("city")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .isLength({ max: 255 }),

        body("district")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .isLength({ max: 255 }),

        body("minPrice")
            .optional()
            .isFloat({ min: 0 })
            .withMessage("minPrice must be 0 or more")
            .toFloat(),

        body("maxPrice")
            .optional()
            .isFloat({ min: 0 })
            .withMessage("maxPrice must be 0 or more")
            .custom((value, { req }) => req.body?.minPrice === undefined || Number(value) >= Number(req.body.minPrice))
            .withMessage("maxPrice must be greater than or equal to minPrice")
            .toFloat(),

        body("amenities")
            .optional()
            .isArray()
            .withMessage("amenities must be an array"),

        body("amenities.*")
            .optional()
            .custom((value) => ["string", "number"].includes(typeof value))
            .withMessage("amenities values must be strings or numbers"),

        body("locationGroup")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .isLength({ max: 120 })
            .withMessage("locationGroup is invalid"),

        body("propertyType")
            .optional()
            .isIn(["apartment", "villa", "hotel", "homestay"])
            .withMessage("propertyType is invalid"),

        body("roomType")
            .optional()
            .isIn(["entire_place", "private_room", "shared_room"])
            .withMessage("roomType is invalid"),

        body("page")
            .optional()
            .isInt({ min: 1 })
            .withMessage("page must be at least 1")
            .toInt(),

        body("limit")
            .optional()
            .isInt({ min: 1, max: 30 })
            .withMessage("limit must be between 1 and 30")
            .toInt(),
    ],
    semanticSearchListings,
);

aiListingSearchRouter.post(
    "/",
    [
        body("query")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("query is required")
            .isLength({ max: 500 })
            .withMessage("query must be at most 500 characters"),

        body("limit")
            .optional()
            .isInt({ min: 1, max: 30 })
            .withMessage("limit must be between 1 and 30")
            .toInt(),

        body("filters")
            .optional()
            .isObject()
            .withMessage("filters must be an object"),

        body("filters.city")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("filters.city must be a non-empty string")
            .isLength({ max: 255 }),

        body("filters.minPrice")
            .optional()
            .isFloat({ min: 0 })
            .withMessage("filters.minPrice must be 0 or more")
            .toFloat(),

        body("filters.maxPrice")
            .optional()
            .isFloat({ min: 0 })
            .withMessage("filters.maxPrice must be 0 or more")
            .custom((value, { req }) =>
                req.body?.filters?.minPrice === undefined ||
                Number(value) >= Number(req.body.filters.minPrice),
            )
            .withMessage("filters.maxPrice must be greater than or equal to filters.minPrice")
            .toFloat(),

        body("filters.guests")
            .optional()
            .isInt({ min: 1 })
            .withMessage("filters.guests must be at least 1")
            .toInt(),

        body("filters.checkIn")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("filters.checkIn must use YYYY-MM-DD format"),

        body("filters.checkOut")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("filters.checkOut must use YYYY-MM-DD format")
            .custom((value, { req }) => !req.body?.filters?.checkIn || String(req.body.filters.checkIn) < String(value))
            .withMessage("filters.checkOut must be after filters.checkIn"),

        body("filters.amenities")
            .optional()
            .isArray()
            .withMessage("filters.amenities must be an array"),

        body("filters.amenities.*")
            .optional()
            .custom((value) => ["string", "number"].includes(typeof value))
            .withMessage("filters.amenities values must be strings or numbers"),

        body("filters.locationGroup")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .isLength({ max: 120 })
            .withMessage("filters.locationGroup is invalid"),

        body("filters.propertyType")
            .optional()
            .isIn(["apartment", "villa", "hotel", "homestay"])
            .withMessage("filters.propertyType is invalid"),

        body("filters.roomType")
            .optional()
            .isIn(["entire_place", "private_room", "shared_room"])
            .withMessage("filters.roomType is invalid"),
    ],
    aiListingSearch,
);

export default router;
