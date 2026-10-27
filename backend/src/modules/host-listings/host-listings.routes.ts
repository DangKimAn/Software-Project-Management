import express from "express";
import type { RequestHandler } from "express";
import { body, param, query } from "express-validator";

import { ApiError } from "../../common/api-error";
import { listingApiStatuses } from "../../common/listing-mappers";
import { isValidIsoDate, isValidTime } from "../../common/validation";
import {
    addHostListingImages,
    bulkUpdateHostListingCalendar,
    createHostListing,
    deleteHostListing,
    deleteHostListingImage,
    getHostListingCalendar,
    getHostListingDetail,
    getMyHostListings,
    replaceHostListingAmenities,
    setHostListingImageCover,
    updateHostListing,
    updateHostListingRules,
} from "./host-listings.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireHostOnly } from "../../middlewares/require-role.middleware";
import { hostListingsMaxPageLimit } from "./host-listings.service";

const router = express.Router();

const listingIdParamValidator = param("listingId")
    .isInt({ min: 1 })
    .withMessage("listingId must be a positive integer")
    .toInt();

const imageIdParamValidator = param("imageId")
    .isInt({ min: 1 })
    .withMessage("imageId must be a positive integer")
    .toInt();

const normalizeDecimalInput = (value: unknown) => (typeof value === "string" ? value.trim().replace(",", ".") : value);

const rejectDirectListingImageUpload: RequestHandler = (_req, _res, next) => {
    next(new ApiError(410, "Direct image upload is disabled. Use /api/uploads/presign and save the R2 URL."));
};

router.use(authenticate, requireHostOnly);

router.post(
    "/",
    [
        body("title").isString().trim().notEmpty().withMessage("title is required").isLength({ max: 255 }),
        body("description").isString().trim().notEmpty().withMessage("description is required").isLength({ max: 5000 }),
        body("addressLine").isString().trim().notEmpty().withMessage("addressLine is required").isLength({ max: 255 }),
        body("ward").isString().trim().notEmpty().withMessage("ward is required").isLength({ max: 255 }),
        body("district").optional({ nullable: true, checkFalsy: true }).isString().trim().isLength({ max: 255 }),
        body("city").optional({ nullable: true, checkFalsy: true }).isString().trim().isLength({ max: 255 }),
        body("stateRegion").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("country").equals("VN").withMessage("country must be VN"),
        body("postalCode").optional({ nullable: true }).isString().trim().isLength({ max: 32 }),
        body("latitude")
            .customSanitizer(normalizeDecimalInput)
            .isFloat({ min: -90, max: 90 })
            .withMessage("latitude is invalid")
            .toFloat(),
        body("longitude")
            .customSanitizer(normalizeDecimalInput)
            .isFloat({ min: -180, max: 180 })
            .withMessage("longitude is invalid")
            .toFloat(),
        body("propertyType")
            .isIn(["apartment", "villa", "hotel", "homestay"])
            .withMessage("propertyType is invalid"),
        body("roomType")
            .isIn(["entire_place", "private_room", "shared_room"])
            .withMessage("roomType is invalid"),
        body("maxGuests").isInt({ min: 1 }).withMessage("maxGuests must be at least 1").toInt(),
        body("bedrooms").isInt({ min: 0 }).withMessage("bedrooms must be 0 or more").toInt(),
        body("beds").isInt({ min: 1 }).withMessage("beds must be at least 1").toInt(),
        body("bathrooms").isFloat({ min: 0.5 }).withMessage("bathrooms must be at least 0.5").toFloat(),
        body("basePrice").isFloat({ min: 0 }).withMessage("basePrice must be 0 or more").toFloat(),
        body("weekendPrice").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("weekendPrice must be 0 or more").toFloat(),
        body("cleaningFee").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("cleaningFee must be 0 or more").toFloat(),
        body("surchargeAmount").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("surchargeAmount must be 0 or more").toFloat(),
        body("extraGuestFee").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("extraGuestFee must be 0 or more").toFloat(),
        body("includedGuests").optional({ nullable: true }).isInt({ min: 1 }).withMessage("includedGuests must be at least 1").toInt(),
        body("serviceFeePct")
            .optional({ nullable: true })
            .isFloat({ min: 0, max: 100 })
            .withMessage("serviceFeePct must be between 0 and 100")
            .toFloat(),
        body("currency").equals("VND").withMessage("currency must be VND"),
        body("minNights").isInt({ min: 1 }).withMessage("minNights must be at least 1").toInt(),
        body("maxNights").optional({ nullable: true }).isInt({ min: 1 }).withMessage("maxNights must be at least 1").toInt(),
        body("checkInFrom")
            .custom((value) => isValidTime(String(value)))
            .withMessage("checkInFrom must use HH:mm format"),
        body("checkOutBefore")
            .custom((value) => isValidTime(String(value)))
            .withMessage("checkOutBefore must use HH:mm format"),
        body("cancellationPolicy")
            .isIn(["flexible", "moderate", "strict"])
            .withMessage("cancellationPolicy is invalid"),
        body("instantBookEnabled").isBoolean().withMessage("instantBookEnabled must be boolean").toBoolean(),
        body("amenityIds").optional().isArray().withMessage("amenityIds must be an array"),
        body("amenityIds.*").optional().isInt({ min: 1 }).withMessage("amenityIds must contain positive integers").toInt(),
        body("status")
            .optional()
            .isIn(["draft", "pending_approval"])
            .withMessage("status must be draft or pending_approval"),
    ],
    createHostListing,
);

