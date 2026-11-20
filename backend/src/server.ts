import "dotenv/config";

import { createServer } from "node:http";
import type { Server } from "node:http";

import app from "./app";
import sequelize from "./config/database";
import { getEnv } from "./config/env";
import { logger } from "./config/logger";
import "./models";
import { ensureRuntimeSchema } from "./scripts/ensure-runtime-schema";
import { initializeSocket } from "./socket/socket";
import {
    startPaymentExpirationSweep,
    stopPaymentExpirationSweep,
} from "./modules/bookings/booking-expiration.service";
import {
    startHostSheetSyncWorker,
    stopHostSheetSyncWorker,
} from "./modules/host-sheet-sync/host-sheet-sync.worker";

type ExitProcess = (code: number) => never | void;
const HOST = process.env.HOST || "0.0.0.0";

/**
 * Giải thuật đóng máy chủ êm ái (Graceful Shutdown) khi nhận tín hiệu hệ điều hành (`SIGTERM`/`SIGINT`):
 * - Ngừng nhận kết nối HTTP mới, dừng các tiến trình nền thu hồi giữ chỗ và đồng bộ Google Sheets, sau đó đóng bể kết nối MySQL trước khi thoát tiến trình.
 */
export const shutdownServer = async (
    server: Server | undefined,
    signal: NodeJS.Signals,
    exitProcess: ExitProcess = (code) => process.exit(code),
) => {
    logger.info("Shutdown signal received", { signal });

    try {
        if (server) {
            await new Promise<void>((resolve, reject) => {
                server.close((error) => {
                    if (error) {
                        reject(error);
                        return;
                    }

                    resolve();
                });
            });
        }
        stopPaymentExpirationSweep();
        stopHostSheetSyncWorker();
        await sequelize.close();
        logger.info("Shutdown complete", { signal });
        exitProcess(0);
    } catch (error) {
        logger.error("Shutdown failed", error, { signal });
        exitProcess(1);
    }
};

/**
 * Giải thuật khởi động máy chủ HTTP + Socket.IO và các tiến trình nền:
 * - Xác thực kết nối MySQL, đồng bộ lược đồ an toàn ở môi trường phi `production`, gắn kênh thời gian thực Socket.IO và kích hoạt worker nền.
 */
export const startServer = async () => {
    const env = getEnv();
    const { port } = env;
    let server: Server | undefined;

    process.once("SIGTERM", () => {
        void shutdownServer(server, "SIGTERM");
    });
    process.once("SIGINT", () => {
        void shutdownServer(server, "SIGINT");
    });
    process.on("unhandledRejection", (reason) => {
        logger.error("Unhandled promise rejection", reason);
    });
    process.on("uncaughtException", (error) => {
        logger.error("Uncaught exception", error);
        void shutdownServer(server, "SIGTERM");
    });

    try {
        await sequelize.authenticate();

        if (env.nodeEnv !== "production" || env.allowProductionAutoSchemaSync) {
            await ensureRuntimeSchema();
            await sequelize.sync();
        } else {
            logger.info("Skipped automatic schema sync in production");
        }

        logger.info("MySQL connected successfully");

        server = createServer(app);
        initializeSocket(server);

        server.listen(port, HOST, () => {
            logger.info(`Server running at http://localhost:${port}`);
        });
        if (env.nodeEnv !== "test") {
            startPaymentExpirationSweep();
            startHostSheetSyncWorker();
        }
        return server;
    } catch (error) {
        logger.error("Failed to start server", error);
        process.exit(1);
    }
};

export default app;
