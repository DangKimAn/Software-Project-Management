import "dotenv/config";

import sequelize from "../config/database";

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

const ensureColumn = async (tableName: string, columnName: string, definition: string) => {
    if (await columnExists(tableName, columnName)) {
        return;
    }

    await sequelize.query(`ALTER TABLE \`${tableName}\` ADD COLUMN ${definition}`);
    console.info(`Added column ${tableName}.${columnName}`);
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
    console.info(`Added index ${tableName}.${indexName}`);
};

const ensureConversationSchema = async () => {
    await ensureColumn("conversation", "created_by_user_id", "`created_by_user_id` BIGINT UNSIGNED NULL");
    await ensureColumn("conversation", "listing_id", "`listing_id` BIGINT UNSIGNED NULL");
    await ensureColumn("conversation", "booking_order_id", "`booking_order_id` BIGINT UNSIGNED NULL");
    await ensureColumn("conversation", "dedupe_key", "`dedupe_key` VARCHAR(255) NULL");
    await ensureColumn("conversation", "last_message_at", "`last_message_at` DATETIME NULL");
    await ensureIndex("conversation", "uq_conversation_dedupe_key", "UNIQUE INDEX", "`dedupe_key`");
};

const ensureMessageSchema = async () => {
    await ensureColumn(
        "conversation_participant",
        "last_read_at",
        "`last_read_at` DATETIME NULL",
    );
    await ensureColumn(
        "message",
        "message_type",
        "`message_type` ENUM('text','image') NOT NULL DEFAULT 'text'",
    );
    await ensureColumn("message", "attachments_json", "`attachments_json` TEXT NULL");
};

const ensureHostVerificationSchema = async () => {
    if (!(await tableExists("host_verification"))) {
        await sequelize.query(`
            CREATE TABLE \`host_verification\` (
                \`verification_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_id\` BIGINT UNSIGNED NOT NULL,
                \`verification_type\` ENUM('identity','business','bank') NOT NULL,
                \`full_name\` VARCHAR(255) NOT NULL,
                \`id_number\` VARCHAR(100) NULL,
                \`document_urls_json\` TEXT NOT NULL,
                \`notes\` TEXT NULL,
                \`status\` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
                \`reviewed_by_user_id\` BIGINT UNSIGNED NULL,
                \`reviewed_at\` DATETIME NULL,
                \`review_notes\` TEXT NULL,
                \`rejection_reason\` TEXT NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`verification_id\`),
                INDEX \`idx_host_verification_host_status\` (\`host_id\`, \`status\`),
                INDEX \`idx_host_verification_status_type\` (\`status\`, \`verification_type\`)
            )
        `);
        console.info("Created table host_verification");
    }

    if (!(await tableExists("host_applications"))) {
        await sequelize.query(`
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
            )
        `);
        console.info("Created table host_applications");
    }
};

const ensurePayoutSchema = async () => {
    await ensureColumn("payout_account", "bank_code", "`bank_code` VARCHAR(32) NULL AFTER `bank_name`");
    await ensureColumn("payout_account", "bank_short_name", "`bank_short_name` VARCHAR(100) NULL AFTER `bank_code`");
    await ensureColumn("payout_account", "bank_bin", "`bank_bin` VARCHAR(16) NULL AFTER `bank_short_name`");
    await ensureColumn("payout_account", "branch_name", "`branch_name` VARCHAR(255) NULL AFTER `account_name`");
    await ensureColumn("payout_account", "deleted_at", "`deleted_at` DATETIME NULL AFTER `is_default`");
    await ensureIndex(
        "payout_account",
        "idx_payout_account_user_deleted_default",
        "INDEX",
        "`user_id`, `deleted_at`, `is_default`",
    );

    if (!(await tableExists("host_payout_batch"))) {
        await sequelize.query(`
            CREATE TABLE \`host_payout_batch\` (
                \`payout_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`host_id\` BIGINT UNSIGNED NOT NULL,
                \`payout_account_id\` BIGINT UNSIGNED NOT NULL,
                \`amount\` DECIMAL(12,2) NOT NULL,
                \`currency\` VARCHAR(8) NOT NULL DEFAULT 'VND',
                \`status\` ENUM('pending','processing','paid','failed','cancelled') NOT NULL DEFAULT 'pending',
                \`notes\` TEXT NULL,
                \`paid_at\` DATETIME NULL,
                \`paid_by_user_id\` BIGINT UNSIGNED NULL,
                \`transfer_reference\` VARCHAR(255) NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (\`payout_id\`),
                INDEX \`idx_host_payout_batch_host_status\` (\`host_id\`, \`status\`),
                INDEX \`idx_host_payout_batch_status\` (\`status\`)
            )
        `);
        console.info("Created table host_payout_batch");
    }

    if (!(await tableExists("host_payout_booking_item"))) {
        await sequelize.query(`
            CREATE TABLE \`host_payout_booking_item\` (
                \`payout_item_id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                \`payout_id\` BIGINT UNSIGNED NOT NULL,
                \`booking_order_id\` BIGINT UNSIGNED NOT NULL,
                \`booking_detail_id\` BIGINT UNSIGNED NOT NULL,
                \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (\`payout_item_id\`),
                UNIQUE KEY \`uq_host_payout_booking_item_detail\` (\`booking_detail_id\`),
                INDEX \`idx_host_payout_booking_item_payout\` (\`payout_id\`)
            )
        `);
        console.info("Created table host_payout_booking_item");
    }
};

const main = async () => {
    await sequelize.authenticate();
    await ensureConversationSchema();
    await ensureMessageSchema();
    await ensureHostVerificationSchema();
    await ensurePayoutSchema();
    console.info("Final modules schema OK");
};

main()
    .catch((error: unknown) => {
        console.error("Final modules schema FAILED");

        if (error instanceof Error) {
            console.error(error.message);
        } else {
            console.error(error);
        }

        process.exitCode = 1;
    })
    .finally(async () => {
        await sequelize.close();
    });
