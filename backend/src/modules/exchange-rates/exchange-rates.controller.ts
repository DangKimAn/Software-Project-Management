/**
 * Bộ điều phối HTTP tra cứu tỷ giá quy đổi ngoại tệ tham khảo từ đồng cơ sở VND (`exchange-rates`):
 * - Gắn header kiểm soát bộ nhớ đệm ngắn hạn và ủy quyền lấy bảng tỷ giá mới nhất (kèm cơ chế dự phòng cache) cho tầng dịch vụ.
 */

import type { RequestHandler } from "express";

import { sendError, sendSuccess } from "../../common/http";
import { getExchangeRatesService } from "./exchange-rates.service";
import { ExchangeRatesUnavailableError } from "./exchange-rates.types";

/**
 * Xử lý yêu cầu HTTP trả về bảng tỷ giá quy đổi từ VND sang USD/KRW kèm siêu dữ liệu nguồn và độ tươi dữ liệu.
 */
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
