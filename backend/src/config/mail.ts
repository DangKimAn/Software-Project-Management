import { getEnv } from "./env";

/**
 * Giải thuật đọc cấu hình máy chủ gửi thư SMTP và xác định cờ kích hoạt `enabled` khi hội đủ thông tin xác thực.
 */
export const getMailConfig = () => {
    const env = getEnv();

    return {
        host: env.mailHost,
        port: env.mailPort,
        user: env.mailUser,
        password: env.mailPassword,
        from: env.mailFrom,
        enabled: Boolean(env.mailHost && env.mailUser && env.mailPassword),
    };
};
