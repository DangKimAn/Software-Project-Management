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
