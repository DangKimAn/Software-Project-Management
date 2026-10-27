import { z } from "zod";

export const reviewIdParamSchema = z.object({
    reviewId: z.coerce.number().int().positive(),
});

export const createReviewBodySchema = z.object({
    bookingId: z.coerce.number().int().positive(),
    rating: z.coerce.number().int().min(1).max(5),
    comment: z.string().trim().max(2000).optional().nullable(),
});

