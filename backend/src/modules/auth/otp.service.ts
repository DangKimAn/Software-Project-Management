import { createHash, randomInt } from "node:crypto";

import { getEnv } from "../../config/env";
import { AuthOtpPurpose } from "../../models/auth-otp-token";

/**
 * Giải thuật sinh mã OTP ngẫu nhiên an toàn mật mã học gồm 6 chữ số:
 * - Sử dụng bộ sinh số giả ngẫu nhiên an toàn mật mã `crypto.randomInt(0, 1_000_000)` (CSPRNG)
 *   để đảm bảo phân phối đều trên miền `[0, 999999]`, loại bỏ thiên lệch modulo và khả năng dự đoán chuỗi.
 * - Đệm ký tự `0` ở đầu (`padStart`) để luôn trả về chuỗi cố định 6 chữ số.
 */
export const generateOtp = () => String(randomInt(0, 1_000_000)).padStart(6, "0");

/**
 * Giải thuật băm một chiều mã OTP gắn khóa bí mật và ngữ cảnh định danh:
 * - Kết hợp khóa bí mật máy chủ riêng (`otpHashSecret`), định danh chuẩn hóa (`identifier`),
 *   mục đích sử dụng (`purpose`) và mã OTP thuần qua dấu phân tách `:` trước khi băm `SHA-256`
 *   (cấu trúc Keyed Hash một chiều bảo vệ bằng khóa bí mật riêng, kết hợp đối chiếu
 *   thời gian hằng định `timingSafeEqual` và giới hạn số lần thử sai ở tầng xác thực).
 * - Ràng buộc chặt `identifier` và `purpose` vào đầu vào băm giúp chống tấn công bảng cầu vồng
 *   (rainbow table) và ngăn chặn tấn công phát lại chéo ngữ cảnh (cross-purpose/cross-user replay).
 */
export const hashOtpToken = (identifier: string, purpose: AuthOtpPurpose, otp: string) =>
    createHash("sha256")
        .update(getEnv().otpHashSecret)
        .update(":")
        .update(identifier)
        .update(":")
        .update(purpose)
        .update(":")
        .update(otp)
        .digest("hex");
