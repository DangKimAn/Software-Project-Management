/**
 * Bộ điều phối HTTP kiểm duyệt chỗ ở dành cho quản trị viên:
 * - Tiếp nhận request, trích xuất ngữ cảnh kiểm toán (IP, User-Agent, `actorId`) và gọi tầng dịch vụ duyệt/từ chối/chuyển nhượng chủ nhà cho listing.
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
    AdminListingQuery,
    RejectListingInput,
    approveAdminListing,
    getAdminListingDetail,
    listAdminListings,
    listPendingAdminListings,
    rejectAdminListing,
    transferAdminListingHost,
} from "./admin.service";

/**
 * Liệt kê phân trang danh sách chỗ ở cho quản trị viên theo bộ lọc trạng thái (`pending_approval`, `active`, `rejected`, `inactive`, `all`).
 */
export const listAllAdminListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<AdminListingQuery>(req);
    const result = await listAdminListings(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Liệt kê phân trang danh sách các chỗ ở đang chờ quản trị viên kiểm duyệt.
 */
export const listPendingListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<AdminListingQuery>(req);
    const result = await listPendingAdminListings(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Trả về thông tin chi tiết đầy đủ của một chỗ ở phục vụ kiểm duyệt quản trị.
 */
export const getAdminListingDetailHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const detail = await getAdminListingDetail(params.listingId);

    return sendSuccess(res, {
        data: detail,
    });
});

/**
 * Phê duyệt chỗ ở đủ điều kiện hiển thị công khai và ghi nhận ngữ cảnh kiểm toán.
 */
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

/**
 * Chuyển quyền sở hữu chỗ ở sang một tài khoản chủ nhà hợp lệ khác.
 */
export const transferListingHostHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const body = getValidatedBody<{ newHostId: number }>(req);
    const result = await transferAdminListingHost(params.listingId, body.newHostId, req.user!, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Listing ownership transferred",
        data: result,
    });
});

/**
 * Từ chối xuất bản chỗ ở kèm lý do phản hồi cho chủ nhà.
 */
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
