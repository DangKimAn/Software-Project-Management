import express from "express";

import adminAmenitiesRoutes from "../amenities/admin-amenities.routes";
import { adminBlogsRoutes } from "../blogs/blogs.routes";
import adminHostApplicationRoutes from "./admin-host-application.routes";
import adminHostPayoutsRoutes from "../payouts/admin-host-payouts.routes";
import adminListingsRoutes from "./admin-listings.routes";
import adminUsersRoutes from "./admin-users.routes";
import adminVerificationsRoutes from "../verifications/admin-verifications.routes";
import { adminCouponsRoutes } from "../coupons/coupons.routes";
import { adminReportsRouter } from "../reports/reports.routes";

const router = express.Router();

router.use("/amenities", adminAmenitiesRoutes);
router.use("/blogs", adminBlogsRoutes);
router.use("/host-applications", adminHostApplicationRoutes);
router.use("/verifications", adminVerificationsRoutes);
router.use("/listings", adminListingsRoutes);
router.use("/users", adminUsersRoutes);
router.use("/host-payouts", adminHostPayoutsRoutes);
router.use("/coupons", adminCouponsRoutes);
router.use("/reports", adminReportsRouter);

export default router;
