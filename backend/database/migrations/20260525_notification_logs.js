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

async function main() {
    const connection = await mysql.createConnection(config);

    try {
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
      )
    `);

        console.log("20260525_notification_logs migrated");
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});