import fs from "fs";
import path from "path";
import nodemailer, { type Transporter } from "nodemailer";

import { logger } from "../config/logger";
import { getMailConfig } from "../config/mail";

export type MailAttachment = {
    filename?: string;
    path?: string;
    content?: Buffer | string;
    cid?: string;
    contentType?: string;
};

type SendMailInput = {
    to: string;
    subject: string;
    text: string;
    html?: string;
    attachments?: MailAttachment[];
};

let transporter: Transporter | null = null;

/**
 * Giải thuật dò tìm tuần tự đường dẫn tệp biểu trưng thương hiệu (`app_icon.png`) trên các vị trí triển khai
 * (`src/assets`, `dist/assets` hoặc thư mục ứng dụng Flutter) để đính kèm nội tuyến CID vào email HTML.
 */
export const resolveBrandLogoPath = (): string | null => {
    const candidates = [
        path.resolve(__dirname, "../assets/app_icon.png"),
        path.resolve(__dirname, "../../src/assets/app_icon.png"),
        path.resolve(process.cwd(), "src/assets/app_icon.png"),
        path.resolve(process.cwd(), "dist/assets/app_icon.png"),
        path.resolve(process.cwd(), "../hotel-booking-flutter/assets/icons/app_icon.png"),
        path.resolve(process.cwd(), "hotel-booking-flutter/assets/icons/app_icon.png"),
    ];
    for (const p of candidates) {
        if (fs.existsSync(p)) {
            return p;
        }
    }
    return null;
};

/**
 * Giải thuật khởi tạo lười và lưu đệm đơn bản (Lazy Singleton) đối tượng `Transporter` SMTP của `nodemailer`:
 * - Kiểm tra đầy đủ thông số máy chủ thư (`host`, `user`, `password`) và tự động bật TLS trực tiếp (`secure: true`)
 *   khi kết nối cổng chuẩn SMTPS `465`.
 */
const getTransporter = () => {
    const mailConfig = getMailConfig();

    if (!mailConfig.enabled || !mailConfig.host || !mailConfig.user || !mailConfig.password) {
        throw new Error(
            "Mail service is not configured. Please set MAIL_HOST, MAIL_USER, MAIL_PASSWORD, and MAIL_FROM.",
        );
    }

    if (!transporter) {
        transporter = nodemailer.createTransport({
            host: mailConfig.host,
            port: mailConfig.port,
            secure: mailConfig.port === 465,
            auth: {
                user: mailConfig.user,
                pass: mailConfig.password,
            },
        });
    }

    return transporter;
};

/**
 * Kiểm tra bắt tay kết nối và xác thực thông tin đăng nhập tới máy chủ SMTP (`transporter.verify()`).
 */
export const verifyMailConnection = async () => {
    await getTransporter().verify();
    logger.info("Mail transporter verified successfully");
};

/**
 * Giải thuật gửi thư điện tử giao dịch (OTP, thông báo đặt phòng/thanh toán) qua SMTP:
 * - Tự động phát hiện tham chiếu ảnh nội tuyến `cid:the_palm_villa_logo` trong thân HTML để đính kèm
 *   tệp logo thương hiệu không trùng lặp trước khi chuyển phát qua `nodemailer` và ghi log đối soát `messageId`.
 */
export const sendMail = async (input: SendMailInput) => {
    const mailConfig = getMailConfig();

    // Giải thuật hạ cấp an toàn trên môi trường phát triển/kiểm thử cục bộ khi chưa cấu hình SMTP thực:
    // ghi nhận nhật ký cảnh báo thay vì chặn đứng luồng OTP 503 để cho phép kiểm thử đầu-cuối (kèm debugOtp nếu bật).
    if (
        (!mailConfig.enabled || !mailConfig.host || !mailConfig.user || !mailConfig.password) &&
        process.env.NODE_ENV !== "production"
    ) {
        logger.warn("SMTP is not configured in non-production environment; skipping external email dispatch", {
            to: input.to,
            subject: input.subject,
        });
        return { messageId: "dev-local-noop" };
    }

    const attachments = [...(input.attachments ?? [])];
    if (input.html && input.html.includes("cid:the_palm_villa_logo")) {
        const logoPath = resolveBrandLogoPath();
        if (logoPath && !attachments.some((a) => a.cid === "the_palm_villa_logo")) {
            attachments.push({
                filename: "the-palm-villa-icon.png",
                path: logoPath,
                cid: "the_palm_villa_logo",
                contentType: "image/png",
            });
        }
    }

    const result = await getTransporter().sendMail({
        from: mailConfig.from ?? mailConfig.user,
        to: input.to,
        subject: input.subject,
        text: input.text,
        html: input.html,
        attachments: attachments.length > 0 ? attachments : undefined,
    });

    logger.info("Mail sent", {
        to: input.to,
        subject: input.subject,
        messageId: result.messageId,
    });

    return result;
};