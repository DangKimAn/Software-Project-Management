/**
 * Lược đồ kiểm chứng tham số đường dẫn `payoutId` bằng Zod cho phân hệ quyết toán chi trả (`payouts`).
 */

import { z } from "zod";

/**
 * Schema kiểm chứng tham số đường dẫn `payoutId` nguyên dương.
 */
export const payoutIdParamSchema = z.object({
    payoutId: z.coerce.number().int().positive(),
});

