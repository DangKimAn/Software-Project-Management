// CONFLICT-RESOLVED: Chuyển nghiệp vụ kiểm tra giao cắt ngày đặt phòng từ `src/common/booking-availability.ts` về `src/modules/bookings/`.
import { Op, type WhereOptions } from "sequelize";

import type { BookingDocument, BookingStatus } from "../../models/booking";
import { getTodayInVietnamDateString } from "../../common/date-time";

/**
 * Tập hằng số định nghĩa các trạng thái đơn đặt phòng có hiệu lực khóa lịch lưu trú:
 * - `alwaysBlockingBookingStatuses`: luôn chiếm giữ phòng trong khoảng `[checkInDate, checkOutDate)`.
 * - `pendingPaymentBlockingStatus`: chiếm giữ tạm thời khi chưa hết thời hạn thanh toán (`lockedUntil > now`).
 * - `checkedOutBlockingStatus`: vẫn chặn các đêm còn lại nếu ngày trả phòng lớn hơn ngày hiện tại theo giờ Việt Nam.
 */
export const alwaysBlockingBookingStatuses = [
    "paid",
    "confirmed",
    "checked_in",
] as const satisfies readonly BookingStatus[];
export const pendingPaymentBlockingStatus = "pending_payment" as const satisfies BookingStatus;
export const checkedOutBlockingStatus = "checked_out" as const satisfies BookingStatus;

/**
 * Giải thuật kiểm tra giao cắt khoảng ngày lưu trú nửa mở `[checkInDate, checkOutDate)`:
 * - Áp dụng bất đẳng thức giao cắt hai khoảng nửa mở:
 *   `existing.checkInDate < req.checkOutDate AND existing.checkOutDate > req.checkInDate`.
 * - Biên phải mở tại `checkOutDate` đảm bảo bất biến nghiệp vụ lưu trú: khách mới được phép
 *   nhận phòng (`req.checkInDate`) đúng vào ngày khách trước trả phòng (`existing.checkOutDate`).
 */
export const buildBookingDateOverlapWhere = (
    checkInDate: string,
    checkOutDate: string,
): WhereOptions<BookingDocument> => ({
    checkInDate: {
        [Op.lt]: checkOutDate,
    },
    checkOutDate: {
        [Op.gt]: checkInDate,
    },
});

/**
 * Giải thuật lọc tập trạng thái đơn đặt phòng đang chiếm giữ lịch phòng theo thời gian thực:
 * 1. Trạng thái chặn tuyệt đối (`paid`, `confirmed`, `checked_in`): luôn giữ chỗ trong suốt kỳ lưu trú.
 * 2. Trạng thái chờ thanh toán (`pending_payment`): chỉ giữ chỗ khi khóa tạm thời chưa hết hạn (`lockedUntil > now`).
 * 3. Trạng thái đã trả phòng (`checked_out`): chỉ giữ chỗ nếu ngày trả phòng vẫn lớn hơn ngày hiện tại theo giờ Việt Nam (`checkOutDate > stayCompletionCutoffDate`).
 */
export const buildActiveBookingStatusWhere = (now = new Date()): WhereOptions<BookingDocument> => {
    const stayCompletionCutoffDate = getTodayInVietnamDateString(now);

    return {
        [Op.or]: [
            {
                status: {
                    [Op.in]: [...alwaysBlockingBookingStatuses],
                },
            },
            {
                status: pendingPaymentBlockingStatus,
                lockedUntil: {
                    [Op.gt]: now,
                },
            },
            {
                status: checkedOutBlockingStatus,
                checkOutDate: {
                    [Op.gt]: stayCompletionCutoffDate,
                },
            },
        ],
    };
};
