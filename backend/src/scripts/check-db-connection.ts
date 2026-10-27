import "dotenv/config";

import fs from "node:fs";
import path from "node:path";
import { QueryTypes } from "sequelize";

import sequelize from "../config/database";
import { getEnv } from "../config/env";

type DatabaseInfoRow = {
    db: string | null;
    version: string;
};

const main = async () => {
    const env = getEnv();
    const caPath = env.dbSslCa ? path.resolve(process.cwd(), env.dbSslCa) : undefined;

    if (env.dbSsl && caPath && !fs.existsSync(caPath)) {
        console.warn(`MYSQL_SSL_CA file not found: ${env.dbSslCa}`);
    }

    await sequelize.authenticate();

    const [databaseInfo] = await sequelize.query<DatabaseInfoRow>(
        "SELECT DATABASE() AS db, VERSION() AS version;",
        {
            type: QueryTypes.SELECT,
        },
    );
    const tableRows = await sequelize.query<Record<string, string>>("SHOW TABLES;", {
        type: QueryTypes.SELECT,
    });
    const tableNames = tableRows
        .map((row) => Object.values(row)[0])
        .filter((tableName): tableName is string => Boolean(tableName));

    console.info("Aiven MySQL connection OK");
    console.info(`Database: ${databaseInfo?.db ?? "(none selected)"}`);
    console.info(`Version: ${databaseInfo?.version ?? "unknown"}`);
    console.info(`Tables: ${tableNames.length}`);

    if (tableNames.length > 0) {
        console.info(`First tables: ${tableNames.slice(0, 10).join(", ")}`);
    }
};

main()
    .catch((error: unknown) => {
        console.error("Aiven MySQL connection FAILED");

        if (error instanceof Error) {
            console.error(error.message);
        } else {
            console.error(error);
        }

        process.exitCode = 1;
    })
    .finally(async () => {
        await sequelize.close();
    });