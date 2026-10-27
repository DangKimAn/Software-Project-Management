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

async function addColumnIfMissing(connection, tableName, columnName, ddl) {
    if (!(await columnExists(connection, tableName, columnName))) {
        await connection.query(`ALTER TABLE ${tableName} ADD COLUMN ${ddl}`);
    }
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        await connection.query(`
      ALTER TABLE host_payout_batch
      MODIFY COLUMN status ENUM(
        'pending',
        'approved',
        'processing',
        'paid',
        'failed',
        'rejected',
        'cancelled'
      ) NOT NULL DEFAULT 'pending'
    `);

        await addColumnIfMissing(
            connection,
            "host_payout_batch",
            "created_by_user_id",
            "created_by_user_id BIGINT UNSIGNED NULL"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_batch",
            "approved_by_user_id",
            "approved_by_user_id BIGINT UNSIGNED NULL"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_batch",
            "approved_at",
            "approved_at DATETIME NULL"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_batch",
            "rejected_by_user_id",
            "rejected_by_user_id BIGINT UNSIGNED NULL"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_batch",
            "rejected_at",
            "rejected_at DATETIME NULL"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_batch",
            "rejection_reason",
            "rejection_reason TEXT NULL"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_booking_item",
            "amount",
            "amount DECIMAL(15, 2) NOT NULL DEFAULT 0"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_booking_item",
            "currency",
            "currency VARCHAR(8) NOT NULL DEFAULT 'VND'"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_booking_item",
            "service_fee_amount",
            "service_fee_amount DECIMAL(15, 2) NOT NULL DEFAULT 0"
        );

        await addColumnIfMissing(
            connection,
            "host_payout_booking_item",
            "host_amount",
            "host_amount DECIMAL(15, 2) NOT NULL DEFAULT 0"
        );

        if (!(await indexExists(connection, "host_payout_batch", "idx_host_payout_batch_host_status"))) {
            await connection.query(`
        CREATE INDEX idx_host_payout_batch_host_status
        ON host_payout_batch(host_id, status)
      `);
        }

        if (!(await indexExists(connection, "host_payout_batch", "idx_host_payout_batch_status"))) {
            await connection.query(`
        CREATE INDEX idx_host_payout_batch_status
        ON host_payout_batch(status)
      `);
        }

        if (!(await indexExists(connection, "host_payout_booking_item", "idx_host_payout_booking_item_payout"))) {
            await connection.query(`
        CREATE INDEX idx_host_payout_booking_item_payout
        ON host_payout_booking_item(payout_id)
      `);
        }

        if (!(await indexExists(connection, "host_payout_booking_item", "uniq_host_payout_booking_item_booking_detail"))) {
            await connection.query(`
        CREATE UNIQUE INDEX uniq_host_payout_booking_item_booking_detail
        ON host_payout_booking_item(booking_detail_id)
      `);
        }

        await connection.commit();
        console.log("20260525_payout_maker_checker migrated");
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