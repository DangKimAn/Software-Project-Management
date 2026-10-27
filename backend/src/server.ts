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
} from "./services/booking-expiration.service";
import { initQdrantCollections } from "./modules/semantic-search/qdrant-vector.service";
type ExitProcess = (code: number) => never | void;
const HOST = process.env.HOST || "0.0.0.0";
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
        await sequelize.close();
        logger.info("Shutdown complete", { signal });
        exitProcess(0);
    } catch (error) {
        logger.error("Shutdown failed", error, { signal });
        exitProcess(1);
    }
};

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

    try {
        await sequelize.authenticate();

        if (env.nodeEnv !== "production" || env.allowProductionAutoSchemaSync) {
            await ensureRuntimeSchema();
            await sequelize.sync();
        } else {
            logger.info("Skipped automatic schema sync in production");
        }

        logger.info("MySQL connected successfully");

        // Initialize Qdrant collection (non-blocking: logs error but does not crash)
        await initQdrantCollections();

        server = createServer(app);
        initializeSocket(server);

        server.listen(port, HOST, () => {
            logger.info(`Server running at http://localhost:${port}`);
        });
        if (env.nodeEnv !== "test") {
            startPaymentExpirationSweep();
        }
        return server;
    } catch (error) {
        logger.error("Failed to start server", error);
        process.exit(1);
    }
};

export default app;
