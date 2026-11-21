/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ báo cáo vi phạm và thống kê phân tích (`reports`), cung cấp `reportsRoutes`, controller, service và validator.
 */

export { default as reportsRoutes } from "./reports.routes";
export * from "./reports.controller";
export * from "./reports.service";
export * from "./reports.validator";
