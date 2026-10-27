import express from "express";

import {
    cancelGuestBookingById,
    cancelHostBookingById,
    checkInHostBookingById,
    checkOutHostBookingById,
    confirmHostBookingById,
    createGuestBulkBookings,
    createGuestBooking,
    getGuestBookingById,
    getHostBookingById,
    getHostBookingList,
    getMyGuestBookings,
} from "./bookings.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireHostOnly, requireRole } from "../../middlewares/require-role.middleware";
import { getBookingCreateRateLimiter } from "../../middlewares/rate-limit.middleware";
import { validate } from "../../middlewares/validate";
import {
    bookingIdParamSchema,
    bookingsQuerySchema,
    cancelBookingBodySchema,
    createBulkBookingBodySchema,
    createBookingBodySchema,
} from "./bookings.validator";

const router = express.Router();
export const hostBookingsRoutes = express.Router();

router.use(authenticate, requireRole("guest", "host", "admin"));

router.post("/bulk", getBookingCreateRateLimiter(), validate({ body: createBulkBookingBodySchema }), createGuestBulkBookings);
router.post("/", getBookingCreateRateLimiter(), validate({ body: createBookingBodySchema }), createGuestBooking);
router.get("/mine", validate({ query: bookingsQuerySchema }), getMyGuestBookings);
router.get("/:bookingId", validate({ params: bookingIdParamSchema }), getGuestBookingById);
router.post(
    "/:bookingId/cancel",
    validate({ params: bookingIdParamSchema, body: cancelBookingBodySchema }),
    cancelGuestBookingById,
);

hostBookingsRoutes.use(authenticate, requireHostOnly);

hostBookingsRoutes.get("/", validate({ query: bookingsQuerySchema }), getHostBookingList);
hostBookingsRoutes.get("/:bookingId", validate({ params: bookingIdParamSchema }), getHostBookingById);
hostBookingsRoutes.patch("/:bookingId/confirm", validate({ params: bookingIdParamSchema }), confirmHostBookingById);
hostBookingsRoutes.post("/:bookingId/check-in", validate({ params: bookingIdParamSchema }), checkInHostBookingById);
hostBookingsRoutes.patch("/:bookingId/check-in", validate({ params: bookingIdParamSchema }), checkInHostBookingById);
hostBookingsRoutes.post("/:bookingId/check-out", validate({ params: bookingIdParamSchema }), checkOutHostBookingById);
hostBookingsRoutes.patch("/:bookingId/check-out", validate({ params: bookingIdParamSchema }), checkOutHostBookingById);
hostBookingsRoutes.patch(
    "/:bookingId/cancel",
    validate({ params: bookingIdParamSchema, body: cancelBookingBodySchema }),
    cancelHostBookingById,
);

export default router;
