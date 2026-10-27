import { z } from "zod";

export const amenityIdParamSchema = z.object({
    amenityId: z.coerce.number().int().positive(),
});

