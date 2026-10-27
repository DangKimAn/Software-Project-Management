import nodemailer, { type Transporter } from "nodemailer";

import { logger } from "../config/logger";
import { getMailConfig } from "../config/mail";

type SendMailInput = {
    to: string;
    subject: string;
    text: string;
    html?: string;
};

let transporter: Transporter | null = null;

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

    const result = await getTransporter().sendMail({
        from: mailConfig.from ?? mailConfig.user,
        to: input.to,
        subject: input.subject,
        text: input.text,
        html: input.html,
    });

    logger.info("Mail sent", {
        to: input.to,
        subject: input.subject,
        messageId: result.messageId,
    });

    return result;
};