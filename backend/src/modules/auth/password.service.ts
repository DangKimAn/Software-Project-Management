import { randomUUID } from "node:crypto";

import bcrypt from "bcryptjs";

export const passwordHashCost = 12;

const fallbackPasswordHash = "$2b$12$eKZSwzTu05dcsxAduTUjKecXvctT38aP7TEH28xTZ4TDxiNyyVvHu";

/**
 * Giải thuật băm mật khẩu thích nghi bằng `bcrypt`:
 * - Tự động sinh salt ngẫu nhiên 128-bit riêng biệt cho mỗi mật khẩu và thực thi hàm dẫn xuất khóa
 *   Eksblowfish với hệ số chi phí `passwordHashCost = 12` (2^12 vòng lặp), làm chậm đáng kể
 *   tấn công vét cạn ngoại tuyến (offline brute-force) và vô hiệu hóa bảng cầu vồng (rainbow table).
 */
export const hashPassword = (plainPassword: string) => bcrypt.hash(plainPassword, passwordHashCost);

/**
 * Giải thuật sinh bản băm mật khẩu ngẫu nhiên không thể đoán trước:
 * - Tạo chuỗi UUIDv4 ngẫu nhiên an toàn mật mã học (`crypto.randomUUID()`) rồi băm qua `bcrypt`.
 * - Dùng làm giá trị khởi tạo `passwordHash` cho tài khoản đăng nhập qua OAuth/mạng xã hội,
 *   đảm bảo không thể đăng nhập bằng mật khẩu cục bộ khi người dùng chưa chủ động đặt mật khẩu.
 */
export const hashRandomPassword = () => hashPassword(randomUUID());

/**
 * Giải thuật đối chiếu mật khẩu an toàn chống tấn công kênh kề thời gian (Timing Attack):
 * - Trích xuất salt cùng hệ số chi phí trực tiếp từ chuỗi băm `bcrypt` lưu trữ để tính lại bản băm
 *   và đối chiếu an toàn với `plainPassword`.
 * - Khi người dùng không tồn tại hoặc chưa có mật khẩu (`hashedPassword` rỗng), hàm vẫn thực thi
 *   `bcrypt.compare` với hằng số `fallbackPasswordHash` (cùng hệ số chi phí 12) nhằm cân bằng thời gian
 *   phản hồi, chống tấn công dò tìm sự tồn tại tài khoản qua độ trễ (timing user enumeration).
 */
export const comparePassword = async (plainPassword: string, hashedPassword?: string) =>
    bcrypt.compare(plainPassword, hashedPassword ?? fallbackPasswordHash);
