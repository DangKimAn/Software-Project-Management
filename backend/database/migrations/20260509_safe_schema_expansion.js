require("dotenv/config");

const fs = require("node:fs");
const path = require("node:path");
const mysql = require("mysql2/promise");

const databaseName =
    process.env.MYSQL_DATABASE || process.env.MYSQLDATABASE || "booking_room";

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

const quoteId = (value) => `\`${String(value).replace(/`/g, "``")}\``;

const createConnection = () =>
    mysql.createConnection({
        host: process.env.MYSQLHOST || "127.0.0.1",
        port: Number(process.env.MYSQLPORT || 3306),
        user: dbUser,
        password: process.env.MYSQLPASSWORD || "",
        database: databaseName,
        ssl,
        multipleStatements: false,
    });

const tableExists = async (connection, tableName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = ?
        `,
        [tableName],
    );

    return Number(rows[0].count) > 0;
};

const columnExists = async (connection, tableName, columnName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        `,
        [tableName, columnName],
    );

    return Number(rows[0].count) > 0;
};

const indexExists = async (connection, tableName, indexName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND index_name = ?
        `,
        [tableName, indexName],
    );

    return Number(rows[0].count) > 0;
};

const constraintExists = async (connection, tableName, constraintName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.table_constraints
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND constraint_name = ?
        `,
        [tableName, constraintName],
    );

    return Number(rows[0].count) > 0;
};

const getColumnType = async (connection, tableName, columnName) => {
    const [rows] = await connection.execute(
        `
        SELECT column_type AS columnType
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        LIMIT 1
        `,
        [tableName, columnName],
    );

    return rows[0]?.columnType || null;
};

const run = async (connection, description, sql) => {
    await connection.query(sql);
    console.info(description);
};

const ensureColumn = async (connection, tableName, columnName, definition) => {
    if (!(await tableExists(connection, tableName))) {
        console.info(`Skipped ${tableName}.${columnName}: table missing`);
        return;
    }

    if (await columnExists(connection, tableName, columnName)) {
        return;
    }

    await run(
        connection,
        `Added column ${tableName}.${columnName}`,
        `ALTER TABLE ${quoteId(tableName)} ADD COLUMN ${definition}`,
    );
};

const ensureIndex = async (connection, tableName, indexName, columns, unique = false) => {
    if (!(await tableExists(connection, tableName))) {
        console.info(`Skipped index ${tableName}.${indexName}: table missing`);
        return;
    }

    if (await indexExists(connection, tableName, indexName)) {
        return;
    }

    await run(
        connection,
        `Added index ${tableName}.${indexName}`,
        `CREATE ${unique ? "UNIQUE " : ""}INDEX ${quoteId(indexName)} ON ${quoteId(tableName)} (${columns})`,
    );
};

const ensureSingleColumnUniqueIndex = async (connection, tableName, indexName, columnName) => {
    if (!(await tableExists(connection, tableName))) {
        console.info(`Skipped unique index ${tableName}.${indexName}: table missing`);
        return;
    }

    if (await indexExists(connection, tableName, indexName)) {
        return;
    }

    const [duplicates] = await connection.query(
        `
        SELECT ${quoteId(columnName)}, COUNT(*) AS count
        FROM ${quoteId(tableName)}
        WHERE ${quoteId(columnName)} IS NOT NULL
        GROUP BY ${quoteId(columnName)}
        HAVING COUNT(*) > 1
        LIMIT 1
        `,
    );

    if (duplicates.length > 0) {
        console.info(`Skipped unique index ${tableName}.${indexName}: duplicate ${columnName} values exist`);
        return;
    }

    await ensureIndex(connection, tableName, indexName, quoteId(columnName), true);
};

const ensureTable = async (connection, tableName, createSql) => {
    if (await tableExists(connection, tableName)) {
        return;
    }

    await run(connection, `Created table ${tableName}`, createSql);
};

