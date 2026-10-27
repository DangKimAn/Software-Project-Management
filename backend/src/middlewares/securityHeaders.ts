import helmet from "helmet";

import { getEnv } from "../config/env";

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
