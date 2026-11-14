import { Sequelize } from "sequelize";
import fs from "node:fs";
import path from "node:path";

import { getEnv } from "./env";

const env = getEnv();
const caPath = env.dbSslCa ? path.resolve(process.cwd(), env.dbSslCa) : undefined;

/**
 * Giải thuật quyết định chế độ kiểm tra chứng chỉ TLS (`rejectUnauthorized`) khi kết nối MySQL qua SSL:
 * - Cho phép cấu hình tường minh qua `MYSQL_SSL_REJECT_UNAUTHORIZED`, mặc định bật nghiêm ngặt trên môi trường `production`.
 */
const sslRejectUnauthorized = (() => {
    const raw = process.env.MYSQL_SSL_REJECT_UNAUTHORIZED;
    if (raw === "false") return false;
    if (raw === "true") return true;
    return env.nodeEnv === "production";
})();

/**
 * Khởi tạo bể kết nối Sequelize MySQL chuẩn hóa múi giờ `+00:00`, bảng mã `utf8mb4` và cảnh báo truy vấn chậm (`> 500ms`).
 */
export const sequelize = new Sequelize(env.dbName, env.dbUser, env.dbPassword, {
    host: env.dbHost,
    port: env.dbPort,
    dialect: "mysql",
    timezone: "+00:00",
    dialectOptions: {
        decimalNumbers: true,
        timezone: "+00:00",
        ...(env.dbSsl
            ? {
                  ssl: {
                      rejectUnauthorized: sslRejectUnauthorized,
                      ...(caPath && fs.existsSync(caPath) ? { ca: fs.readFileSync(caPath, "utf8") } : {}),
                  },
              }
            : {}),
    },
    pool: {
        max: 10,
        min: env.nodeEnv === "test" ? 0 : 2,
        acquire: 30000,
        idle: env.nodeEnv === "test" ? 1000 : 60000,
    },
    define: {
        charset: "utf8mb4",
        collate: "utf8mb4_unicode_ci",
        engine: "InnoDB",
    },
    benchmark: true,
    logging: (sql, timing) => {
        const ms = typeof timing === "number" ? timing : 0;
        if (ms > 500) {
            console.warn(`[SLOW QUERY] ${ms}ms: ${sql}`);
        }
    },
});

export default sequelize;
