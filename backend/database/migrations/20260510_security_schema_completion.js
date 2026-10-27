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
        decimalNumbers: true,
        timezone: "+00:00",
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

const ensureTable = async (connection, tableName, createSql) => {
    if (await tableExists(connection, tableName)) {
        return;
    }

    await run(connection, `Created table ${tableName}`, createSql);
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

const ensureColumnType = async (connection, tableName, columnName, definition, expectedTypeFragments) => {
    if (!(await tableExists(connection, tableName)) || !(await columnExists(connection, tableName, columnName))) {
        console.info(`Skipped type check ${tableName}.${columnName}: table or column missing`);
        return;
    }

    const columnType = String(await getColumnType(connection, tableName, columnName)).toLowerCase();
    if (
        Array.isArray(expectedTypeFragments)
            ? expectedTypeFragments.every((fragment) => columnType.includes(String(fragment).toLowerCase()))
            : columnType === String(expectedTypeFragments).toLowerCase()
    ) {
        return;
    }

    await run(
        connection,
        `Changed column type ${tableName}.${columnName}`,
        `ALTER TABLE ${quoteId(tableName)} MODIFY COLUMN ${definition}`,
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
    if (!(await tableExists(connection, tableName)) || !(await columnExists(connection, tableName, columnName))) {
        console.info(`Skipped unique index ${tableName}.${indexName}: table or column missing`);
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

const ensureBookingDateLockActiveUniqueIndex = async (connection) => {
    const tableName = "booking_date_locks";
    const indexName = "uq_booking_date_locks_active";

    if (
        !(await tableExists(connection, tableName)) ||
        !(await columnExists(connection, tableName, "listing_id")) ||
        !(await columnExists(connection, tableName, "reserved_date")) ||
        !(await columnExists(connection, tableName, "active_lock_key"))
    ) {
        console.info(`Skipped unique index ${tableName}.${indexName}: table or column missing`);
        return;
    }

    if (await indexExists(connection, tableName, indexName)) {
        return;
    }

    const [duplicates] = await connection.query(
        `
        SELECT listing_id, reserved_date, COUNT(*) AS count
        FROM ${quoteId(tableName)}
        WHERE released_at IS NULL
        GROUP BY listing_id, reserved_date
        HAVING COUNT(*) > 1
        LIMIT 1
        `,
    );

    if (duplicates.length > 0) {
        console.info(`Skipped unique index ${tableName}.${indexName}: duplicate active date locks exist`);
        return;
    }

    await ensureIndex(
        connection,
        tableName,
        indexName,
        "`listing_id`, `reserved_date`, `active_lock_key`",
        true,
    );
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

const parseEnumValues = (columnType) =>
    Array.from(String(columnType).matchAll(/'((?:''|[^'])*)'/g)).map((match) =>
        match[1].replace(/''/g, "'"),
    );

const ensureEnumContains = async (connection, tableName, columnName, values, nullSql, defaultSql = "") => {
    const columnType = await getColumnType(connection, tableName, columnName);

    if (!columnType) {
        return;
    }

    const currentValues = parseEnumValues(columnType);

    if (values.every((value) => currentValues.includes(value))) {
        return;
    }

    const nextValues = [...currentValues];

    for (const value of values) {
        if (!nextValues.includes(value)) {
            nextValues.push(value);
        }
    }

    const enumSql = nextValues.map((value) => `'${value.replace(/'/g, "''")}'`).join(",");
    await run(
        connection,
        `Extended enum ${tableName}.${columnName}`,
        `ALTER TABLE ${quoteId(tableName)} MODIFY COLUMN ${quoteId(columnName)} ENUM(${enumSql}) ${nullSql} ${defaultSql}`,
    );
};

const createMissingTables = async (connection) => {
    await ensureTable(
        connection,
        "user_profiles",
        `
        CREATE TABLE \`user_profiles\` (
            \`profile_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`user_id\` BIGINT UNSIGNED NOT NULL,
            \`first_name\` VARCHAR(120) NULL,
            \`last_name\` VARCHAR(120) NULL,
            \`avatar_url\` VARCHAR(1024) NULL,
            \`date_of_birth\` DATE NULL,
            \`gender\` ENUM('male','female','other','prefer_not_to_say') NULL,
            \`address_line\` VARCHAR(500) NULL,
            \`ward\` VARCHAR(255) NULL,
            \`district\` VARCHAR(255) NULL,
            \`city\` VARCHAR(255) NULL,
            \`country\` VARCHAR(8) NOT NULL DEFAULT 'VN',
            \`emergency_contact_name\` VARCHAR(255) NULL,
            \`emergency_contact_phone\` VARCHAR(32) NULL,
            \`deleted_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`profile_id\`),
            UNIQUE KEY \`uq_user_profiles_user\` (\`user_id\`),
            INDEX \`idx_user_profiles_city\` (\`city\`, \`district\`),
            INDEX \`idx_user_profiles_deleted_at\` (\`deleted_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "host_profiles",
        `
        CREATE TABLE \`host_profiles\` (
            \`host_profile_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`user_id\` BIGINT UNSIGNED NOT NULL,
            \`display_name\` VARCHAR(255) NULL,
            \`bio\` TEXT NULL,
            \`business_name\` VARCHAR(255) NULL,
            \`business_tax_id_hash\` VARCHAR(128) NULL,
            \`response_rate\` DECIMAL(5,2) NULL,
            \`response_time_minutes\` INT UNSIGNED NULL,
            \`is_superhost\` TINYINT(1) NOT NULL DEFAULT 0,
            \`verification_status\` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
            \`approved_by\` BIGINT UNSIGNED NULL,
            \`approved_at\` DATETIME NULL,
            \`deleted_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`host_profile_id\`),
            UNIQUE KEY \`uq_host_profiles_user\` (\`user_id\`),
            INDEX \`idx_host_profiles_status\` (\`verification_status\`, \`deleted_at\`),
            INDEX \`idx_host_profiles_approved_by\` (\`approved_by\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "booking_guests",
        `
        CREATE TABLE \`booking_guests\` (
            \`booking_guest_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`booking_id\` INT UNSIGNED NOT NULL,
            \`full_name\` VARCHAR(255) NOT NULL,
            \`email\` VARCHAR(255) NULL,
            \`phone\` VARCHAR(32) NULL,
            \`age\` INT UNSIGNED NULL,
            \`document_type\` VARCHAR(64) NULL,
            \`document_number_hash\` VARCHAR(128) NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`booking_guest_id\`),
            INDEX \`idx_booking_guests_booking\` (\`booking_id\`),
            INDEX \`idx_booking_guests_document_hash\` (\`document_number_hash\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "booking_status_history",
        `
        CREATE TABLE \`booking_status_history\` (
            \`history_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`booking_id\` INT UNSIGNED NOT NULL,
            \`old_status\` VARCHAR(32) NULL,
            \`new_status\` VARCHAR(32) NOT NULL,
            \`changed_by_user_id\` BIGINT UNSIGNED NULL,
            \`reason\` TEXT NULL,
            \`metadata_json\` JSON NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`history_id\`),
            INDEX \`idx_booking_status_history_booking\` (\`booking_id\`, \`created_at\`),
            INDEX \`idx_booking_status_history_changed_by\` (\`changed_by_user_id\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "booking_date_locks",
        `
        CREATE TABLE \`booking_date_locks\` (
            \`booking_date_lock_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`booking_id\` INT UNSIGNED NOT NULL,
            \`listing_id\` INT UNSIGNED NOT NULL,
            \`reserved_date\` DATE NOT NULL,
            \`status\` VARCHAR(32) NOT NULL DEFAULT 'held',
            \`released_at\` DATETIME NULL,
            \`active_lock_key\` TINYINT GENERATED ALWAYS AS (CASE WHEN \`released_at\` IS NULL THEN 1 ELSE NULL END) STORED,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`booking_date_lock_id\`),
            UNIQUE KEY \`uq_booking_date_locks_booking_date\` (\`booking_id\`, \`reserved_date\`),
            UNIQUE KEY \`uq_booking_date_locks_active\` (\`listing_id\`, \`reserved_date\`, \`active_lock_key\`),
            INDEX \`idx_booking_date_locks_listing_date\` (\`listing_id\`, \`reserved_date\`),
            INDEX \`idx_booking_date_locks_released_at\` (\`released_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "payment_transactions",
        `
        CREATE TABLE \`payment_transactions\` (
            \`transaction_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`payment_id\` INT UNSIGNED NOT NULL,
            \`booking_id\` INT UNSIGNED NOT NULL,
            \`provider\` VARCHAR(64) NULL,
            \`provider_txn_ref\` VARCHAR(100) NULL,
            \`provider_transaction_no\` VARCHAR(64) NULL,
            \`transaction_type\` ENUM('authorization','capture','payment','refund','void') NOT NULL DEFAULT 'payment',
            \`status\` ENUM('pending','succeeded','failed','cancelled') NOT NULL DEFAULT 'pending',
            \`amount\` DECIMAL(15,2) NOT NULL,
            \`currency\` VARCHAR(8) NOT NULL DEFAULT 'VND',
            \`raw_payload_json\` JSON NULL,
            \`processed_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`transaction_id\`),
            UNIQUE KEY \`uq_payment_transactions_provider_ref\` (\`provider_txn_ref\`),
            INDEX \`idx_payment_transactions_payment\` (\`payment_id\`, \`status\`),
            INDEX \`idx_payment_transactions_booking\` (\`booking_id\`),
            INDEX \`idx_payment_transactions_provider_no\` (\`provider_transaction_no\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "refunds",
        `
        CREATE TABLE \`refunds\` (
            \`refund_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`payment_id\` INT UNSIGNED NOT NULL,
            \`booking_id\` INT UNSIGNED NOT NULL,
            \`amount\` DECIMAL(15,2) NOT NULL,
            \`currency\` VARCHAR(8) NOT NULL DEFAULT 'VND',
            \`reason\` TEXT NULL,
            \`status\` ENUM('pending','processing','succeeded','failed','cancelled') NOT NULL DEFAULT 'pending',
            \`provider_ref\` VARCHAR(100) NULL,
            \`requested_by_user_id\` BIGINT UNSIGNED NULL,
            \`processed_by_user_id\` BIGINT UNSIGNED NULL,
            \`processed_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`refund_id\`),
            UNIQUE KEY \`uq_refunds_provider_ref\` (\`provider_ref\`),
            INDEX \`idx_refunds_payment\` (\`payment_id\`, \`status\`),
            INDEX \`idx_refunds_booking\` (\`booking_id\`),
            INDEX \`idx_refunds_requested_by\` (\`requested_by_user_id\`),
            INDEX \`idx_refunds_processed_by\` (\`processed_by_user_id\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "security_logs",
        `
        CREATE TABLE \`security_logs\` (
            \`security_log_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`user_id\` BIGINT UNSIGNED NULL,
            \`event_type\` VARCHAR(120) NOT NULL,
            \`severity\` ENUM('info','warning','high','critical') NOT NULL DEFAULT 'info',
            \`ip_address\` VARCHAR(255) NULL,
            \`user_agent\` VARCHAR(1024) NULL,
            \`metadata_json\` JSON NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`security_log_id\`),
            INDEX \`idx_security_logs_user\` (\`user_id\`),
            INDEX \`idx_security_logs_event\` (\`event_type\`),
            INDEX \`idx_security_logs_severity\` (\`severity\`),
            INDEX \`idx_security_logs_created_at\` (\`created_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "conversation",
        `
        CREATE TABLE \`conversation\` (
            \`conversation_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`created_by_user_id\` BIGINT UNSIGNED NULL,
            \`listing_id\` INT UNSIGNED NULL,
            \`guest_user_id\` BIGINT UNSIGNED NULL,
            \`host_user_id\` BIGINT UNSIGNED NULL,
            \`booking_order_id\` INT UNSIGNED NULL,
            \`dedupe_key\` VARCHAR(255) NULL,
            \`last_message\` TEXT NULL,
            \`last_message_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`conversation_id\`),
            UNIQUE KEY \`uq_conversation_dedupe_key\` (\`dedupe_key\`),
            INDEX \`idx_conversation_listing\` (\`listing_id\`),
            INDEX \`idx_conversation_guest\` (\`guest_user_id\`),
            INDEX \`idx_conversation_host\` (\`host_user_id\`),
            INDEX \`idx_conversation_booking\` (\`booking_order_id\`),
            INDEX \`idx_conversation_last_message_at\` (\`last_message_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "conversation_participant",
        `
        CREATE TABLE \`conversation_participant\` (
            \`conversation_id\` BIGINT UNSIGNED NOT NULL,
            \`user_id\` BIGINT UNSIGNED NOT NULL,
            \`role\` ENUM('guest','host','admin') NULL,
            \`joined_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`last_read_at\` DATETIME NULL,
            PRIMARY KEY (\`conversation_id\`, \`user_id\`),
            INDEX \`idx_conversation_participant_user\` (\`user_id\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "message",
        `
        CREATE TABLE \`message\` (
            \`message_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`conversation_id\` BIGINT UNSIGNED NOT NULL,
            \`sender_id\` BIGINT UNSIGNED NOT NULL,
            \`content\` TEXT NOT NULL,
            \`message_type\` ENUM('text','image','system','file') NOT NULL DEFAULT 'text',
            \`attachments_json\` LONGTEXT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`message_id\`),
            INDEX \`idx_message_conversation_created\` (\`conversation_id\`, \`created_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );
};

const addColumns = async (connection) => {
    await ensureColumn(connection, "users", "first_name", "`first_name` VARCHAR(120) NULL AFTER `full_name`");
    await ensureColumn(connection, "users", "last_name", "`last_name` VARCHAR(120) NULL AFTER `first_name`");
    await ensureColumn(connection, "users", "avatar_url", "`avatar_url` VARCHAR(1024) NULL AFTER `bio`");
    await ensureColumn(connection, "users", "dob", "`dob` DATE NULL AFTER `date_of_birth`");
    await ensureColumn(connection, "users", "last_login_at", "`last_login_at` DATETIME NULL AFTER `status`");
    await ensureColumn(connection, "users", "deleted_at", "`deleted_at` DATETIME NULL AFTER `last_login_at`");

    await ensureColumn(connection, "refresh_sessions", "device_id", "`device_id` VARCHAR(128) NULL AFTER `user_agent`");
    await ensureColumn(connection, "refresh_sessions", "device_name", "`device_name` VARCHAR(255) NULL AFTER `device_id`");

    await ensureColumn(connection, "auth_otp_tokens", "attempt_count", "`attempt_count` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `consumed_at`");
    await ensureColumn(connection, "auth_otp_tokens", "used_at", "`used_at` DATETIME NULL AFTER `attempt_count`");

    await ensureColumn(connection, "bookings", "version", "`version` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `status`");
    await ensureColumn(connection, "bookings", "locked_until", "`locked_until` DATETIME NULL AFTER `version`");
    await ensureColumn(connection, "bookings", "nights", "`nights` INT UNSIGNED NULL AFTER `guest_count`");
    await ensureColumn(
        connection,
        "bookings",
        "cleaning_fee_amount",
        "`cleaning_fee_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `subtotal_amount`",
    );
    await ensureColumn(
        connection,
        "bookings",
        "discount_amount",
        "`discount_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `service_fee_amount`",
    );
    await ensureColumn(connection, "bookings", "coupon_id", "`coupon_id` BIGINT UNSIGNED NULL AFTER `currency`");
    await ensureColumn(connection, "bookings", "booking_note", "`booking_note` TEXT NULL AFTER `total_amount`");
    await ensureColumn(connection, "bookings", "cancellation_reason", "`cancellation_reason` TEXT NULL AFTER `booking_note`");
    await ensureColumn(connection, "bookings", "cancelled_by_user_id", "`cancelled_by_user_id` BIGINT UNSIGNED NULL AFTER `cancellation_reason`");
    await ensureColumn(connection, "bookings", "cancelled_at", "`cancelled_at` DATETIME NULL AFTER `cancelled_by_user_id`");
    await ensureColumn(connection, "bookings", "checked_in_at", "`checked_in_at` DATETIME NULL AFTER `cancelled_at`");
    await ensureColumn(connection, "bookings", "checked_out_at", "`checked_out_at` DATETIME NULL AFTER `checked_in_at`");

    await ensureColumn(
        connection,
        "booking_date_locks",
        "active_lock_key",
        "`active_lock_key` TINYINT GENERATED ALWAYS AS (CASE WHEN `released_at` IS NULL THEN 1 ELSE NULL END) STORED AFTER `released_at`",
    );

    await ensureColumn(connection, "payments", "refunded_at", "`refunded_at` DATETIME NULL AFTER `failed_at`");
    await ensureColumn(connection, "listing_images", "object_key", "`object_key` VARCHAR(1024) NULL AFTER `url`");
    await ensureColumn(connection, "conversation", "guest_user_id", "`guest_user_id` BIGINT UNSIGNED NULL AFTER `listing_id`");
    await ensureColumn(connection, "conversation", "host_user_id", "`host_user_id` BIGINT UNSIGNED NULL AFTER `guest_user_id`");
    await ensureColumn(connection, "message", "attachments_json", "`attachments_json` LONGTEXT NULL AFTER `message_type`");
    await ensureColumn(connection, "message", "updated_at", "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`");

    await ensureColumn(connection, "payout_account", "account_number_encrypted", "`account_number_encrypted` TEXT NULL AFTER `account_number`");
    await ensureColumn(connection, "payout_account", "account_number_hash", "`account_number_hash` VARCHAR(128) NULL AFTER `account_number_encrypted`");
    await ensureColumn(connection, "payout_account", "account_number_last4", "`account_number_last4` CHAR(4) NULL AFTER `account_number_hash`");
};

const normalizeColumnTypes = async (connection) => {
    await ensureColumnType(connection, "refresh_sessions", "user_id", "`user_id` BIGINT UNSIGNED NOT NULL", "bigint unsigned");
    await ensureColumnType(connection, "social_accounts", "user_id", "`user_id` BIGINT UNSIGNED NOT NULL", "bigint unsigned");
    await ensureColumnType(connection, "listings", "host_id", "`host_id` BIGINT UNSIGNED NOT NULL", "bigint unsigned");
    await ensureColumnType(connection, "bookings", "guest_user_id", "`guest_user_id` BIGINT UNSIGNED NOT NULL", "bigint unsigned");
    await ensureColumnType(connection, "bookings", "host_user_id", "`host_user_id` BIGINT UNSIGNED NOT NULL", "bigint unsigned");
    await ensureColumnType(connection, "payments", "user_id", "`user_id` BIGINT UNSIGNED NOT NULL", "bigint unsigned");
    await ensureColumnType(connection, "reviews", "reviewer_user_id", "`reviewer_user_id` BIGINT UNSIGNED NULL", "bigint unsigned");
    await ensureColumnType(connection, "conversation", "listing_id", "`listing_id` INT UNSIGNED NULL", "int unsigned");
    await ensureColumnType(connection, "conversation", "guest_user_id", "`guest_user_id` BIGINT UNSIGNED NULL", "bigint unsigned");
    await ensureColumnType(connection, "conversation", "host_user_id", "`host_user_id` BIGINT UNSIGNED NULL", "bigint unsigned");
    await ensureColumnType(connection, "conversation", "booking_order_id", "`booking_order_id` INT UNSIGNED NULL", "int unsigned");
    await ensureColumnType(connection, "host_payout_booking_item", "booking_order_id", "`booking_order_id` INT UNSIGNED NOT NULL", "int unsigned");
    await ensureColumnType(connection, "host_payout_booking_item", "booking_detail_id", "`booking_detail_id` INT UNSIGNED NOT NULL", "int unsigned");

    await ensureColumnType(connection, "listings", "base_price", "`base_price` DECIMAL(15,2) NOT NULL", "decimal(15,2)");
    await ensureColumnType(connection, "listings", "bathrooms", "`bathrooms` DECIMAL(4,1) NOT NULL", "decimal(4,1)");
    await ensureColumnType(connection, "listings", "weekend_price", "`weekend_price` DECIMAL(15,2) NULL", "decimal(15,2)");
    await ensureColumnType(connection, "listings", "cleaning_fee", "`cleaning_fee` DECIMAL(15,2) NULL", "decimal(15,2)");
    await ensureColumnType(connection, "bookings", "subtotal_amount", "`subtotal_amount` DECIMAL(15,2) NOT NULL", "decimal(15,2)");
    await ensureColumnType(connection, "bookings", "service_fee_amount", "`service_fee_amount` DECIMAL(15,2) NOT NULL DEFAULT 0", "decimal(15,2)");
    await ensureColumnType(connection, "bookings", "cleaning_fee_amount", "`cleaning_fee_amount` DECIMAL(15,2) NOT NULL DEFAULT 0", "decimal(15,2)");
    await ensureColumnType(connection, "bookings", "discount_amount", "`discount_amount` DECIMAL(15,2) NOT NULL DEFAULT 0", "decimal(15,2)");
    await ensureColumnType(connection, "bookings", "total_amount", "`total_amount` DECIMAL(15,2) NOT NULL", "decimal(15,2)");
    await ensureColumnType(connection, "payments", "amount", "`amount` DECIMAL(15,2) NOT NULL", "decimal(15,2)");
    await ensureColumnType(connection, "availability_calendars", "price_override", "`price_override` DECIMAL(15,2) NULL", "decimal(15,2)");
    await ensureColumnType(connection, "coupons", "discount_value", "`discount_value` DECIMAL(15,2) NOT NULL", "decimal(15,2)");
    await ensureColumnType(connection, "coupons", "max_discount_amount", "`max_discount_amount` DECIMAL(15,2) NULL", "decimal(15,2)");
    await ensureColumnType(connection, "coupons", "min_order_value", "`min_order_value` DECIMAL(15,2) NULL", "decimal(15,2)");
    await ensureColumnType(connection, "coupon_redemptions", "discount_amount", "`discount_amount` DECIMAL(15,2) NOT NULL DEFAULT 0", "decimal(15,2)");
    await ensureColumnType(connection, "host_payout_batch", "amount", "`amount` DECIMAL(15,2) NOT NULL", "decimal(15,2)");
};

const extendEnums = async (connection) => {
    await ensureEnumContains(
        connection,
        "bookings",
        "status",
        [
            "pending",
            "pending_host",
            "pending_payment",
            "payment_expired",
            "paid",
            "confirmed",
            "checked_in",
            "checked_out",
            "completed",
            "cancelled_by_guest",
            "cancelled_by_host",
            "cancelled_by_admin",
            "rejected",
            "cancelled",
            "expired",
        ],
        "NOT NULL",
        "DEFAULT 'pending_payment'",
    );
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
    await ensureEnumContains(
        connection,
        "auth_otp_tokens",
        "purpose",
        ["sign_up", "forgot_password", "verify_email", "verify_phone"],
        "NOT NULL",
    );
};

const addIndexes = async (connection) => {
    await ensureSingleColumnUniqueIndex(connection, "users", "uq_users_email", "email");
    await ensureSingleColumnUniqueIndex(connection, "users", "uq_users_username", "username");
    await ensureSingleColumnUniqueIndex(connection, "users", "uq_users_phone", "phone");
    await ensureIndex(connection, "users", "idx_users_status_deleted", "`status`, `deleted_at`");
    await ensureIndex(connection, "users", "idx_users_last_login_at", "`last_login_at`");

    await ensureSingleColumnUniqueIndex(connection, "listings", "uq_listings_listing_id", "listing_id");
    await ensureIndex(connection, "listings", "idx_listings_search", "`status`, `city`, `district`, `base_price`, `max_guests`");

    await ensureSingleColumnUniqueIndex(connection, "bookings", "uq_bookings_booking_id", "booking_id");
    await ensureIndex(connection, "bookings", "idx_bookings_listing_status_dates", "`listing_id`, `status`, `check_in_date`, `check_out_date`");
    await ensureIndex(connection, "bookings", "idx_bookings_guest_status_dates", "`guest_user_id`, `status`, `check_in_date`");
    await ensureIndex(connection, "bookings", "idx_bookings_host_status_dates", "`host_user_id`, `status`, `check_in_date`");
    await ensureIndex(connection, "bookings", "idx_bookings_locked_until", "`locked_until`");
    await ensureBookingDateLockActiveUniqueIndex(connection);

    await ensureSingleColumnUniqueIndex(connection, "payments", "uq_payments_payment_id", "payment_id");
    await ensureIndex(connection, "payments", "idx_payments_provider_refs", "`provider_txn_ref`, `provider_transaction_no`");

    await ensureSingleColumnUniqueIndex(connection, "reviews", "uq_reviews_review_id", "review_id");
    await ensureIndex(connection, "reviews", "idx_reviews_reviewer_created", "`reviewer_user_id`, `created_at`");

    await ensureIndex(connection, "refresh_sessions", "idx_refresh_sessions_user_active", "`user_id`, `revoked_at`, `expires_at`");
    await ensureIndex(connection, "auth_otp_tokens", "idx_auth_otp_identifier_active", "`identifier`, `purpose`, `consumed_at`, `expires_at`");
    await ensureIndex(connection, "auth_otp_tokens", "idx_auth_otp_used_at", "`used_at`");

    await ensureIndex(connection, "conversation", "idx_conversation_listing", "`listing_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_guest", "`guest_user_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_host", "`host_user_id`");
    await ensureIndex(connection, "conversation", "idx_conversation_booking", "`booking_order_id`");
    await ensureIndex(connection, "message", "idx_message_conversation_created", "`conversation_id`, `created_at`");

    await ensureIndex(connection, "payout_account", "idx_payout_account_user_default", "`user_id`, `is_default`");
    await ensureIndex(connection, "payout_account", "idx_payout_account_number_hash", "`account_number_hash`");
    await ensureIndex(connection, "host_payout_batch", "idx_host_payout_batch_host_status_paid", "`host_id`, `status`, `paid_at`");
};

const addForeignKeys = async (connection) => {
    await ensureForeignKey(connection, "user_profiles", "fk_user_profiles_user", "user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "host_profiles", "fk_host_profiles_user", "user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "host_profiles", "fk_host_profiles_approved_by", "approved_by", "users", "user_id", "SET NULL");

    await ensureForeignKey(connection, "refresh_sessions", "fk_refresh_sessions_user", "user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "auth_otp_tokens", "fk_auth_otp_tokens_user", "user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "social_accounts", "fk_social_accounts_user", "user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "user_role", "fk_user_role_user", "user_id", "users", "user_id", "CASCADE");
    await ensureForeignKey(connection, "user_role", "fk_user_role_role", "role_id", "roles", "role_id", "CASCADE");

    await ensureForeignKey(connection, "listings", "fk_listings_host", "host_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "listings", "fk_listings_approved_by", "approved_by", "users", "user_id", "SET NULL");

    await ensureForeignKey(connection, "bookings", "fk_bookings_listing", "listing_id", "listings", "listing_id", "RESTRICT");
    await ensureForeignKey(connection, "bookings", "fk_bookings_guest", "guest_user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "bookings", "fk_bookings_host", "host_user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "bookings", "fk_bookings_coupon", "coupon_id", "coupons", "coupon_id", "SET NULL");
    await ensureForeignKey(connection, "bookings", "fk_bookings_cancelled_by", "cancelled_by_user_id", "users", "user_id", "SET NULL");

    await ensureForeignKey(connection, "booking_guests", "fk_booking_guests_booking", "booking_id", "bookings", "booking_id", "RESTRICT");
    await ensureForeignKey(connection, "booking_status_history", "fk_booking_status_history_booking", "booking_id", "bookings", "booking_id", "RESTRICT");
    await ensureForeignKey(connection, "booking_status_history", "fk_booking_status_history_changed_by", "changed_by_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "booking_date_locks", "fk_booking_date_locks_booking", "booking_id", "bookings", "booking_id", "RESTRICT");
    await ensureForeignKey(connection, "booking_date_locks", "fk_booking_date_locks_listing", "listing_id", "listings", "listing_id", "RESTRICT");

    await ensureForeignKey(connection, "payments", "fk_payments_booking", "booking_id", "bookings", "booking_id", "RESTRICT");
    await ensureForeignKey(connection, "payments", "fk_payments_user", "user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "payment_transactions", "fk_payment_transactions_payment", "payment_id", "payments", "payment_id", "RESTRICT");
    await ensureForeignKey(connection, "payment_transactions", "fk_payment_transactions_booking", "booking_id", "bookings", "booking_id", "RESTRICT");
    await ensureForeignKey(connection, "refunds", "fk_refunds_payment", "payment_id", "payments", "payment_id", "RESTRICT");
    await ensureForeignKey(connection, "refunds", "fk_refunds_booking", "booking_id", "bookings", "booking_id", "RESTRICT");
    await ensureForeignKey(connection, "refunds", "fk_refunds_requested_by", "requested_by_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "refunds", "fk_refunds_processed_by", "processed_by_user_id", "users", "user_id", "SET NULL");

    await ensureForeignKey(connection, "reviews", "fk_reviews_booking", "booking_id", "bookings", "booking_id", "SET NULL");
    await ensureForeignKey(connection, "reviews", "fk_reviews_listing", "listing_id", "listings", "listing_id", "RESTRICT");
    await ensureForeignKey(connection, "reviews", "fk_reviews_reviewer", "reviewer_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "review_replies", "fk_review_replies_review", "review_id", "reviews", "review_id", "CASCADE");
    await ensureForeignKey(connection, "review_replies", "fk_review_replies_host", "host_id", "users", "user_id", "RESTRICT");

    await ensureForeignKey(connection, "conversation", "fk_conversation_created_by", "created_by_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "conversation", "fk_conversation_listing", "listing_id", "listings", "listing_id", "SET NULL");
    await ensureForeignKey(connection, "conversation", "fk_conversation_guest", "guest_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "conversation", "fk_conversation_host", "host_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "conversation", "fk_conversation_booking", "booking_order_id", "bookings", "booking_id", "SET NULL");
    await ensureForeignKey(connection, "conversation_participant", "fk_conversation_participant_conversation", "conversation_id", "conversation", "conversation_id", "CASCADE");
    await ensureForeignKey(connection, "conversation_participant", "fk_conversation_participant_user", "user_id", "users", "user_id", "CASCADE");
    await ensureForeignKey(connection, "message", "fk_message_conversation", "conversation_id", "conversation", "conversation_id", "CASCADE");
    await ensureForeignKey(connection, "message", "fk_message_sender", "sender_id", "users", "user_id", "RESTRICT");

    await ensureForeignKey(connection, "reports", "fk_reports_reporter", "reporter_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "reports", "fk_reports_resolved_by", "resolved_by", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "security_logs", "fk_security_logs_user", "user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "audit_logs", "fk_audit_logs_actor", "actor_id", "users", "user_id", "SET NULL");

    await ensureForeignKey(connection, "payout_account", "fk_payout_account_user", "user_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "host_payout_batch", "fk_host_payout_batch_host", "host_id", "users", "user_id", "RESTRICT");
    await ensureForeignKey(connection, "host_payout_batch", "fk_host_payout_batch_account", "payout_account_id", "payout_account", "payout_account_id", "RESTRICT");
    await ensureForeignKey(connection, "host_payout_batch", "fk_host_payout_batch_paid_by", "paid_by_user_id", "users", "user_id", "SET NULL");
    await ensureForeignKey(connection, "host_payout_booking_item", "fk_host_payout_booking_item_payout", "payout_id", "host_payout_batch", "payout_id", "RESTRICT");
    await ensureForeignKey(connection, "host_payout_booking_item", "fk_host_payout_booking_item_booking", "booking_order_id", "bookings", "booking_id", "RESTRICT");
};

const ensureDefaultRoles = async (connection) => {
    if (!(await tableExists(connection, "roles"))) {
        return;
    }

    const roles = [
        ["guest", "Guest"],
        ["host", "Host"],
        ["moderator", "Moderator"],
        ["admin", "Admin"],
    ];

    for (const [code, name] of roles) {
        await connection.execute(
            `
            INSERT INTO roles (code, name, created_at, updated_at)
            VALUES (?, ?, UTC_TIMESTAMP(), UTC_TIMESTAMP())
            ON DUPLICATE KEY UPDATE name = VALUES(name), updated_at = UTC_TIMESTAMP()
            `,
            [code, name],
        );
    }

    console.info("Ensured default roles");
};

const main = async () => {
    const connection = await createConnection();

    try {
        await connection.query("SET time_zone = '+00:00'");
        await createMissingTables(connection);
        await addColumns(connection);
        await normalizeColumnTypes(connection);
        await extendEnums(connection);
        await addIndexes(connection);
        await addForeignKeys(connection);
        await ensureDefaultRoles(connection);
        console.info("Security schema completion completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error("Security schema completion failed");
    console.error(error.message);
    process.exitCode = 1;
});
