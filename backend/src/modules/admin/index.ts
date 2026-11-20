/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ quản trị (`admin`),
 * cung cấp định tuyến `adminRoutes`, các handler điều phối và dịch vụ nghiệp vụ quản trị.
 */

export { default as adminRoutes } from "./admin.routes";
export * from "./admin.controller";
export * from "./admin.service";

