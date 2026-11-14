/**
 * Định tuyến HTTP danh sách yêu thích cá nhân (`/api/wishlist`):
 * - Bắt buộc xác thực phiên (`authenticate`) và kiểm chứng định danh `listingId` (`validate`) trên các thao tác thêm/xóa.
 */

import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { validate } from "../../middlewares/validate";
import {
    addMyWishlistListing,
    getMyWishlist,
    removeMyWishlistListing,
} from "./wishlist.controller";
import { wishlistListingIdParamSchema } from "./wishlist.validator";

const router = express.Router();

router.use(authenticate);
router.get("/", getMyWishlist);
router.post("/:listingId", validate({ params: wishlistListingIdParamSchema }), addMyWishlistListing);
router.delete("/:listingId", validate({ params: wishlistListingIdParamSchema }), removeMyWishlistListing);

export default router;
