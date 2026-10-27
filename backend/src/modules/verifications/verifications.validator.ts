import { z } from "zod";

export const verificationIdParamSchema = z.object({
    verificationId: z.coerce.number().int().positive(),
});

