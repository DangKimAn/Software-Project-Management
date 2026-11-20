/**
 * Bộ điều phối HTTP phân tích chất lượng và gắn nhãn tự động ảnh chỗ ở bằng AI Vision:
 * - Điều phối các yêu cầu phân tích đơn lẻ/hàng loạt ảnh phòng, truy vấn kết quả đánh giá, cập nhật nhãn (tags), xóa ảnh của chủ nhà và phân tích lại từ phía quản trị viên.
 */

import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import { toHostActor } from "../host-listings/host-listings.service";
import {
    analyzeListingImage,
    analyzeListingImages,
    deleteImageByIdForHost,
    getListingImageAnalysis,
    reanalyzeImageAsAdmin,
    updateImageTags,
} from "./listing-image-vision.service";

/**
 * Phân tích chất lượng và gắn thẻ phân loại bằng AI cho một ảnh chỗ ở cụ thể.
 */
export const analyzeSingleListingImage: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number; imageId: number }>(req);
    const result = await analyzeListingImage(params.listingId, params.imageId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: result.aiAnalysisStatus === "analyzed" ? "Image analyzed" : "Image analysis failed",
        data: result,
    });
});

/**
 * Kích hoạt phân tích hàng loạt toàn bộ hình ảnh của một chỗ ở bằng AI Vision.
 */
export const analyzeAllListingImages: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const query = getValidatedQuery<{ force?: boolean; limit?: number }>(req);
    const result = await analyzeListingImages(params.listingId, toHostActor(req.user!), {
        force: Boolean(query.force),
        limit: query.limit,
    });

    return sendSuccess(res, {
        message: `Analyzed ${result.analyzedCount} image(s), failed ${result.failedCount}`,
        data: result,
    });
});

/**
 * Truy vấn kết quả phân tích AI và nhãn phân loại của toàn bộ ảnh thuộc chỗ ở.
 */
export const getHostListingImageAnalysis: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getListingImageAnalysis(params.listingId, toHostActor(req.user!));

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Cập nhật thủ công danh sách nhãn phân loại của một ảnh chỗ ở thuộc quyền quản lý của chủ nhà.
 */
export const updateHostImageTags: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ imageId: number }>(req);
    const payload = getValidatedBody<{ tags: string[] }>(req);
    const result = await updateImageTags(params.imageId, toHostActor(req.user!), payload.tags);

    return sendSuccess(res, {
        message: "Image tags updated",
        data: result,
    });
});

/**
 * Xóa một hình ảnh chỗ ở thuộc quyền sở hữu của chủ nhà.
 */
export const deleteHostImageById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ imageId: number }>(req);
    const result = await deleteImageByIdForHost(params.imageId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Image deleted",
        data: result,
    });
});

/**
 * Yêu cầu chạy phân tích AI lại từ đầu đối với một hình ảnh chỗ ở từ phía quản trị viên.
 */
export const reanalyzeAdminImage: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ imageId: number }>(req);
    const result = await reanalyzeImageAsAdmin(params.imageId);

    return sendSuccess(res, {
        message: result.aiAnalysisStatus === "analyzed" ? "Image reanalyzed" : "Image analysis failed",
        data: result,
    });
});
