import { getEnv } from "./env";

/**
 * Giải thuật tổng hợp cấu hình mật mã học JWT và thông số bảo mật Cookie Refresh Token từ biến môi trường đã xác thực.
 */
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
