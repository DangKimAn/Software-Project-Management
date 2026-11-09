require("dotenv/config");
const mysql = require("mysql2/promise");
const fs = require("node:fs");
const path = require("node:path");

const dbUser = process.env.MYSQLUSER || process.env.MYSQL_USER || "booking_app";

if (
    dbUser.toLowerCase() === "root" &&
    process.env.ALLOW_DATABASE_ROOT_USER !== "true"
) {
    throw new Error("Refusing to run migration with MySQL root user.");
}

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

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        if (!(await columnExists(connection, "refunds", "bank_name"))) {
            await connection.query(`
                ALTER TABLE refunds
                ADD COLUMN bank_name VARCHAR(150) NULL AFTER reason
            `);
        }

        if (!(await columnExists(connection, "refunds", "account_number"))) {
            await connection.query(`
                ALTER TABLE refunds
                ADD COLUMN account_number VARCHAR(64) NULL AFTER bank_name
            `);
        }

        if (!(await columnExists(connection, "refunds", "account_name"))) {
            await connection.query(`
                ALTER TABLE refunds
                ADD COLUMN account_name VARCHAR(255) NULL AFTER account_number
            `);
        }

        await connection.commit();
        console.log("20261107_refund_bank_account_fields migrated successfully");
    } catch (error) {
        await connection.rollback();
        console.error("Migration failed:", error);
        process.exitCode = 1;
    } finally {
        await connection.end();
    }
}

if (require.main === module) {
    main();
}
