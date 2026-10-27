import { z } from "zod";

const isoDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "date must use YYYY-MM-DD format");

export const reportRangeQuerySchema = z
    .object({
        from: isoDateSchema.optional(),
        to: isoDateSchema.optional(),
    })
    .refine((value) => !value.from || !value.to || value.from <= value.to, {
        message: "to must be greater than or equal to from",
        path: ["to"],
    });
