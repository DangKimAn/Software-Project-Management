import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedParams, getValidatedQuery } from "../../common/validation";
import {
    getPublicListingAvailability,
    getPublicListingDetail,
    getPublicListingReviews,
    getPublicListingRules,
    getPublicListings,
    PublicListingAvailabilityQuery,
    PublicListingReviewsQuery,
    PublicListingsQuery,
} from "./listings.service";

export const listPublicListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<PublicListingsQuery>(req);
    const result = await getPublicListings(queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const getPublicListingAvailabilityById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<PublicListingAvailabilityQuery>(req);
    const result = await getPublicListingAvailability(params.listingId, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const getPublicListingReviewsById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<PublicListingReviewsQuery>(req);
    const result = await getPublicListingReviews(params.listingId, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const getPublicListingRulesById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getPublicListingRules(params.listingId);

    return sendSuccess(res, {
        data: result,
    });
});

export const getPublicListingDetailById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getPublicListingDetail(params.listingId);

    return sendSuccess(res, {
        data: result,
    });
});