const countOrphans = async (connection, tableName, columnName, refTable, refColumn) => {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM ${quoteId(tableName)} child
        LEFT JOIN ${quoteId(refTable)} parent
          ON child.${quoteId(columnName)} = parent.${quoteId(refColumn)}
        WHERE child.${quoteId(columnName)} IS NOT NULL
          AND parent.${quoteId(refColumn)} IS NULL
        `,
    );

    return Number(rows[0].count);
};

const ensureForeignKey = async (
    connection,
    tableName,
    constraintName,
    columnName,
    refTable,
    refColumn,
    onDelete = "RESTRICT",
) => {
    if (
        !(await tableExists(connection, tableName)) ||
        !(await tableExists(connection, refTable)) ||
        !(await columnExists(connection, tableName, columnName)) ||
        !(await columnExists(connection, refTable, refColumn))
    ) {
        console.info(`Skipped FK ${constraintName}: table or column missing`);
        return;
    }

    if (await constraintExists(connection, tableName, constraintName)) {
        return;
    }

    const orphanCount = await countOrphans(connection, tableName, columnName, refTable, refColumn);

    if (orphanCount > 0) {
        console.info(`Skipped FK ${constraintName}: ${orphanCount} orphan rows`);
        return;
    }

    await run(
        connection,
        `Added FK ${constraintName}`,
        `
        ALTER TABLE ${quoteId(tableName)}
        ADD CONSTRAINT ${quoteId(constraintName)}
        FOREIGN KEY (${quoteId(columnName)})
        REFERENCES ${quoteId(refTable)} (${quoteId(refColumn)})
        ON DELETE ${onDelete}
        ON UPDATE CASCADE
        `,
    );
};

const ensureEnumContains = async (connection, tableName, columnName, values, nullSql, defaultSql) => {
    const columnType = await getColumnType(connection, tableName, columnName);

    if (!columnType) {
        return;
    }

    if (values.every((value) => columnType.includes(`'${value}'`))) {
        return;
    }

    const enumSql = values.map((value) => `'${value.replace(/'/g, "''")}'`).join(",");
    await run(
        connection,
        `Extended enum ${tableName}.${columnName}`,
        `ALTER TABLE ${quoteId(tableName)} MODIFY COLUMN ${quoteId(columnName)} ENUM(${enumSql}) ${nullSql} ${defaultSql}`,
    );
};

