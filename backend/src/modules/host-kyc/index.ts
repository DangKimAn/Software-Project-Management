/**
 * Điểm xuất hợp nhất của phân hệ xác minh danh tính và đăng ký chủ nhà (`modules/host-kyc`).
 */
// CONFLICT-RESOLVED: Cung cấp barrel chuẩn cho phân hệ `host-kyc` thay thế ba module trùng lặp cũ.
export * from "./host-kyc.routes";
export * from "./host-kyc-policy";
export * from "./host-status-sync.service";
