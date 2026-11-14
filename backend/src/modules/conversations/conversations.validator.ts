/**
 * Lược đồ kiểm chứng tham số đường dẫn `conversationId` bằng Zod cho phân hệ hội thoại (`conversations`).
 */

import { z } from "zod";

/**
 * Schema kiểm chứng tham số định danh cuộc hội thoại `conversationId`.
 */
export const conversationIdParamSchema = z.object({
    conversationId: z.coerce.number().int().positive(),
});