const createMissingTables = async (connection) => {
    await ensureTable(
        connection,
        "otp_verifications",
        `
        CREATE TABLE \`otp_verifications\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`email\` VARCHAR(255) NULL,
            \`phone\` VARCHAR(32) NULL,
            \`otp_hash\` VARCHAR(255) NOT NULL,
            \`purpose\` ENUM('sign_up','forgot_password','verify_email','verify_phone') NOT NULL,
            \`expires_at\` DATETIME NOT NULL,
            \`consumed_at\` DATETIME NULL,
            \`attempts\` INT UNSIGNED NOT NULL DEFAULT 0,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            INDEX \`idx_otp_verifications_email\` (\`email\`),
            INDEX \`idx_otp_verifications_phone\` (\`phone\`),
            INDEX \`idx_otp_verifications_purpose\` (\`purpose\`),
            INDEX \`idx_otp_verifications_expires_at\` (\`expires_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "listing_images",
        `
        CREATE TABLE \`listing_images\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`listing_id\` INT UNSIGNED NOT NULL,
            \`url\` VARCHAR(1024) NOT NULL,
            \`object_key\` VARCHAR(1024) NULL,
            \`caption\` VARCHAR(255) NULL,
            \`sort_order\` INT UNSIGNED NOT NULL DEFAULT 0,
            \`is_cover\` TINYINT(1) NOT NULL DEFAULT 0,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_listing_images_listing_sort\` (\`listing_id\`, \`sort_order\`),
            INDEX \`idx_listing_images_listing\` (\`listing_id\`),
            CONSTRAINT \`fk_listing_images_listing\`
                FOREIGN KEY (\`listing_id\`) REFERENCES \`listings\` (\`listing_id\`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "listing_amenities",
        `
        CREATE TABLE \`listing_amenities\` (
            \`listing_id\` INT UNSIGNED NOT NULL,
            \`amenity_id\` INT UNSIGNED NOT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`listing_id\`, \`amenity_id\`),
            INDEX \`idx_listing_amenities_amenity\` (\`amenity_id\`),
            CONSTRAINT \`fk_listing_amenities_listing\`
                FOREIGN KEY (\`listing_id\`) REFERENCES \`listings\` (\`listing_id\`)
                ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT \`fk_listing_amenities_amenity\`
                FOREIGN KEY (\`amenity_id\`) REFERENCES \`amenities\` (\`amenity_id\`)
                ON DELETE RESTRICT ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "listing_rules",
        `
        CREATE TABLE \`listing_rules\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`listing_id\` INT UNSIGNED NOT NULL,
            \`check_in_from\` TIME NULL,
            \`check_out_before\` TIME NULL,
            \`smoking_allowed\` TINYINT(1) NOT NULL DEFAULT 0,
            \`pets_allowed\` TINYINT(1) NOT NULL DEFAULT 0,
            \`party_allowed\` TINYINT(1) NOT NULL DEFAULT 0,
            \`quiet_hours\` VARCHAR(255) NULL,
            \`extra_rules\` TEXT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_listing_rules_listing\` (\`listing_id\`),
            CONSTRAINT \`fk_listing_rules_listing\`
                FOREIGN KEY (\`listing_id\`) REFERENCES \`listings\` (\`listing_id\`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "availability_calendars",
        `
        CREATE TABLE \`availability_calendars\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`listing_id\` INT UNSIGNED NOT NULL,
            \`date\` DATE NOT NULL,
            \`is_available\` TINYINT(1) NOT NULL DEFAULT 1,
            \`is_blocked_by_host\` TINYINT(1) NOT NULL DEFAULT 0,
            \`price_override\` BIGINT UNSIGNED NULL,
            \`min_nights_override\` INT UNSIGNED NULL,
            \`notes\` TEXT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_availability_calendars_listing_date\` (\`listing_id\`, \`date\`),
            INDEX \`idx_availability_calendars_listing\` (\`listing_id\`),
            INDEX \`idx_availability_calendars_date\` (\`date\`),
            CONSTRAINT \`fk_availability_calendars_listing\`
                FOREIGN KEY (\`listing_id\`) REFERENCES \`listings\` (\`listing_id\`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "coupons",
        `
        CREATE TABLE \`coupons\` (
            \`coupon_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`code\` VARCHAR(64) NOT NULL,
            \`title\` VARCHAR(255) NOT NULL,
            \`description\` TEXT NULL,
            \`type\` ENUM('percent','fixed_amount') NOT NULL,
            \`discount_value\` BIGINT UNSIGNED NOT NULL,
            \`max_discount_amount\` BIGINT UNSIGNED NULL,
            \`min_order_value\` BIGINT UNSIGNED NULL,
            \`start_date\` DATETIME NOT NULL,
            \`end_date\` DATETIME NOT NULL,
            \`total_limit\` INT UNSIGNED NULL,
            \`used_count\` INT UNSIGNED NOT NULL DEFAULT 0,
            \`limit_per_user\` INT UNSIGNED NULL,
            \`is_active\` TINYINT(1) NOT NULL DEFAULT 1,
            \`deleted_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`coupon_id\`),
            UNIQUE KEY \`uq_coupons_code\` (\`code\`),
            INDEX \`idx_coupons_active_dates\` (\`is_active\`, \`start_date\`, \`end_date\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "coupon_redemptions",
        `
        CREATE TABLE \`coupon_redemptions\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`coupon_id\` BIGINT UNSIGNED NOT NULL,
            \`user_id\` BIGINT UNSIGNED NOT NULL,
            \`booking_id\` INT UNSIGNED NOT NULL,
            \`discount_amount\` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            \`redeemed_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_coupon_redemptions_coupon_booking\` (\`coupon_id\`, \`booking_id\`),
            INDEX \`idx_coupon_redemptions_coupon\` (\`coupon_id\`),
            INDEX \`idx_coupon_redemptions_user\` (\`user_id\`),
            CONSTRAINT \`fk_coupon_redemptions_coupon\`
                FOREIGN KEY (\`coupon_id\`) REFERENCES \`coupons\` (\`coupon_id\`)
                ON DELETE RESTRICT ON UPDATE CASCADE,
            CONSTRAINT \`fk_coupon_redemptions_user\`
                FOREIGN KEY (\`user_id\`) REFERENCES \`users\` (\`user_id\`)
                ON DELETE RESTRICT ON UPDATE CASCADE,
            CONSTRAINT \`fk_coupon_redemptions_booking\`
                FOREIGN KEY (\`booking_id\`) REFERENCES \`bookings\` (\`booking_id\`)
                ON DELETE RESTRICT ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "review_replies",
        `
        CREATE TABLE \`review_replies\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`review_id\` INT UNSIGNED NOT NULL,
            \`host_id\` BIGINT UNSIGNED NOT NULL,
            \`reply\` TEXT NOT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_review_replies_review\` (\`review_id\`),
            INDEX \`idx_review_replies_host\` (\`host_id\`),
            CONSTRAINT \`fk_review_replies_review\`
                FOREIGN KEY (\`review_id\`) REFERENCES \`reviews\` (\`review_id\`)
                ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT \`fk_review_replies_host\`
                FOREIGN KEY (\`host_id\`) REFERENCES \`users\` (\`user_id\`)
                ON DELETE RESTRICT ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "reports",
        `
        CREATE TABLE \`reports\` (
            \`report_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`reporter_id\` BIGINT UNSIGNED NOT NULL,
            \`target_type\` ENUM('listing','user','review','booking') NOT NULL,
            \`target_id\` BIGINT UNSIGNED NOT NULL,
            \`reason\` VARCHAR(255) NOT NULL,
            \`description\` TEXT NULL,
            \`status\` ENUM('open','resolved','rejected') NOT NULL DEFAULT 'open',
            \`resolved_by\` BIGINT UNSIGNED NULL,
            \`resolved_at\` DATETIME NULL,
            \`resolution\` TEXT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`report_id\`),
            INDEX \`idx_reports_reporter\` (\`reporter_id\`),
            INDEX \`idx_reports_target\` (\`target_type\`, \`target_id\`),
            INDEX \`idx_reports_status\` (\`status\`),
            CONSTRAINT \`fk_reports_reporter\`
                FOREIGN KEY (\`reporter_id\`) REFERENCES \`users\` (\`user_id\`)
                ON DELETE RESTRICT ON UPDATE CASCADE,
            CONSTRAINT \`fk_reports_resolved_by\`
                FOREIGN KEY (\`resolved_by\`) REFERENCES \`users\` (\`user_id\`)
                ON DELETE SET NULL ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "audit_logs",
        `
        CREATE TABLE \`audit_logs\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`actor_id\` BIGINT UNSIGNED NULL,
            \`action\` VARCHAR(120) NOT NULL,
            \`target_type\` VARCHAR(80) NOT NULL,
            \`target_id\` BIGINT UNSIGNED NULL,
            \`metadata_json\` JSON NULL,
            \`ip_address\` VARCHAR(255) NULL,
            \`user_agent\` VARCHAR(1024) NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            INDEX \`idx_audit_logs_actor\` (\`actor_id\`),
            INDEX \`idx_audit_logs_action\` (\`action\`),
            INDEX \`idx_audit_logs_target\` (\`target_type\`, \`target_id\`),
            INDEX \`idx_audit_logs_created_at\` (\`created_at\`),
            CONSTRAINT \`fk_audit_logs_actor\`
                FOREIGN KEY (\`actor_id\`) REFERENCES \`users\` (\`user_id\`)
                ON DELETE SET NULL ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "host_applications",
        `
        CREATE TABLE \`host_applications\` (
            \`application_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`user_id\` BIGINT UNSIGNED NOT NULL,
            \`contact_name\` VARCHAR(255) NULL,
            \`contact_email\` VARCHAR(255) NULL,
            \`contact_phone\` VARCHAR(32) NOT NULL,
            \`business_address\` VARCHAR(500) NOT NULL,
            \`entity_type\` ENUM('individual','business') NOT NULL,
            \`notes\` TEXT NULL,
            \`status\` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
            \`reviewed_by_user_id\` BIGINT UNSIGNED NULL,
            \`reviewed_at\` DATETIME NULL,
            \`rejection_reason\` TEXT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`application_id\`),
            INDEX \`idx_host_applications_user_status\` (\`user_id\`, \`status\`),
            INDEX \`idx_host_applications_status\` (\`status\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );
};

const addColumns = async (connection) => {
    await ensureColumn(connection, "users", "first_name", "`first_name` VARCHAR(120) NULL AFTER `full_name`");
    await ensureColumn(connection, "users", "last_name", "`last_name` VARCHAR(120) NULL AFTER `first_name`");
    await ensureColumn(connection, "users", "avatar_url", "`avatar_url` VARCHAR(1024) NULL AFTER `bio`");
    await ensureColumn(connection, "users", "dob", "`dob` DATE NULL AFTER `date_of_birth`");
    await ensureColumn(
        connection,
        "users",
        "is_email_verified",
        "`is_email_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `dob`",
    );
    await ensureColumn(
        connection,
        "users",
        "is_phone_verified",
        "`is_phone_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_email_verified`",
    );
    await ensureColumn(
        connection,
        "users",
        "is_host_verified",
        "`is_host_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_phone_verified`",
    );
    await ensureColumn(
        connection,
        "users",
        "host_application_status",
        "`host_application_status` ENUM('pending','approved','rejected') NULL AFTER `is_host_verified`",
    );
    await ensureColumn(connection, "users", "last_login_at", "`last_login_at` DATETIME NULL AFTER `status`");
    await ensureColumn(connection, "users", "deleted_at", "`deleted_at` DATETIME NULL AFTER `last_login_at`");

    await ensureColumn(connection, "auth_otp_tokens", "used_at", "`used_at` DATETIME NULL AFTER `consumed_at`");
    await ensureColumn(
        connection,
        "auth_otp_tokens",
        "attempt_count",
        "`attempt_count` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `used_at`",
    );

    await ensureColumn(connection, "amenities", "icon", "`icon` VARCHAR(255) NULL AFTER `name`");
    await ensureColumn(connection, "amenities", "is_active", "`is_active` TINYINT(1) NOT NULL DEFAULT 1 AFTER `active`");
    await ensureColumn(connection, "amenities", "deleted_at", "`deleted_at` DATETIME NULL AFTER `is_active`");

    await ensureColumn(connection, "listings", "rejection_reason", "`rejection_reason` TEXT NULL AFTER `status`");
    await ensureColumn(connection, "listings", "approved_by", "`approved_by` BIGINT UNSIGNED NULL AFTER `rejection_reason`");
    await ensureColumn(connection, "listings", "approved_at", "`approved_at` DATETIME NULL AFTER `approved_by`");
    await ensureColumn(connection, "listing_images", "object_key", "`object_key` VARCHAR(1024) NULL AFTER `url`");

    await ensureColumn(connection, "bookings", "nights", "`nights` INT UNSIGNED NULL AFTER `guest_count`");
    await ensureColumn(
        connection,
        "bookings",
        "cleaning_fee_amount",
        "`cleaning_fee_amount` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `subtotal_amount`",
    );
    await ensureColumn(
        connection,
        "bookings",
        "discount_amount",
        "`discount_amount` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `service_fee_amount`",
    );
    await ensureColumn(connection, "bookings", "coupon_id", "`coupon_id` BIGINT UNSIGNED NULL AFTER `currency`");
    await ensureColumn(connection, "bookings", "booking_note", "`booking_note` TEXT NULL AFTER `total_amount`");
    await ensureColumn(
        connection,
        "bookings",
        "cancellation_reason",
        "`cancellation_reason` TEXT NULL AFTER `booking_note`",
    );
    await ensureColumn(
        connection,
        "bookings",
        "cancelled_by_user_id",
        "`cancelled_by_user_id` BIGINT UNSIGNED NULL AFTER `cancellation_reason`",
    );
    await ensureColumn(connection, "bookings", "cancelled_at", "`cancelled_at` DATETIME NULL AFTER `cancelled_by_user_id`");
    await ensureColumn(connection, "bookings", "checked_in_at", "`checked_in_at` DATETIME NULL AFTER `cancelled_at`");
    await ensureColumn(connection, "bookings", "checked_out_at", "`checked_out_at` DATETIME NULL AFTER `checked_in_at`");

    await ensureColumn(connection, "payments", "refunded_at", "`refunded_at` DATETIME NULL AFTER `failed_at`");

    await ensureColumn(connection, "conversation", "guest_user_id", "`guest_user_id` BIGINT UNSIGNED NULL AFTER `listing_id`");
    await ensureColumn(connection, "conversation", "host_user_id", "`host_user_id` BIGINT UNSIGNED NULL AFTER `guest_user_id`");
    await ensureColumn(connection, "message", "attachments_json", "`attachments_json` LONGTEXT NULL AFTER `message_type`");
    await ensureColumn(connection, "message", "updated_at", "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`");

    await ensureColumn(
        connection,
        "payout_account",
        "account_number_encrypted",
        "`account_number_encrypted` TEXT NULL AFTER `account_number`",
    );
    await ensureColumn(
        connection,
        "payout_account",
        "account_number_hash",
        "`account_number_hash` VARCHAR(128) NULL AFTER `account_number_encrypted`",
    );
    await ensureColumn(
        connection,
        "payout_account",
        "account_number_last4",
        "`account_number_last4` CHAR(4) NULL AFTER `account_number_hash`",
    );
};

