/**
 * Bộ điều phối HTTP quản lý vòng đời đơn đặt phòng (`bookings`) cho cả khách lưu trú (`guest`) và chủ nhà (`host`):
 * - Xử lý đặt phòng đơn lẻ/hàng loạt, tra cứu lịch sử, hủy đơn phía khách và xác nhận/check-in/check-out/hủy đơn phía chủ nhà.
 */

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

/**
 * Khởi tạo đơn đặt phòng đơn lẻ cho khách, khóa lịch giữ chỗ tạm thời chờ thanh toán.
 */
export const createGuestBooking: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<CreateBookingInput>(req);
    const result = await createBooking(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Booking created",
        data: result,
    });
});

/**
 * Khởi tạo đồng thời nhiều đơn đặt phòng trong một yêu cầu đặt gộp của khách.
 */
export const createGuestBulkBookings: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<CreateBulkBookingInput>(req);
    const result = await createBulkBookings(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Bookings created",
        data: result,
    });
});

/**
 * Liệt kê lịch sử và trạng thái các đơn đặt phòng của khách đang đăng nhập.
 */
export const getMyGuestBookings: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBookingsQuery>(req);
    const result = await getMyBookings(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn thông tin chi tiết một đơn đặt phòng thuộc quyền sở hữu của khách.
 */
export const getGuestBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await getGuestBookingDetail(req.user!, params.bookingId);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Thực hiện hủy đơn đặt phòng từ phía khách theo quy tắc trạng thái và chính sách hoàn hủy.
 */
export const cancelGuestBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const payload = getValidatedBody<CancelBookingInput>(req);
    const result = await cancelGuestBooking(req.user!, params.bookingId, payload);

    return sendSuccess(res, {
        message: "Booking cancelled",
        data: result,
    });
});

/**
 * Liệt kê danh sách các đơn đặt phòng phát sinh tại các chỗ ở thuộc quyền quản lý của chủ nhà.
 */
export const getHostBookingList: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBookingsQuery>(req);
    const result = await getHostBookings(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn chi tiết đơn đặt phòng dành cho chủ nhà sở hữu chỗ ở tương ứng.
 */
export const getHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await getHostBookingDetail(req.user!, params.bookingId);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Xác nhận chấp thuận đơn đặt phòng từ phía chủ nhà.
 */
export const confirmHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await confirmHostBooking(req.user!, params.bookingId);

    return sendSuccess(res, {
        message: "Booking confirmed",
        data: result,
    });
});

/**
 * Ghi nhận trạng thái khách đã nhận phòng (`checked_in`) cho đơn đặt phòng.
 */
export const checkInHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await checkInHostBooking(req.user!, params.bookingId);

    return sendSuccess(res, {
        message: "Booking checked in",
        data: result,
    });
});

/**
 * Ghi nhận trạng thái khách đã trả phòng (`checked_out`) hoàn tất kỳ lưu trú.
 */
export const checkOutHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const result = await checkOutHostBooking(req.user!, params.bookingId);

    return sendSuccess(res, {
        message: "Booking checked out",
        data: result,
    });
});

/**
 * Thực hiện hủy hoặc từ chối đơn đặt phòng từ phía chủ nhà kèm lý do.
 */
export const cancelHostBookingById: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ bookingId: number }>(req);
    const payload = getValidatedBody<CancelBookingInput>(req);
    const result = await cancelHostBooking(req.user!, params.bookingId, payload);

    return sendSuccess(res, {
        message: "Booking cancelled",
        data: result,
    });
});
