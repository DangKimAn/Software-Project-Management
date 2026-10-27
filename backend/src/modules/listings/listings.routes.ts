import express from "express";
import { param, query } from "express-validator";

import { isValidIsoDate } from "../../common/validation";
import { isValidLocationGroup } from "../../common/vung-tau-location-groups";
import {
    getPublicListingAvailabilityById,
    getPublicListingDetailById,
    getPublicListingReviewsById,
    getPublicListingRulesById,
    listPublicListings,
} from "./listings.controller";
import {
    publicListingSortValues,
    publicListingsMaxPageLimit,
} from "./listings.service";

const router = express.Router();

const listingIdParamValidator = param("listingId")
    .isInt({ min: 1 })
    .withMessage("listingId must be a positive integer")
    .toInt();

router.get(
    "/",
    [
        query("q")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("q must be a non-empty string")
            .isLength({ max: 255 })
            .withMessage("q must be 255 characters or fewer"),
        query("city")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("city must be a non-empty string")
            .isLength({ max: 255 }),
        query("district")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("district must be a non-empty string")
            .isLength({ max: 255 }),
        query("checkIn")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("checkIn must use YYYY-MM-DD format"),
        query("checkOut")
            .optional()
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("checkOut must use YYYY-MM-DD format")
            .custom((value, { req }) => !req.query?.checkIn || String(req.query.checkIn) < String(value))
            .withMessage("checkOut must be after checkIn"),
        query("guests").optional().isInt({ min: 1 }).withMessage("guests must be at least 1").toInt(),
        query("propertyType")
            .optional()
            .isIn(["apartment", "villa", "hotel", "homestay"])
            .withMessage("propertyType is invalid"),
        query("roomType")
            .optional()
            .isIn(["entire_place", "private_room", "shared_room"])
            .withMessage("roomType is invalid"),
        query("priceMin").optional().isFloat({ min: 0 }).withMessage("priceMin must be 0 or more").toFloat(),
        query("priceMax")
            .optional()
            .isFloat({ min: 0 })
            .withMessage("priceMax must be 0 or more")
            .custom((value, { req }) => {
                const minValue = req.query?.priceMin ?? req.query?.minPrice;
                return minValue === undefined || Number(value) >= Number(minValue);
            })
            .withMessage("priceMax must be greater than or equal to priceMin")
            .toFloat(),
        query("minPrice").optional().isFloat({ min: 0 }).withMessage("minPrice must be 0 or more").toFloat(),
        query("maxPrice")
            .optional()
            .isFloat({ min: 0 })
            .withMessage("maxPrice must be 0 or more")
            .custom((value, { req }) => {
                const minValue = req.query?.minPrice ?? req.query?.priceMin;
                return minValue === undefined || Number(value) >= Number(minValue);
            })
            .withMessage("maxPrice must be greater than or equal to minPrice")
            .toFloat(),
        query("amenities").optional().isString().trim().notEmpty().withMessage("amenities must be a non-empty string"),
        query("locationGroup")
            .optional()
            .isString()
            .trim()
            .custom((value) => isValidLocationGroup(String(value)))
            .withMessage("locationGroup is invalid"),
        query("lat")
            .optional()
            .isFloat({ min: -90, max: 90 })
            .withMessage("lat must be a number between -90 and 90")
            .toFloat(),
        query("lng")
            .optional()
            .isFloat({ min: -180, max: 180 })
            .withMessage("lng must be a number between -180 and 180")
            .toFloat(),
        query("radius")
            .optional()
            .isFloat({ min: 1, max: 10000 })
            .withMessage("radius must be between 1 and 10000")
            .toFloat(),
        query("sort").optional().isIn(publicListingSortValues).withMessage("sort is invalid"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: publicListingsMaxPageLimit })
            .withMessage(`limit must be between 1 and ${publicListingsMaxPageLimit}`)
            .toInt(),
    ],
    listPublicListings,
);

router.get(
    "/:listingId/availability",
    [
        listingIdParamValidator,
        query("month").optional().isInt({ min: 1, max: 12 }).withMessage("month must be between 1 and 12").toInt(),
        query("year").optional().isInt({ min: 2000, max: 2100 }).withMessage("year is invalid").toInt(),
    ],
    getPublicListingAvailabilityById,
);

router.get(
    "/:listingId/reviews",
    [
        listingIdParamValidator,
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: publicListingsMaxPageLimit })
            .withMessage(`limit must be between 1 and ${publicListingsMaxPageLimit}`)
            .toInt(),
        query("rating").optional().isInt({ min: 1, max: 5 }).withMessage("rating must be between 1 and 5").toInt(),
    ],
    getPublicListingReviewsById,
);

router.get(
    "/:listingId/rules",
    [listingIdParamValidator],
    getPublicListingRulesById,
);

router.get(
    "/:listingId",
    [listingIdParamValidator],
    getPublicListingDetailById,
);

export default router;