const addIndexes = async (connection) => {
    await ensureIndex(connection, "users", "idx_users_status", "`status`");
    await ensureIndex(connection, "users", "idx_users_deleted_at", "`deleted_at`");
    await ensureIndex(connection, "users", "idx_users_host_application_status", "`host_application_status`");

    await ensureSingleColumnUniqueIndex(connection, "amenities", "uq_amenities_name", "name");
    await ensureIndex(connection, "amenities", "idx_amenities_is_active", "`is_active`");

    await ensureIndex(connection, "listings", "idx_listings_status", "`status`");
    await ensureIndex(connection, "listings", "idx_listings_city_district", "`city`, `district`");
    await ensureIndex(connection, "listings", "idx_listings_base_price", "`base_price`");
    await ensureIndex(connection, "listings", "idx_listings_max_guests", "`max_guests`");
    await ensureIndex(connection, "listings", "idx_listings_property_type", "`property_type`");
    await ensureIndex(connection, "listings", "idx_listings_room_type", "`room_type`");
    await ensureIndex(connection, "listings", "idx_listings_approved_by", "`approved_by`");

    await ensureIndex(connection, "bookings", "idx_bookings_status", "`status`");
    await ensureIndex(connection, "bookings", "idx_bookings_check_in", "`check_in_date`");
    await ensureIndex(connection, "bookings", "idx_bookings_check_out", "`check_out_date`");
    await ensureIndex(connection, "bookings", "idx_bookings_coupon", "`coupon_id`");
    await ensureIndex(connection, "bookings", "idx_bookings_cancelled_by", "`cancelled_by_user_id`");

    await ensureIndex(connection, "payments", "idx_payments_status", "`status`");
    await ensureIndex(connection, "payments", "idx_payments_provider_transaction_no", "`provider_transaction_no`");

    await ensureIndex(connection, "reviews", "idx_reviews_reviewer_user", "`reviewer_user_id`");
    await ensureIndex(connection, "reviews", "idx_reviews_rating", "`rating`");

    await ensureIndex(connection, "conversation", "idx_conversation_created_by", "`created_by_user_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_listing", "`listing_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_guest", "`guest_user_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_host", "`host_user_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_booking", "`booking_order_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_last_message_at", "`last_message_at`");
    await ensureIndex(connection, "message", "idx_message_conversation_created", "`conversation_id`, `created_at`");

    await ensureIndex(connection, "host_verification", "idx_host_verification_type", "`verification_type`");
    await ensureIndex(connection, "host_verification", "idx_host_verification_reviewed_by", "`reviewed_by_user_id`");
    await ensureIndex(connection, "host_applications", "idx_host_applications_reviewed_by", "`reviewed_by_user_id`");

    await ensureIndex(connection, "payout_account", "idx_payout_account_user_default", "`user_id`, `is_default`");
    await ensureIndex(connection, "payout_account", "idx_payout_account_number_hash", "`account_number_hash`");
    await ensureIndex(connection, "host_payout_batch", "idx_host_payout_batch_paid_at", "`paid_at`");
    await ensureIndex(connection, "host_payout_batch", "idx_host_payout_batch_paid_by", "`paid_by_user_id`");
};

