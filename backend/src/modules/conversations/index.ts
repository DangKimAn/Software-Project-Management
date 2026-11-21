/**
 * Điểm xuất tập trung (Barrel Export) của phân hệ hội thoại (`conversations`), bao gồm định tuyến, controller, service và validator.
 */

export { default as conversationsRoutes } from "./conversations.routes";
export * from "./conversations.controller";
export * from "./conversations.service";
export * from "./conversations.validator";

