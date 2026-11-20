/**
 * Tập hợp lược đồ kiểm chứng tham số đầu vào dùng chung cho phân hệ quản trị (`admin`),
 * tái xuất các schema định danh đợt chi trả (`payoutIdParamSchema`) và hồ sơ xác minh (`verificationIdParamSchema`).
 */

export { payoutIdParamSchema } from "../payouts/payouts.validator";
// CONFLICT-RESOLVED: Dùng chung schema kiểm chứng `verificationId` từ phân hệ hợp nhất `host-kyc`.
export { verificationIdParamSchema } from "../host-kyc/host-verification.service";

