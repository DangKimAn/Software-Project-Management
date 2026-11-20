/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ xác thực (`auth`), cung cấp `authRoutes`, controller, service và validator.
 */

export { default as authRoutes } from "./auth.routes";
export * from "./auth.controller";
export * from "./auth.service";
export * from "./auth.validator";

