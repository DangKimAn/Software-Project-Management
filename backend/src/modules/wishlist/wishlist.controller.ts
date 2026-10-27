import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { getValidatedParams } from "../../common/validation";
import {
    addListingToWishlist,
    listMyWishlist,
    removeListingFromWishlist,
} from "./wishlist.service";

export const getMyWishlist: RequestHandler = asyncHandler(async (req, res) => {
    const result = await listMyWishlist(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});

export const addMyWishlistListing: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await addListingToWishlist(req.user!, params.listingId);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Listing saved",
        data: result,
    });
});

export const removeMyWishlistListing: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await removeListingFromWishlist(req.user!, params.listingId);

    return sendSuccess(res, {
        message: "Listing removed from wishlist",
        data: result,
    });
});
