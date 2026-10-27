import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    approveHostVerification,
    ApproveVerificationInput,
    CreateVerificationInput,
    getAdminVerifications,
    AdminVerificationQuery,
    getMyHostVerifications,
    MyVerificationQuery,
    rejectHostVerification,
    RejectVerificationInput,
    submitHostVerification,
} from "./verifications.service";

export const submitVerification: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreateVerificationInput>(req);
    const result = await submitHostVerification(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Verification submitted",
        data: result,
    });
});

export const getMyVerifications: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<MyVerificationQuery>(req);
    const result = await getMyHostVerifications(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const listAdminVerifications: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<AdminVerificationQuery>(req);
    const result = await getAdminVerifications(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const approveVerification: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ verificationId: number }>(req);
    const payload = getValidatedBody<ApproveVerificationInput>(req);
    const result = await approveHostVerification(params.verificationId, req.user!, payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Verification approved",
        data: result,
    });
});

export const rejectVerification: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ verificationId: number }>(req);
    const payload = getValidatedBody<RejectVerificationInput>(req);
    const result = await rejectHostVerification(params.verificationId, req.user!, payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Verification rejected",
        data: result,
    });
});
