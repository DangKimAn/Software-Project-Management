import { Op, QueryTypes } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import Booking from "../../models/booking";
import Conversation from "../../models/conversation";
import ConversationParticipant from "../../models/conversation-participant";
import Listing from "../../models/listing";
import Message from "../../models/message";
import Report, {
    ReportStatus,
    ReportTargetType,
} from "../../models/report";
import Review from "../../models/review";
import User from "../../models/user";
import { writeAuditLog } from "../../services/audit-log.service";
import type { AuthenticatedUser } from "../auth/auth.service";
import { moneyToVnd, vndToNumber } from "../../common/money";
import { sanitizeAndModerateText } from "../../common/text-moderation";

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
    listingId?: number;
};

export type ReportActionContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

const maxPageLimit = 100;
const maxAnalyticsRangeDays = 1096;
const duplicateReportWindowMs = 24 * 60 * 60 * 1000;
const maxDuplicateReportsPerTarget = 3;
const vietnamOffsetMs = 7 * 60 * 60 * 1000;

/**
 * Giải thuật trích xuất định danh số nguyên của người dùng từ phiên xác thực hiện tại.
 */
const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

/**
 * Giải thuật chuẩn hóa tham số phân trang có kẹp biên an toàn (`page >= 1`, `1 <= limit <= maxPageLimit`).
 */
const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(maxPageLimit, Math.max(1, limit ?? 10)),
});

/**
 * Giải thuật tuần tự hóa bản ghi báo cáo vi phạm (`Report`) sang cấu trúc dữ liệu phản hồi chuẩn.
 */
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

/**
 * Giải thuật kiểm tra quyền quản trị viên (`admin`); ném lỗi `403 Forbidden` nếu không thỏa mãn.
 */
const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật trích xuất chuỗi ngày lịch `YYYY-MM-DD` từ đối tượng `Date` theo chuẩn ISO UTC.
 */
const toIsoDate = (date: Date) => date.toISOString().slice(0, 10);

/**
 * Giải thuật định dạng đối tượng `Date` sang chuỗi datetime chuẩn UTC `YYYY-MM-DD HH:mm:ss` cho truy vấn MySQL.
 */
const toMySqlUtcDateTime = (date: Date) => date.toISOString().slice(0, 19).replace("T", " ");

/**
 * Giải thuật cộng/trừ số ngày nguyên trên mốc `Date` UTC mà không làm biến đổi đối tượng gốc.
 */
const addDays = (date: Date, days: number) => {
    const nextDate = new Date(date);
    nextDate.setUTCDate(nextDate.getUTCDate() + days);
    return nextDate;
};

/**
 * Giải thuật chuẩn hóa khoảng thời gian truy vấn báo cáo phân tích theo múi giờ Việt Nam (`UTC+7`):
 * - Mặc định lấy cửa sổ 30 ngày gần nhất tính đến ngày hiện tại tại Việt Nam nếu không truyền `from` / `to`.
 * - Kiểm định bất biến `from <= to` và độ rộng khoảng thời gian không vượt quá `maxAnalyticsRangeDays` (1096 ngày).
 * - Quy đổi biên đầu ngày (`00:00:00.000+07:00`) và cuối ngày (`23:59:59.999+07:00`) về mốc datetime UTC tương ứng để lọc chính xác trên chỉ mục DB.
 */
const parseAnalyticsRange = (query: AnalyticsReportQuery) => {
    const vietnamToday = toIsoDate(new Date(Date.now() + vietnamOffsetMs));
    const to = query.to ?? vietnamToday;
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

    const fromUtc = new Date(`${from}T00:00:00.000+07:00`);
    const toUtc = new Date(`${to}T23:59:59.999+07:00`);

    return {
        from,
        to,
        fromDateTime: toMySqlUtcDateTime(fromUtc),
        toDateTime: toMySqlUtcDateTime(toUtc),
        group: query.group ?? "day",
    };
};

/**
 * Bảng ánh xạ biểu thức SQL gộp nhóm chuỗi thời gian theo kỳ (`day`, `month`, `year`)
 * sau khi dịch chuyển cột dấu thời gian UTC sang múi giờ Việt Nam (`INTERVAL 7 HOUR`).
 */
