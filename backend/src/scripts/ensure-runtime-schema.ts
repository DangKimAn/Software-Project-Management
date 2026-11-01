import "dotenv/config";

import sequelize from "../config/database";

const defaultRoles = [
    { code: "guest", name: "Guest" },
    { code: "host", name: "Host" },
    { code: "admin", name: "Admin" },
];

const tableExists = async (tableName: string) => {
    const [rows] = await sequelize.query(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = ?
        `,
        {
            replacements: [tableName],
        },
    );

    return Number((rows as Array<{ count: number }>)[0]?.count ?? 0) > 0;
};

const columnExists = async (tableName: string, columnName: string) => {
    const [rows] = await sequelize.query(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        `,
        {
            replacements: [tableName, columnName],
        },
    );

    return Number((rows as Array<{ count: number }>)[0]?.count ?? 0) > 0;
};

const indexExists = async (tableName: string, indexName: string) => {
    const [rows] = await sequelize.query(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND index_name = ?
        `,
        {
            replacements: [tableName, indexName],
        },
    );

    return Number((rows as Array<{ count: number }>)[0]?.count ?? 0) > 0;
};

const getColumnType = async (tableName: string, columnName: string) => {
    const [rows] = await sequelize.query(
        `
        SELECT column_type AS columnType
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        LIMIT 1
        `,
        {
            replacements: [tableName, columnName],
        },
    );

    return ((rows as Array<{ columnType?: string }>)[0]?.columnType ?? null) as string | null;
};

const ensureColumn = async (tableName: string, columnName: string, definition: string) => {
    if (await columnExists(tableName, columnName)) {
        return;
    }

    await sequelize.query(`ALTER TABLE \`${tableName}\` ADD COLUMN ${definition}`);
};

const ensureIndex = async (
    tableName: string,
    indexName: string,
    indexType: "INDEX" | "UNIQUE INDEX",
    columns: string,
) => {
    if (await indexExists(tableName, indexName)) {
        return;
    }

    await sequelize.query(`CREATE ${indexType} \`${indexName}\` ON \`${tableName}\` (${columns})`);
};

const ensureEnumContains = async (
    tableName: string,
    columnName: string,
    values: string[],
    nullSql: "NULL" | "NOT NULL",
    defaultSql?: string,
) => {
    const columnType = await getColumnType(tableName, columnName);

    if (!columnType) {
        return;
    }

    if (values.every((value) => columnType.includes(`'${value}'`))) {
        return;
    }

    const enumSql = values.map((value) => `'${value.replace(/'/g, "''")}'`).join(",");
    await sequelize.query(
        `ALTER TABLE \`${tableName}\` MODIFY COLUMN \`${columnName}\` ENUM(${enumSql}) ${nullSql} ${defaultSql ?? ""
        }`,
    );
};

const checkConstraintMatchesValues = async (
    tableName: string,
    constraintName: string,
    requiredValues: string[],
) => {
    const [rows] = await sequelize.query(
        `
        SELECT CHECK_CLAUSE AS checkClause
        FROM information_schema.CHECK_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
          AND CONSTRAINT_NAME = ?
        LIMIT 1
        `,
        {
            replacements: [constraintName],
        },
    );

    const clause = (rows as Array<{ checkClause?: string }>)[0]?.checkClause ?? "";

    if (!clause) {
        return false;
    }

    return requiredValues.every((value) => clause.includes(`'${value}'`));
};

const ensureCheckConstraint = async (
    tableName: string,
    constraintName: string,
    columnName: string,
    values: string[],
) => {
    if (await checkConstraintMatchesValues(tableName, constraintName, values)) {
        return;
    }

    try {
        await sequelize.query(`ALTER TABLE \`${tableName}\` DROP CHECK \`${constraintName}\``);
    } catch {
        // constraint may not exist
    }

    const inList = values.map((v) => `'${v.replace(/'/g, "''")}'`).join(",");
    await sequelize.query(
        `ALTER TABLE \`${tableName}\` ADD CONSTRAINT \`${constraintName}\` CHECK (\`${columnName}\` IN (${inList}))`,
    );
};

