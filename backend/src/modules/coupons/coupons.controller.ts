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

export const validateCoupon: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ValidateCouponInput>(req);
    const result = await validateCouponForUser(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const getAdminCoupons: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListCouponsQuery>(req);
    const result = await listAdminCoupons(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const createAdminCouponRequest: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<CreateCouponInput>(req);
    const result = await createAdminCoupon(req.user!, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        statusCode: 201,
        message: "Coupon created",
        data: result,
    });
});

export const updateAdminCouponRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ couponId: number }>(req);
    const payload = getValidatedBody<UpdateCouponInput>(req);
    const result = await updateAdminCoupon(req.user!, params.couponId, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Coupon updated",
        data: result,
    });
});

export const deleteAdminCouponRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ couponId: number }>(req);
    await deleteAdminCoupon(req.user!, params.couponId, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Coupon deleted",
    });
});
