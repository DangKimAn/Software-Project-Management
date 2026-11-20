/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ hồ sơ và quản lý người dùng (`users`), cung cấp `usersRoutes`, controller, service và validator.
 */

export { default as usersRoutes } from "./users.routes";
export * from "./users.controller";
export * from "./users.service";
export * from "./users.validator";

