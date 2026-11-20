/**
 * Bộ điều phối HTTP quản lý danh sách chỗ ở yêu thích của người dùng (`wishlist`):
 * - Điều phối truy vấn danh sách yêu thích hiện tại, thêm chỗ ở vào danh sách và gỡ bỏ chỗ ở khỏi danh sách yêu thích.
 */

import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { getValidatedParams } from "../../common/validation";
import {
    addListingToWishlist,
    listMyWishlist,
    removeListingFromWishlist,
} from "./wishlist.service";

/**
 * Truy vấn danh sách các chỗ ở nằm trong mục yêu thích của người dùng hiện tại.
 */
export const getMyWishlist: RequestHandler = asyncHandler(async (req, res) => {
    const result = await listMyWishlist(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Thêm một chỗ ở vào danh sách yêu thích cá nhân một cách bất biến.
 */
export const addMyWishlistListing: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await addListingToWishlist(req.user!, params.listingId);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Listing saved",
        data: result,
    });
});

/**
 * Gỡ bỏ một chỗ ở khỏi danh sách yêu thích của người dùng hiện tại.
 */
export const removeMyWishlistListing: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await removeListingFromWishlist(req.user!, params.listingId);

    return sendSuccess(res, {
        message: "Listing removed from wishlist",
        data: result,
    });
});
