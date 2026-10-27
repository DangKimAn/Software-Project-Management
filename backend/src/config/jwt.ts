import { getEnv } from "./env";

export const getJwtConfig = () => {
    const env = getEnv();

    return {
        accessSecret: env.jwtAccessSecret,
        refreshSecret: env.jwtRefreshSecret,
        accessTokenTtlMinutes: env.accessTokenTtlMinutes,
        refreshTokenTtlDays: env.refreshTokenTtlDays,
        refreshTokenTtlMs: env.refreshTokenTtlMs,
        refreshCookieName: env.refreshCookieName,
        refreshCookiePath: env.refreshCookiePath,
        refreshCookieSameSite: env.refreshCookieSameSite,
        refreshCookieSecure: env.refreshCookieSecure,
    };
};

