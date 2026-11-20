/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ thanh toán (`payments`), cung cấp `paymentsRoutes`, controller, service và validator.
 */

export { default as paymentsRoutes } from "./payments.routes";
export * from "./payments.controller";
export * from "./payments.service";
export * from "./payments.validator";

