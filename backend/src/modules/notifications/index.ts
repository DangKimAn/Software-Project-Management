/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ thông báo (`notifications`), cung cấp `notificationsRoutes` và các hàm dịch vụ phát thông báo.
 */

export { default as notificationsRoutes } from "./notifications.routes";
export * from "./notification.service";
