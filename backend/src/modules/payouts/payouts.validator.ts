import { z } from "zod";

export const payoutIdParamSchema = z.object({
    payoutId: z.coerce.number().int().positive(),
});

