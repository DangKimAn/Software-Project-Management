// CONFLICT-RESOLVED: Chuyển dịch vụ khóa ngày giữ phòng từ `src/services/booking-date-lock.service.ts` về `src/modules/bookings/`.
import { Op, UniqueConstraintError, type Transaction } from "sequelize";
import { ApiError } from "../../common/api-error";
import BookingDateLock from "../../models/booking-date-lock";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const ISO_DATE_ONLY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

/**
 * Giải thuật chuẩn hóa đầu vào ngày về dấu thời gian Unix mili-giây tại mốc `00:00:00.000Z` (nửa đêm UTC):
 * - Nếu là chuỗi định dạng ngày thuần `YYYY-MM-DD`, giải mã trực tiếp năm-tháng-ngày qua `Date.UTC` để triệt tiêu sai lệch múi giờ cục bộ.
 * - Nếu là chuỗi ISO đầy đủ hoặc đối tượng `Date`, sao chép và đặt lại các thành phần giờ-phút-giây-mili-giây UTC về `0`.
 */
function toUtcMidnightTimestamp(input: Date | string): number {
    if (typeof input === "string") {
        const trimmed = input.trim();
        const match = ISO_DATE_ONLY_PATTERN.exec(trimmed);
        if (match) {
            return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        }
        const parsed = new Date(trimmed);
        parsed.setUTCHours(0, 0, 0, 0);
        return parsed.getTime();
    }

    const cloned = new Date(input.getTime());
    cloned.setUTCHours(0, 0, 0, 0);
    return cloned.getTime();
}

/**
 * Giải thuật rời rạc hóa khoảng lưu trú nửa mở `[checkInDate, checkOutDate)` thành danh sách các đêm giữ phòng:
 * - Kiểm tra tính hợp lệ hữu hạn và điều kiện biên `startMs < endMs`.
 * - Duyệt tuyến tính với bước nhảy `MS_PER_DAY = 86_400_000 ms` từ `startMs` đến sát trước `endMs` (`cursor < endMs`),
 *   sinh mảng ngày định dạng `YYYY-MM-DD` (không khóa ngày `checkOutDate` để cho phép khách kế tiếp nhận phòng cùng ngày).
 */
export function buildReservedDates(checkInDate: Date | string, checkOutDate: Date | string): string[] {
    const startMs = toUtcMidnightTimestamp(checkInDate);
    const endMs = toUtcMidnightTimestamp(checkOutDate);

    if (!Number.isFinite(startMs) || !Number.isFinite(endMs) || startMs >= endMs) {
        return [];
    }

    const dates: string[] = [];
    for (let cursor = startMs; cursor < endMs; cursor += MS_PER_DAY) {
        dates.push(new Date(cursor).toISOString().slice(0, 10));
    }

    return dates;
}

/**
 * Giải thuật cấp phát khóa ngày lưu trú nguyên tử (ACID) chống race-condition đặt trùng phòng dưới tải đồng thời:
 * 1. Rời rạc hóa khoảng lưu trú thành danh sách từng đêm `[checkInDate, checkOutDate)`.
 * 2. Chèn hàng loạt (`bulkCreate`) các bản ghi trạng thái `held` vào bảng `booking_date_locks` trong cùng `transaction`.
 * 3. Tận dụng ràng buộc khóa duy nhất (UNIQUE constraint) mức cơ sở dữ liệu trên cặp `(listingId, reservedDate)` đang giữ:
 *    khi có nhiều giao dịch cạnh tranh cùng một đêm lưu trú, chỉ giao dịch đầu tiên ghi thành công; các giao dịch còn lại
 *    bị cơ sở dữ liệu từ chối bằng `UniqueConstraintError` và được ánh xạ tường minh sang lỗi `409 Conflict`.
 */
export async function createBookingDateLocks(params: {
    bookingId: number;
    listingId: number;
    checkInDate: Date | string;
    checkOutDate: Date | string;
    transaction?: Transaction;
}): Promise<void> {
    const reservedDates = buildReservedDates(params.checkInDate, params.checkOutDate);

    if (reservedDates.length === 0) {
        return;
    }

    try {
        await BookingDateLock.bulkCreate(
            reservedDates.map((reservedDate) => ({
                bookingId: params.bookingId,
                listingId: params.listingId,
                reservedDate,
                status: "held",
                releasedAt: null,
            })),
            {
                transaction: params.transaction,
            },
        );
    } catch (error) {
        if (error instanceof UniqueConstraintError) {
            throw new ApiError(409, "Listing is already booked for the selected dates", undefined, {
                code: "DATES_UNAVAILABLE",
            });
        }

        throw error;
    }
}

/**
 * Giải thuật giải phóng toàn bộ khóa ngày lưu trú của một đơn đặt phòng (`bookingId`) theo tính chất lũy đẳng (idempotent):
 * - Chỉ cập nhật các bản ghi đang ở trạng thái giữ chỗ (`releasedAt IS NULL`) sang `status = 'released'` kèm dấu thời gian `releasedAt`.
 * - Thực thi bên trong `transaction` khi hủy đơn hoặc hết hạn thanh toán nhằm hoàn trả tức thì lịch trống cho căn hộ.
 */
export async function releaseBookingDateLocksForBooking(params: {
    bookingId: number;
    transaction?: Transaction;
}): Promise<number> {
    const [affectedRows] = await BookingDateLock.update(
        {
            status: "released",
            releasedAt: new Date(),
        },
        {
            where: {
                bookingId: params.bookingId,
                releasedAt: {
                    [Op.is]: null,
                },
            },
            transaction: params.transaction,
        },
    );

    return affectedRows;
}

/**
 * Giải thuật giải phóng có chọn lọc danh sách ngày khóa `reservedDates` của một căn hộ (`listingId`):
 * - Bỏ qua truy vấn nếu tập ngày rỗng; ngược lại cập nhật nguyên tử các khóa chưa giải phóng (`releasedAt IS NULL`)
 *   thuộc tập `reservedDates` sang trạng thái `released` và trả về số lượng đêm thực tế được mở khóa.
 */
export async function releaseBookingDateLocks(params: {
    listingId: number;
    reservedDates: string[];
    transaction?: Transaction;
}): Promise<number> {
    if (params.reservedDates.length === 0) {
        return 0;
    }

    const [affectedRows] = await BookingDateLock.update(
        {
            status: "released",
            releasedAt: new Date(),
        },
        {
            where: {
                listingId: params.listingId,
                reservedDate: {
                    [Op.in]: params.reservedDates,
                },
                releasedAt: {
                    [Op.is]: null,
                },
            },
            transaction: params.transaction,
        },
    );

    return affectedRows;
}
