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

export const verifyMailConnection = async () => {
    await getTransporter().verify();
    logger.info("Mail transporter verified successfully");
};

export const sendMail = async (input: SendMailInput) => {
    const mailConfig = getMailConfig();

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