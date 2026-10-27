import { Op, QueryTypes } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import Booking from "../../models/booking";
import Listing from "../../models/listing";
import Report, {
    ReportStatus,
    ReportTargetType,
} from "../../models/report";
import Review from "../../models/review";
import User from "../../models/user";
import { writeAuditLog } from "../../services/audit-log-service";
import type { AuthenticatedUser } from "../auth/auth.service";
import { moneyToVnd, vndToNumber } from "../../utils/money";
import { sanitizeAndModerateText } from "../../services/trust-safety-service";

export type CreateReportInput = {
    targetType: ReportTargetType;
    targetId: number;
    reason: string;
    description?: string | null;
};

export type ReportListQuery = {
    status?: ReportStatus;
    targetType?: ReportTargetType;
    type?: ReportTargetType;
    page?: number;
    limit?: number;
};

export type AdminReportListQuery = ReportListQuery & {
    reporterId?: number;
};

export type ResolveReportInput = {
    resolution?: string | null;
    note?: string | null;
    reason?: string | null;
};

export type RejectReportInput = {
    reason?: string | null;
    note?: string | null;
};

export type AnalyticsGroup = "day" | "month" | "year";

export type AnalyticsReportQuery = {
    from?: string;
    to?: string;
    group?: AnalyticsGroup;
};

export type ReportActionContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

const maxPageLimit = 100;
const maxAnalyticsRangeDays = 1096;
const duplicateReportWindowMs = 24 * 60 * 60 * 1000;
const maxDuplicateReportsPerTarget = 3;

const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(maxPageLimit, Math.max(1, limit ?? 10)),
});

const serializeReport = (report: Report) => ({
    reportId: report.reportId,
    reporterId: report.reporterId,
    targetType: report.targetType,
    targetId: report.targetId,
    reason: report.reason,
    description: report.description,
    status: report.status,
    resolvedBy: report.resolvedBy,
    resolvedAt: report.resolvedAt,
    resolution: report.resolution,
    createdAt: report.createdAt,
    updatedAt: report.updatedAt,
});

const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

const toIsoDate = (date: Date) => date.toISOString().slice(0, 10);

const addDays = (date: Date, days: number) => {
    const nextDate = new Date(date);
    nextDate.setUTCDate(nextDate.getUTCDate() + days);
    return nextDate;
};

const parseAnalyticsRange = (query: AnalyticsReportQuery) => {
    const today = new Date();
    const to = query.to ?? toIsoDate(today);
    const from = query.from ?? toIsoDate(addDays(new Date(`${to}T00:00:00.000Z`), -29));
    const fromDate = new Date(`${from}T00:00:00.000Z`);
    const toDate = new Date(`${to}T00:00:00.000Z`);

    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime()) || from > to) {
        throw new ApiError(422, "Validation error", [
            {
                path: "to",
                msg: "to must be greater than or equal to from",
            },
        ]);
    }

    const diffDays = Math.floor((toDate.getTime() - fromDate.getTime()) / (24 * 60 * 60 * 1000)) + 1;

    if (diffDays > maxAnalyticsRangeDays) {
        throw new ApiError(422, "Validation error", [
            {
                path: "from",
                msg: `Date range must be ${maxAnalyticsRangeDays} days or less`,
            },
        ]);
    }

    return {
        from,
        to,
        fromDateTime: `${from} 00:00:00`,
        toDateTime: `${to} 23:59:59`,
        group: query.group ?? "day",
    };
};

const groupExpressions: Record<AnalyticsGroup, (column: string) => string> = {
    day: (column) => `DATE(${column})`,
    month: (column) => `DATE_FORMAT(${column}, '%Y-%m')`,
    year: (column) => `DATE_FORMAT(${column}, '%Y')`,
};

const getGroupExpression = (group: AnalyticsGroup, column: string) => groupExpressions[group](column);

const toIntegerAmount = (value: unknown) => {
    if (value === null || value === undefined) {
        return 0;
    }

    return vndToNumber(moneyToVnd(String(value)));
};

