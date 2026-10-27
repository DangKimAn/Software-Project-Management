import { createHash } from "node:crypto";

import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { getEnv } from "../../config/env";
import type { AuthenticatedUser } from "../auth/auth.service";
import HostPayoutBatch, { HostPayoutStatus } from "../../models/host-payout-batch";
import HostPayoutBookingItem from "../../models/host-payout-booking-item";
import PayoutAccount, { PayoutAccountDocument } from "../../models/payout-account";
import { moneyToVnd, vndToNumber } from "../../utils/money";
import { writeAuditLog } from "../../services/audit-log-service";
import { assertUserHasRole } from "../../services/user-access-service";
import { notifyPayoutCreated } from "../notifications/notification.service";

export type CreatePayoutAccountInput = {
    bankName: string;
    bankCode?: string | null;
    accountName: string;
    accountNumber: string;
    isDefault?: boolean;
};

export type UpdatePayoutAccountInput = Partial<CreatePayoutAccountInput>;

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

const hasOwn = <T extends object>(value: T, key: keyof T) =>
    Object.prototype.hasOwnProperty.call(value, key);

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

const normalizeOptional = (value?: string | null) => (value?.trim() ? value.trim() : null);

function assertTransferReference(value: string | undefined | null): string {
    const normalized = value?.trim();

    if (!normalized) {
        throw new ApiError(400, "Mã chuyển khoản là bắt buộc khi đánh dấu đã thanh toán.");
    }

    return normalized;
}

function assertDifferentAdmin(params: {
    actorUserId: number;
    blockedUserId: number | null | undefined;
    message: string;
}) {
    if (params.blockedUserId && Number(params.blockedUserId) === Number(params.actorUserId)) {
        throw new ApiError(403, params.message);
    }
}

const assertValidBankInfo = (input: {
    bankName?: string;
    bankCode?: string | null;
    accountName?: string;
    accountNumber?: string;
}) => {
    if (input.bankName !== undefined && !/^[\p{L}0-9 .,'&()-]{2,150}$/u.test(input.bankName.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "bankName",
                msg: "bankName format is invalid",
            },
        ]);
    }

    if (input.bankCode !== undefined && input.bankCode !== null && input.bankCode.trim() !== "") {
        if (!/^[A-Z0-9_-]{2,32}$/i.test(input.bankCode.trim())) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "bankCode",
                    msg: "bankCode format is invalid",
                },
            ]);
        }
    }

    if (input.accountName !== undefined && !/^[\p{L} .,'-]{2,255}$/u.test(input.accountName.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "accountName",
                msg: "accountName format is invalid",
            },
        ]);
    }

    if (input.accountNumber !== undefined && !/^\d{4,32}$/.test(input.accountNumber.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "accountNumber",
                msg: "accountNumber must contain 4 to 32 digits",
            },
        ]);
    }
};

const maskAccountNumber = (value: string) => {
    const suffix = value.slice(-4);
    return `****${suffix}`;
};

const hashAccountNumber = (value: string) =>
    createHash("sha256")
        .update(getEnv().tokenHashSecret)
        .update(":payout-account:")
        .update(value)
        .digest("hex");

const serializePayoutAccount = (account: PayoutAccountDocument) => ({
    payoutAccountId: account.payoutAccountId,
    bankName: account.bankName,
    bankCode: account.bankCode ?? null,
    accountName: account.accountName,
    accountNumberMasked: maskAccountNumber(account.accountNumber),
    isDefault: account.isDefault,
    createdAt: account.createdAt,
    updatedAt: account.updatedAt,
});

const getPayoutAccountForActor = async (
    payoutAccountId: number,
    actor: AuthenticatedUser,
    transaction?: Transaction,
) => {
    const account = await PayoutAccount.findOne({
        where: {
            payoutAccountId,
            deletedAt: null,
        },
        transaction,
    });

    if (!account) {
        throw new ApiError(404, "Payout account not found");
    }

    if (!actor.roles.includes("admin") && account.userId !== getCurrentUserId(actor)) {
        throw new ApiError(403, "Forbidden");
    }

    return account;
};

const assertNoDuplicatePayoutAccount = async (
    userId: number,
    bankName: string,
    bankCode: string | null,
    accountNumber: string,
    excludePayoutAccountId?: number,
) => {
    const rows = await PayoutAccount.find({
        userId,
        bankName,
        accountNumber,
        deletedAt: null,
    });
    const duplicate = rows.find(
        (row) =>
            row.payoutAccountId !== excludePayoutAccountId &&
            (bankCode === null || row.bankCode === null || row.bankCode === bankCode),
    );

    if (duplicate) {
        throw new ApiError(409, "Payout account already exists");
    }
};

