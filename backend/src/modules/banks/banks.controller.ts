import type { RequestHandler } from "express";

import { sendSuccess } from "../../common/http";
import { vietnamBanks } from "../../constants/vietnamBanks";

export const listVietnamBanks: RequestHandler = (_req, res) =>
    sendSuccess(res, {
        data: {
            items: vietnamBanks,
        },
    });
