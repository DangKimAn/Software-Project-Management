/**
 * Bộ điều phối HTTP quản trị cấu hình phí dịch vụ nền tảng (Platform Fee):
 * - Tiếp nhận yêu cầu từ quản trị viên để tra cứu mức phí hiện hành, đặt lịch thay đổi phí và hủy lịch thay đổi phí.
 */

import { Request, Response, RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import {
    cancelScheduledPlatformFee,
    getCurrentPlatformFeeStatus,
    schedulePlatformFeeChange,
} from "./admin-fees.service";

/**
 * Trả về cấu hình tỷ lệ phí dịch vụ nền tảng hiện hành và lịch thay đổi phí sắp tới (nếu có).
 */
export const getCurrentPlatformFeeStatusHandler: RequestHandler = asyncHandler(async (_req: Request, res: Response) => {
    const data = await getCurrentPlatformFeeStatus();
    res.status(200).json({
        success: true,
        message: "Lấy trạng thái phí nền tảng thành công",
        data,
    });
});

/**
 * Đặt lịch áp dụng mức phí nền tảng mới vào thời điểm hiệu lực xác định.
 */
export const schedulePlatformFeeChangeHandler: RequestHandler = asyncHandler(async (req: Request, res: Response) => {
    const { feePct, reason } = req.body;
    const adminUserId = Number((req as any).user?.userId ?? 1);

    const data = await schedulePlatformFeeChange({
        feePct: Number(feePct),
        reason: typeof reason === "string" ? reason : undefined,
        adminUserId,
    });

    res.status(201).json({
        success: true,
        message: "Lên lịch điều chỉnh phí nền tảng thành công (hiệu lực sau 7 ngày). Đã gửi thông báo đến các Host.",
        data,
    });
});

/**
 * Hủy bỏ lịch thay đổi phí dịch vụ nền tảng đang chờ áp dụng.
 */
export const cancelScheduledPlatformFeeHandler: RequestHandler = asyncHandler(async (req: Request, res: Response) => {
    const adminUserId = Number((req as any).user?.userId ?? 1);
    const data = await cancelScheduledPlatformFee(adminUserId);

    res.status(200).json({
        success: true,
        message: data.message,
        data,
    });
});
