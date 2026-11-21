/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ tiện ích (`amenities`), ràng buộc định dạng tham số đường dẫn `amenityId`.
 */

import { z } from "zod";

/**
 * Schema kiểm chứng tham số đường dẫn `amenityId` là số nguyên dương hợp lệ.
 */
export const amenityIdParamSchema = z.object({
    amenityId: z.coerce.number().int().positive(),
});