router.get(
    "/mine",
    [
        query("status").optional().isIn(listingApiStatuses).withMessage("status is invalid"),
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit")
            .optional()
            .isInt({ min: 1, max: hostListingsMaxPageLimit })
            .withMessage(`limit must be between 1 and ${hostListingsMaxPageLimit}`)
            .toInt(),
    ],
    getMyHostListings,
);

router.get(
    "/:listingId/calendar",
    [
        listingIdParamValidator,
        query("month").optional().isInt({ min: 1, max: 12 }).withMessage("month must be between 1 and 12").toInt(),
        query("year").optional().isInt({ min: 2000, max: 2100 }).withMessage("year is invalid").toInt(),
    ],
    getHostListingCalendar,
);

router.patch(
    "/:listingId/calendar/bulk",
    [
        listingIdParamValidator,
        body("dates").isArray({ min: 1 }).withMessage("dates must be a non-empty array"),
        body("dates.*")
            .custom((value) => isValidIsoDate(String(value)))
            .withMessage("dates must use YYYY-MM-DD format"),
        body("isAvailable").optional().isBoolean().withMessage("isAvailable must be boolean").toBoolean(),
        body("isBlockedByHost").optional().isBoolean().withMessage("isBlockedByHost must be boolean").toBoolean(),
        body("priceOverride")
            .optional({ nullable: true })
            .isFloat({ min: 0 })
            .withMessage("priceOverride must be 0 or more")
            .toFloat(),
        body("minNightsOverride")
            .optional({ nullable: true })
            .isInt({ min: 1 })
            .withMessage("minNightsOverride must be at least 1")
            .toInt(),
        body("notes").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
    ],
    bulkUpdateHostListingCalendar,
);

router.post(
    "/:listingId/images",
    [
        listingIdParamValidator,
        body().custom((value) => {
            if (Array.isArray(value?.images) && value.images.length >= 1 && value.images.length <= 30) {
                return true;
            }

            if (typeof value?.url === "string" && value.url.trim().length > 0) {
                return true;
            }

            throw new Error("Provide either url or images with between 1 and 30 items");
        }),
        body("images").optional().isArray({ min: 1, max: 30 }).withMessage("images must contain between 1 and 30 items"),
        body("images.*.url")
            .optional()
            .isURL({ protocols: ["http", "https"], require_protocol: true })
            .withMessage("images.url must be a valid URL"),
        body("images.*.key").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
        body("images.*.objectKey").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
        body("images.*.originalFilename").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("images.*.displayTitle").optional({ nullable: true }).isString().trim().isLength({ max: 120 }),
        body("images.*.altText").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
        body("images.*.caption").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("images.*.sortOrder")
            .optional()
            .isInt({ min: 0 })
            .withMessage("images.sortOrder must be 0 or more")
            .toInt(),
        body("images.*.isCover").optional().isBoolean().withMessage("images.isCover must be boolean").toBoolean(),
        body("url")
            .optional()
            .isURL({ protocols: ["http", "https"], require_protocol: true })
            .withMessage("url must be a valid URL"),
        body("key").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
        body("objectKey").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
        body("originalFilename").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("displayTitle").optional({ nullable: true }).isString().trim().isLength({ max: 120 }),
        body("altText").optional({ nullable: true }).isString().trim().isLength({ max: 500 }),
        body("caption").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("sortOrder")
            .optional()
            .isInt({ min: 0 })
            .withMessage("sortOrder must be 0 or more")
            .toInt(),
        body("isCover").optional().isBoolean().withMessage("isCover must be boolean").toBoolean(),
    ],
    addHostListingImages,
);

router.patch(
    "/:listingId/images/:imageId/cover",
    [listingIdParamValidator, imageIdParamValidator],
    setHostListingImageCover,
);

router.post(
    "/:listingId/images/upload",
    [listingIdParamValidator],
    rejectDirectListingImageUpload,
);

router.delete(
    "/:listingId/images/:imageId",
    [listingIdParamValidator, imageIdParamValidator],
    deleteHostListingImage,
);

