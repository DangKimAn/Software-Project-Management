/**
 * Dịch vụ đối soát, khởi tạo và phê duyệt lô chi trả doanh thu Chủ nhà theo nguyên tắc Maker-Checker (`payouts.service`).
 */
// CONFLICT-RESOLVED: Tách phần quản lý tài khoản ngân hàng sang `payout-accounts.service.ts` để giữ `payouts.service.ts`
// tập trung vào nghiệp vụ quyết toán lô chi trả và kiểm soát chéo Maker-Checker.
import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import { parseVietnamDateBoundary } from "../../common/date-time";
import { moneyToVnd, vndToNumber } from "../../common/money";
import sequelize from "../../config/database";
import HostPayoutBatch, { type HostPayoutStatus } from "../../models/host-payout-batch";
import HostPayoutBookingItem from "../../models/host-payout-booking-item";
import PayoutAccount from "../../models/payout-account";
import { writeAuditLog } from "../../services/audit-log.service";
import type { AuthenticatedUser } from "../auth/auth.service";
import { notifyPayoutCreated } from "../notifications/notification.service";
import { assertUserHasRole } from "../users/user-access.service";
import * as payoutAccountsService from "./payout-accounts.service";

export type {
    CreatePayoutAccountInput,
    SaveHostBankAccountInput,
    UpdatePayoutAccountInput,
} from "./payout-accounts.service";

export type PayoutListQuery = {
    status?: HostPayoutStatus;
    from?: string;
    to?: string;
    page?: number;
    limit?: number;
};

export type AdminPayoutListQuery = PayoutListQuery & {
    hostId?: number;
};

export type CreateHostPayoutInput = {
    hostId: number;
    bookingIds: number[];
    payoutAccountId: number;
    amount: number;
    currency: "VND";
    notes?: string | null;
};

type AuditContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

type BookingPayoutCandidate = {
    bookingId: number;
    bookingDetailId: number;
    listingId: number;
    hostId: number;
    bookingStatus: string;
    paymentStatus: string | null;
    listingTitle: string;
    totalAmount: string;
    currency: string;
    serviceFeeAmount: string;
    hostAmount: string;
};

type PayoutRow = {
    payoutId: number;
    hostId: number;
    payoutAccountId: number;
    amount: string;
    currency: string;
    status: HostPayoutStatus;
    notes: string | null;
    paidAt: Date | null;
    transferReference: string | null;
    createdAt: Date;
    bookingIds: string | null;
    listingTitles: string | null;
};

const toPagination = (page?: number, limit?: number) => ({
    page: page ?? 1,
    limit: limit ?? 10,
});

const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

function assertTransferReference(value: string | undefined | null): string {
    const normalized = value?.trim();

    if (!normalized) {
        throw new ApiError(400, "Mã chuyển khoản là bắt buộc khi đánh dấu đã thanh toán.");
    }

    return normalized;
}

/**
 * Giải thuật kiểm soát phân tách nhiệm vụ Maker-Checker (Segregation of Duties):
 * Nghiêm cấm một quản trị viên vừa khởi tạo vừa tự phê duyệt, hoặc vừa phê duyệt vừa tự xác nhận chuyển tiền (`403 Forbidden`).
 */
function assertDifferentAdmin(params: {
    actorUserId: number;
    blockedUserId: number | null | undefined;
    message: string;
}) {
    if (params.blockedUserId && Number(params.blockedUserId) === Number(params.actorUserId)) {
        throw new ApiError(403, params.message);
    }
}

export const getHostPayoutAccounts = (user: AuthenticatedUser) =>
    payoutAccountsService.getHostPayoutAccounts(user);

export const createPayoutAccount = (
    user: AuthenticatedUser,
    input: payoutAccountsService.CreatePayoutAccountInput,
) => payoutAccountsService.createPayoutAccount(user, input);

export const updatePayoutAccount = (
    user: AuthenticatedUser,
    payoutAccountId: number,
    input: payoutAccountsService.UpdatePayoutAccountInput,
) => payoutAccountsService.updatePayoutAccount(user, payoutAccountId, input);

export const deletePayoutAccount = (user: AuthenticatedUser, payoutAccountId: number) =>
    payoutAccountsService.deletePayoutAccount(user, payoutAccountId);

export const getHostBankAccount = (user: AuthenticatedUser) =>
    payoutAccountsService.getHostBankAccount(user);

export const saveHostBankAccount = (
    user: AuthenticatedUser,
    input: payoutAccountsService.SaveHostBankAccountInput,
) => payoutAccountsService.saveHostBankAccount(user, input);

