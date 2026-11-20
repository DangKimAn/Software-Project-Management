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
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        `,
        [tableName, columnName],
    );
    return Number(rows[0]?.count ?? 0) > 0;
}

async function ensureColumn(connection, tableName, columnName, definition) {
    if (await columnExists(connection, tableName, columnName)) {
        return;
    }
    await connection.query(`ALTER TABLE \`${tableName}\` ADD COLUMN ${definition}`);
}

async function tableExists(connection, tableName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = ?
        `,
        [tableName],
    );
    return Number(rows[0]?.count ?? 0) > 0;
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        if (await tableExists(connection, "availability_calendars")) {
            await ensureColumn(
                connection,
                "availability_calendars",
                "is_blocked_by_admin",
                "`is_blocked_by_admin` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_blocked_by_host`",
            );
            await ensureColumn(
                connection,
                "availability_calendars",
                "lock_source",
                "`lock_source` VARCHAR(32) NULL AFTER `is_blocked_by_admin`",
            );
            await ensureColumn(
                connection,
                "availability_calendars",
                "sync_revision",
                "`sync_revision` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `notes`",
            );
            await ensureColumn(
                connection,
                "availability_calendars",
                "last_sheet_synced_at",
                "`last_sheet_synced_at` DATETIME NULL AFTER `sync_revision`",
            );
        }

        await connection.query(`
            CREATE TABLE IF NOT EXISTS host_sheet_integrations (
                integration_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                host_user_id BIGINT UNSIGNED NOT NULL,
                spreadsheet_id VARCHAR(128) NOT NULL,
                spreadsheet_url VARCHAR(512) NOT NULL,
                spreadsheet_title VARCHAR(255) NULL,
                host_editor_email VARCHAR(255) NULL,
                service_account_email VARCHAR(255) NULL,
                status ENUM(
                    'disconnected',
                    'connected',
                    'permission_error',
                    'structure_error',
                    'quota_limited',
                    'sync_error'
                ) NOT NULL DEFAULT 'connected',
                auto_sync_enabled TINYINT(1) NOT NULL DEFAULT 1,
                strict_booking_precheck TINYINT(1) NOT NULL DEFAULT 1,
                permission_verified_at DATETIME NULL,
                can_write_verified TINYINT(1) NOT NULL DEFAULT 0,
                schema_version INT UNSIGNED NOT NULL DEFAULT 1,
                sync_revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
                sync_lock_token VARCHAR(64) NULL,
                sync_lock_expires_at DATETIME NULL,
                last_synced_at DATETIME NULL,
                last_polled_at DATETIME NULL,
                next_poll_at DATETIME NULL,
                last_error_code VARCHAR(64) NULL,
                last_error_message TEXT NULL,
                consecutive_failures INT UNSIGNED NOT NULL DEFAULT 0,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (integration_id),
                UNIQUE KEY uq_host_sheet_host (host_user_id),
                UNIQUE KEY uq_host_sheet_spreadsheet (spreadsheet_id),
                INDEX idx_host_sheet_poll (auto_sync_enabled, status, next_poll_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);

        await connection.query(`
            CREATE TABLE IF NOT EXISTS host_sheet_sync_jobs (
                job_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                host_user_id BIGINT UNSIGNED NOT NULL,
                integration_id BIGINT UNSIGNED NULL,
                listing_id INT UNSIGNED NULL,
                booking_id INT UNSIGNED NULL,
                job_type ENUM(
                    'init_standard_calendar',
                    'booking_changed',
                    'listing_created',
                    'listing_updated',
                    'listing_archived',
                    'listing_restored',
                    'listing_transferred',
                    'app_calendar_updated',
                    'manual_sync',
                    'periodic_poll',
                    'structure_repair'
                ) NOT NULL,
                priority TINYINT UNSIGNED NOT NULL DEFAULT 50,
                dedupe_key VARCHAR(191) NULL,
                payload_json JSON NULL,
                status ENUM('pending', 'processing', 'succeeded', 'failed', 'cancelled') NOT NULL DEFAULT 'pending',
                attempts INT UNSIGNED NOT NULL DEFAULT 0,
                max_attempts INT UNSIGNED NOT NULL DEFAULT 5,
                available_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                locked_by VARCHAR(64) NULL,
                locked_until DATETIME NULL,
                last_error TEXT NULL,
                completed_at DATETIME NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (job_id),
                INDEX idx_sheet_jobs_claim (status, available_at, priority, job_id),
                INDEX idx_sheet_jobs_host_status (host_user_id, status),
                INDEX idx_sheet_jobs_dedupe (dedupe_key, status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);

        await connection.query(`
            CREATE TABLE IF NOT EXISTS host_sheet_cell_snapshots (
                snapshot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                host_user_id BIGINT UNSIGNED NOT NULL,
                listing_id INT UNSIGNED NOT NULL,
                date DATE NOT NULL,
                last_sheet_state ENUM('empty', 'host_blocked', 'pending_hold', 'booked', 'conflict') NOT NULL DEFAULT 'empty',
                last_sheet_raw_value VARCHAR(255) NULL,
                last_sheet_bg_hex VARCHAR(16) NULL,
                last_app_blocked_by_host TINYINT(1) NOT NULL DEFAULT 0,
                last_active_booking_id INT UNSIGNED NULL,
                lock_source ENUM(
                    'none',
                    'sheet_manual',
                    'app_manual',
                    'booking_hold',
                    'booking_paid',
                    'admin_lock',
                    'listing_inactive'
                ) NOT NULL DEFAULT 'none',
                sync_revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
                synced_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (snapshot_id),
                UNIQUE KEY uq_sheet_snapshot_listing_date (listing_id, date),
                INDEX idx_sheet_snapshot_host (host_user_id, date)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);

        await connection.query(`
            CREATE TABLE IF NOT EXISTS host_sheet_sync_conflicts (
                conflict_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                host_user_id BIGINT UNSIGNED NOT NULL,
                integration_id BIGINT UNSIGNED NOT NULL,
                listing_id INT UNSIGNED NULL,
                booking_id INT UNSIGNED NULL,
                conflict_date DATE NULL,
                month_tab VARCHAR(16) NULL,
                conflict_type ENUM(
                    'booking_vs_sheet_edit',
                    'app_vs_sheet_concurrent',
                    'missing_listing_row',
                    'duplicate_listing_row',
                    'missing_month_tab',
                    'bulk_row_block_warning',
                    'permission_revoked'
                ) NOT NULL,
                severity ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'high',
                status ENUM('open', 'auto_repaired', 'resolved', 'reverted') NOT NULL DEFAULT 'open',
                description VARCHAR(500) NOT NULL,
                details_json JSON NULL,
                resolved_by_user_id BIGINT UNSIGNED NULL,
                resolved_at DATETIME NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (conflict_id),
                INDEX idx_sheet_conflicts_host_status (host_user_id, status, created_at),
                INDEX idx_sheet_conflicts_listing (listing_id, conflict_date)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);

        await connection.query(`
            CREATE TABLE IF NOT EXISTS host_sheet_change_logs (
                log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                host_user_id BIGINT UNSIGNED NOT NULL,
                integration_id BIGINT UNSIGNED NOT NULL,
                listing_id INT UNSIGNED NULL,
                target_date DATE NULL,
                direction ENUM('sheet_to_app', 'app_to_sheet', 'structure_repair') NOT NULL,
                action VARCHAR(64) NOT NULL,
                previous_value VARCHAR(255) NULL,
                new_value VARCHAR(255) NULL,
                metadata_json JSON NULL,
                detected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (log_id),
                INDEX idx_sheet_change_logs_host (host_user_id, detected_at),
                INDEX idx_sheet_change_logs_listing (listing_id, target_date)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);

        console.log("20261031_host_sheet_sync_schema migrated");
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});