const ensureUsersSchema = async () => {
    if (!(await tableExists("users"))) {
        await sequelize.query(`
            CREATE TABLE \`users\` (
                \`user_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`username\` VARCHAR(255) NULL,
                \`email\` VARCHAR(255) NOT NULL,
                \`phone\` VARCHAR(32) NULL,
                \`full_name\` VARCHAR(255) NOT NULL,
                \`first_name\` VARCHAR(120) NULL,
                \`last_name\` VARCHAR(120) NULL,
                \`password_hash\` VARCHAR(255) NOT NULL,
                \`date_of_birth\` DATE NULL,
                \`dob\` DATE NULL,
                \`bio\` TEXT NULL,
                \`avatar_url\` VARCHAR(1024) NULL,
                \`avatar_key\` VARCHAR(500) NULL,
                \`is_email_verified\` TINYINT(1) NOT NULL DEFAULT 0,
                \`is_phone_verified\` TINYINT(1) NOT NULL DEFAULT 0,
                \`is_host_verified\` TINYINT(1) NOT NULL DEFAULT 0,
                \`host_application_status\` ENUM('pending','approved','rejected') NULL,
                \`status\` ENUM('active','inactive','blocked','suspended','deleted','locked') NOT NULL DEFAULT 'active',
                \`last_login_at\` DATETIME NULL,
                \`deleted_at\` DATETIME NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`user_id\`),
                UNIQUE KEY \`uq_users_email\` (\`email\`),
                UNIQUE KEY \`uq_users_phone\` (\`phone\`),
                UNIQUE KEY \`uq_users_username\` (\`username\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        return;
    }

    await ensureColumn("users", "username", "`username` VARCHAR(255) NULL AFTER `user_id`");
    await ensureColumn("users", "first_name", "`first_name` VARCHAR(120) NULL AFTER `full_name`");
    await ensureColumn("users", "last_name", "`last_name` VARCHAR(120) NULL AFTER `first_name`");
    await ensureColumn("users", "dob", "`dob` DATE NULL AFTER `date_of_birth`");
    await ensureColumn(
        "users",
        "is_email_verified",
        "`is_email_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `bio`",
    );
    await ensureColumn("users", "avatar_url", "`avatar_url` VARCHAR(1024) NULL AFTER `bio`");
    await ensureColumn("users", "avatar_key", "`avatar_key` VARCHAR(500) NULL AFTER `avatar_url`");
    await ensureColumn(
        "users",
        "is_phone_verified",
        "`is_phone_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_email_verified`",
    );
    await ensureColumn(
        "users",
        "is_host_verified",
        "`is_host_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_phone_verified`",
    );
    await ensureColumn(
        "users",
        "host_application_status",
        "`host_application_status` ENUM('pending','approved','rejected') NULL AFTER `is_host_verified`",
    );
    await ensureColumn("users", "last_login_at", "`last_login_at` DATETIME NULL AFTER `status`");
    await ensureColumn("users", "deleted_at", "`deleted_at` DATETIME NULL AFTER `last_login_at`");
    await ensureIndex("users", "uq_users_username", "UNIQUE INDEX", "`username`");
    await ensureEnumContains(
        "users",
        "status",
        ["active", "inactive", "blocked", "suspended", "deleted", "locked"],
        "NOT NULL",
        "DEFAULT 'active'",
    );
    await ensureCheckConstraint(
        "users",
        "chk_users_status",
        "status",
        ["active", "inactive", "blocked", "suspended", "deleted", "locked"],
    );
};

const ensureUserProfilesSchema = async () => {
    if (!(await tableExists("user_profiles"))) {
        return;
    }

    await ensureColumn("user_profiles", "location", "`location` VARCHAR(255) NULL AFTER `gender`");
    await ensureColumn("user_profiles", "job", "`job` VARCHAR(255) NULL AFTER `location`");
    await ensureColumn(
        "user_profiles",
        "dream_destination",
        "`dream_destination` VARCHAR(255) NULL AFTER `job`",
    );
    await ensureColumn("user_profiles", "school", "`school` VARCHAR(255) NULL AFTER `dream_destination`");
    await ensureColumn("user_profiles", "languages_json", "`languages_json` JSON NULL AFTER `school`");
};

const ensureRolesSchema = async () => {
    if (!(await tableExists("roles"))) {
        await sequelize.query(`
            CREATE TABLE \`roles\` (
                \`role_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`code\` VARCHAR(64) NOT NULL,
                \`name\` VARCHAR(120) NOT NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`role_id\`),
                UNIQUE KEY \`uq_roles_code\` (\`code\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }

    if (!(await tableExists("user_role"))) {
        await sequelize.query(`
            CREATE TABLE \`user_role\` (
                \`user_id\` BIGINT UNSIGNED NOT NULL,
                \`role_id\` BIGINT UNSIGNED NOT NULL,
                \`assigned_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (\`user_id\`, \`role_id\`),
                INDEX \`idx_user_role_role\` (\`role_id\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }

    for (const role of defaultRoles) {
        await sequelize.query(
            `
            INSERT INTO roles (code, name, created_at, updated_at)
            VALUES (?, ?, NOW(), NOW())
            ON DUPLICATE KEY UPDATE name = VALUES(name), updated_at = NOW()
            `,
            {
                replacements: [role.code, role.name],
            },
        );
    }
};

const ensureAuthOtpSchema = async () => {
    if (await tableExists("auth_otp_tokens")) {
        await ensureEnumContains(
            "auth_otp_tokens",
            "purpose",
            ["sign_up", "forgot_password", "verify_email", "verify_phone", "password_reset"],
            "NOT NULL",
        );
        await sequelize.query(
            "UPDATE auth_otp_tokens SET purpose = 'forgot_password' WHERE purpose = 'password_reset'",
        );
        await ensureEnumContains(
            "auth_otp_tokens",
            "purpose",
            ["sign_up", "forgot_password", "verify_email", "verify_phone"],
            "NOT NULL",
        );
        await sequelize.query(
            "ALTER TABLE `auth_otp_tokens` MODIFY COLUMN `user_id` BIGINT UNSIGNED NULL",
        );
        await ensureColumn("auth_otp_tokens", "used_at", "`used_at` DATETIME NULL AFTER `consumed_at`");
        await ensureColumn(
            "auth_otp_tokens",
            "attempt_count",
            "`attempt_count` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `used_at`",
        );
        return;
    }

    await sequelize.query(`
        CREATE TABLE \`auth_otp_tokens\` (
            \`otp_token_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`user_id\` BIGINT UNSIGNED NULL,
            \`identifier\` VARCHAR(255) NOT NULL,
            \`purpose\` ENUM('sign_up','forgot_password','verify_email','verify_phone') NOT NULL,
            \`token_hash\` VARCHAR(255) NOT NULL,
            \`expires_at\` DATETIME NOT NULL,
            \`consumed_at\` DATETIME NULL,
            \`used_at\` DATETIME NULL,
            \`attempt_count\` INT UNSIGNED NOT NULL DEFAULT 0,
            \`sent_at\` DATETIME NOT NULL,
            \`ip_address\` VARCHAR(255) NULL,
            \`user_agent\` VARCHAR(1024) NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`otp_token_id\`),
            INDEX \`idx_auth_otp_user_purpose_expires\` (\`user_id\`, \`purpose\`, \`expires_at\`),
            INDEX \`idx_auth_otp_identifier_purpose_sent\` (\`identifier\`, \`purpose\`, \`sent_at\`),
            INDEX \`idx_auth_otp_hash\` (\`token_hash\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
};

const ensureAuditLogsSchema = async () => {
    if (await tableExists("audit_logs")) {
        return;
    }

    await sequelize.query(`
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
            INDEX \`idx_audit_logs_created_at\` (\`created_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
};

const ensureNotificationLogsSchema = async () => {
    if (!(await tableExists("notification_logs"))) {
        await sequelize.query(`
            CREATE TABLE \`notification_logs\` (
                \`notification_log_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`event_type\` VARCHAR(100) NOT NULL,
                \`target_type\` VARCHAR(64) NOT NULL,
                \`target_id\` VARCHAR(64) NOT NULL,
                \`recipient\` VARCHAR(255) NOT NULL,
                \`recipient_user_id\` BIGINT UNSIGNED NULL,
                \`title\` VARCHAR(255) NULL,
                \`body\` TEXT NULL,
                \`action_url\` VARCHAR(1024) NULL,
                \`payload_json\` JSON NULL,
                \`status\` ENUM('pending','sent','failed','skipped') NOT NULL DEFAULT 'pending',
                \`provider\` VARCHAR(64) NULL,
                \`provider_message_id\` VARCHAR(255) NULL,
                \`error_message\` TEXT NULL,
                \`sent_at\` DATETIME NULL,
                \`read_at\` DATETIME NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`notification_log_id\`),
                UNIQUE KEY \`uniq_notification_event_target_recipient\` (
                    \`event_type\`,
                    \`target_type\`,
                    \`target_id\`,
                    \`recipient\`
                ),
                INDEX \`idx_notification_logs_status\` (\`status\`),
                INDEX \`idx_notification_logs_target\` (\`target_type\`, \`target_id\`),
                INDEX \`idx_notification_logs_recipient_user_read\` (\`recipient_user_id\`, \`read_at\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        return;
    }

    await ensureColumn("notification_logs", "recipient_user_id", "`recipient_user_id` BIGINT UNSIGNED NULL");
    await ensureColumn("notification_logs", "title", "`title` VARCHAR(255) NULL");
    await ensureColumn("notification_logs", "body", "`body` TEXT NULL");
    await ensureColumn("notification_logs", "action_url", "`action_url` VARCHAR(1024) NULL");
    await ensureColumn("notification_logs", "payload_json", "`payload_json` JSON NULL");
    await ensureColumn("notification_logs", "read_at", "`read_at` DATETIME NULL");
    await ensureIndex(
        "notification_logs",
        "idx_notification_logs_recipient_user_read",
        "INDEX",
        "`recipient_user_id`, `read_at`",
    );
};

const ensureUserDeviceTokensSchema = async () => {
    if (!(await tableExists("user_device_tokens"))) {
        await sequelize.query(`
            CREATE TABLE \`user_device_tokens\` (
                \`device_token_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`user_id\` BIGINT UNSIGNED NOT NULL,
                \`fcm_token\` VARCHAR(512) NOT NULL,
                \`token_hash\` CHAR(64) NOT NULL,
                \`platform\` ENUM('android','ios','web') NOT NULL DEFAULT 'android',
                \`app_flavor\` VARCHAR(32) NULL,
                \`device_label\` VARCHAR(255) NULL,
                \`is_active\` TINYINT(1) NOT NULL DEFAULT 1,
                \`last_seen_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`device_token_id\`),
                UNIQUE KEY \`uq_user_device_tokens_hash\` (\`token_hash\`),
                INDEX \`idx_user_device_tokens_user_active\` (\`user_id\`, \`is_active\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        return;
    }

    await ensureColumn("user_device_tokens", "app_flavor", "`app_flavor` VARCHAR(32) NULL AFTER `platform`");
    await ensureColumn("user_device_tokens", "device_label", "`device_label` VARCHAR(255) NULL AFTER `app_flavor`");
    await ensureColumn("user_device_tokens", "is_active", "`is_active` TINYINT(1) NOT NULL DEFAULT 1 AFTER `device_label`");
    await ensureColumn(
        "user_device_tokens",
        "last_seen_at",
        "`last_seen_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `is_active`",
    );
    await ensureIndex("user_device_tokens", "uq_user_device_tokens_hash", "UNIQUE INDEX", "`token_hash`");
    await ensureIndex("user_device_tokens", "idx_user_device_tokens_user_active", "INDEX", "`user_id`, `is_active`");
};

const ensurePayoutAccountSchema = async () => {
    if (!(await tableExists("payout_account"))) {
        return;
    }

    await ensureColumn("payout_account", "bank_code", "`bank_code` VARCHAR(32) NULL");
    await ensureColumn("payout_account", "bank_short_name", "`bank_short_name` VARCHAR(100) NULL");
    await ensureColumn("payout_account", "bank_bin", "`bank_bin` VARCHAR(16) NULL");
    await ensureColumn("payout_account", "branch_name", "`branch_name` VARCHAR(255) NULL");
    await ensureColumn("payout_account", "account_number_encrypted", "`account_number_encrypted` TEXT NULL");
    await ensureColumn("payout_account", "account_number_hash", "`account_number_hash` VARCHAR(128) NULL");
    await ensureColumn("payout_account", "account_number_last4", "`account_number_last4` CHAR(4) NULL");
    await ensureColumn("payout_account", "is_default", "`is_default` TINYINT(1) NOT NULL DEFAULT 0");
    await ensureColumn("payout_account", "deleted_at", "`deleted_at` DATETIME NULL");
    await ensureIndex(
        "payout_account",
        "idx_payout_account_user_deleted_default",
        "INDEX",
        "`user_id`, `deleted_at`, `is_default`",
    );
};

const ensureMessagingSchema = async () => {
    if (!(await tableExists("conversation"))) {
        await sequelize.query(`
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
        `);
    } else {
        await ensureColumn("conversation", "last_message", "`last_message` TEXT NULL AFTER `dedupe_key`");
        await ensureColumn("conversation", "last_message_at", "`last_message_at` DATETIME NULL AFTER `last_message`");
        await ensureColumn("conversation", "guest_user_id", "`guest_user_id` BIGINT UNSIGNED NULL AFTER `listing_id`");
        await ensureColumn("conversation", "host_user_id", "`host_user_id` BIGINT UNSIGNED NULL AFTER `guest_user_id`");
        await ensureIndex("conversation", "idx_conversation_listing", "INDEX", "`listing_id`");
        await ensureIndex("conversation", "idx_conversation_guest", "INDEX", "`guest_user_id`");
        await ensureIndex("conversation", "idx_conversation_host", "INDEX", "`host_user_id`");
        await ensureIndex("conversation", "idx_conversation_booking", "INDEX", "`booking_order_id`");
        await ensureIndex("conversation", "idx_conversation_last_message_at", "INDEX", "`last_message_at`");
    }

    if (!(await tableExists("conversation_participant"))) {
        await sequelize.query(`
            CREATE TABLE \`conversation_participant\` (
                \`conversation_id\` BIGINT UNSIGNED NOT NULL,
                \`user_id\` BIGINT UNSIGNED NOT NULL,
                \`role\` ENUM('guest','host','admin') NULL,
                \`joined_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`last_read_at\` DATETIME NULL,
                PRIMARY KEY (\`conversation_id\`, \`user_id\`),
                INDEX \`idx_conversation_participant_user\` (\`user_id\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    } else {
        await ensureColumn(
            "conversation_participant",
            "role",
            "`role` ENUM('guest','host','admin') NULL AFTER `user_id`",
        );
        await ensureIndex(
            "conversation_participant",
            "idx_conversation_participant_user",
            "INDEX",
            "`user_id`",
        );
        await ensureEnumContains(
            "conversation_participant",
            "role",
            ["guest", "host", "admin"],
            "NULL",
        );
    }

    if (!(await tableExists("message"))) {
        await sequelize.query(`
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
        `);
    } else {
        await ensureColumn(
            "message",
            "updated_at",
            "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`",
        );
        await ensureColumn("message", "attachments_json", "`attachments_json` LONGTEXT NULL AFTER `message_type`");
        await ensureIndex("message", "idx_message_conversation_created", "INDEX", "`conversation_id`, `created_at`");
        await ensureEnumContains(
            "message",
            "message_type",
            ["text", "image", "system", "file"],
            "NOT NULL",
            "DEFAULT 'text'",
        );
    }
};

const ensureHostSheetSyncSchema = async () => {
    if (await tableExists("availability_calendars")) {
        await ensureColumn(
            "availability_calendars",
            "is_blocked_by_admin",
            "`is_blocked_by_admin` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_blocked_by_host`",
        );
        await ensureColumn(
            "availability_calendars",
            "lock_source",
            "`lock_source` VARCHAR(32) NULL AFTER `is_blocked_by_admin`",
        );
        await ensureColumn(
            "availability_calendars",
            "sync_revision",
            "`sync_revision` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `notes`",
        );
        await ensureColumn(
            "availability_calendars",
            "last_sheet_synced_at",
            "`last_sheet_synced_at` DATETIME NULL AFTER `sync_revision`",
        );
    }

    if (!(await tableExists("host_sheet_integrations"))) {
        await sequelize.query(`
            CREATE TABLE \`host_sheet_integrations\` (
                \`integration_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_user_id\` BIGINT UNSIGNED NOT NULL,
                \`spreadsheet_id\` VARCHAR(128) NOT NULL,
                \`spreadsheet_url\` VARCHAR(512) NOT NULL,
                \`spreadsheet_title\` VARCHAR(255) NULL,
                \`host_editor_email\` VARCHAR(255) NULL,
                \`service_account_email\` VARCHAR(255) NULL,
                \`status\` ENUM(
                    'disconnected',
                    'connected',
                    'permission_error',
                    'structure_error',
                    'quota_limited',
                    'sync_error'
                ) NOT NULL DEFAULT 'connected',
                \`auto_sync_enabled\` TINYINT(1) NOT NULL DEFAULT 1,
                \`strict_booking_precheck\` TINYINT(1) NOT NULL DEFAULT 1,
                \`permission_verified_at\` DATETIME NULL,
                \`can_write_verified\` TINYINT(1) NOT NULL DEFAULT 0,
                \`schema_version\` INT UNSIGNED NOT NULL DEFAULT 1,
                \`sync_revision\` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                \`sync_lock_token\` VARCHAR(64) NULL,
                \`sync_lock_expires_at\` DATETIME NULL,
                \`last_synced_at\` DATETIME NULL,
                \`last_polled_at\` DATETIME NULL,
                \`next_poll_at\` DATETIME NULL,
                \`last_error_code\` VARCHAR(64) NULL,
                \`last_error_message\` TEXT NULL,
                \`consecutive_failures\` INT UNSIGNED NOT NULL DEFAULT 0,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`integration_id\`),
                UNIQUE KEY \`uq_host_sheet_host\` (\`host_user_id\`),
                UNIQUE KEY \`uq_host_sheet_spreadsheet\` (\`spreadsheet_id\`),
                INDEX \`idx_host_sheet_poll\` (\`auto_sync_enabled\`, \`status\`, \`next_poll_at\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }

    if (!(await tableExists("host_sheet_sync_jobs"))) {
        await sequelize.query(`
            CREATE TABLE \`host_sheet_sync_jobs\` (
                \`job_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_user_id\` BIGINT UNSIGNED NOT NULL,
                \`integration_id\` BIGINT UNSIGNED NULL,
                \`listing_id\` INT UNSIGNED NULL,
                \`booking_id\` INT UNSIGNED NULL,
                \`job_type\` ENUM(
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
                \`priority\` TINYINT UNSIGNED NOT NULL DEFAULT 50,
                \`dedupe_key\` VARCHAR(191) NULL,
                \`payload_json\` JSON NULL,
                \`status\` ENUM('pending', 'processing', 'succeeded', 'failed', 'cancelled') NOT NULL DEFAULT 'pending',
                \`attempts\` INT UNSIGNED NOT NULL DEFAULT 0,
                \`max_attempts\` INT UNSIGNED NOT NULL DEFAULT 5,
                \`available_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`locked_by\` VARCHAR(64) NULL,
                \`locked_until\` DATETIME NULL,
                \`last_error\` TEXT NULL,
                \`completed_at\` DATETIME NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`job_id\`),
                INDEX \`idx_sheet_jobs_claim\` (\`status\`, \`available_at\`, \`priority\`, \`job_id\`),
                INDEX \`idx_sheet_jobs_host_status\` (\`host_user_id\`, \`status\`),
                INDEX \`idx_sheet_jobs_dedupe\` (\`dedupe_key\`, \`status\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }

    if (!(await tableExists("host_sheet_cell_snapshots"))) {
        await sequelize.query(`
            CREATE TABLE \`host_sheet_cell_snapshots\` (
                \`snapshot_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_user_id\` BIGINT UNSIGNED NOT NULL,
                \`listing_id\` INT UNSIGNED NOT NULL,
                \`date\` DATE NOT NULL,
                \`last_sheet_state\` ENUM('empty', 'host_blocked', 'pending_hold', 'booked', 'conflict') NOT NULL DEFAULT 'empty',
                \`last_sheet_raw_value\` VARCHAR(255) NULL,
                \`last_sheet_bg_hex\` VARCHAR(16) NULL,
                \`last_app_blocked_by_host\` TINYINT(1) NOT NULL DEFAULT 0,
                \`last_active_booking_id\` INT UNSIGNED NULL,
                \`lock_source\` ENUM(
                    'none',
                    'sheet_manual',
                    'app_manual',
                    'booking_hold',
                    'booking_paid',
                    'admin_lock',
                    'listing_inactive'
                ) NOT NULL DEFAULT 'none',
                \`sync_revision\` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                \`synced_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (\`snapshot_id\`),
                UNIQUE KEY \`uq_sheet_snapshot_listing_date\` (\`listing_id\`, \`date\`),
                INDEX \`idx_sheet_snapshot_host\` (\`host_user_id\`, \`date\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }

    if (!(await tableExists("host_sheet_sync_conflicts"))) {
        await sequelize.query(`
            CREATE TABLE \`host_sheet_sync_conflicts\` (
                \`conflict_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_user_id\` BIGINT UNSIGNED NOT NULL,
                \`integration_id\` BIGINT UNSIGNED NOT NULL,
                \`listing_id\` INT UNSIGNED NULL,
                \`booking_id\` INT UNSIGNED NULL,
                \`conflict_date\` DATE NULL,
                \`month_tab\` VARCHAR(16) NULL,
                \`conflict_type\` ENUM(
                    'booking_vs_sheet_edit',
                    'app_vs_sheet_concurrent',
                    'missing_listing_row',
                    'duplicate_listing_row',
                    'missing_month_tab',
                    'bulk_row_block_warning',
                    'permission_revoked'
                ) NOT NULL,
                \`severity\` ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'high',
                \`status\` ENUM('open', 'auto_repaired', 'resolved', 'reverted') NOT NULL DEFAULT 'open',
                \`description\` VARCHAR(500) NOT NULL,
                \`details_json\` JSON NULL,
                \`resolved_by_user_id\` BIGINT UNSIGNED NULL,
                \`resolved_at\` DATETIME NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`conflict_id\`),
                INDEX \`idx_sheet_conflicts_host_status\` (\`host_user_id\`, \`status\`, \`created_at\`),
                INDEX \`idx_sheet_conflicts_listing\` (\`listing_id\`, \`conflict_date\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }

    if (!(await tableExists("host_sheet_change_logs"))) {
        await sequelize.query(`
            CREATE TABLE \`host_sheet_change_logs\` (
                \`log_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_user_id\` BIGINT UNSIGNED NOT NULL,
                \`integration_id\` BIGINT UNSIGNED NOT NULL,
                \`listing_id\` INT UNSIGNED NULL,
                \`target_date\` DATE NULL,
                \`direction\` ENUM('sheet_to_app', 'app_to_sheet', 'structure_repair') NOT NULL,
                \`action\` VARCHAR(64) NOT NULL,
                \`previous_value\` VARCHAR(255) NULL,
                \`new_value\` VARCHAR(255) NULL,
                \`metadata_json\` JSON NULL,
                \`detected_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (\`log_id\`),
                INDEX \`idx_sheet_change_logs_host\` (\`host_user_id\`, \`detected_at\`),
                INDEX \`idx_sheet_change_logs_listing\` (\`listing_id\`, \`target_date\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
    }
};

export const ensureRuntimeSchema = async () => {
    await ensureUsersSchema();
    await ensureUserProfilesSchema();
    await ensureRolesSchema();
    await ensureAuthOtpSchema();
    await ensureAuditLogsSchema();
    await ensureNotificationLogsSchema();
    await ensureUserDeviceTokensSchema();
    await ensurePayoutAccountSchema();
    await ensureMessagingSchema();
    await ensureHostSheetSyncSchema();
};

if (require.main === module) {
    ensureRuntimeSchema()
        .then(() => {
            console.info("Runtime schema OK");
        })
        .catch((error: unknown) => {
            console.error("Runtime schema FAILED");
            console.error(error);
            process.exitCode = 1;
        })
        .finally(async () => {
            await sequelize.close();
        });
}