const buildPayoutWhere = (query: PayoutListQuery, hostId?: number) => {
    const where: string[] = [];
    const replacements: Record<string, unknown> = {};

    if (hostId !== undefined) {
        where.push("p.host_id = :hostId");
        replacements.hostId = hostId;
    }

    if (query.status) {
        where.push("p.status = :status");
        replacements.status = query.status;
    }

    if (query.from) {
        where.push("p.created_at >= :from");
        replacements.from = parseVietnamDateBoundary(query.from, "start");
    }

    if (query.to) {
        where.push("p.created_at <= :to");
        replacements.to = parseVietnamDateBoundary(query.to, "end");
    }

    return {
        whereSql: where.length > 0 ? `WHERE ${where.join(" AND ")}` : "",
        replacements,
    };
};

const mapPayoutRow = (row: PayoutRow) => ({
    payoutId: row.payoutId,
    hostId: row.hostId,
    payoutAccountId: row.payoutAccountId,
    amount: vndToNumber(moneyToVnd(row.amount)),
    currency: row.currency,
    status: row.status,
    notes: row.notes ?? null,
    paidAt: row.paidAt ?? null,
    transferReference: row.transferReference ?? null,
    bookingIds: row.bookingIds ? row.bookingIds.split(",").map(Number) : [],
    listingTitles: row.listingTitles ? row.listingTitles.split("||").filter(Boolean) : [],
    createdAt: row.createdAt,
});

