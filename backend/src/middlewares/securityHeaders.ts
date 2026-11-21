import helmet from "helmet";

import { getEnv } from "../config/env";

/**
 * Giải thuật thiết lập tập HTTP Security Headers qua Helmet:
 * - Kích hoạt HSTS (`Strict-Transport-Security` 180 ngày kèm `includeSubDomains` và `preload`) khi chạy môi trường `production`, tắt HSTS ở môi trường phát triển nội bộ HTTP.
 */
export const securityHeaders = () => {
    const env = getEnv();

    return helmet({
        strictTransportSecurity:
            env.nodeEnv === "production"
                ? {
                      maxAge: 15552000,
                      includeSubDomains: true,
                      preload: true,
                  }
                : false,
    });
};
