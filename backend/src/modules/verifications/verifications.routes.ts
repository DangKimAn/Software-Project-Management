import express from "express";

import adminVerificationsRoutes from "./admin-verifications.routes";
import hostVerificationsRoutes from "./host-verifications.routes";

const router = express.Router();

router.use("/host", hostVerificationsRoutes);
router.use("/admin", adminVerificationsRoutes);

export default router;
