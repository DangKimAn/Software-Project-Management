import express from "express";

import { getLatestExchangeRates } from "./exchange-rates.controller";

const router = express.Router();

router.get("/", getLatestExchangeRates);

export default router;
