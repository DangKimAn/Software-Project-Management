/**
 * Bộ điều phối HTTP quản lý danh sách chỗ ở dành riêng cho chủ nhà (`host-listings`):
 * - Điều phối tạo/cập nhật/khôi phục/xóa mềm chỗ ở, quản lý lịch giá và khóa ngày hàng loạt, tải/xóa/đặt ảnh bìa, cập nhật tiện ích, nội quy và xem đánh giá.
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
import {
    addListingImages,
    AddListingImagesInput,
    bulkUpdateListingCalendar,
    BulkCalendarUpdateInput,
    createListing,
    CreateListingInput,
    deleteListing,
    deleteListingImage,
    getHostListingReviews,
    HostListingReviewsQuery,
    getListingCalendar,
    GetCalendarQuery,
    getListingDetail,
    getMyListings,
    ListMineQuery,
    replaceListingAmenities,
    restoreListing,
    ReplaceAmenitiesInput,
    setListingImageCover,
    toHostActor,
    updateListing,
    UpdateListingInput,
    updateListingRules,
    UpdateRulesInput,
} from "./host-listings.service";

/**
 * Tạo mới hồ sơ chỗ ở cho chủ nhà ở trạng thái nháp hoặc gửi chờ duyệt.
 */
export const createHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreateListingInput>(req);
    const result = await createListing(req.user!.id, payload, {
        isAdmin: req.user!.roles.includes("admin"),
    });

    return sendSuccess(res, {
        statusCode: 201,
        message: "Listing created",
        data: result,
    });
});

/**
 * Liệt kê phân trang các chỗ ở thuộc quyền sở hữu của chủ nhà hiện tại.
 */
export const getMyHostListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<ListMineQuery>(req);
    const result = await getMyListings(toHostActor(req.user!), queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn dữ liệu lịch trống, ngày khóa và giá theo ngày của một chỗ ở.
 */
export const getHostListingCalendar: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<GetCalendarQuery>(req);
    const result = await getListingCalendar(params.listingId, toHostActor(req.user!), queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Cập nhật hàng loạt trạng thái mở/khóa lịch và giá tùy chỉnh trên dải ngày của chỗ ở.
 */
export const bulkUpdateHostListingCalendar: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<BulkCalendarUpdateInput>(req);
    const result = await bulkUpdateListingCalendar(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Calendar updated",
        data: result,
    });
});

/**
 * Đính kèm thêm danh sách hình ảnh mới vào hồ sơ chỗ ở của chủ nhà.
 */
export const addHostListingImages: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<AddListingImagesInput>(req);
    const result = await addListingImages(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Images added",
        data: result,
    });
});

/**
 * Xóa một hình ảnh khỏi bộ sưu tập ảnh của chỗ ở.
 */
export const deleteHostListingImage: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number; imageId: number }>(req);
    await deleteListingImage(params.listingId, params.imageId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Image deleted",
    });
});

/**
 * Đặt một hình ảnh làm ảnh đại diện chính (cover) của chỗ ở.
 */
export const setHostListingImageCover: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number; imageId: number }>(req);
    const result = await setListingImageCover(params.listingId, params.imageId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Cover image updated",
        data: result,
    });
});

/**
 * Thay thế đồng bộ danh sách tiện ích gắn với chỗ ở của chủ nhà.
 */
export const replaceHostListingAmenities: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<ReplaceAmenitiesInput>(req);
    const result = await replaceListingAmenities(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Amenities updated",
        data: result,
    });
});

/**
 * Cập nhật quy định nhận/trả phòng và nội quy lưu trú của chỗ ở.
 */
export const updateHostListingRules: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<UpdateRulesInput>(req);
    const result = await updateListingRules(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Rules updated",
        data: result,
    });
});

/**
 * Truy vấn danh sách đánh giá của khách đối với một chỗ ở cụ thể của chủ nhà.
 */
export const getHostListingReviewsById: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<HostListingReviewsQuery>(req);
    const result = await getHostListingReviews(params.listingId, toHostActor(req.user!), queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn đầy đủ thông tin cấu hình chi tiết của chỗ ở dành cho chủ nhà sở hữu.
 */
export const getHostListingDetail: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getListingDetail(params.listingId, toHostActor(req.user!));

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Cập nhật thông tin mô tả, giá cơ sở, sức chứa và vị trí của chỗ ở.
 */
export const updateHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<UpdateListingInput>(req);
    const result = await updateListing(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Listing updated",
        data: result,
    });
});

/**
 * Khôi phục chỗ ở đã ẩn/lưu trữ trở lại trạng thái hoạt động hợp lệ.
 */
export const restoreHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await restoreListing(params.listingId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Listing restored",
        data: result,
    });
});

/**
 * Xóa mềm hoặc ngừng khai thác chỗ ở theo yêu cầu của chủ nhà.
 */
export const deleteHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    await deleteListing(params.listingId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Listing deleted",
    });
});
