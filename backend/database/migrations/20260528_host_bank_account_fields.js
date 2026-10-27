require("dotenv/config");
const mysql = require("mysql2/promise");

const dbUser = process.env.MYSQLUSER || process.env.MYSQL_USER || "booking_app";

if (
    dbUser.toLowerCase() === "root" &&
    process.env.ALLOW_DATABASE_ROOT_USER !== "true"
) {
    throw new Error("Refusing to run migration with MySQL root user.");
}

const fs = require("node:fs");
const path = require("node:path");

const ssl =
    process.env.MYSQL_SSL === "true"
        ? {
              rejectUnauthorized: true,
              ...(process.env.MYSQL_SSL_CA && fs.existsSync(path.resolve(process.cwd(), process.env.MYSQL_SSL_CA))
                  ? { ca: fs.readFileSync(path.resolve(process.cwd(), process.env.MYSQL_SSL_CA), "utf8") }
                  : {}),
          }
        : undefined;

const config = {
    host: process.env.MYSQLHOST || process.env.MYSQL_HOST || "localhost",
    port: Number(process.env.MYSQLPORT || process.env.MYSQL_PORT || 3306),
    user: dbUser,
    password: process.env.MYSQLPASSWORD || process.env.MYSQL_PASSWORD || "",
    database: process.env.MYSQLDATABASE || process.env.MYSQL_DATABASE || "booking_room",
    ssl,
};

async function columnExists(connection, tableName, columnName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
        `,
        [tableName, columnName],
    );

    return Number(rows[0].count) > 0;
}

async function indexExists(connection, tableName, indexName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND INDEX_NAME = ?
        `,
        [tableName, indexName],
    );

    return Number(rows[0].count) > 0;
}

async function addColumnIfMissing(connection, tableName, columnName, ddl) {
    if (!(await columnExists(connection, tableName, columnName))) {
        await connection.query(`ALTER TABLE \`${tableName}\` ADD COLUMN ${ddl}`);
    }
}

async function addIndexIfMissing(connection, tableName, indexName, ddl) {
    if (!(await indexExists(connection, tableName, indexName))) {
        await connection.query(ddl);
    }
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        await addColumnIfMissing(
            connection,
            "payout_account",
            "bank_short_name",
            "`bank_short_name` VARCHAR(100) NULL AFTER `bank_code`",
        );
        await addColumnIfMissing(
            connection,
            "payout_account",
            "bank_bin",
            "`bank_bin` VARCHAR(16) NULL AFTER `bank_short_name`",
        );
        await addColumnIfMissing(
            connection,
            "payout_account",
            "branch_name",
            "`branch_name` VARCHAR(255) NULL AFTER `account_name`",
        );
        await addIndexIfMissing(
            connection,
            "payout_account",
            "idx_payout_account_user_deleted_default",
            "CREATE INDEX `idx_payout_account_user_deleted_default` ON `payout_account` (`user_id`, `deleted_at`, `is_default`)",
        );

        await connection.commit();
        console.log("20260528_host_bank_account_fields migrated");
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
