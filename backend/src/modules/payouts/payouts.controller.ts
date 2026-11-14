/**
 * Bộ điều phối HTTP hợp nhất quản lý danh mục ngân hàng Việt Nam, tài khoản thụ hưởng Chủ nhà
 * và quy trình đối soát/giải ngân doanh thu (`modules/payouts`).
 */
// CONFLICT-RESOLVED: Hợp nhất Controller từ `modules/banks/`, `modules/host-bank-account/` và `modules/payouts/`
// về một tệp điều phối duy nhất, loại bỏ ba phân hệ ngân hàng/chi trả chồng chéo.
import type { Request, RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
// CONFLICT-RESOLVED: Trỏ các hàm xử lý chi trả và rút tiền mới (`disburseHostPayout`, `requestHostPayout`) qua namespace `payoutsService` đồng nhất với `payoutAccountsService`.
import * as payoutAccountsService from "./payout-accounts.service";
import * as payoutsService from "./payouts.service";
import { vietnamBanks } from "./vietnam-banks.data";

const auditContextFromRequest = (req: Request) => ({
    ipAddress: req.ip,
    userAgent: req.get("user-agent") ?? null,
});

export const listVietnamBanks: RequestHandler = (_req, res) =>
    sendSuccess(res, {
        data: {
            items: vietnamBanks,
        },
    });

export const getMyHostBankAccount: RequestHandler = asyncHandler(async (req, res) => {
    const account = await payoutAccountsService.getHostBankAccount(req.user!);

    return sendSuccess(res, {
        data: account,
    });
});

export const saveMyHostBankAccount: RequestHandler = asyncHandler(async (req, res) => {
    const account = await payoutAccountsService.saveHostBankAccount(
        req.user!,
        req.body as payoutAccountsService.SaveHostBankAccountInput,
    );

    return sendSuccess(res, {
        message: "Đã lưu thông tin tài khoản ngân hàng",
        data: account,
    });
});

export const listPayoutAccounts: RequestHandler = asyncHandler(async (req, res) => {
    const result = await payoutsService.getHostPayoutAccounts(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});

export const createNewPayoutAccount: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<payoutAccountsService.CreatePayoutAccountInput>(req);
    const result = await payoutsService.createPayoutAccount(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Payout account created",
        data: result,
    });
});

export const updateExistingPayoutAccount: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ payoutAccountId: number }>(req);
    const payload = getValidatedBody<payoutAccountsService.UpdatePayoutAccountInput>(req);
    const result = await payoutsService.updatePayoutAccount(
        req.user!,
        params.payoutAccountId,
        payload,
    );

    return sendSuccess(res, {
        message: "Payout account updated",
        data: result,
    });
});

export const deleteExistingPayoutAccount: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ payoutAccountId: number }>(req);
    await payoutsService.deletePayoutAccount(req.user!, params.payoutAccountId);

    return sendSuccess(res, {
        message: "Payout account deleted",
    });
});

export const listHostPayouts: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<payoutsService.PayoutListQuery>(req);
    const result = await payoutsService.getHostPayouts(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const listAdminHostPayouts: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<payoutsService.AdminPayoutListQuery>(req);
    const result = await payoutsService.getAdminHostPayouts(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const createAdminHostPayout: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<payoutsService.CreateHostPayoutInput>(req);
    const result = await payoutsService.createHostPayout(
        req.user!,
        payload,
        auditContextFromRequest(req),
    );

    return sendSuccess(res, {
        statusCode: 201,
        message: "Payout created",
        data: result,
    });
});

export const approveHostPayoutHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ payoutId: number }>(req);
    const payout = await payoutsService.approveHostPayout({
        payoutId: params.payoutId,
        actorUserId: Number(req.user!.id),
    });

    return sendSuccess(res, {
        data: payout,
    });
});

export const rejectHostPayoutHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ payoutId: number }>(req);
    const payout = await payoutsService.rejectHostPayout({
        payoutId: params.payoutId,
        actorUserId: Number(req.user!.id),
        reason: String(req.body.reason ?? ""),
    });

    return sendSuccess(res, {
        data: payout,
    });
});

export const markHostPayoutPaidHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ payoutId: number }>(req);
    const payout = await payoutsService.markHostPayoutPaid({
        payoutId: params.payoutId,
        actorUserId: Number(req.user!.id),
        transferReference: String(req.body.transferReference ?? ""),
    });

    return sendSuccess(res, {
        data: payout,
    });
});

// CONFLICT-RESOLVED: Bổ sung endpoint giải ngân tự động Admin (`disburseHostPayoutHandler`) và yêu cầu rút tiền Chủ nhà (`requestHostPayoutHandler`) từ `origin/develop` qua namespace `payoutsService`.
export const disburseHostPayoutHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ payoutId: number }>(req);
    const result = await payoutsService.disburseHostPayout({
        payoutId: params.payoutId,
        actorUserId: Number(req.user!.id),
    });

    return sendSuccess(res, {
        message: "Chi trả tiền cho Host thành công",
        data: result,
    });
});

export const requestHostPayoutHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const body = getValidatedBody<payoutsService.RequestHostPayoutInput>(req);
    const result = await payoutsService.requestHostPayout(req.user!, body, auditContextFromRequest(req));

    return sendSuccess(res, {
        statusCode: 201,
        message: "Yêu cầu rút tiền đã được gửi thành công, vui lòng chờ Admin kiểm duyệt",
        data: result,
    });
});
