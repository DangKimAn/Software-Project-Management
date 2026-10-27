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

export const listMyReports: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<ReportListQuery>(req);
    const result = await getMyReports(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const listAdminReports: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AdminReportListQuery>(req);
    const result = await getAdminReports(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

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

export const getAdminRevenueAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminRevenueReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

export const getAdminBookingsAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminBookingsReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

export const getAdminListingsAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminListingsReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

export const getAdminHostsAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getAdminHostsReport(req.user!, query);

    return sendSuccess(res, { data: result });
});

export const getHostRevenueAnalytics: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const query = getValidatedQuery<AnalyticsReportQuery>(req);
    const result = await getHostRevenueReport(req.user!, query);

    return sendSuccess(res, { data: result });
});
