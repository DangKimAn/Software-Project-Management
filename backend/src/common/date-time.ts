/**
 * Tiện ích ngày giờ dùng chung theo múi giờ Việt Nam (UTC+7).
 *
 * Mọi phép so sánh ngày cần mốc "hôm nay" trong dự án phải dùng
 * {@link getTodayInVietnamDateString} để nhất quán biên ngày bất kể múi giờ máy chủ.
 */

const VIETNAM_UTC_OFFSET_MS = 7 * 60 * 60 * 1000;

/**
 * Giải thuật xác định ngày lịch hiện tại theo múi giờ Việt Nam (UTC+7):
 * - Dịch thời điểm UTC sang +07:00 bằng độ lệch mili-giây cố định rồi cắt chuỗi `YYYY-MM-DD`.
 * - Hỗ trợ truyền đồng hồ giả lập `now` phục vụ kiểm thử đơn vị tất định.
 */
export const getTodayInVietnamDateString = (now = new Date()): string =>
    new Date(now.getTime() + VIETNAM_UTC_OFFSET_MS).toISOString().slice(0, 10);

const ISO_DATE_ONLY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Giải thuật chuẩn hóa biên thời gian theo múi giờ Việt Nam (UTC+7):
 * - Nếu chuỗi đầu vào chỉ là ngày lịch YYYY-MM-DD, gắn offset +07:00 cho đầu ngày (00:00:00.000)
 *   hoặc cuối ngày (23:59:59.999) để không bị lệch 7 giờ khi máy chủ chạy ở UTC+0.
 * - Nếu chuỗi đã có thông tin giờ/offset ISO đầy đủ, giữ nguyên thời điểm tuyệt đối.
 */
export const parseVietnamDateBoundary = (
    value: string,
    boundary: "start" | "end" = "start",
): Date => {
    const trimmed = value.trim();
    if (ISO_DATE_ONLY_PATTERN.test(trimmed)) {
        const suffix = boundary === "end" ? "T23:59:59.999+07:00" : "T00:00:00.000+07:00";
        return new Date(`${trimmed}${suffix}`);
    }
    return new Date(trimmed);
};