const groupExpressions: Record<AnalyticsGroup, (column: string) => string> = {
    day: (column) => `DATE(DATE_ADD(${column}, INTERVAL 7 HOUR))`,
    month: (column) => `DATE_FORMAT(DATE_ADD(${column}, INTERVAL 7 HOUR), '%Y-%m')`,
    year: (column) => `DATE_FORMAT(DATE_ADD(${column}, INTERVAL 7 HOUR), '%Y')`,
};

/**
 * Giải thuật lấy biểu thức SQL gộp nhóm thời gian tương ứng với độ mịn kỳ báo cáo (`AnalyticsGroup`).
 */
const getGroupExpression = (group: AnalyticsGroup, column: string) => groupExpressions[group](column);

/**
 * Giải thuật chuẩn hóa giá trị tiền tệ trả về từ truy vấn tổng hợp SQL sang số nguyên đồng VND an toàn thông qua `BigInt` (`moneyToVnd` -> `vndToNumber`).
 */
const toIntegerAmount = (value: unknown) => {
    if (value === null || value === undefined) {
        return 0;
    }

    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
        return vndToNumber(moneyToVnd(String(Math.round(numeric))));
    }

    return vndToNumber(moneyToVnd(String(value)));
};

/**
 * Giải thuật cộng tổng một trường tiền tệ trên tập dòng kết quả sau khi chuẩn hóa từng phần tử về số nguyên đồng VND.
 */
const sumIntegerAmount = <T>(rows: T[], selector: (row: T) => unknown) =>
    rows.reduce((total, row) => total + toIntegerAmount(selector(row)), 0);

/**
 * Giải thuật làm sạch và kiểm duyệt nội dung lý do báo cáo trên một dòng (`singleLine`).
 */
const normalizeReason = (value: string) =>
    sanitizeAndModerateText(value, {
        field: "reason",
        mode: "singleLine",
    });

/**
 * Giải thuật làm sạch và kiểm duyệt mô tả chi tiết báo cáo tùy chọn; trả về `null` nếu nội dung trống.
 */
const normalizeOptionalDescription = (value?: string | null) => {
    const normalized = sanitizeAndModerateText(value ?? "", {
        field: "description",
        allowEmpty: true,
    });

    return normalized.length > 0 ? normalized : null;
};

/**
 * Giải thuật làm sạch và kiểm duyệt ghi chú xử lý / lý do từ chối báo cáo của quản trị viên.
 */
const normalizeOptionalResolution = (value?: string | null, field = "resolution") => {
    const normalized = sanitizeAndModerateText(value ?? "", {
        field,
        allowEmpty: true,
    });

    return normalized.length > 0 ? normalized : null;
};

