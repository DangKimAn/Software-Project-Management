/**
 * Bộ điều phối HTTP xử lý báo cáo vi phạm từ người dùng và trích xuất dữ liệu thống kê doanh thu/vận hành (`reports`):
 * - Bao gồm gửi báo cáo, xem báo cáo đã gửi, xử lý/bác bỏ báo cáo phía `admin` và cung cấp biểu đồ phân tích doanh thu, đơn đặt phòng, chỗ ở, chủ nhà.
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
    AdminReportListQuery,
    AnalyticsReportQuery,
    createReport,
    CreateReportInput,
    getAdminBookingsReport,
    getAdminHostsReport,
    getAdminListingsReport,
    getAdminReports,
    getAdminRevenueReport,
    getHostRevenueReport,
    getMyReports,
    rejectReport,
    RejectReportInput,
    ReportListQuery,
    resolveReport,
    ResolveReportInput,
} from "./reports.service";

const getReportActionContext = (req: Parameters<RequestHandler>[0]) => ({
    ipAddress: req.ip,
    userAgent: req.get("user-agent") ?? null,
});

/**
 * Tiếp nhận báo cáo vi phạm hoặc phản ánh sự cố mới từ người dùng.
 */
export const createUserReport: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreateReportInput>(req);
    const result = await createReport(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Report created",
        data: result,
    });
});

/**
 * Liệt kê các báo cáo vi phạm do chính người dùng hiện tại đã gửi.
 */
export const listMyReports: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<ReportListQuery>(req);
    const result = await getMyReports(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Liệt kê phân trang toàn bộ báo cáo vi phạm để quản trị viên xem xét xử lý.
 */
export const listAdminReports: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AdminReportListQuery>(req);
    const result = await getAdminReports(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Đánh dấu đã giải quyết báo cáo vi phạm kèm ghi chú xử lý của quản trị viên.
 */
export const resolveAdminReport: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ reportId: number }>(req);
    const payload = getValidatedBody<ResolveReportInput>(req);
    const result = await resolveReport(req.user!, params.reportId, payload, getReportActionContext(req));

    return sendSuccess(res, {
        message: "Report resolved",
        data: result,
    });
});

/**
 * Bác bỏ báo cáo vi phạm không đủ căn cứ kèm lý do từ quản trị viên.
 */
export const rejectAdminReport: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ reportId: number }>(req);
    const payload = getValidatedBody<RejectReportInput>(req);
    const result = await rejectReport(req.user!, params.reportId, payload, getReportActionContext(req));

    return sendSuccess(res, {
        message: "Report rejected",
        data: result,
    });
});

/**
 * Tổng hợp số liệu phân tích doanh thu toàn nền tảng theo khoảng thời gian cho quản trị viên.
 */
export const getAdminRevenueAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminRevenueReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

/**
 * Tổng hợp thống kê lượng đơn đặt phòng và tỷ lệ chuyển đổi/hủy đơn toàn hệ thống.
 */
export const getAdminBookingsAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminBookingsReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

/**
 * Tổng hợp thống kê tăng trưởng và hiệu suất hoạt động của chỗ ở trên nền tảng.
 */
export const getAdminListingsAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminListingsReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

/**
 * Tổng hợp thống kê hoạt động và doanh thu theo nhóm chủ nhà cho quản trị viên.
 */
export const getAdminHostsAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminHostsReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

/**
 * Tổng hợp biểu đồ doanh thu và công suất đặt phòng dành riêng cho chủ nhà đang đăng nhập.
 */
export const getHostRevenueAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getHostRevenueReport(req.user!, query);

    return sendSuccess(res, { data: result });
});