const sumIntegerAmount = <T>(rows: T[], selector: (row: T) => unknown) =>
    rows.reduce((total, row) => total + toIntegerAmount(selector(row)), 0);

const normalizeReason = (value: string) =>
    sanitizeAndModerateText(value, {
        field: "reason",
        mode: "singleLine",
    });

const normalizeOptionalDescription = (value?: string | null) => {
    const normalized = sanitizeAndModerateText(value ?? "", {
        field: "description",
        allowEmpty: true,
    });

    return normalized.length > 0 ? normalized : null;
};

const normalizeOptionalResolution = (value?: string | null, field = "resolution") => {
    const normalized = sanitizeAndModerateText(value ?? "", {
        field,
        allowEmpty: true,
    });

    return normalized.length > 0 ? normalized : null;
};

const assertTargetExists = async (targetType: ReportTargetType, targetId: number, reporterId: number) => {
    if (targetType === "listing") {
        const listing = await Listing.findOne({
            listingId: targetId,
            deletedAt: null,
        });

        if (!listing) {
            throw new ApiError(404, "Listing not found");
        }

        return;
    }

    if (targetType === "user") {
        const user = await User.findById(targetId);

        if (!user || user.deletedAt || user.status === "deleted") {
            throw new ApiError(404, "User not found");
        }

        return;
    }

    if (targetType === "review") {
        const review = await Review.findOne({
            reviewId: targetId,
            isVisible: true,
            deletedAt: null,
        });

        if (!review) {
            throw new ApiError(404, "Review not found");
        }

        return;
    }

    const booking = await Booking.findOne({
        bookingId: targetId,
    });

    if (!booking) {
        throw new ApiError(404, "Booking not found");
    }

    const participantIds = new Set([Number(booking.guestUserId), Number(booking.hostUserId)]);

    if (!participantIds.has(reporterId)) {
        throw new ApiError(403, "Forbidden");
    }
};

const assertNotReportSpam = async (reporterId: number, targetType: ReportTargetType, targetId: number) => {
    const existingOpenReport = await Report.findOne({
        where: {
            reporterId,
            targetType,
            targetId,
            status: "open",
        },
    });

    if (existingOpenReport) {
        throw new ApiError(409, "Report already exists for this target");
    }

    const recentDuplicateCount = await Report.count({
        where: {
            reporterId,
            targetType,
            targetId,
            createdAt: {
                [Op.gte]: new Date(Date.now() - duplicateReportWindowMs),
            },
        },
    });

    if (recentDuplicateCount >= maxDuplicateReportsPerTarget) {
        throw new ApiError(409, "Too many reports for this target");
    }
};

export const createReport = async (user: AuthenticatedUser, input: CreateReportInput) =>
    sequelize.transaction(async (transaction) => {
        const reporterId = getCurrentUserId(user);
        await assertTargetExists(input.targetType, input.targetId, reporterId);
        await assertNotReportSpam(reporterId, input.targetType, input.targetId);

        const report = await Report.create(
            {
                reporterId,
                targetType: input.targetType,
                targetId: input.targetId,
                reason: normalizeReason(input.reason),
                description: normalizeOptionalDescription(input.description),
                status: "open",
                resolvedBy: null,
                resolvedAt: null,
                resolution: null,
            },
            { transaction },
        );

        return serializeReport(report);
    });

export const getMyReports = async (user: AuthenticatedUser, query: ReportListQuery) => {
    const { page, limit } = toPagination(query.page, query.limit);
    const targetType = query.targetType ?? query.type;
    const where: Record<string, unknown> = {
        reporterId: getCurrentUserId(user),
    };

    if (query.status) {
        where.status = query.status;
    }

    if (targetType) {
        where.targetType = targetType;
    }

    const result = await Report.findAndCountAll({
        where,
        order: [
            ["createdAt", "DESC"],
            ["reportId", "DESC"],
        ],
        limit,
        offset: (page - 1) * limit,
    });

    return {
        items: result.rows.map((report) => {
            const item = serializeReport(report);
            delete (item as Partial<typeof item>).reporterId;
            delete (item as Partial<typeof item>).resolvedBy;
            return item;
        }),
        pagination: {
            page,
            limit,
            total: result.count,
            totalPages: Math.max(1, Math.ceil(result.count / limit)),
        },
    };
};