const listPayouts = async (query: PayoutListQuery, hostId?: number) => {
    const { page, limit } = toPagination(query.page, query.limit);
    const offset = (page - 1) * limit;
    const { whereSql, replacements } = buildPayoutWhere(query, hostId);
    const rows = await sequelize.query<PayoutRow>(
        `
        SELECT
            p.payout_id AS payoutId,
            p.host_id AS hostId,
            p.payout_account_id AS payoutAccountId,
            p.amount,
            p.currency,
            p.status,
            p.notes,
            p.paid_at AS paidAt,
            p.transfer_reference AS transferReference,
            p.created_at AS createdAt,
            GROUP_CONCAT(DISTINCT i.booking_order_id ORDER BY i.booking_order_id) AS bookingIds,
            GROUP_CONCAT(DISTINCT l.title ORDER BY l.title SEPARATOR '||') AS listingTitles
        FROM host_payout_batch p
        LEFT JOIN host_payout_booking_item i ON i.payout_id = p.payout_id
        LEFT JOIN bookings b ON b.booking_id = i.booking_order_id
        LEFT JOIN listings l ON l.listing_id = b.listing_id
        ${whereSql}
        GROUP BY p.payout_id
        ORDER BY p.created_at DESC, p.payout_id DESC
        LIMIT :limit OFFSET :offset
        `,
        {
            replacements: { ...replacements, limit, offset },
            type: QueryTypes.SELECT,
        },
    );
    const countRows = await sequelize.query<{ totalItems: number }>(
        `
        SELECT COUNT(*) AS totalItems
        FROM host_payout_batch p
        ${whereSql}
        `,
        {
            replacements,
            type: QueryTypes.SELECT,
        },
    );
    const totalItems = Number(countRows[0]?.totalItems ?? 0);

    return {
        items: rows.map(mapPayoutRow),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

export const getHostPayouts = async (user: AuthenticatedUser, query: PayoutListQuery) =>
    listPayouts(query, getCurrentUserId(user));

export const getAdminHostPayouts = async (admin: AuthenticatedUser, query: AdminPayoutListQuery) => {
    assertAdmin(admin);
    return listPayouts(query, query.hostId);
};

const getBookingPayoutCandidates = async (
    bookingIds: number[],
    hostId: number,
    transaction?: Transaction,
) =>
    sequelize.query<BookingPayoutCandidate>(
        `
        SELECT
            b.booking_id AS bookingId,
            b.booking_id AS bookingDetailId,
            b.listing_id AS listingId,
            b.host_user_id AS hostId,
            b.status AS bookingStatus,
            p.status AS paymentStatus,
            l.title AS listingTitle,
            b.total_amount AS totalAmount,
            b.currency,
            COALESCE(b.service_fee_amount, 0) AS serviceFeeAmount,
            GREATEST(COALESCE(b.total_amount, 0) - COALESCE(b.service_fee_amount, 0), 0) AS hostAmount
        FROM bookings b
        INNER JOIN listings l ON l.listing_id = b.listing_id
        LEFT JOIN payments p ON p.booking_id = b.booking_id AND p.status = 'paid'
        WHERE b.booking_id IN (:bookingIds)
          AND b.host_user_id = :hostId
        FOR UPDATE
        `,
        {
            replacements: {
                bookingIds,
                hostId,
            },
            type: QueryTypes.SELECT,
            transaction,
        },
    );

/**
 * Giải thuật chống chi trả trùng lặp (Anti-Double-Payout) trong giao dịch ACID có khóa bi quan `FOR UPDATE`.
 */
const assertNoDuplicatePayoutBookings = async (
    bookingDetailIds: number[],
    transaction?: Transaction,
) => {
    const duplicateBatchRows = await sequelize.query<{ bookingDetailId: number }>(
        `
        SELECT i.booking_detail_id AS bookingDetailId
        FROM host_payout_booking_item i
        INNER JOIN host_payout_batch p ON p.payout_id = i.payout_id
        WHERE i.booking_detail_id IN (:bookingDetailIds)
          AND p.status IN ('pending','approved','processing','paid')
        FOR UPDATE
        `,
        {
            replacements: { bookingDetailIds },
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    if (duplicateBatchRows.length > 0) {
        throw new ApiError(409, "One or more bookings already have a payout");
    }

    const legacyTableRows = await sequelize.query<{ count: number }>(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = 'host_payout'
        `,
        {
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    if (Number(legacyTableRows[0]?.count ?? 0) === 0) {
        return;
    }

    const legacyRows = await sequelize.query<{ bookingDetailId: number }>(
        `
        SELECT booking_detail_id AS bookingDetailId
        FROM host_payout
        WHERE booking_detail_id IN (:bookingDetailIds)
          AND status IN ('pending','approved','processing','paid')
        `,
        {
            replacements: { bookingDetailIds },
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    if (legacyRows.length > 0) {
        throw new ApiError(409, "One or more bookings already have a payout");
    }
};

/**
 * Giải thuật khởi tạo lô chi trả cho Host nguyên tử trong giao dịch ACID (chặng Maker khởi tạo):
 * Khóa bi quan đơn ứng viên, đối chiếu số tiền thực nhận trên miền `BigInt` VND và ghi nhận `createdByUserId`.
 */
export const createHostPayout = async (
    admin: AuthenticatedUser,
    input: CreateHostPayoutInput,
    context: AuditContext = {},
) => {
    assertAdmin(admin);

    const actorUserId = getCurrentUserId(admin);
    const bookingIds = Array.from(new Set(input.bookingIds));

    await assertUserHasRole(input.hostId, "host");

    return sequelize.transaction(async (transaction) => {
        const payoutAccount = await PayoutAccount.findOne({
            where: {
                payoutAccountId: input.payoutAccountId,
                userId: input.hostId,
                deletedAt: null,
            },
            transaction,
        });

        if (!payoutAccount) {
            throw new ApiError(404, "Payout account not found");
        }

        const bookingRows = await getBookingPayoutCandidates(bookingIds, input.hostId, transaction);
        const foundBookingIds = new Set(bookingRows.map((row) => row.bookingId));
        const missingBookingIds = bookingIds.filter((bookingId) => !foundBookingIds.has(bookingId));

        if (missingBookingIds.length > 0) {
            throw new ApiError(404, "One or more bookings were not found");
        }

        const invalidRows = bookingRows.filter(
            (row) => !["checked_out", "completed"].includes(row.bookingStatus) || row.paymentStatus !== "paid",
        );

        if (invalidRows.length > 0) {
            throw new ApiError(409, "Bookings must have paid payment and checked_out/completed status before payout");
        }

        await assertNoDuplicatePayoutBookings(
            bookingRows.map((row) => row.bookingDetailId),
            transaction,
        );

        const expectedAmountVnd = bookingRows.reduce(
            (total, row) => total + moneyToVnd(row.hostAmount),
            0n,
        );
        const inputAmountVnd = moneyToVnd(input.amount);

        if (inputAmountVnd !== expectedAmountVnd) {
            throw new ApiError(422, "Payout amount does not match eligible bookings total", [
                {
                    path: "amount",
                    msg: `amount must equal ${expectedAmountVnd.toString()} VND`,
                },
            ]);
        }

        const payout = await HostPayoutBatch.create(
            {
                hostId: input.hostId,
                payoutAccountId: input.payoutAccountId,
                amount: vndToNumber(expectedAmountVnd),
                currency: input.currency,
                status: "pending",
                notes: input.notes?.trim() ? input.notes.trim() : null,
                createdByUserId: actorUserId,
                approvedByUserId: null,
                approvedAt: null,
                rejectedByUserId: null,
                rejectedAt: null,
                rejectionReason: null,
                paidAt: null,
                paidByUserId: null,
                transferReference: null,
            },
            { transaction },
        );

        await HostPayoutBookingItem.bulkCreate(
            bookingRows.map((row) => ({
                payoutId: payout.payoutId,
                bookingOrderId: row.bookingId,
                bookingDetailId: row.bookingDetailId,
                amount: row.totalAmount,
                currency: row.currency,
                serviceFeeAmount: row.serviceFeeAmount,
                hostAmount: row.hostAmount,
                createdAt: new Date(),
            })),
            { transaction },
        );

        await writeAuditLog({
            actorId: actorUserId,
            action: "payout.create",
            targetType: "host_payout_batch",
            targetId: payout.payoutId,
            metadata: {
                hostId: input.hostId,
                payoutAccountId: input.payoutAccountId,
                bookingIds,
                amount: vndToNumber(expectedAmountVnd),
                currency: input.currency,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
        await notifyPayoutCreated(payout.payoutId, transaction);

        return {
            payoutId: payout.payoutId,
            status: payout.status,
        };
    });
};

export async function approveHostPayout(params: {
    payoutId: number;
    actorUserId: number;
}) {
    return sequelize.transaction(async (transaction) => {
        const payout = await HostPayoutBatch.findByPk(params.payoutId, {
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!payout) {
            throw new ApiError(404, "Không tìm thấy payout");
        }

        if (payout.status !== "pending") {
            throw new ApiError(409, "Chỉ payout pending mới được duyệt.");
        }

        assertDifferentAdmin({
            actorUserId: params.actorUserId,
            blockedUserId: payout.createdByUserId,
            message: "Admin tạo payout không được tự duyệt payout này.",
        });

        payout.status = "approved";
        payout.approvedByUserId = params.actorUserId;
        payout.approvedAt = new Date();

        await payout.save({ transaction });
        await writeAuditLog({
            actorId: params.actorUserId,
            action: "admin_payout.approve",
            targetType: "host_payout_batch",
            targetId: payout.payoutId,
            metadata: {
                hostId: payout.hostId,
                status: payout.status,
            },
            transaction,
        });

        return payout;
    });
}

export async function rejectHostPayout(params: {
    payoutId: number;
    actorUserId: number;
    reason: string;
}) {
    return sequelize.transaction(async (transaction) => {
        const payout = await HostPayoutBatch.findByPk(params.payoutId, {
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!payout) {
            throw new ApiError(404, "Không tìm thấy payout");
        }

        if (payout.status !== "pending" && payout.status !== "approved") {
            throw new ApiError(409, "Payout hiện tại không thể từ chối.");
        }

        const rejectionReason = params.reason.trim();

        if (!rejectionReason) {
            throw new ApiError(400, "Lý do từ chối là bắt buộc.");
        }

        payout.status = "rejected";
        payout.rejectedByUserId = params.actorUserId;
        payout.rejectedAt = new Date();
        payout.rejectionReason = rejectionReason;

        await payout.save({ transaction });
        await writeAuditLog({
            actorId: params.actorUserId,
            action: "admin_payout.reject",
            targetType: "host_payout_batch",
            targetId: payout.payoutId,
            metadata: {
                hostId: payout.hostId,
                reason: rejectionReason,
            },
            transaction,
        });

        return payout;
    });
}

export async function markHostPayoutPaid(params: {
    payoutId: number;
    actorUserId: number;
    transferReference: string;
}) {
    return sequelize.transaction(async (transaction) => {
        const payout = await HostPayoutBatch.findByPk(params.payoutId, {
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!payout) {
            throw new ApiError(404, "Không tìm thấy payout");
        }

        if (payout.status !== "approved") {
            throw new ApiError(409, "Chỉ payout đã duyệt mới được đánh dấu đã chuyển tiền.");
        }

        assertDifferentAdmin({
            actorUserId: params.actorUserId,
            blockedUserId: payout.approvedByUserId,
            message: "Admin đã duyệt payout không được tự đánh dấu đã chuyển tiền.",
        });

        payout.status = "paid";
        payout.paidAt = new Date();
        payout.paidByUserId = params.actorUserId;
        payout.transferReference = assertTransferReference(params.transferReference);

        await payout.save({ transaction });
        await writeAuditLog({
            actorId: params.actorUserId,
            action: "admin_payout.mark_paid",
            targetType: "host_payout_batch",
            targetId: payout.payoutId,
            metadata: {
                hostId: payout.hostId,
                transferReference: payout.transferReference,
            },
            transaction,
        });

        return payout;
    });
}