export const getHostPayoutAccounts = async (user: AuthenticatedUser) => {
    const accounts = await PayoutAccount.find({
        userId: getCurrentUserId(user),
        deletedAt: null,
    }).sort({ isDefault: -1, createdAt: -1 });

    return {
        items: accounts.map(serializePayoutAccount),
    };
};

export const createPayoutAccount = async (
    user: AuthenticatedUser,
    input: CreatePayoutAccountInput,
) => {
    const userId = getCurrentUserId(user);
    const bankName = input.bankName.trim();
    const bankCode = normalizeOptional(input.bankCode);
    const accountNumber = input.accountNumber.trim();

    assertValidBankInfo(input);
    await assertNoDuplicatePayoutAccount(userId, bankName, bankCode, accountNumber);

    const account = await sequelize.transaction(async (transaction) => {
        if (input.isDefault === true) {
            await PayoutAccount.update(
                { isDefault: false },
                {
                    where: {
                        userId,
                        deletedAt: null,
                    },
                    transaction,
                },
            );
        }

        return PayoutAccount.create(
            {
                userId,
                bankName,
                bankCode,
                accountName: input.accountName.trim(),
                accountNumber,
                accountNumberEncrypted: null,
                accountNumberHash: hashAccountNumber(accountNumber),
                accountNumberLast4: accountNumber.slice(-4),
                isDefault: input.isDefault ?? false,
                deletedAt: null,
            },
            { transaction },
        );
    });

    return serializePayoutAccount(account);
};

export const updatePayoutAccount = async (
    user: AuthenticatedUser,
    payoutAccountId: number,
    input: UpdatePayoutAccountInput,
) => {
    if (
        !hasOwn(input, "bankName") &&
        !hasOwn(input, "bankCode") &&
        !hasOwn(input, "accountName") &&
        !hasOwn(input, "accountNumber") &&
        !hasOwn(input, "isDefault")
    ) {
        throw new ApiError(422, "Validation error", [
            {
                path: "body",
                msg: "At least one payout account field must be provided",
            },
        ]);
    }

    return sequelize.transaction(async (transaction) => {
        const account = await getPayoutAccountForActor(payoutAccountId, user, transaction);
        const nextBankName = input.bankName?.trim() ?? account.bankName;
        const nextBankCode = hasOwn(input, "bankCode") ? normalizeOptional(input.bankCode) : account.bankCode;
        const nextAccountNumber = input.accountNumber?.trim() ?? account.accountNumber;

        assertValidBankInfo(input);
        await assertNoDuplicatePayoutAccount(
            account.userId,
            nextBankName,
            nextBankCode,
            nextAccountNumber,
            account.payoutAccountId,
        );

        if (input.isDefault === true) {
            await PayoutAccount.update(
                { isDefault: false },
                {
                    where: {
                        userId: account.userId,
                        deletedAt: null,
                    },
                    transaction,
                },
            );
        }

        account.bankName = nextBankName;
        account.bankCode = nextBankCode;
        account.accountNumber = nextAccountNumber;
        account.accountNumberHash = hashAccountNumber(nextAccountNumber);
        account.accountNumberLast4 = nextAccountNumber.slice(-4);

        if (input.accountName !== undefined) {
            account.accountName = input.accountName.trim();
        }

        if (input.isDefault !== undefined) {
            account.isDefault = input.isDefault;
        }

        await account.save({ transaction });
        return serializePayoutAccount(account);
    });
};

export const deletePayoutAccount = async (user: AuthenticatedUser, payoutAccountId: number) => {
    return sequelize.transaction(async (transaction) => {
        const account = await getPayoutAccountForActor(payoutAccountId, user, transaction);

        if (account.isDefault) {
            const activePayoutCount = await HostPayoutBatch.countDocuments({
                payoutAccountId: account.payoutAccountId,
                status: { $in: ["pending", "approved", "processing"] },
            });

            if (activePayoutCount > 0) {
                throw new ApiError(409, "Cannot delete default account used by active payouts");
            }
        }

        account.deletedAt = new Date();
        account.isDefault = false;
        await account.save({ transaction });
    });
};

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
        replacements.from = `${query.from} 00:00:00`;
    }

    if (query.to) {
        where.push("p.created_at <= :to");
        replacements.to = `${query.to} 23:59:59`;
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

        return payout;
    });
}