const addForeignKeys = async (connection) => {
    await ensureForeignKey(connection, "listings", "fk_listings_approved_by", "approved_by", "users", "user_id", "SET NULL");

    await ensureForeignKey(connection, "bookings", "fk_bookings_listing", "listing_id", "listings", "listing_id", "RESTRICT");
    await ensureForeignKey(connection, "bookings", "fk_bookings_coupon", "coupon_id", "coupons", "coupon_id", "SET NULL");
    await ensureForeignKey(
        connection,
        "bookings",
        "fk_bookings_cancelled_by",
        "cancelled_by_user_id",
        "users",
        "user_id",
        "SET NULL",
    );

    await ensureForeignKey(connection, "payments", "fk_payments_booking", "booking_id", "bookings", "booking_id", "RESTRICT");

    await ensureForeignKey(connection, "reviews", "fk_reviews_booking", "booking_id", "bookings", "booking_id", "SET NULL");
    await ensureForeignKey(connection, "reviews", "fk_reviews_listing", "listing_id", "listings", "listing_id", "RESTRICT");

    await ensureForeignKey(
        connection,
        "conversation",
        "fk_conversation_created_by",
        "created_by_user_id",
        "users",
        "user_id",
        "SET NULL",
    );
    await ensureForeignKey(connection, "conversation", "fk_conversation_guest", "guest_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "conversation", "fk_conversation_host", "host_user_id", "users", "user_id", "SET NULL");

    await ensureForeignKey(
        connection,
        "host_verification",
        "fk_host_verification_host",
        "host_id",
        "users",
        "user_id",
        "RESTRICT",
    );
    await ensureForeignKey(
        connection,
        "host_verification",
        "fk_host_verification_reviewed_by",
        "reviewed_by_user_id",
        "users",
        "user_id",
        "SET NULL",
    );

    await ensureForeignKey(
        connection,
        "host_applications",
        "fk_host_applications_user",
        "user_id",
        "users",
        "user_id",
        "RESTRICT",
    );
    await ensureForeignKey(
        connection,
        "host_applications",
        "fk_host_applications_reviewed_by",
        "reviewed_by_user_id",
        "users",
        "user_id",
        "SET NULL",
    );

    await ensureForeignKey(
        connection,
        "host_payout_batch",
        "fk_host_payout_batch_host",
        "host_id",
        "users",
        "user_id",
        "RESTRICT",
    );
    await ensureForeignKey(
        connection,
        "host_payout_batch",
        "fk_host_payout_batch_account",
        "payout_account_id",
        "payout_account",
        "payout_account_id",
        "RESTRICT",
    );
    await ensureForeignKey(
        connection,
        "host_payout_batch",
        "fk_host_payout_batch_paid_by",
        "paid_by_user_id",
        "users",
        "user_id",
        "SET NULL",
    );
};

const extendEnums = async (connection) => {
    await ensureEnumContains(
        connection,
        "users",
        "status",
        ["active", "inactive", "blocked", "suspended", "deleted", "locked"],
        "NOT NULL",
        "DEFAULT 'active'",
    );
    await ensureEnumContains(
        connection,
        "auth_otp_tokens",
        "purpose",
        ["sign_up", "forgot_password", "password_reset"],
        "NOT NULL",
        "",
    );
    if (
        (await tableExists(connection, "auth_otp_tokens")) &&
        (await columnExists(connection, "auth_otp_tokens", "purpose"))
    ) {
        await connection.query(
            "UPDATE `auth_otp_tokens` SET `purpose` = 'forgot_password' WHERE `purpose` = 'password_reset'",
        );
    }
    if (
        (await tableExists(connection, "auth_otp_tokens")) &&
        (await columnExists(connection, "auth_otp_tokens", "user_id"))
    ) {
        await run(
            connection,
            "Allowed nullable auth_otp_tokens.user_id",
            "ALTER TABLE `auth_otp_tokens` MODIFY COLUMN `user_id` BIGINT UNSIGNED NULL",
        );
    }
    await ensureEnumContains(
        connection,
        "payments",
        "status",
        ["pending", "paid", "failed", "cancelled", "expired", "refunded"],
        "NOT NULL",
        "DEFAULT 'pending'",
    );
    await ensureEnumContains(
        connection,
        "message",
        "message_type",
        ["text", "image", "system", "file"],
        "NOT NULL",
        "DEFAULT 'text'",
    );
};

const main = async () => {
    const connection = await createConnection();

    try {
        await createMissingTables(connection);
        await addColumns(connection);
        await extendEnums(connection);
        await addIndexes(connection);
        await addForeignKeys(connection);
        console.info("Safe schema expansion completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error("Safe schema expansion failed");
    console.error(error.message);
    process.exitCode = 1;
});
