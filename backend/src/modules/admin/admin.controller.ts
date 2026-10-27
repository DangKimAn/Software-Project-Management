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
    AdminListingQuery,
    RejectListingInput,
    approveAdminListing,
    getAdminListingDetail,
    listPendingAdminListings,
    rejectAdminListing,
} from "./admin.service";

export const listPendingListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<AdminListingQuery>(req);
    const result = await listPendingAdminListings(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const getAdminListingDetailHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const detail = await getAdminListingDetail(params.listingId);

    return sendSuccess(res, {
        data: detail,
    });
});

export const approveListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await approveAdminListing(params.listingId, req.user!, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Listing approved",
        data: result,
    });
});

export const rejectListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<RejectListingInput>(req);
    const result = await rejectAdminListing(params.listingId, req.user!, payload, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Listing rejected",
        data: result,
    });
});
