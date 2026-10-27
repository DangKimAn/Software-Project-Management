import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    cancelGuestBooking,
    cancelHostBooking,
    CancelBookingInput,
    checkInHostBooking,
    checkOutHostBooking,
    confirmHostBooking,
    createBulkBookings,
    createBooking,
    CreateBulkBookingInput,
    CreateBookingInput,
    getGuestBookingDetail,
    getHostBookingDetail,
    getHostBookings,
    getMyBookings,
    ListBookingsQuery,
} from "./bookings.service";

export const createGuestBooking: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<CreateBookingInput>(req);
    const result = await createBooking(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Booking created",
        data: result,
    });
});

export const createGuestBulkBookings: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<CreateBulkBookingInput>(req);
    const result = await createBulkBookings(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Bookings created",
        data: result,
    });
});

export const getMyGuestBookings: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBookingsQuery>(req);
    const result = await getMyBookings(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const getGuestBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await getGuestBookingDetail(req.user!, params.bookingId);

    return sendSuccess(res, {
        data: result,
    });
});

export const cancelGuestBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const payload = getValidatedBody<CancelBookingInput>(req);
    const result = await cancelGuestBooking(req.user!, params.bookingId, payload);

    return sendSuccess(res, {
        message: "Booking cancelled",
        data: result,
    });
});

export const getHostBookingList: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBookingsQuery>(req);
    const result = await getHostBookings(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const getHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await getHostBookingDetail(req.user!, params.bookingId);

    return sendSuccess(res, {
        data: result,
    });
});

export const confirmHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await confirmHostBooking(req.user!, params.bookingId);

    return sendSuccess(res, {
        message: "Booking confirmed",
        data: result,
    });
});

export const checkInHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await checkInHostBooking(req.user!, params.bookingId);

    return sendSuccess(res, {
        message: "Booking checked in",
        data: result,
    });
});

export const checkOutHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await checkOutHostBooking(req.user!, params.bookingId);

    return sendSuccess(res, {
        message: "Booking checked out",
        data: result,
    });
});

export const cancelHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const payload = getValidatedBody<CancelBookingInput>(req);
    const result = await cancelHostBooking(req.user!, params.bookingId, payload);

    return sendSuccess(res, {
        message: "Booking cancelled",
        data: result,
    });
});
