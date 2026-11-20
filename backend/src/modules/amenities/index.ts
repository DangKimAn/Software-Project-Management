/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ tiện ích (`amenities`), tổng hợp routes, controller, service và validator.
 */

export { default as amenitiesRoutes } from "./amenities.routes";
export * from "./amenities.controller";
export * from "./amenities.service";
export * from "./amenities.validator";
