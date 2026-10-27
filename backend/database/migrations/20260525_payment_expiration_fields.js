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
        [tableName, columnName]
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
        [tableName, indexName]
    );

    return Number(rows[0].count) > 0;
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        if (!(await columnExists(connection, "payments", "expires_at"))) {
            await connection.query(`
        ALTER TABLE payments
        ADD COLUMN expires_at DATETIME NULL
      `);
        }

        if (!(await columnExists(connection, "payments", "expired_at"))) {
            await connection.query(`
        ALTER TABLE payments
        ADD COLUMN expired_at DATETIME NULL
      `);
        }

        if (!(await indexExists(connection, "payments", "idx_payments_status_expires_at"))) {
            await connection.query(`
        CREATE INDEX idx_payments_status_expires_at
        ON payments(status, expires_at)
      `);
        }

        if (!(await indexExists(connection, "payments", "idx_payments_booking_status"))) {
            await connection.query(`
        CREATE INDEX idx_payments_booking_status
        ON payments(booking_id, status)
      `);
        }

        await connection.commit();
        console.log("20260525_payment_expiration_fields migrated");
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
