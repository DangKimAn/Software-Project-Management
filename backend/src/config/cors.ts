import type { CorsOptions } from "cors";

import { ApiError } from "../common/api-error";
import { getEnv } from "./env";

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

            if (env.nodeEnv !== "production" && allowedOrigins.length === 0) {
                return callback(null, true);
            }

            if (allowedOrigins.includes(origin)) {
                return callback(null, true);
            }

            return callback(new ApiError(403, "CORS origin is not allowed"));
        },
    };
};
