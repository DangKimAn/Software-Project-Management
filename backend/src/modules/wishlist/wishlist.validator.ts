/**
 * Lược đồ kiểm chứng tham số đường dẫn `listingId` bằng Zod cho phân hệ danh sách yêu thích (`wishlist`).
 */

import { z } from "zod";

/**
 * Schema kiểm chứng tham số đường dẫn `listingId` nguyên dương cho thao tác danh sách yêu thích.
 */
export const wishlistListingIdParamSchema = z.object({
    listingId: z.coerce.number().int().positive(),
});
