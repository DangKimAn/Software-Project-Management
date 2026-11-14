/**
 * Bộ điều phối HTTP đồng bộ hóa hai chiều lịch phòng và giá với Google Sheets cho chủ nhà (`host-sheet-sync`):
 * - Điều phối kết nối bảng tính, kiểm tra quyền chia sẻ Service Account, khởi tạo mẫu lịch chuẩn, đồng bộ tức thời, cấu hình tự động, xử lý xung đột và tra cứu nhật ký thay đổi.
 */

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

/**
 * Truy vấn trạng thái kết nối và đồng bộ Google Sheets hiện tại của chủ nhà.
 */
export const getHostSheetSyncStatusHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const data = await getHostSheetSyncStatus(Number(req.user!.id));
    return sendSuccess(res, { data });
});

/**
 * Thiết lập liên kết bảng tính Google Sheets với tài khoản chủ nhà.
 */
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

/**
 * Kiểm tra quyền đọc/ghi của tài khoản dịch vụ hệ thống trên tệp Google Sheets đã cấu hình.
 */
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

/**
 * Khởi tạo cấu trúc trang tính lịch phòng và biểu giá tiêu chuẩn trên Google Sheets của chủ nhà.
 */
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

/**
 * Kích hoạt tiến trình đồng bộ tức thời dữ liệu lịch và giá giữa hệ thống với Google Sheets.
 */
export const syncHostSpreadsheetNowHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const data = await syncHostSpreadsheetNow(Number(req.user!.id));
    return sendSuccess(res, {
        message: "Đồng bộ lịch 2 chiều hoàn tất",
        data,
    });
});

/**
 * Cập nhật tùy chọn cấu hình đồng bộ tự động Google Sheets của chủ nhà.
 */
export const updateHostSheetSettingsHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const body = getValidatedBody<UpdateHostSheetSettingsInput>(req);
    const data = await updateHostSheetSettings(Number(req.user!.id), body);
    return sendSuccess(res, {
        message: "Đã lưu cấu hình đồng bộ Google Sheets",
        data,
    });
});

/**
 * Ngắt kết nối tích hợp Google Sheets khỏi tài khoản chủ nhà.
 */
export const disconnectHostSpreadsheetHandler: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);
    const data = await disconnectHostSpreadsheet(Number(req.user!.id));
    return sendSuccess(res, {
        message: "Đã ngắt kết nối Google Sheets (dữ liệu đặt phòng trên hệ thống được giữ nguyên)",
        data,
    });
});

/**
 * Liệt kê các xung đột dữ liệu phát sinh trong quá trình đồng bộ hai chiều với Google Sheets.
 */
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

/**
 * Áp dụng quyết định giải quyết xung đột đồng bộ lịch/giá do chủ nhà lựa chọn.
 */
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

/**
 * Truy vấn lịch sử nhật ký các lần đồng bộ và biến động dữ liệu với Google Sheets.
 */
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

