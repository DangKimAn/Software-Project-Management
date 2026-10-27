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

async function tableExists(connection, tableName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
        `,
        [tableName],
    );

    return Number(rows[0].count) > 0;
}

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

async function createTableIfMissing(connection) {
    if (await tableExists(connection, "booking_date_locks")) {
        return;
    }

    await connection.query(`
        CREATE TABLE booking_date_locks (
            booking_date_lock_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            booking_id INT UNSIGNED NOT NULL,
            listing_id INT UNSIGNED NOT NULL,
            reserved_date DATE NOT NULL,
            status VARCHAR(32) NOT NULL DEFAULT 'held',
            released_at DATETIME NULL,
            active_lock_key TINYINT GENERATED ALWAYS AS (CASE WHEN released_at IS NULL THEN 1 ELSE NULL END) STORED,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (booking_date_lock_id),
            UNIQUE KEY uq_booking_date_locks_booking_date (booking_id, reserved_date),
            UNIQUE KEY uq_booking_date_locks_active (listing_id, reserved_date, active_lock_key),
            INDEX idx_booking_date_locks_listing_date (listing_id, reserved_date),
            INDEX idx_booking_date_locks_released_at (released_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

async function ensureActiveLockKeyColumn(connection) {
    if (await columnExists(connection, "booking_date_locks", "active_lock_key")) {
        return;
    }

    await connection.query(`
        ALTER TABLE booking_date_locks
        ADD COLUMN active_lock_key TINYINT
        GENERATED ALWAYS AS (CASE WHEN released_at IS NULL THEN 1 ELSE NULL END) STORED
        AFTER released_at
    `);
}

async function assertNoDuplicateActiveLocks(connection) {
    const [rows] = await connection.query(`
        SELECT listing_id, reserved_date, COUNT(*) AS count
        FROM booking_date_locks
        WHERE released_at IS NULL
        GROUP BY listing_id, reserved_date
        HAVING COUNT(*) > 1
        LIMIT 1
    `);

    if (rows.length > 0) {
        const duplicate = rows[0];
        throw new Error(
            `Cannot create uq_booking_date_locks_active: duplicate active locks exist for listing ` +
            `${duplicate.listing_id} on ${duplicate.reserved_date}. Release or reconcile duplicates first.`,
        );
    }
}

async function addIndexIfMissing(connection, tableName, indexName, ddl) {
    if (await indexExists(connection, tableName, indexName)) {
        return;
    }

    await connection.query(ddl);
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await createTableIfMissing(connection);
        await ensureActiveLockKeyColumn(connection);
        await assertNoDuplicateActiveLocks(connection);

        await addIndexIfMissing(
            connection,
            "booking_date_locks",
            "uq_booking_date_locks_booking_date",
            "CREATE UNIQUE INDEX uq_booking_date_locks_booking_date ON booking_date_locks (booking_id, reserved_date)",
        );
        await addIndexIfMissing(
            connection,
            "booking_date_locks",
            "uq_booking_date_locks_active",
            "CREATE UNIQUE INDEX uq_booking_date_locks_active ON booking_date_locks (listing_id, reserved_date, active_lock_key)",
        );
        await addIndexIfMissing(
            connection,
            "booking_date_locks",
            "idx_booking_date_locks_listing_date",
            "CREATE INDEX idx_booking_date_locks_listing_date ON booking_date_locks (listing_id, reserved_date)",
        );
        await addIndexIfMissing(
            connection,
            "booking_date_locks",
            "idx_booking_date_locks_released_at",
            "CREATE INDEX idx_booking_date_locks_released_at ON booking_date_locks (released_at)",
        );

        console.log("20260525_booking_date_locks_active_unique migrated");
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
