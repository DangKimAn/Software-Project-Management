import { spawn } from "node:child_process";
import { createWriteStream, promises as fs } from "node:fs";
import path from "node:path";
import { createGzip } from "node:zlib";

import { getEnv } from "../config/env";
import { logger } from "../config/logger";

const cleanupOldBackups = async (backupDir: string, retentionDays: number) => {
    const files = await fs.readdir(backupDir);
    const threshold = Date.now() - retentionDays * 24 * 60 * 60 * 1000;

    await Promise.all(
        files
            .filter((file) => file.endsWith(".sql.gz"))
            .map(async (file) => {
                const filePath = path.join(backupDir, file);
                const stat = await fs.stat(filePath);

                if (stat.mtime.getTime() < threshold) {
                    await fs.unlink(filePath);
                    logger.info("Old database backup deleted", { file });
                }
            }),
    );
};

const runBackup = async () => {
    const env = getEnv();
    const backupDir = path.resolve(process.cwd(), env.backupDir);
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const outputFile = path.join(backupDir, `${env.dbName}-${timestamp}.sql.gz`);

    await fs.mkdir(backupDir, { recursive: true });

    const args = [
        `--host=${env.dbHost}`,
        `--port=${env.dbPort}`,
        `--user=${env.dbUser}`,
        `--password=${env.dbPassword}`,
        "--single-transaction",
        "--quick",
        "--routines",
        "--events",
        "--triggers",
        env.dbName,
    ];

    await new Promise<void>((resolve, reject) => {
        const dump = spawn("mysqldump", args, {
            stdio: ["ignore", "pipe", "pipe"],
        });

        const gzip = createGzip();
        const output = createWriteStream(outputFile);

        let stderr = "";

        dump.stderr.on("data", (chunk) => {
            stderr += String(chunk);
        });

        dump.stdout.pipe(gzip).pipe(output);

        dump.on("error", reject);

        dump.on("close", (code) => {
            if (code !== 0) {
                reject(new Error(`mysqldump failed with code ${code}: ${stderr}`));
            }
        });

        output.on("finish", resolve);
        output.on("error", reject);
    });

    await cleanupOldBackups(backupDir, env.backupRetentionDays);

    logger.info("Database backup completed", {
        outputFile,
    });
};

runBackup().catch((error) => {
    logger.error("Database backup failed", error);
    process.exit(1);
});     