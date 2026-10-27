import { z } from "zod";

export const conversationIdParamSchema = z.object({
    conversationId: z.coerce.number().int().positive(),
});

