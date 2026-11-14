/**
 * Bộ hàm tiện ích sinh mốc ngày động tương đối theo đồng hồ hệ thống phục vụ kiểm thử tự động:
 * - Loại bỏ hoàn toàn các chuỗi ngày cố định (`2026-11-10`...) dễ bị trôi thành ngày quá khứ theo thời gian thực (WBS 6.3 / DEF-BE-02).
 */

/**
 * Giải thuật tính chuỗi ngày tương lai chuẩn ISO `YYYY-MM-DD` theo UTC cách thời điểm hiện tại `daysFromNow` ngày.
 */
export const futureDate = (daysFromNow: number): string => {
    const target = new Date();
    target.setUTCDate(target.getUTCDate() + daysFromNow);
    return target.toISOString().slice(0, 10);
};

/**
 * Giải thuật tính chuỗi ngày quá khứ chuẩn ISO `YYYY-MM-DD` theo UTC lùi về trước `daysAgo` ngày.
 */
export const pastDate = (daysAgo: number): string => futureDate(-Math.abs(daysAgo));

/**
 * Giải thuật dựng đối tượng `Date` đầu ngày UTC (`00:00:00.000Z`) cho mốc ngày tương lai cách hiện tại `daysFromNow` ngày.
 */
export const futureDateObject = (daysFromNow: number): Date =>
    new Date(`${futureDate(daysFromNow)}T00:00:00.000Z`);
