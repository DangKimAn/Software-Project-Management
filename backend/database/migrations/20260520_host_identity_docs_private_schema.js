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
        host: process.env.MYSQLHOST || process.env.MYSQL_HOST || "127.0.0.1",
        port: Number(process.env.MYSQLPORT || process.env.MYSQL_PORT || 3306),
        user: dbUser,
        password: process.env.MYSQLPASSWORD || process.env.MYSQL_PASSWORD || "",
        database: databaseName,
        ssl,
        multipleStatements: false,
        charset: "utf8mb4",
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

const createMissingTables = async (connection) => {
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
            \`entity_type\` ENUM('individual','business') NOT NULL DEFAULT 'individual',
            \`notes\` TEXT NULL,
            \`status\` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
            \`reviewed_by_user_id\` BIGINT UNSIGNED NULL,
            \`reviewed_at\` DATETIME NULL,
            \`rejection_reason\` TEXT NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`application_id\`),
            INDEX \`idx_host_applications_user\` (\`user_id\`),
            INDEX \`idx_host_applications_status\` (\`status\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );

    await ensureTable(
        connection,
        "host_identity_documents",
        `
        CREATE TABLE \`host_identity_documents\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`application_id\` BIGINT UNSIGNED NOT NULL,
            \`user_id\` BIGINT UNSIGNED NOT NULL,
            \`document_type\` ENUM('cccd','cmnd','passport','driver_license','business_license','other') NOT NULL,
            \`side\` ENUM('front','back','single','business_license') NOT NULL,
            \`original_filename\` VARCHAR(255) NULL,
            \`object_key\` VARCHAR(700) NOT NULL,
            \`mime_type\` VARCHAR(120) NOT NULL,
            \`file_size\` INT UNSIGNED NOT NULL,
            \`status\` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            INDEX \`idx_host_identity_documents_application\` (\`application_id\`),
            INDEX \`idx_host_identity_documents_user\` (\`user_id\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `,
    );
};

const addMissingColumns = async (connection) => {
    await ensureColumn(connection, "host_applications", "contact_name", "`contact_name` VARCHAR(255) NULL AFTER `user_id`");
    await ensureColumn(connection, "host_applications", "contact_email", "`contact_email` VARCHAR(255) NULL AFTER `contact_name`");
    await ensureColumn(connection, "host_applications", "contact_phone", "`contact_phone` VARCHAR(32) NOT NULL AFTER `contact_email`");
    await ensureColumn(connection, "host_applications", "business_address", "`business_address` VARCHAR(500) NOT NULL AFTER `contact_phone`");
    await ensureColumn(connection, "host_applications", "entity_type", "`entity_type` ENUM('individual','business') NOT NULL DEFAULT 'individual' AFTER `business_address`");
    await ensureColumn(connection, "host_applications", "notes", "`notes` TEXT NULL AFTER `entity_type`");
    await ensureColumn(connection, "host_applications", "status", "`status` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending' AFTER `notes`");
    await ensureColumn(connection, "host_applications", "reviewed_by_user_id", "`reviewed_by_user_id` BIGINT UNSIGNED NULL AFTER `status`");
    await ensureColumn(connection, "host_applications", "reviewed_at", "`reviewed_at` DATETIME NULL AFTER `reviewed_by_user_id`");
    await ensureColumn(connection, "host_applications", "rejection_reason", "`rejection_reason` TEXT NULL AFTER `reviewed_at`");

    await ensureColumn(connection, "users", "host_application_status", "`host_application_status` ENUM('pending','approved','rejected') NULL");
};

const addIndexes = async (connection) => {
    await ensureIndex(connection, "host_applications", "idx_host_applications_user", "`user_id`");
    await ensureIndex(connection, "host_applications", "idx_host_applications_status", "`status`");
    await ensureIndex(connection, "host_identity_documents", "idx_host_identity_documents_application", "`application_id`");
    await ensureIndex(connection, "host_identity_documents", "idx_host_identity_documents_user", "`user_id`");
};

const addForeignKeys = async (connection) => {
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
        "host_identity_documents",
        "fk_host_identity_documents_application",
        "application_id",
        "host_applications",
        "application_id",
        "CASCADE",
    );
    await ensureForeignKey(
        connection,
        "host_identity_documents",
        "fk_host_identity_documents_user",
        "user_id",
        "users",
        "user_id",
        "RESTRICT",
    );
};

const main = async () => {
    const connection = await createConnection();

    try {
        await createMissingTables(connection);
        await addMissingColumns(connection);
        await addIndexes(connection);
        await addForeignKeys(connection);
        console.info("Host identity docs private schema completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error("Host identity docs private schema failed");
    console.error(error.message);
    process.exitCode = 1;
});
