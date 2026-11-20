/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ đánh giá lưu trú (`reviews`), tổng hợp `reviewsRoutes`, controller, service và validator.
 */

export { default as reviewsRoutes } from "./reviews.routes";
export * from "./reviews.controller";
export * from "./reviews.service";
export * from "./reviews.validator";