router.put(
    "/:listingId/amenities",
    [
        listingIdParamValidator,
        body("amenityIds").isArray().withMessage("amenityIds must be an array"),
        body("amenityIds.*").optional().isInt({ min: 1 }).withMessage("amenityIds must contain positive integers").toInt(),
    ],
    replaceHostListingAmenities,
);

router.patch(
    "/:listingId/rules",
    [
        listingIdParamValidator,
        body("checkInFrom")
            .optional()
            .custom((value) => isValidTime(String(value)))
            .withMessage("checkInFrom must use HH:mm format"),
        body("checkOutBefore")
            .optional()
            .custom((value) => isValidTime(String(value)))
            .withMessage("checkOutBefore must use HH:mm format"),
        body("smokingAllowed").optional().isBoolean().withMessage("smokingAllowed must be boolean").toBoolean(),
        body("petsAllowed").optional().isBoolean().withMessage("petsAllowed must be boolean").toBoolean(),
        body("partyAllowed").optional().isBoolean().withMessage("partyAllowed must be boolean").toBoolean(),
        body("quietHours").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
    ],
    updateHostListingRules,
);

router.get(
    "/:listingId",
    [listingIdParamValidator],
    getHostListingDetail,
);

router.patch(
    "/:listingId",
    [
        listingIdParamValidator,
        body("title").optional().isString().trim().notEmpty().withMessage("title cannot be empty").isLength({ max: 255 }),
        body("description")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("description cannot be empty")
            .isLength({ max: 5000 }),
        body("addressLine")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("addressLine cannot be empty")
            .isLength({ max: 255 }),
        body("ward").optional().isString().trim().notEmpty().withMessage("ward cannot be empty").isLength({ max: 255 }),
        body("district")
            .optional()
            .isString()
            .trim()
            .notEmpty()
            .withMessage("district cannot be empty")
            .isLength({ max: 255 }),
        body("city").optional().isString().trim().notEmpty().withMessage("city cannot be empty").isLength({ max: 255 }),
        body("stateRegion").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
        body("country").optional().equals("VN").withMessage("country must be VN"),
        body("postalCode").optional({ nullable: true }).isString().trim().isLength({ max: 32 }),
        body("latitude")
            .optional()
            .customSanitizer(normalizeDecimalInput)
            .isFloat({ min: -90, max: 90 })
            .withMessage("latitude is invalid")
            .toFloat(),
        body("longitude")
            .optional()
            .customSanitizer(normalizeDecimalInput)
            .isFloat({ min: -180, max: 180 })
            .withMessage("longitude is invalid")
            .toFloat(),
        body("propertyType")
            .optional()
            .isIn(["apartment", "villa", "hotel", "homestay"])
            .withMessage("propertyType is invalid"),
        body("roomType")
            .optional()
            .isIn(["entire_place", "private_room", "shared_room"])
            .withMessage("roomType is invalid"),
        body("basePrice").optional().isFloat({ min: 0 }).withMessage("basePrice must be 0 or more").toFloat(),
        body("weekendPrice").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("weekendPrice must be 0 or more").toFloat(),
        body("cleaningFee").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("cleaningFee must be 0 or more").toFloat(),
        body("surchargeAmount").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("surchargeAmount must be 0 or more").toFloat(),
        body("extraGuestFee").optional({ nullable: true }).isFloat({ min: 0 }).withMessage("extraGuestFee must be 0 or more").toFloat(),
        body("includedGuests").optional({ nullable: true }).isInt({ min: 1 }).withMessage("includedGuests must be at least 1").toInt(),
        body("serviceFeePct")
            .optional({ nullable: true })
            .isFloat({ min: 0, max: 100 })
            .withMessage("serviceFeePct must be between 0 and 100")
            .toFloat(),
        body("maxGuests").optional().isInt({ min: 1 }).withMessage("maxGuests must be at least 1").toInt(),
        body("bedrooms").optional().isInt({ min: 0 }).withMessage("bedrooms must be 0 or more").toInt(),
        body("beds").optional().isInt({ min: 1 }).withMessage("beds must be at least 1").toInt(),
        body("bathrooms").optional().isFloat({ min: 0.5 }).withMessage("bathrooms must be at least 0.5").toFloat(),
        body("minNights").optional().isInt({ min: 1 }).withMessage("minNights must be at least 1").toInt(),
        body("maxNights").optional({ nullable: true }).isInt({ min: 1 }).withMessage("maxNights must be at least 1").toInt(),
        body("cancellationPolicy")
            .optional()
            .isIn(["flexible", "moderate", "strict"])
            .withMessage("cancellationPolicy is invalid"),
        body("instantBookEnabled").optional().isBoolean().withMessage("instantBookEnabled must be boolean").toBoolean(),
        body("status").optional().isIn(listingApiStatuses).withMessage("status is invalid"),
    ],
    updateHostListing,
);

router.delete(
    "/:listingId",
    [listingIdParamValidator],
    deleteHostListing,
);

export default router;
