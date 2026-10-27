import { AuthOtpPurpose } from "../../models/auth-otp-token";
import { sendMail } from "../../services/mail.service";

const purposeTitle: Record<AuthOtpPurpose, string> = {
    sign_up: "đăng ký tài khoản",
    forgot_password: "quên mật khẩu",
    verify_email: "xác thực email",
    verify_phone: "xác thực số điện thoại",
};

const escapeHtml = (value: string) =>
    value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");

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