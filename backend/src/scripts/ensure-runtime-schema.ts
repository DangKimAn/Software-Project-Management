import "dotenv/config";

import sequelize from "../config/database";

const defaultRoles = [
    { code: "guest", name: "Guest" },
    { code: "host", name: "Host" },
    { code: "moderator", name: "Moderator" },
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
        `ALTER TABLE \`${tableName}\` MODIFY COLUMN \`${columnName}\` ENUM(${enumSql}) ${nullSql} ${
            defaultSql ?? ""
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

export const ensureRuntimeSchema = async () => {
    await ensureUsersSchema();
    await ensureUserProfilesSchema();
    await ensureRolesSchema();
    await ensureAuthOtpSchema();
    await ensureAuditLogsSchema();
    await ensureNotificationLogsSchema();
    await ensurePayoutAccountSchema();
    await ensureMessagingSchema();
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