/**
 * Giải thuật xác thực sự tồn tại hợp lệ của đối tượng bị báo cáo (`listing`, `user`, `review`, `booking`):
 * riêng đối với `booking`, bắt buộc người gửi báo cáo phải là một trong hai bên tham gia giao dịch (`guestUserId` hoặc `hostUserId`).
 */
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

    if (targetType === "message") {
        // Giải thuật xác thực báo cáo tin nhắn vi phạm (TC-095):
        // Kiểm tra tin nhắn tồn tại và người báo cáo bắt buộc là thành viên hợp lệ trong cuộc hội thoại chứa tin nhắn đó.
        const message = await Message.findOne({
            where: {
                messageId: targetId,
            },
        });

        if (!message) {
            throw new ApiError(404, "Message not found");
        }

        const conversation = await Conversation.findOne({
            where: {
                conversationId: message.conversationId,
            },
        });

        const isDirectMember =
            conversation &&
            (Number(conversation.guestUserId) === reporterId || Number(conversation.hostUserId) === reporterId);
        if (!isDirectMember) {
            const participant = await ConversationParticipant.findOne({
                where: {
                    conversationId: message.conversationId,
                    userId: reporterId,
                },
            });
            if (!participant) {
                throw new ApiError(403, "Forbidden");
            }
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

/**
 * Giải thuật chống gửi báo cáo trùng lặp và giới hạn tần suất (Anti-Spam Rate Limiting):
 * 1. Từ chối (`409 Conflict`) nếu người dùng đang có sẵn một báo cáo ở trạng thái `open` nhắm tới cùng mục tiêu.
 * 2. Giới hạn tối đa `maxDuplicateReportsPerTarget` (3 lần) trên cùng mục tiêu trong cửa sổ trượt 24 giờ (`duplicateReportWindowMs`).
 */
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

/**
 * Giải thuật khởi tạo báo cáo vi phạm mới nguyên tử trong giao dịch ACID sau khi kiểm định mục tiêu, chống spam và lọc nội dung.
 */
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

/**
 * Giải thuật truy vấn danh sách báo cáo vi phạm có phân trang của người dùng hiện tại, ẩn thông tin định danh người xử lý nội bộ (`resolvedBy`).
 */
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

/**
 * Giải thuật truy vấn danh sách báo cáo vi phạm toàn hệ thống có phân trang và bộ lọc đa tiêu chí dành cho quản trị viên.
 */
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

/**
 * Giải thuật chuyển trạng thái xử lý báo cáo (`open -> resolved | rejected`) nguyên tử trong giao dịch ACID
 * kèm ghi nhận người giải quyết, thời điểm hoàn tất và nhật ký kiểm toán (`audit_logs`).
 */
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

/**
 * Giải thuật đánh dấu đã giải quyết báo cáo vi phạm (`resolved`) kèm kết luận xử lý đã làm sạch.
 */
export const resolveReport = async (
    admin: AuthenticatedUser,
    reportId: number,
    input: ResolveReportInput,
    context: ReportActionContext = {},
) => {
    const resolution = normalizeOptionalResolution(input.resolution ?? input.note ?? input.reason);
    return updateReportStatus(admin, reportId, "resolved", resolution, context);
};

/**
 * Giải thuật từ chối báo cáo vi phạm (`rejected`), bắt buộc quản trị viên cung cấp lý do từ chối hợp lệ (`422` nếu để trống).
 */
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

type PendingStayRevenueRow = {
    pendingStayRevenue: string | number | null;
    pendingStayPlatformRevenue: string | number | null;
    pendingStayHostRevenue: string | number | null;
    pendingStayBookingCount: number;
};

type RefundSummaryRow = {
    refundedAmount: string | number | null;
    refundCount: number;
};

/**
 * Giải thuật chuẩn hóa một dòng dữ liệu chuỗi thời gian doanh thu từ SQL sang đối tượng số nguyên đồng VND an toàn.
 */
const mapRevenueRow = (row: RevenueRow) => ({
    period: row.period,
    grossRevenue: toIntegerAmount(row.grossRevenue),
    platformRevenue: toIntegerAmount(row.platformRevenue),
    hostRevenue: toIntegerAmount(row.hostRevenue),
    bookingCount: Number(row.bookingCount ?? 0),
    paymentCount: Number(row.paymentCount ?? 0),
});

/**
 * Hệ biểu thức SQL ghi nhận doanh thu thực tế (Accrual/Completion Revenue Recognition) và phân bổ sau hoàn tiền:
 * 1. `recognizedRevenueTimestampSql`: đối với đơn hoàn thành (`checked_out`, `completed`), lấy mốc trả phòng thực tế `checked_out_at`
 *    (dự phòng `12:00` trưa giờ Việt Nam tức `05:00:00 UTC` ngày `check_out_date`, hoặc `paid_at`); đối với đơn hủy có phí giữ lại, lấy `cancelled_at`.
 * 2. `netRetainedAmountSql`: doanh thu gộp giữ lại ròng sau khi trừ tổng tiền hoàn hợp lệ:
 *    `netRetained = ROUND(GREATEST(p.amount - COALESCE(r.refunded_amount, 0), 0), 0)`.
 * 3. `netPlatformFeeSql`: phí dịch vụ nền tảng phân bổ tỷ lệ thuận theo phần tiền giữ lại:
 *    `netPlatformFee = ROUND(LEAST(b.service_fee_amount, p.amount) * (netRetained / p.amount), 0)`.
 * 4. `netHostShareSql`: doanh thu thực nhận của Host = `netRetained - netPlatformFee`, bảo toàn hằng đẳng thức kế toán `gross = platform + host`.
 */
const recognizedRevenueTimestampSql = `
    CASE
        WHEN b.status IN ('checked_out', 'completed')
            THEN COALESCE(b.checked_out_at, TIMESTAMP(b.check_out_date, '05:00:00'), p.paid_at)
        ELSE COALESCE(b.cancelled_at, b.updated_at, p.paid_at)
    END
`;

const netRetainedAmountSql = "ROUND(GREATEST(p.amount - COALESCE(r.refunded_amount, 0), 0), 0)";
const netPlatformFeeSql = `
    CASE
        WHEN p.amount > 0
            THEN ROUND(
                LEAST(b.service_fee_amount, p.amount) *
                (GREATEST(p.amount - COALESCE(r.refunded_amount, 0), 0) / p.amount),
                0
            )
        ELSE 0
    END
`;
const netHostShareSql = `(${netRetainedAmountSql} - (${netPlatformFeeSql}))`;

const activeRefundsJoinSql = `
    LEFT JOIN (
        SELECT
            payment_id,
            COALESCE(SUM(amount), 0) AS refunded_amount
        FROM refunds
        WHERE status IN ('pending', 'processing', 'succeeded')
        GROUP BY payment_id
    ) r ON r.payment_id = p.payment_id
`;

/**
 * Giải thuật tổng hợp báo cáo doanh thu gộp, doanh thu phí nền tảng, phần thực nhận Host, tiền hoàn và chuỗi thời gian theo kỳ:
 * - Thực thi song song (`Promise.all`) 3 truy vấn độc lập:
 *   1. Chuỗi thời gian (`day`/`month`/`year`) các khoản doanh thu đã đủ điều kiện ghi nhận (`grossRevenue`, `platformRevenue`, `hostRevenue`).
 *   2. Tổng doanh thu đang tạm giữ của các kỳ lưu trú đã thanh toán nhưng chưa hoàn tất (`paid`, `confirmed`, `checked_in`).
 *   3. Tổng giá trị và số lượng giao dịch hoàn tiền (`pending`, `processing`, `succeeded`) phát sinh trong khoảng thời gian truy vấn.
 */
const getRevenueReport = async (query: AnalyticsReportQuery, hostId?: number) => {
    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, recognizedRevenueTimestampSql);
    const hostFilter = hostId ? "AND b.host_user_id = :hostId" : "";
    const listingFilter = query.listingId ? "AND b.listing_id = :listingId" : "";
    const replacements = {
        from: range.fromDateTime,
        to: range.toDateTime,
        ...(hostId ? { hostId } : {}),
        ...(query.listingId ? { listingId: query.listingId } : {}),
    };

    const [rows, pendingStayRows, refundRows] = await Promise.all([
        sequelize.query<RevenueRow>(
            `
            SELECT
                ${groupBy} AS period,
                COALESCE(SUM(${netRetainedAmountSql}), 0) AS grossRevenue,
                COALESCE(SUM(${netPlatformFeeSql}), 0) AS platformRevenue,
                COALESCE(SUM(${netHostShareSql}), 0) AS hostRevenue,
                COUNT(DISTINCT b.booking_id) AS bookingCount,
                COUNT(DISTINCT p.payment_id) AS paymentCount
            FROM payments p
            INNER JOIN bookings b ON b.booking_id = p.booking_id
            ${activeRefundsJoinSql}
            WHERE p.status IN ('paid', 'refunded')
              AND p.paid_at IS NOT NULL
              AND b.status IN (
                  'checked_out',
                  'completed',
                  'cancelled_by_guest',
                  'cancelled_by_host',
                  'cancelled_by_admin',
                  'rejected'
              )
              AND (${netRetainedAmountSql}) > 0
              AND (${recognizedRevenueTimestampSql}) BETWEEN :from AND :to
              ${hostFilter}
              ${listingFilter}
            GROUP BY ${groupBy}
            ORDER BY ${groupBy} ASC
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
        sequelize.query<PendingStayRevenueRow>(
            `
            SELECT
                COALESCE(SUM(${netRetainedAmountSql}), 0) AS pendingStayRevenue,
                COALESCE(SUM(${netPlatformFeeSql}), 0) AS pendingStayPlatformRevenue,
                COALESCE(SUM(${netHostShareSql}), 0) AS pendingStayHostRevenue,
                COUNT(DISTINCT b.booking_id) AS pendingStayBookingCount
            FROM payments p
            INNER JOIN bookings b ON b.booking_id = p.booking_id
            ${activeRefundsJoinSql}
            WHERE p.status = 'paid'
              AND p.paid_at IS NOT NULL
              AND b.status IN ('paid', 'confirmed', 'checked_in')
              AND (${netRetainedAmountSql}) > 0
              ${hostFilter}
              ${listingFilter}
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
        sequelize.query<RefundSummaryRow>(
            `
            SELECT
                COALESCE(SUM(ROUND(rf.amount, 0)), 0) AS refundedAmount,
                COUNT(DISTINCT rf.refund_id) AS refundCount
            FROM refunds rf
            INNER JOIN bookings b ON b.booking_id = rf.booking_id
            WHERE rf.status IN ('pending', 'processing', 'succeeded')
              AND rf.created_at BETWEEN :from AND :to
              ${hostFilter}
              ${listingFilter}
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
    ]);

    const series = rows.map(mapRevenueRow);
    const pendingStay = pendingStayRows[0];
    const refundSummary = refundRows[0];

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
            pendingStayRevenue: toIntegerAmount(pendingStay?.pendingStayRevenue),
            pendingStayPlatformRevenue: toIntegerAmount(pendingStay?.pendingStayPlatformRevenue),
            pendingStayHostRevenue: toIntegerAmount(pendingStay?.pendingStayHostRevenue),
            pendingStayBookingCount: Number(pendingStay?.pendingStayBookingCount ?? 0),
            refundedAmount: toIntegerAmount(refundSummary?.refundedAmount),
            refundCount: Number(refundSummary?.refundCount ?? 0),
        },
        series,
    };
};

/**
 * Giải thuật xuất báo cáo doanh thu toàn nền tảng dành cho quản trị viên (`admin`).
 */
export const getAdminRevenueReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);
    return getRevenueReport(query);
};

/**
 * Giải thuật xuất báo cáo doanh thu riêng theo danh mục căn hộ thuộc quyền sở hữu của chủ nhà (`host`).
 */
export const getHostRevenueReport = async (host: AuthenticatedUser, query: AnalyticsReportQuery) => {
    if (!host.roles.includes("host") && !host.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    return getRevenueReport(query, getCurrentUserId(host));
};

type BookingAnalyticsRow = {
    period: string;
    totalBookings: number;
    successfulBookings: number;
    pendingBookings: number;
    paidBookings: number;
    completedBookings: number;
    cancelledBookings: number;
    expiredBookings: number;
    totalAmount: string | number | null;
};

/**
 * Giải thuật tổng hợp thống kê đơn đặt phòng theo chuỗi thời gian (`day`/`month`/`year`) cho quản trị viên:
 * phân tách số lượng đơn theo từng nhóm trạng thái vòng đời (thành công, chờ thanh toán, đang lưu trú, hoàn tất, đã hủy, hết hạn)
 * và tính tổng giá trị đặt phòng hợp lệ trên miền số nguyên VND.
 */
export const getAdminBookingsReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);

    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "b.created_at");
    const rows = await sequelize.query<BookingAnalyticsRow>(
        `
        SELECT
            ${groupBy} AS period,
            COUNT(*) AS totalBookings,
            SUM(b.status IN ('paid','confirmed','checked_in','checked_out','completed')) AS successfulBookings,
            SUM(b.status = 'pending_payment') AS pendingBookings,
            SUM(b.status IN ('paid','confirmed','checked_in')) AS paidBookings,
            SUM(b.status IN ('checked_out','completed')) AS completedBookings,
            SUM(b.status IN ('cancelled_by_guest','cancelled_by_host','cancelled_by_admin','rejected')) AS cancelledBookings,
            SUM(b.status = 'payment_expired') AS expiredBookings,
            COALESCE(
                SUM(
                    CASE
                        WHEN b.status IN ('paid','confirmed','checked_in','checked_out','completed')
                            THEN b.total_amount
                        ELSE 0
                    END
                ),
                0
            ) AS totalAmount
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
        successfulBookings: Number(row.successfulBookings ?? 0),
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
            successfulBookings: series.reduce((total, row) => total + row.successfulBookings, 0),
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

type ListingSnapshotRow = {
    totalListings: number;
    activeListings: number;
    inactiveListings: number;
};

/**
 * Giải thuật tổng hợp báo cáo tăng trưởng căn hộ tạo mới theo chuỗi thời gian kết hợp ảnh chụp tổng thể (`snapshot`)
 * số lượng căn hộ đang hoạt động / tạm ngưng chưa xóa mềm trên toàn hệ thống.
 */
export const getAdminListingsReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);

    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "l.created_at");
    const [rows, snapshotRows] = await Promise.all([
        sequelize.query<ListingAnalyticsRow>(
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
        ),
        sequelize.query<ListingSnapshotRow>(
            `
            SELECT
                COUNT(*) AS totalListings,
                COALESCE(SUM(l.status = 'active'), 0) AS activeListings,
                COALESCE(SUM(l.status <> 'active'), 0) AS inactiveListings
            FROM listings l
            WHERE l.deleted_at IS NULL
            `,
            {
                type: QueryTypes.SELECT,
            },
        ),
    ]);
    const series = rows.map((row) => ({
        period: row.period,
        listingsCreated: Number(row.listingsCreated ?? 0),
        activeListings: Number(row.activeListings ?? 0),
        inactiveListings: Number(row.inactiveListings ?? 0),
    }));
    const snapshot = snapshotRows[0];

    return {
        range: { from: range.from, to: range.to },
        group: range.group,
        totals: {
            totalListings: Number(snapshot?.totalListings ?? 0),
            listingsCreated: series.reduce((total, row) => total + row.listingsCreated, 0),
            activeListings: Number(snapshot?.activeListings ?? 0),
            inactiveListings: Number(snapshot?.inactiveListings ?? 0),
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

type HostSnapshotRow = {
    allHosts: number;
    activeHosts: number;
    verifiedHosts: number;
};

/**
 * Giải thuật tổng hợp báo cáo tăng trưởng chủ nhà (`role = 'host'`) theo kỳ kết hợp ảnh chụp toàn cục
 * số lượng tài khoản chủ nhà đang hoạt động và đã hoàn tất xác minh danh tính (`is_host_verified = 1`).
 */
export const getAdminHostsReport = async (admin: AuthenticatedUser, query: AnalyticsReportQuery) => {
    assertAdmin(admin);

    const range = parseAnalyticsRange(query);
    const groupBy = getGroupExpression(range.group, "u.created_at");
    const [rows, snapshotRows] = await Promise.all([
        sequelize.query<HostAnalyticsRow>(
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
        ),
        sequelize.query<HostSnapshotRow>(
            `
            SELECT
                COUNT(DISTINCT u.user_id) AS allHosts,
                COUNT(DISTINCT CASE WHEN u.status = 'active' THEN u.user_id END) AS activeHosts,
                COUNT(DISTINCT CASE WHEN u.status = 'active' AND u.is_host_verified = 1 THEN u.user_id END) AS verifiedHosts
            FROM users u
            INNER JOIN user_role ur ON ur.user_id = u.user_id
            INNER JOIN roles r ON r.role_id = ur.role_id AND r.code = 'host'
            WHERE u.deleted_at IS NULL
            `,
            {
                type: QueryTypes.SELECT,
            },
        ),
    ]);
    const series = rows.map((row) => ({
        period: row.period,
        hostsCreated: Number(row.hostsCreated ?? 0),
        activeHosts: Number(row.activeHosts ?? 0),
        verifiedHosts: Number(row.verifiedHosts ?? 0),
    }));
    const snapshot = snapshotRows[0];

    return {
        range: { from: range.from, to: range.to },
        group: range.group,
        totals: {
            totalHosts: Number(snapshot?.activeHosts ?? 0),
            hostsCreated: series.reduce((total, row) => total + row.hostsCreated, 0),
            activeHosts: Number(snapshot?.activeHosts ?? 0),
            verifiedHosts: Number(snapshot?.verifiedHosts ?? 0),
        },
        series,
    };
};
