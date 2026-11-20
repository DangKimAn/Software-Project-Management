/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ đặt phòng (`bookings`), cung cấp `bookingsRoutes`, `hostBookingsRoutes` và các schema kiểm chứng.
 */

export { default as bookingsRoutes } from "./bookings.routes";
export { hostBookingsRoutes } from "./bookings.routes";
export * from "./bookings.validator";