export const getAdminReports = async (admin: AuthenticatedUser, query: AdminReportListQuery) => {
    assertAdmin(admin);

    const { page, limit } = toPagination(query.page, query.limit);
    const targetType = query.targetType ?? query.type;
    const where: Record<string, unknown> = {};

    if (query.status) {
        where.status = query.status;
    }

    if (targetType) {
        where.targetType = targetType;
    }

    if (query.reporterId !== undefined) {
        where.reporterId = query.reporterId;
    }

    const result = await Report.findAndCountAll({
        where,
        order: [
            ["createdAt", "DESC"],
            ["reportId", "DESC"],
        ],
        limit,
        offset: (page - 1) * limit,
    });

    return {
        items: result.rows.map(serializeReport),
        pagination: {
            page,
            limit,
            total: result.count,
            totalPages: Math.max(1, Math.ceil(result.count / limit)),
        },
    };
};

const updateReportStatus = async (
    admin: AuthenticatedUser,
    reportId: number,
    status: Extract<ReportStatus, "resolved" | "rejected">,
    resolution: string | null,
    context: ReportActionContext,
) =>
    sequelize.transaction(async (transaction) => {
        assertAdmin(admin);

        const report = await Report.findOne({
            where: {
                reportId,
            },
            transaction,
        });

        if (!report) {
            throw new ApiError(404, "Report not found");
        }

        if (report.status !== "open") {
            throw new ApiError(409, "Report has already been processed");
        }

        report.status = status;
        report.resolvedBy = getCurrentUserId(admin);
        report.resolvedAt = new Date();
        report.resolution = resolution;

        await report.save({ transaction });

        await writeAuditLog({
            actorId: getCurrentUserId(admin),
            action: `reports.${status}`,
            targetType: "report",
            targetId: report.reportId,
            metadata: {
                targetType: report.targetType,
                targetId: report.targetId,
                status,
            },
            ipAddress: context.ipAddress ?? null,
            userAgent: context.userAgent ?? null,
            transaction,
        });

        return serializeReport(report);
    });

export const resolveReport = async (
    admin: AuthenticatedUser,
    reportId: number,
    input: ResolveReportInput,
    context: ReportActionContext = {},
) => {
    const resolution = normalizeOptionalResolution(input.resolution ?? input.note ?? input.reason);
    return updateReportStatus(admin, reportId, "resolved", resolution, context);
};

export const rejectReport = async (
    admin: AuthenticatedUser,
    reportId: number,
    input: RejectReportInput,
    context: ReportActionContext = {},
) => {
    const reason = normalizeOptionalResolution(input.reason ?? input.note, "reason");

    if (!reason) {
        throw new ApiError(422, "Validation error", [
            {
                path: "reason",
                msg: "reason is required",
            },
        ]);
    }

    return updateReportStatus(admin, reportId, "rejected", reason, context);
};

type RevenueRow = {
    period: string;
    grossRevenue: string | number | null;
    platformRevenue: string | number | null;
    hostRevenue: string | number | null;
    bookingCount: number;
    paymentCount: number;
};

const mapRevenueRow = (row: RevenueRow) => ({
    period: row.period,
    grossRevenue: toIntegerAmount(row.grossRevenue),
    platformRevenue: toIntegerAmount(row.platformRevenue),
    hostRevenue: toIntegerAmount(row.hostRevenue),
    bookingCount: Number(row.bookingCount ?? 0),
    paymentCount: Number(row.paymentCount ?? 0),
});

