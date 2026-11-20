/**
 * Bộ điều phối HTTP khám phá và tìm kiếm chỗ ở công khai (`listings`):
 * - Phục vụ tìm kiếm/lọc danh sách phòng đang hoạt động, xem chi tiết chỗ ở, kiểm tra lịch trống khả dụng, đọc đánh giá và nội quy lưu trú.
 */

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

/**
 * Tìm kiếm và phân trang danh sách chỗ ở đang hoạt động theo bộ lọc địa điểm, ngày lưu trú, số khách và khoảng giá.
 */
export const listPublicListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<PublicListingsQuery>(req);
    const result = await getPublicListings(queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Kiểm tra lịch trống và tính khả dụng lưu trú của một chỗ ở công khai.
 */
export const getPublicListingAvailabilityById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<PublicListingAvailabilityQuery>(req);
    const result = await getPublicListingAvailability(params.listingId, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn phân trang các đánh giá công khai của khách từng lưu trú tại chỗ ở.
 */
export const getPublicListingReviewsById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<PublicListingReviewsQuery>(req);
    const result = await getPublicListingReviews(params.listingId, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn nội quy lưu trú và chính sách nhận/trả phòng công khai của chỗ ở.
 */
export const getPublicListingRulesById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getPublicListingRules(params.listingId);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn thông tin chi tiết công khai của chỗ ở phục vụ trang xem phòng và đặt chỗ.
 */
export const getPublicListingDetailById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getPublicListingDetail(params.listingId);

    return sendSuccess(res, {
        data: result,
    });
});
