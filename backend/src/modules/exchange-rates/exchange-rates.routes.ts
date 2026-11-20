/**
 * Định tuyến HTTP công khai tra cứu tỷ giá tiền tệ (`/api/exchange-rates`).
 */

import express from "express";

import { getLatestExchangeRates } from "./exchange-rates.controller";

const router = express.Router();

router.get("/", getLatestExchangeRates);

export default router;
