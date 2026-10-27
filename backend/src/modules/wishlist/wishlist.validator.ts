import { z } from "zod";

export const wishlistListingIdParamSchema = z.object({
    listingId: z.coerce.number().int().positive(),
});
