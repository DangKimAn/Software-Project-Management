/**
 * Bộ điều phối HTTP cho phân hệ mã giảm giá khuyến mãi (`coupons`):
 * - Hỗ trợ khách kiểm tra tính hợp lệ/mức giảm của mã khuyến mãi khi đặt phòng và hỗ trợ quản trị viên quản lý vòng đời mã giảm giá (CRUD).
 */

import type { Request, RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    createAdminCoupon,
    CreateCouponInput,
    deleteAdminCoupon,
    listAdminCoupons,
    ListCouponsQuery,
    updateAdminCoupon,
    UpdateCouponInput,
    validateCouponForUser,
    ValidateCouponInput,
} from "./coupons.service";

const auditContextFromRequest = (req: Request) => ({
    ipAddress: req.ip,
    userAgent: req.get("user-agent") ?? null,
});

/**
 * Kiểm tra điều kiện áp dụng và tính toán số tiền giảm giá dự kiến của mã khuyến mãi cho đơn đặt phòng.
 */
export const validateCoupon: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ValidateCouponInput>(req);
    const result = await validateCouponForUser(req.user ?? null, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Liệt kê phân trang danh sách mã giảm giá phục vụ quản trị.
 */
export const getAdminCoupons: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListCouponsQuery>(req);
    const result = await listAdminCoupons(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Tạo mới mã giảm giá khuyến mãi từ phía quản trị viên.
 */
export const createAdminCouponRequest: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<CreateCouponInput>(req);
    const result = await createAdminCoupon(req.user!, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        statusCode: 201,
        message: "Coupon created",
        data: result,
    });
});

/**
 * Cập nhật thông số, hạn dùng hoặc trạng thái kích hoạt của mã giảm giá.
 */
export const updateAdminCouponRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ couponId: number }>(req);
    const payload = getValidatedBody<UpdateCouponInput>(req);
    const result = await updateAdminCoupon(req.user!, params.couponId, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Coupon updated",
        data: result,
    });
});

/**
 * Xóa mềm mã giảm giá theo `couponId` kèm ghi nhật ký kiểm toán.
 */
export const deleteAdminCouponRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ couponId: number }>(req);
    await deleteAdminCoupon(req.user!, params.couponId, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Coupon deleted",
    });
});
