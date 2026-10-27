import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedBody, getValidatedParams } from "../../common/validation";
import {
    createReview,
    CreateReviewInput,
    createReviewReply,
    CreateReviewReplyInput,
    deleteReview,
    updateReview,
    UpdateReviewInput,
} from "./reviews.service";

export const createGuestReview: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreateReviewInput>(req);
    const result = await createReview(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Review created",
        data: result,
    });
});

export const updateGuestReview: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ reviewId: number }>(req);
    const payload = getValidatedBody<UpdateReviewInput>(req);
    const result = await updateReview(req.user!, params.reviewId, payload);

    return sendSuccess(res, {
        message: "Review updated",
        data: result,
    });
});

export const deleteGuestReview: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ reviewId: number }>(req);
    await deleteReview(req.user!, params.reviewId);

    return sendSuccess(res, {
        message: "Review deleted",
    });
});

export const createHostReviewReply: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ reviewId: number }>(req);
    const payload = getValidatedBody<CreateReviewReplyInput>(req);
    const result = await createReviewReply(req.user!, params.reviewId, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Reply created",
        data: result,
    });
});
