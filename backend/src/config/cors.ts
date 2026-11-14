import type { CorsOptions } from "cors";

import { ApiError } from "../common/api-error";
import { getEnv } from "./env";

/**
 * Giải thuật nhận diện nguồn gốc (Origin) localhost phục vụ môi trường phát triển nội bộ.
 */
const isLocalDevOrigin = (origin: string) =>
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);

/**
 * Giải thuật cấu hình chính sách CORS chặt chẽ khi bật `credentials: true`:
 * - Cấm tuyệt đối cấu hình đại diện `*` và bắt buộc khai báo danh sách allowlist tường minh trên môi trường `production`.
 * - Từ chối các origin ngoài danh sách cho phép bằng lỗi `ApiError(403)`.
 */
export const getCorsOptions = (): CorsOptions => {
    const env = getEnv();
    const allowedOrigins = env.corsOrigins;

    if (env.corsOrigins.includes("*") || allowedOrigins.includes("*")) {
        throw new Error("Wildcard CORS origin is not allowed when credentials are enabled");
    }

    if (env.nodeEnv === "production" && allowedOrigins.length === 0) {
        throw new Error("Production CORS requires at least one valid origin");
    }

    return {
        credentials: true,
        origin(origin, callback) {
            if (!origin) {
                return callback(null, true);
            }

            if (
                env.nodeEnv !== "production" &&
                (allowedOrigins.length === 0 || isLocalDevOrigin(origin))
            ) {
                return callback(null, true);
            }

            if (allowedOrigins.includes(origin)) {
                return callback(null, true);
            }

            return callback(new ApiError(403, "CORS origin is not allowed"));
        },
    };
};
