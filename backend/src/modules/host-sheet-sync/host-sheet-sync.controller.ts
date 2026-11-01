import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    connectHostSpreadsheet,
    ConnectHostSheetInput,
    disconnectHostSpreadsheet,
    getHostSheetSyncStatus,
    initializeHostStandardCalendar,
    listHostSheetChangeLogs,
    listHostSheetConflicts,
    ResolveConflictAction,
    resolveHostSheetConflict,
    syncHostSpreadsheetNow,
    updateHostSheetSettings,
    UpdateHostSheetSettingsInput,
    verifyHostSpreadsheetPermissions,
} from "./host-sheet-sync.service";

export const getHostSheetSyncStatusHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const data = await getHostSheetSyncStatus(Number(req.user!.id));
    return sendSuccess(res, { data });
});

export const connectHostSpreadsheetHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const body = getValidatedBody<ConnectHostSheetInput>(req);
    const data = await connectHostSpreadsheet(Number(req.user!.id), body);
    return sendSuccess(res, {
        statusCode: 200,
        message: "Đã kết nối Google Sheets thành công",
        data,
    });
});

export const verifyHostSpreadsheetPermissionsHandler: RequestHandler = asyncHandler(
    async (req, res) => {
        assertValidRequest(req);
        const data = await verifyHostSpreadsheetPermissions(Number(req.user!.id));
        return sendSuccess(res, {
            message: "Quyền Chỉnh sửa (Editor) trên Google Sheets hợp lệ",
            data,
        });
    },
);

export const initializeHostStandardCalendarHandler: RequestHandler = asyncHandler(
    async (req, res) => {
        assertValidRequest(req);
        const data = await initializeHostStandardCalendar(Number(req.user!.id));
        return sendSuccess(res, {
            message: "Đã khởi tạo / cập nhật khung lịch chuẩn 6 tháng trên Google Sheets",
            data,
        });
    },
);

export const syncHostSpreadsheetNowHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const data = await syncHostSpreadsheetNow(Number(req.user!.id));
    return sendSuccess(res, {
        message: "Đồng bộ lịch 2 chiều hoàn tất",
        data,
    });
});

export const updateHostSheetSettingsHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const body = getValidatedBody<UpdateHostSheetSettingsInput>(req);
    const data = await updateHostSheetSettings(Number(req.user!.id), body);
    return sendSuccess(res, {
        message: "Đã lưu cấu hình đồng bộ Google Sheets",
        data,
    });
});

export const disconnectHostSpreadsheetHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const data = await disconnectHostSpreadsheet(Number(req.user!.id));
    return sendSuccess(res, {
        message: "Đã ngắt kết nối Google Sheets (dữ liệu đặt phòng trên hệ thống được giữ nguyên)",
        data,
    });
});

export const listHostSheetConflictsHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const query = getValidatedQuery<{
        status?: string;
        listingId?: number;
        page?: number;
        limit?: number;
    }>(req);
    const data = await listHostSheetConflicts(Number(req.user!.id), query);
    return sendSuccess(res, { data });
});

export const resolveHostSheetConflictHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const params = getValidatedParams<{ conflictId: number }>(req);
    const body = getValidatedBody<{ action: ResolveConflictAction }>(req);
    const data = await resolveHostSheetConflict(Number(req.user!.id), params.conflictId, body.action);
    return sendSuccess(res, {
        message: "Đã xử lý cảnh báo đồng bộ",
        data,
    });
});

export const listHostSheetChangeLogsHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const query = getValidatedQuery<{
        listingId?: number;
        search?: string;
        page?: number;
        limit?: number;
    }>(req);
    const data = await listHostSheetChangeLogs(Number(req.user!.id), query);
    return sendSuccess(res, { data });
});

