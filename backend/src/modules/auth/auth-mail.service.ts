import { AuthOtpPurpose } from "../../models/auth-otp-token";
import { sendMail } from "../../services/mail.service";

const purposeTitle: Record<AuthOtpPurpose, string> = {
    sign_up: "đăng ký tài khoản",
    forgot_password: "quên mật khẩu",
    verify_email: "xác thực email",
    verify_phone: "xác thực số điện thoại",
};

/**
 * Giải thuật mã hóa thực thể HTML (HTML Entity Encoding) chống tiêm mã HTML/XSS trong mẫu thư điện tử:
 * Chuyển đổi 5 ký tự đặc biệt (`&`, `<`, `>`, `"`, `'`) sang mã thực thể tương ứng trước khi nội suy vào thân HTML của email OTP.
 */
const escapeHtml = (value: string) =>
    value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");

/**
 * Giải thuật định dạng và gửi thư điện tử chứa mã xác thực một lần (OTP):
 * 1. Ánh xạ mục đích xác thực (`sign_up`, `forgot_password`, `verify_email`, `verify_phone`) sang tiêu đề tiếng Việt thân thiện.
 * 2. Chuẩn hóa mốc thời gian hết hạn sang múi giờ `Asia/Ho_Chi_Minh` (`vi-VN`).
 * 3. Tạo đồng thời phiên bản văn bản thuần (`text`) và giao diện HTML đã qua `escapeHtml` rồi chuyển phát qua dịch vụ SMTP `sendMail`.
 */
export const sendAuthOtpEmail = async (input: {
    to: string;
    otp: string;
    purpose: AuthOtpPurpose;
    expiresAt: Date;
}) => {
    const title = purposeTitle[input.purpose] ?? "xác thực tài khoản";

    const expiresAtText = input.expiresAt.toLocaleString("vi-VN", {
        timeZone: "Asia/Ho_Chi_Minh",
    });

    await sendMail({
        to: input.to,
        subject: `Mã OTP ${title}`,
        text: [
            `Mã OTP của bạn là: ${input.otp}`,
            `Mục đích: ${title}.`,
            `Mã hết hạn lúc: ${expiresAtText}.`,
            "Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email.",
        ].join("\n"),
        html: `
            <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #111827;">
                <h2>Mã OTP ${escapeHtml(title)}</h2>
                <p>Mã xác thực của bạn là:</p>

                <div style="
                    display: inline-block;
                    padding: 12px 18px;
                    margin: 12px 0;
                    font-size: 28px;
                    font-weight: 700;
                    letter-spacing: 6px;
                    background: #f3f4f6;
                    border-radius: 8px;
                    color: #111827;
                ">
                    ${escapeHtml(input.otp)}
                </div>

                <p>Mã này hết hạn lúc <strong>${escapeHtml(expiresAtText)}</strong>.</p>
                <p>Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email.</p>
            </div>
        `,
    });
};