import express from "express";

import { listVietnamBanks } from "./banks.controller";

const router = express.Router();

router.get("/vn", listVietnamBanks);

export default router;
