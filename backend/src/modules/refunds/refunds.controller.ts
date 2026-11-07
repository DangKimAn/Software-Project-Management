import { RequestHandler } from "express";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedParams, getValidatedQuery } from "../../common/validation";
import {
    listAdminRefunds,
    approveAndDisburseRefund,
    rejectRefund,
    AdminRefundListQuery,
} from "./refunds.service";

export const listAdminRefundsHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AdminRefundListQuery>(req);
    const result = await listAdminRefunds(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const approveRefundHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ refundId: number }>(req);
    const { bankName, accountNumber, accountName, notes } = req.body ?? {};

    const result = await approveAndDisburseRefund({
        refundId: params.refundId,
        actorUserId: Number(req.user!.id),
        bankName: bankName ? String(bankName).trim() : undefined,
        accountNumber: accountNumber ? String(accountNumber).trim() : undefined,
        accountName: accountName ? String(accountName).trim() : undefined,
        notes: notes ? String(notes).trim() : undefined,
    });

    return sendSuccess(res, {
        message: "Hoàn tiền thành công",
        data: result,
    });
});

export const rejectRefundHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ refundId: number }>(req);
    const reason = String(req.body?.reason ?? "").trim();

    const result = await rejectRefund({
        refundId: params.refundId,
        actorUserId: Number(req.user!.id),
        reason,
    });

    return sendSuccess(res, {
        message: "Đã từ chối hoàn tiền",
        data: result,
    });
});
