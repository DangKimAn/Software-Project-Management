import express from "express";

import adminHostPayoutsRoutes from "./admin-host-payouts.routes";
import hostPayoutsRoutes from "./host-payouts.routes";

const router = express.Router();

router.use("/host", hostPayoutsRoutes);
router.use("/admin", adminHostPayoutsRoutes);

export default router;
