import { getEnv } from "./env";

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

