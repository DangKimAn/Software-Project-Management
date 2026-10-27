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
    multipleStatements: false,
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

async function addColumnIfMissing(connection, tableName, columnName, ddl) {
    const exists = await columnExists(connection, tableName, columnName);
    if (!exists) {
        await connection.query(`ALTER TABLE ${tableName} ADD COLUMN ${ddl}`);
    }
}

async function addIndexIfMissing(connection, tableName, indexName, ddl) {
    const exists = await indexExists(connection, tableName, indexName);
    if (!exists) {
        await connection.query(ddl);
    }
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        await connection.query(`
      ALTER TABLE bookings
      MODIFY COLUMN status ENUM(
        'pending',
        'pending_host',
        'pending_payment',
        'payment_expired',
        'paid',
        'confirmed',
        'checked_in',
        'checked_out',
        'completed',
        'cancelled_by_guest',
        'cancelled_by_host',
        'cancelled_by_admin',
        'rejected',
        'cancelled',
        'expired'
      ) NOT NULL DEFAULT 'pending_payment'
    `);

        await addColumnIfMissing(
            connection,
            "bookings",
            "version",
            "version INT UNSIGNED NOT NULL DEFAULT 0"
        );

        await addColumnIfMissing(
            connection,
            "bookings",
            "locked_until",
            "locked_until DATETIME NULL"
        );

        await addColumnIfMissing(
            connection,
            "bookings",
            "paid_at",
            "paid_at DATETIME NULL"
        );

        await addColumnIfMissing(
            connection,
            "bookings",
            "cancelled_at",
            "cancelled_at DATETIME NULL"
        );

        await addColumnIfMissing(
            connection,
            "bookings",
            "cancelled_by_user_id",
            "cancelled_by_user_id BIGINT UNSIGNED NULL"
        );

        await addColumnIfMissing(
            connection,
            "bookings",
            "cancellation_reason",
            "cancellation_reason TEXT NULL"
        );

        await addIndexIfMissing(
            connection,
            "bookings",
            "idx_bookings_status_locked_until",
            `
      CREATE INDEX idx_bookings_status_locked_until
      ON bookings(status, locked_until)
      `
        );

        await addIndexIfMissing(
            connection,
            "bookings",
            "idx_bookings_listing_dates_status",
            `
      CREATE INDEX idx_bookings_listing_dates_status
      ON bookings(listing_id, check_in_date, check_out_date, status)
      `
        );

        await connection.commit();
        console.log("20260525_booking_payment_hold_and_expiration migrated");
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
