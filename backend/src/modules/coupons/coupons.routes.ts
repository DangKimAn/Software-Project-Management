/**
 * Định tuyến HTTP kiểm tra mã giảm giá của khách và quản trị mã giảm giá (`adminCouponsRoutes`):
 * - Áp dụng middleware xác thực (`authenticate`), giới hạn tần suất dò mã giảm giá (`Limiter`), phân quyền `admin` cho nhánh quản trị và kiểm chứng `validate`.
 */

import express from "express";

import {
    createAdminCouponRequest,
    deleteAdminCouponRequest,
    getAdminCoupons,
    updateAdminCouponRequest,
    validateCoupon,
} from "./coupons.controller";
import { authenticate, optionalAuthenticate } from "../../middlewares/authenticate.middleware";
import { getCouponValidateRateLimiter } from "../../middlewares/rate-limit.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { validate } from "../../middlewares/validate";
import {
    couponIdParamSchema,
    couponListQuerySchema,
    createCouponBodySchema,
    updateCouponBodySchema,
    validateCouponQuerySchema,
} from "./coupons.validator";

const router = express.Router();

router.get(
    "/validate",
    optionalAuthenticate,
    getCouponValidateRateLimiter(),
    validate({ query: validateCouponQuerySchema }),
    validateCoupon,
);

export const adminCouponsRoutes = express.Router();

adminCouponsRoutes.use(authenticate, requireRole("admin"));
adminCouponsRoutes.get("/", validate({ query: couponListQuerySchema }), getAdminCoupons);
adminCouponsRoutes.post("/", validate({ body: createCouponBodySchema }), createAdminCouponRequest);
adminCouponsRoutes.patch(
    "/:couponId",
    validate({ params: couponIdParamSchema, body: updateCouponBodySchema }),
    updateAdminCouponRequest,
);
adminCouponsRoutes.delete(
    "/:couponId",
    validate({ params: couponIdParamSchema }),
    deleteAdminCouponRequest,
);

export default router;
