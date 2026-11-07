import { Op } from "sequelize";
import sequelize from "../../config/database";
import { ApiError } from "../../common/api-error";
import { AuthenticatedUser } from "../auth/auth.service";
import Booking from "../../models/booking";
import Refund, { RefundStatus } from "../../models/refund";
import { executeDisbursement } from "../disbursement/disbursement.service";
import { writeAuditLog } from "../../services/audit-log-service";
import { notifyRefundSucceeded, notifyRefundRejected } from "../notifications/notification.service";

export type AdminRefundListQuery = {
    status?: RefundStatus;
    bookingId?: number;
    page?: number;
    limit?: number;
};

export const listAdminRefunds = async (admin: AuthenticatedUser, query: AdminRefundListQuery) => {
    if (!admin.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }

    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
    const offset = (page - 1) * limit;

    const where: any = {};
    if (query.status) {
        where.status = query.status;
    }
    if (query.bookingId) {
        where.bookingId = query.bookingId;
    }

    const { count, rows } = await Refund.findAndCountAll({
        where,
        order: [["createdAt", "DESC"]],
        limit,
        offset,
    });

    const bookingIds = Array.from(new Set(rows.map((r) => r.bookingId)));
    const bookings = await Booking.findAll({
        where: {
            bookingId: {
                [Op.in]: bookingIds,
            },
        },
    });
    const bookingMap = new Map(bookings.map((b) => [b.bookingId, b]));

    const items = rows.map((refund) => {
        const booking = bookingMap.get(refund.bookingId);
        return {
            refundId: refund.refundId,
            paymentId: refund.paymentId,
            bookingId: refund.bookingId,
            amount: Number(refund.amount),
            currency: refund.currency,
            status: refund.status,
            reason: refund.reason,
            bankName: refund.bankName,
            accountNumber: refund.accountNumber,
            accountName: refund.accountName,
            providerRef: refund.providerRef,
            requestedByUserId: refund.requestedByUserId,
            processedByUserId: refund.processedByUserId,
            processedAt: refund.processedAt,
            createdAt: refund.createdAt,
            updatedAt: refund.updatedAt,
            booking: booking
                ? {
                      bookingId: booking.bookingId,
                      guestUserId: booking.guestUserId,
                      hostUserId: booking.hostUserId,
                      listingId: booking.listingId,
                      totalAmount: Number(booking.totalAmount),
                      checkInDate: booking.checkInDate,
                      checkOutDate: booking.checkOutDate,
                      status: booking.status,
                  }
                : null,
        };
    });

    return {
        items,
        pagination: {
            page,
            limit,
            totalItems: count,
            totalPages: Math.ceil(count / limit),
        },
    };
};

export const approveAndDisburseRefund = async (params: {
    refundId: number;
    actorUserId: number;
    bankName?: string;
    accountNumber?: string;
    accountName?: string;
    notes?: string;
}) => {
    const refund = await Refund.findByPk(params.refundId);
    if (!refund) {
        throw new ApiError(404, "Không tìm thấy yêu cầu hoàn tiền");
    }

    if (refund.status === "succeeded") {
        throw new ApiError(409, "Yêu cầu hoàn tiền này đã được thực hiện trước đó");
    }

    if (refund.status === "cancelled") {
        throw new ApiError(409, "Yêu cầu hoàn tiền này đã bị từ chối");
    }

    const bankName = params.bankName || refund.bankName;
    const accountNumber = params.accountNumber || refund.accountNumber;
    const accountName = params.accountName || refund.accountName;

    if (!bankName || !accountNumber || !accountName) {
        throw new ApiError(
            422,
            "Thiếu thông tin ngân hàng nhận hoàn tiền (Ngân hàng, STK, Tên chủ tài khoản). Vui lòng cập nhật trước khi duyệt.",
        );
    }

    // 1. Thực hiện chuyển khoản qua Engine Chi hộ (Mock Napas 24/7 hoặc PayOS)
    const disburseResult = await executeDisbursement({
        targetType: "guest_refund",
        targetId: refund.refundId,
        bankCode: bankName,
        accountNumber,
        accountName,
        amount: Number(refund.amount),
        currency: refund.currency,
        description: `Hoan tien booking #${refund.bookingId}`,
    });

    // 2. Cập nhật trạng thái hoàn tiền
    return sequelize.transaction(async (transaction) => {
        refund.status = "succeeded";
        refund.bankName = bankName;
        refund.accountNumber = accountNumber;
        refund.accountName = accountName;
        refund.providerRef = disburseResult.transferReference;
        refund.processedByUserId = params.actorUserId;
        refund.processedAt = disburseResult.transferredAt;

        await refund.save({ transaction });

        await writeAuditLog({
            actorId: params.actorUserId,
            action: "admin_refund.disburse",
            targetType: "refund",
            targetId: refund.refundId,
            metadata: {
                bookingId: refund.bookingId,
                amount: refund.amount,
                provider: disburseResult.provider,
                transferReference: disburseResult.transferReference,
                bankName,
                accountNumber,
            },
            transaction,
        });

        await notifyRefundSucceeded(refund.refundId, transaction);

        return {
            refund,
            disbursement: disburseResult,
        };
    });
};

export const rejectRefund = async (params: {
    refundId: number;
    actorUserId: number;
    reason: string;
}) => {
    const refund = await Refund.findByPk(params.refundId);
    if (!refund) {
        throw new ApiError(404, "Không tìm thấy yêu cầu hoàn tiền");
    }

    if (refund.status === "succeeded") {
        throw new ApiError(409, "Không thể từ chối yêu cầu hoàn tiền đã hoàn tất");
    }

    const rejectionReason = params.reason.trim();
    if (!rejectionReason) {
        throw new ApiError(400, "Lý do từ chối là bắt buộc");
    }

    return sequelize.transaction(async (transaction) => {
        refund.status = "cancelled";
        refund.processedByUserId = params.actorUserId;
        refund.processedAt = new Date();
        refund.reason = refund.reason
            ? `${refund.reason} | Từ chối bởi Admin: ${rejectionReason}`
            : `Từ chối bởi Admin: ${rejectionReason}`;

        await refund.save({ transaction });

        await writeAuditLog({
            actorId: params.actorUserId,
            action: "admin_refund.reject",
            targetType: "refund",
            targetId: refund.refundId,
            metadata: {
                bookingId: refund.bookingId,
                reason: rejectionReason,
            },
            transaction,
        });

        await notifyRefundRejected(refund.refundId, rejectionReason, transaction);

        return refund;
    });
};
