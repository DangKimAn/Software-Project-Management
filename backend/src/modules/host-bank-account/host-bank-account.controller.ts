import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    getHostBankAccount,
    saveHostBankAccount,
    type SaveHostBankAccountInput,
} from "./host-bank-account.service";

export const getMyHostBankAccount: RequestHandler = asyncHandler(async (req, res) => {
    const account = await getHostBankAccount(req.user!);

    return sendSuccess(res, {
        data: account,
    });
});

export const saveMyHostBankAccount: RequestHandler = asyncHandler(async (req, res) => {
    const account = await saveHostBankAccount(req.user!, req.body as SaveHostBankAccountInput);

    return sendSuccess(res, {
        message: "Đã lưu thông tin tài khoản ngân hàng",
        data: account,
    });
});
