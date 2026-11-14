/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ khám phá chỗ ở công khai (`listings`), cung cấp `listingsRoutes`, controller, service và validator.
 */

export { default as listingsRoutes } from "./listings.routes";
export * from "./listings.controller";
export * from "./listings.service";
export * from "./listings.validator";

