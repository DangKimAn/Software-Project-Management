import { Request, Response, RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import {
    cancelScheduledPlatformFee,
    getCurrentPlatformFeeStatus,
    schedulePlatformFeeChange,
} from "./admin-fees.service";

export const getCurrentPlatformFeeStatusHandler: RequestHandler = asyncHandler(async (_req: Request, res: Response) => {
    const data = await getCurrentPlatformFeeStatus();
    res.status(200).json({
        success: true,
        message: "Lấy trạng thái phí nền tảng thành công",
        data,
    });
});

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

export const cancelScheduledPlatformFeeHandler: RequestHandler = asyncHandler(async (req: Request, res: Response) => {
    const adminUserId = Number((req as any).user?.userId ?? 1);
    const data = await cancelScheduledPlatformFee(adminUserId);

    res.status(200).json({
        success: true,
        message: data.message,
        data,
    });
});
