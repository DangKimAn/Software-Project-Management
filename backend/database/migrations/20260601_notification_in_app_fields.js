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

async function ensureNotificationLogsTable(connection) {
    await connection.query(`
        CREATE TABLE IF NOT EXISTS notification_logs (
            notification_log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            event_type VARCHAR(100) NOT NULL,
            target_type VARCHAR(64) NOT NULL,
            target_id VARCHAR(64) NOT NULL,
            recipient VARCHAR(255) NOT NULL,
            status ENUM('pending', 'sent', 'failed', 'skipped') NOT NULL DEFAULT 'pending',
            provider VARCHAR(64) NULL,
            provider_message_id VARCHAR(255) NULL,
            error_message TEXT NULL,
            sent_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (notification_log_id),
            UNIQUE KEY uniq_notification_event_target_recipient (
                event_type,
                target_type,
                target_id,
                recipient
            ),
            INDEX idx_notification_logs_status (status),
            INDEX idx_notification_logs_target (target_type, target_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();
        await ensureNotificationLogsTable(connection);

        await addColumnIfMissing(
            connection,
            "notification_logs",
            "recipient_user_id",
            "`recipient_user_id` BIGINT UNSIGNED NULL AFTER `recipient`",
        );
        await addColumnIfMissing(
            connection,
            "notification_logs",
            "title",
            "`title` VARCHAR(255) NULL AFTER `recipient_user_id`",
        );
        await addColumnIfMissing(
            connection,
            "notification_logs",
            "body",
            "`body` TEXT NULL AFTER `title`",
        );
        await addColumnIfMissing(
            connection,
            "notification_logs",
            "action_url",
            "`action_url` VARCHAR(1024) NULL AFTER `body`",
        );
        await addColumnIfMissing(
            connection,
            "notification_logs",
            "payload_json",
            "`payload_json` JSON NULL AFTER `action_url`",
        );
        await addColumnIfMissing(
            connection,
            "notification_logs",
            "read_at",
            "`read_at` DATETIME NULL AFTER `sent_at`",
        );
        await addIndexIfMissing(
            connection,
            "notification_logs",
            "idx_notification_logs_recipient_user_read",
            "CREATE INDEX `idx_notification_logs_recipient_user_read` ON `notification_logs` (`recipient_user_id`, `read_at`)",
        );

        await connection.commit();
        console.log("20260601_notification_in_app_fields migrated");
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