const getRevenueReport = async (query: AnalyticsReportQuery, hostId?: number) => {
    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "p.paid_at");
    const hostFilter = hostId ? "AND b.host_user_id = :hostId" : "";
    const replacements = {
        from: range.fromDateTime,
        to: range.toDateTime,
        ...(hostId ? { hostId } : {}),
    };
    const rows = await sequelize.query<RevenueRow>(
        `
        SELECT
            ${groupBy} AS period,
            COALESCE(SUM(p.amount), 0) AS grossRevenue,
            COALESCE(SUM(b.service_fee_amount), 0) AS platformRevenue,
            COALESCE(SUM(p.amount - b.service_fee_amount), 0) AS hostRevenue,
            COUNT(DISTINCT b.booking_id) AS bookingCount,
            COUNT(DISTINCT p.payment_id) AS paymentCount
        FROM payments p
        INNER JOIN bookings b ON b.booking_id = p.booking_id
        WHERE p.status = 'paid'
          AND p.paid_at BETWEEN :from AND :to
          ${hostFilter}
        GROUP BY ${groupBy}
        ORDER BY ${groupBy} ASC
        `,
        {
            replacements,
            type: QueryTypes.SELECT,
        },
    );
    const series = rows.map(mapRevenueRow);

    return {
        range: {
            from: range.from,
            to: range.to,
        },
        group: range.group,
        totals: {
            grossRevenue: sumIntegerAmount(rows, (row) => row.grossRevenue),
            platformRevenue: sumIntegerAmount(rows, (row) => row.platformRevenue),
            hostRevenue: sumIntegerAmount(rows, (row) => row.hostRevenue),
            bookingCount: series.reduce((total, row) => total + row.bookingCount, 0),
            paymentCount: series.reduce((total, row) => total + row.paymentCount, 0),
        },
        series,
    };
};

export const getAdminRevenueReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);
    return getRevenueReport(query);
};

export const getHostRevenueReport = async (host: AuthenticatedUser, query: AnalyticsReportQuery) => {
    if (!host.roles.includes("host") && !host.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    return getRevenueReport(query, getCurrentUserId(host));
};

type BookingAnalyticsRow = {
    period: string;
    totalBookings: number;
    pendingBookings: number;
    paidBookings: number;
    completedBookings: number;
    cancelledBookings: number;
    expiredBookings: number;
    totalAmount: string | number | null;
};

export const getAdminBookingsReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);

    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "b.created_at");
    const rows = await sequelize.query<BookingAnalyticsRow>(
        `
        SELECT
            ${groupBy} AS period,
            COUNT(*) AS totalBookings,
            SUM(b.status = 'pending_payment') AS pendingBookings,
            SUM(b.status IN ('paid','confirmed','checked_in','checked_out')) AS paidBookings,
            SUM(b.status = 'completed') AS completedBookings,
            SUM(b.status IN ('cancelled_by_guest','cancelled_by_host','cancelled_by_admin','rejected')) AS cancelledBookings,
            SUM(b.status = 'payment_expired') AS expiredBookings,
            COALESCE(SUM(b.total_amount), 0) AS totalAmount
        FROM bookings b
        WHERE b.created_at BETWEEN :from AND :to
        GROUP BY ${groupBy}
        ORDER BY ${groupBy} ASC
        `,
        {
            replacements: {
                from: range.fromDateTime,
                to: range.toDateTime,
            },
            type: QueryTypes.SELECT,
        },
    );
    const series = rows.map((row) => ({
        period: row.period,
        totalBookings: Number(row.totalBookings ?? 0),
        pendingBookings: Number(row.pendingBookings ?? 0),
        paidBookings: Number(row.paidBookings ?? 0),
        completedBookings: Number(row.completedBookings ?? 0),
        cancelledBookings: Number(row.cancelledBookings ?? 0),
        expiredBookings: Number(row.expiredBookings ?? 0),
        totalAmount: toIntegerAmount(row.totalAmount),
    }));

    return {
        range: { from: range.from, to: range.to },
        group: range.group,
        totals: {
            totalBookings: series.reduce((total, row) => total + row.totalBookings, 0),
            pendingBookings: series.reduce((total, row) => total + row.pendingBookings, 0),
            paidBookings: series.reduce((total, row) => total + row.paidBookings, 0),
            completedBookings: series.reduce((total, row) => total + row.completedBookings, 0),
            cancelledBookings: series.reduce((total, row) => total + row.cancelledBookings, 0),
            expiredBookings: series.reduce((total, row) => total + row.expiredBookings, 0),
            totalAmount: sumIntegerAmount(rows, (row) => row.totalAmount),
        },
        series,
    };
};

