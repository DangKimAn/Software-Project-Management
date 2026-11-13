import type { RequestHandler } from "express";

import { sendError, sendSuccess } from "../../common/http";
import { getExchangeRatesService } from "./exchange-rates.service";
import { ExchangeRatesUnavailableError } from "./exchange-rates.types";

export const getLatestExchangeRates: RequestHandler = async (_req, res, next) => {
    try {
        const payload = await getExchangeRatesService().getExchangeRates();
        res.setHeader("Cache-Control", "public, max-age=300, stale-while-revalidate=3600");
        return sendSuccess(res, {
            message: "Exchange rates retrieved",
            data: payload,
        });
    } catch (error) {
        if (error instanceof ExchangeRatesUnavailableError) {
            res.setHeader("Cache-Control", "no-store");
            if (error.retryAfterSeconds !== undefined) {
                res.setHeader("Retry-After", String(error.retryAfterSeconds));
            }
            return sendError(res, error.statusCode, error.message, error.details ?? {}, error.code);
        }
        return next(error);
    }
};
