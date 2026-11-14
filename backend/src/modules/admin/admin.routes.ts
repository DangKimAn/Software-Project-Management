/**
 * Định tuyến HTTP tổng hợp của phân hệ quản trị (`/api/admin`):
 * - Gắn kết tập trung các nhánh router con gồm tiện ích (`amenities`), bài viết (`blogs`), đơn đăng ký chủ nhà (`host-applications`),
 *   xác minh KYC (`verifications`), chỗ ở (`listings`), người dùng (`users`), chi trả (`host-payouts`), mã giảm giá (`coupons`), báo cáo (`reports`) và biểu phí (`fees`).
 */

import express from "express";

import adminAmenitiesRoutes from "../amenities/admin-amenities.routes";
import { adminBlogsRoutes } from "../blogs/blogs.routes";
// CONFLICT-RESOLVED: Gắn router xét duyệt KYC và chi trả từ hai phân hệ hợp nhất `host-kyc` và `payouts`.
import {
    adminHostApplicationsRouter as adminHostApplicationRoutes,
    adminVerificationsRouter as adminVerificationsRoutes,
} from "../host-kyc/host-kyc.routes";
import { adminHostPayoutsRouter as adminHostPayoutsRoutes } from "../payouts/payouts.routes";
import adminListingsRoutes from "./admin-listings.routes";
import adminUsersRoutes from "./admin-users.routes";
import { adminCouponsRoutes } from "../coupons/coupons.routes";
import { adminReportsRouter } from "../reports/reports.routes";
import adminFeesRoutes from "./admin-fees.routes";
import adminRefundsRoutes from "../refunds/admin-refunds.routes";

const router = express.Router();

router.use("/amenities", adminAmenitiesRoutes);
router.use("/blogs", adminBlogsRoutes);
router.use("/host-applications", adminHostApplicationRoutes);
router.use("/verifications", adminVerificationsRoutes);
router.use("/listings", adminListingsRoutes);
router.use("/users", adminUsersRoutes);
router.use("/host-payouts", adminHostPayoutsRoutes);
router.use("/refunds", adminRefundsRoutes);
router.use("/coupons", adminCouponsRoutes);
router.use("/reports", adminReportsRouter);
router.use("/fees", adminFeesRoutes);

export default router;