type ListingAnalyticsRow = {
    period: string;
    listingsCreated: number;
    activeListings: number;
    inactiveListings: number;
};

export const getAdminListingsReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);

    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "l.created_at");
    const rows = await sequelize.query<ListingAnalyticsRow>(
        `
        SELECT
            ${groupBy} AS period,
            COUNT(*) AS listingsCreated,
            SUM(l.status = 'active') AS activeListings,
            SUM(l.status <> 'active') AS inactiveListings
        FROM listings l
        WHERE l.created_at BETWEEN :from AND :to
          AND l.deleted_at IS NULL
        GROUP BY ${groupBy}
        ORDER BY ${groupBy} ASC
        `,
        {
            replacements: {
                from: range.fromDateTime,
                to: range.toDateTime,
            },
            type: QueryTypes.SELECT,
        },
    );
    const series = rows.map((row) => ({
        period: row.period,
        listingsCreated: Number(row.listingsCreated ?? 0),
        activeListings: Number(row.activeListings ?? 0),
        inactiveListings: Number(row.inactiveListings ?? 0),
    }));

    return {
        range: { from: range.from, to: range.to },
        group: range.group,
        totals: {
            listingsCreated: series.reduce((total, row) => total + row.listingsCreated, 0),
            activeListings: series.reduce((total, row) => total + row.activeListings, 0),
            inactiveListings: series.reduce((total, row) => total + row.inactiveListings, 0),
        },
        series,
    };
};

type HostAnalyticsRow = {
    period: string;
    hostsCreated: number;
    activeHosts: number;
    verifiedHosts: number;
};

export const getAdminHostsReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);

    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "u.created_at");
    const rows = await sequelize.query<HostAnalyticsRow>(
        `
        SELECT
            ${groupBy} AS period,
            COUNT(DISTINCT u.user_id) AS hostsCreated,
            COUNT(DISTINCT CASE WHEN u.status = 'active' THEN u.user_id END) AS activeHosts,
            COUNT(DISTINCT CASE WHEN u.is_host_verified = 1 THEN u.user_id END) AS verifiedHosts
        FROM users u
        INNER JOIN user_role ur ON ur.user_id = u.user_id
        INNER JOIN roles r ON r.role_id = ur.role_id AND r.code = 'host'
        WHERE u.created_at BETWEEN :from AND :to
          AND u.deleted_at IS NULL
        GROUP BY ${groupBy}
        ORDER BY ${groupBy} ASC
        `,
        {
            replacements: {
                from: range.fromDateTime,
                to: range.toDateTime,
            },
            type: QueryTypes.SELECT,
        },
    );
    const series = rows.map((row) => ({
        period: row.period,
        hostsCreated: Number(row.hostsCreated ?? 0),
        activeHosts: Number(row.activeHosts ?? 0),
        verifiedHosts: Number(row.verifiedHosts ?? 0),
    }));

    return {
        range: { from: range.from, to: range.to },
        group: range.group,
        totals: {
            hostsCreated: series.reduce((total, row) => total + row.hostsCreated, 0),
            activeHosts: series.reduce((total, row) => total + row.activeHosts, 0),
            verifiedHosts: series.reduce((total, row) => total + row.verifiedHosts, 0),
        },
        series,
    };
};
