import type { Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import BookingStatusHistory from "../../models/booking-status-history";
import type { BookingDocument, BookingStatus } from "../../models/booking";
import { enqueueHostSheetSyncJobSafe } from "../host-sheet-sync/host-sheet-sync.service";

export type BookingStateActor = "guest" | "host" | "admin" | "system";

export type BookingTransitionCondition =
    | "none"
    | "payment_hold_expired"
    | "payment_succeeded_before_expiration"
    | "successful_payment_exists"
    | "check_in_date_is_today"
    | "check_in_date_reached"
    | "check_out_date_reached"
    | "stay_checked_out"
    | "cancellation_allowed_before_stay"
    | "admin_override"
    | "host_rejects_before_confirmation";

export type BookingTransitionSideEffect =
    | "clear_payment_hold"
    | "set_paid_at"
    | "expire_pending_payments"
    | "release_date_locks"
    | "create_refund_if_needed"
    | "mark_cancelled_at"
    | "mark_checked_in_at"
    | "mark_checked_out_at"
    | "redeem_coupon_if_needed"
    | "send_confirmation_email"
    | "write_booking_status_history"
    | "write_audit_log"
    | "handled_in_refund_status"
    | "handled_in_payout_status";

export type BookingTransitionDefinition = {
    from: readonly BookingStatus[];
    to: BookingStatus;
    actors: readonly BookingStateActor[];
    condition: BookingTransitionCondition;
    sideEffects: readonly BookingTransitionSideEffect[];
};

export type BookingTransitionContext = {
    now?: Date;
    hasSuccessfulPayment?: boolean;
    paymentPaidAt?: Date | null;
    paymentExpiresAt?: Date | null;
    checkInDate?: string | null;
    checkOutDate?: string | null;
};

/**
 * Chính sách phân tách trạng thái tài chính khỏi máy trạng thái vòng đời lưu trú (FSM Separation of Concerns):
 * - Các tiến trình hoàn tiền và chi trả cho Host được quản lý độc lập tại `payments.status`, `refunds.status` và `host_payout_batch.status`,
 *   không trộn lẫn vào cột `bookings.status` nhằm giữ tính đơn định và tránh bùng nổ tổ hợp trạng thái.
 */
export const bookingFinancialStatusesExcludedFromLifecycle = [
    "refund_pending",
    "refunded",
    "payout_pending",
    "payout_paid",
] as const;

export const separatedFinancialStatusPolicy = {
    paymentStatus: "payments.status",
    refundStatus: "refunds.status",
    payoutStatus: "host_payout_batch.status",
    excludedBookingStatuses: bookingFinancialStatusesExcludedFromLifecycle,
} as const;

/**
 * Tập các trạng thái kết thúc (absorbing/terminal states) của máy trạng thái đơn đặt phòng:
 * Một đơn đã đi vào tập này thì không được phép dịch chuyển sang bất kỳ trạng thái lưu trú nào khác.
 */
export const terminalBookingStatuses = [
    "payment_expired",
    "completed",
    "cancelled_by_guest",
    "cancelled_by_host",
    "cancelled_by_admin",
    "rejected",
] as const satisfies readonly BookingStatus[];

/**
 * Ma trận chuyển trạng thái hợp lệ của máy trạng thái hữu hạn (FSM Transition Matrix):
 * - Mỗi phần tử đặc tả bộ quy tắc `(from, to, actors, condition, sideEffects)`.
 * - Kiểm soát phân quyền tác nhân chặt chẽ giữa `guest` (khách đặt), `host` (chủ nhà), `admin` (quản trị viên) và `system` (tiến trình tự động),
 *   đồng thời ràng buộc điều kiện biên về thanh toán và mốc ngày nhận/trả phòng trước khi cho phép đổi trạng thái.
 */
export const allowedBookingTransitions = [
    {
        from: ["pending_payment"],
        to: "payment_expired",
        actors: ["system"],
        condition: "payment_hold_expired",
        sideEffects: ["expire_pending_payments", "release_date_locks", "write_booking_status_history"],
    },
    {
        from: ["pending_payment"],
        to: "paid",
        actors: ["system"],
        condition: "payment_succeeded_before_expiration",
        sideEffects: [
            "clear_payment_hold",
            "set_paid_at",
            "redeem_coupon_if_needed",
            "send_confirmation_email",
            "write_booking_status_history",
        ],
    },
    {
        from: ["paid"],
        to: "confirmed",
        actors: ["host", "admin"],
        condition: "successful_payment_exists",
        sideEffects: ["clear_payment_hold", "write_booking_status_history", "write_audit_log"],
    },
    {
        from: ["confirmed"],
        to: "checked_in",
        actors: ["host", "admin"],
        condition: "check_in_date_is_today",
        sideEffects: ["mark_checked_in_at", "write_booking_status_history", "write_audit_log"],
    },
    {
        from: ["confirmed"],
        to: "checked_in",
        actors: ["system"],
        condition: "check_in_date_reached",
        sideEffects: ["mark_checked_in_at", "write_booking_status_history"],
    },
    {
        from: ["checked_in"],
        to: "checked_out",
        actors: ["host", "admin"],
        condition: "check_out_date_reached",
        sideEffects: ["mark_checked_out_at", "write_booking_status_history", "write_audit_log"],
    },
    {
        from: ["checked_in"],
        to: "checked_out",
        actors: ["system"],
        condition: "check_out_date_reached",
        sideEffects: ["mark_checked_out_at", "write_booking_status_history"],
    },
    // CONFLICT-RESOLVED: Cho phép hệ thống tự động khép vòng đời đơn 'paid' đã qua ngày checkOutDate sang 'completed'
    {
        from: ["paid"],
        to: "completed",
        actors: ["system"],
        condition: "check_out_date_reached",
        sideEffects: [
            "clear_payment_hold",
            "mark_checked_out_at",
            "write_booking_status_history",
            "handled_in_payout_status",
        ],
    },
    {
        from: ["checked_out"],
        to: "completed",
        actors: ["system", "admin"],
        condition: "stay_checked_out",
        sideEffects: [
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_payout_status",
        ],
    },
    {
        from: ["pending_payment", "paid", "confirmed"],
        to: "cancelled_by_guest",
        actors: ["guest"],
        condition: "cancellation_allowed_before_stay",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
    {
        from: ["confirmed"],
        to: "cancelled_by_host",
        actors: ["host"],
        condition: "cancellation_allowed_before_stay",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
    {
        from: ["pending_payment", "paid", "confirmed", "checked_in"],
        to: "cancelled_by_admin",
        actors: ["admin"],
        condition: "admin_override",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
    {
        from: ["paid"],
        to: "rejected",
        actors: ["host", "admin"],
        condition: "host_rejects_before_confirmation",
        sideEffects: [
            "release_date_locks",
            "create_refund_if_needed",
            "mark_cancelled_at",
            "write_booking_status_history",
            "write_audit_log",
            "handled_in_refund_status",
        ],
    },
] as const satisfies readonly BookingTransitionDefinition[];

/**
 * Giải thuật quy đổi thời điểm hiện tại sang chuỗi ngày lịch `YYYY-MM-DD` theo múi giờ Việt Nam (`UTC+7`)
 * nhằm đảm bảo các phép so sánh mốc ngày nhận phòng (`checkInDate`) và trả phòng (`checkOutDate`) nhất quán với giờ địa phương.
 */
const getVietnamTodayDateString = (now = new Date()) =>
    new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);

/**
 * Tập hàm kiểm tra điều kiện gác (Guard Predicates) cho từng quy tắc chuyển trạng thái trong FSM:
 * - Ràng buộc bất biến thời hạn giữ chỗ (`paymentExpiresAt <= now`), thanh toán hợp lệ trước hạn (`paymentPaidAt <= paymentExpiresAt`),
 *   và bất biến trình tự thời gian lưu trú (`todayVN === checkInDate`, `todayVN >= checkInDate`, `todayVN >= checkOutDate`).
 */
const conditionChecks: Record<BookingTransitionCondition, (context: BookingTransitionContext) => boolean> = {
    none: () => true,
    payment_hold_expired: (context) =>
        Boolean(context.paymentExpiresAt && context.paymentExpiresAt.getTime() <= (context.now ?? new Date()).getTime()),
    payment_succeeded_before_expiration: (context) => {
        if (!context.hasSuccessfulPayment) {
            return false;
        }

        if (!context.paymentExpiresAt || !context.paymentPaidAt) {
            return true;
        }

        return context.paymentPaidAt.getTime() <= context.paymentExpiresAt.getTime();
    },
    successful_payment_exists: (context) => Boolean(context.hasSuccessfulPayment),
    check_in_date_is_today: (context) =>
        Boolean(context.checkInDate && context.checkInDate === getVietnamTodayDateString(context.now)),
    check_in_date_reached: (context) =>
        Boolean(context.checkInDate && getVietnamTodayDateString(context.now) >= context.checkInDate),
    check_out_date_reached: (context) =>
        Boolean(context.checkOutDate && getVietnamTodayDateString(context.now) >= context.checkOutDate),
    stay_checked_out: () => true,
    cancellation_allowed_before_stay: () => true,
    admin_override: () => true,
    host_rejects_before_confirmation: () => true,
};

/**
 * Giải thuật tra cứu cung chuyển trạng thái hợp lệ trên ma trận `allowedBookingTransitions`
 * theo bộ ba tham số `(from, to, actor)`; trả về định nghĩa bước chuyển hoặc `null` nếu tác nhân không có quyền hoặc cung không tồn tại.
 */
export const findBookingTransition = (
    from: BookingStatus,
    to: BookingStatus,
    actor: BookingStateActor,
) =>
    allowedBookingTransitions.find(
        (transition) =>
            transition.to === to &&
            (transition.from as readonly BookingStatus[]).includes(from) &&
            (transition.actors as readonly BookingStateActor[]).includes(actor),
    ) ?? null;

/**
 * Giải thuật kiểm định tính hợp lệ toàn diện của một yêu cầu chuyển trạng thái FSM:
 * 1. Tra cứu quyền chuyển `(from -> to)` của tác nhân `actor` trên ma trận FSM.
 * 2. Thực thi hàm gác `conditionChecks[transition.condition]` với ngữ cảnh thời gian/thanh toán hiện tại;
 *    ném ngoại lệ `409 Conflict` ngay lập tức nếu vi phạm bất biến trạng thái hoặc điều kiện biên.
 */
export const assertBookingStatusTransition = (params: {
    from: BookingStatus;
    to: BookingStatus;
    actor: BookingStateActor;
    context?: BookingTransitionContext;
}) => {
    const transition = findBookingTransition(params.from, params.to, params.actor);

    if (!transition) {
        throw new ApiError(409, `Invalid booking status transition: ${params.from} -> ${params.to}`);
    }

    if (!conditionChecks[transition.condition](params.context ?? {})) {
        throw new ApiError(409, `Booking status transition condition failed: ${transition.condition}`);
    }

    return transition;
};

/**
 * Giải thuật thực thi chuyển trạng thái đơn đặt phòng nguyên tử (ACID), tăng phiên bản và ghi vết lịch sử kiểm toán:
 * 1. Xác thực cung chuyển FSM và điều kiện bất biến qua `assertBookingStatusTransition`.
 * 2. Gọi callback `mutate` để cập nhật các trường phụ thuộc, gán `status = toStatus`, tăng bộ đếm `version` thêm 1 và lưu trong `transaction`.
 * 3. Đăng ký đẩy tác vụ đồng bộ Google Sheet của Host qua hook `afterCommit` (đảm bảo chỉ đồng bộ ra ngoài sau khi DB đã commit thành công).
 * 4. Ghi nhận bản ghi bất biến vào `BookingStatusHistory` kèm siêu dữ liệu máy trạng thái (`actor`, `condition`, `sideEffects`).
 */
export const transitionBookingStatus = async (params: {
    booking: BookingDocument;
    toStatus: BookingStatus;
    actor: BookingStateActor;
    changedByUserId: number | null;
    reason: string | null;
    metadata?: Record<string, unknown> | null;
    transaction: Transaction;
    context?: BookingTransitionContext;
    mutate?: (booking: BookingDocument, transition: BookingTransitionDefinition) => void | Promise<void>;
}) => {
    const oldStatus = params.booking.status;
    const persistenceOptions =
        "sequelize" in params.transaction
            ? { transaction: params.transaction }
            : undefined;
    const transition = assertBookingStatusTransition({
        from: oldStatus,
        to: params.toStatus,
        actor: params.actor,
        context: params.context,
    });

    await params.mutate?.(params.booking, transition);

    params.booking.status = params.toStatus;
    params.booking.version = (params.booking.version ?? 0) + 1;
    await params.booking.save(persistenceOptions);

    const hostUserId = Number(params.booking.hostUserId ?? 0);
    const listingId = Number(params.booking.listingId ?? 0) || null;
    const bookingId = Number(params.booking.bookingId ?? 0) || null;
    if (hostUserId > 0) {
        const triggerSheetSync = () => {
            enqueueHostSheetSyncJobSafe({
                hostUserId,
                jobType: "booking_changed",
                listingId,
                bookingId,
            });
        };
        const txWithHook = params.transaction as unknown as {
            afterCommit?: (fn: () => void) => void;
        };
        if (typeof txWithHook?.afterCommit === "function") {
            txWithHook.afterCommit(triggerSheetSync);
        } else {
            setImmediate(triggerSheetSync);
        }
    }

    if (persistenceOptions || process.env.NODE_ENV !== "test") {
        await BookingStatusHistory.create(
            {
                bookingId: params.booking.bookingId,
                oldStatus,
                newStatus: params.toStatus,
                changedByUserId: params.changedByUserId,
                reason: params.reason,
                metadataJson: {
                    ...(params.metadata ?? {}),
                    stateMachine: {
                        actor: params.actor,
                        condition: transition.condition,
                        sideEffects: transition.sideEffects,
                    },
                },
            },
            persistenceOptions,
        );
    }

    return transition;
};
