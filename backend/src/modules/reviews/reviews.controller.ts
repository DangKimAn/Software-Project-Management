/**
 * Bộ điều phối HTTP quản lý đánh giá sau lưu trú của khách và phản hồi từ chủ nhà (`reviews`):
 * - Điều phối tạo mới, chỉnh sửa, xóa đánh giá của khách đặt phòng và đăng phản hồi công khai của chủ nhà.
 */

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

/**
 * Tạo mới đánh giá và chấm điểm của khách sau khi hoàn tất kỳ lưu trú hợp lệ.
 */
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

/**
 * Cập nhật nội dung nhận xét hoặc điểm đánh giá do chính khách đã đăng.
 */
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

/**
 * Xóa đánh giá lưu trú theo yêu cầu của khách sở hữu đánh giá.
 */
export const deleteGuestReview: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ reviewId: number }>(req);
    await deleteReview(req.user!, params.reviewId);

    return sendSuccess(res, {
        message: "Review deleted",
    });
});

/**
 * Đăng nội dung phản hồi công khai của chủ nhà đối với đánh giá từ khách.
 */
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
