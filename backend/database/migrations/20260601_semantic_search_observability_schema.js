require("dotenv/config");

const fs = require("node:fs");
const path = require("node:path");
const mysql = require("mysql2/promise");

const databaseName = process.env.MYSQL_DATABASE || process.env.MYSQLDATABASE || "booking_room";
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
        decimalNumbers: true,
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

const supportsJsonColumn = async (connection) => {
    const tempTable = `tmp_json_probe_${Date.now()}`;

    try {
        await connection.query(`CREATE TEMPORARY TABLE ${quoteId(tempTable)} (payload JSON NULL)`);
        await connection.query(`DROP TEMPORARY TABLE ${quoteId(tempTable)}`);
        return true;
    } catch {
        return false;
    }
};

const createTableIfMissing = async (connection, tableName, sql) => {
    if (await tableExists(connection, tableName)) {
        return;
    }

    await connection.query(sql);
    console.info(`Created table ${tableName}`);
};

const ensureColumn = async (connection, tableName, columnName, definition) => {
    if (!(await tableExists(connection, tableName)) || (await columnExists(connection, tableName, columnName))) {
        return;
    }

    await connection.query(`ALTER TABLE ${quoteId(tableName)} ADD COLUMN ${definition}`);
    console.info(`Added column ${tableName}.${columnName}`);
};

const ensureIndex = async (connection, tableName, indexName, createSql) => {
    if (!(await tableExists(connection, tableName)) || (await indexExists(connection, tableName, indexName))) {
        return;
    }

    await connection.query(createSql);
    console.info(`Added index ${tableName}.${indexName}`);
};

const main = async () => {
    const connection = await createConnection();

    try {
        const jsonType = (await supportsJsonColumn(connection)) ? "JSON" : "LONGTEXT";

        await createTableIfMissing(
            connection,
            "listing_embeddings",
            `
            CREATE TABLE ${quoteId("listing_embeddings")} (
                ${quoteId("id")} BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                ${quoteId("listing_id")} INT UNSIGNED NOT NULL,
                ${quoteId("embedding_provider")} VARCHAR(64) NOT NULL,
                ${quoteId("embedding_model")} VARCHAR(128) NOT NULL,
                ${quoteId("embedding_vector")} ${jsonType} NULL,
                ${quoteId("qdrant_point_id")} VARCHAR(128) NULL,
                ${quoteId("searchable_text")} LONGTEXT NOT NULL,
                ${quoteId("version")} VARCHAR(64) NOT NULL,
                ${quoteId("created_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                ${quoteId("updated_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (${quoteId("id")}),
                UNIQUE KEY ${quoteId("listing_embeddings_unique_model_version")}
                    (${quoteId("listing_id")}, ${quoteId("embedding_provider")}, ${quoteId("embedding_model")}, ${quoteId("version")}),
                KEY ${quoteId("listing_embeddings_listing_id_idx")} (${quoteId("listing_id")})
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "id",
            `${quoteId("id")} BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "listing_id",
            `${quoteId("listing_id")} INT UNSIGNED NOT NULL AFTER ${quoteId("id")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "embedding_provider",
            `${quoteId("embedding_provider")} VARCHAR(64) NOT NULL DEFAULT 'openai' AFTER ${quoteId("listing_id")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "embedding_model",
            `${quoteId("embedding_model")} VARCHAR(128) NOT NULL DEFAULT 'unknown' AFTER ${quoteId("embedding_provider")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "embedding_vector",
            `${quoteId("embedding_vector")} ${jsonType} NULL AFTER ${quoteId("embedding_model")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "qdrant_point_id",
            `${quoteId("qdrant_point_id")} VARCHAR(128) NULL AFTER ${quoteId("embedding_vector")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "searchable_text",
            `${quoteId("searchable_text")} LONGTEXT NULL AFTER ${quoteId("qdrant_point_id")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "version",
            `${quoteId("version")} VARCHAR(64) NOT NULL DEFAULT 'v1' AFTER ${quoteId("searchable_text")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "created_at",
            `${quoteId("created_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER ${quoteId("version")}`,
        );
        await ensureColumn(
            connection,
            "listing_embeddings",
            "updated_at",
            `${quoteId("updated_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER ${quoteId("created_at")}`,
        );
        await ensureIndex(
            connection,
            "listing_embeddings",
            "listing_embeddings_unique_model_version",
            `
            CREATE UNIQUE INDEX ${quoteId("listing_embeddings_unique_model_version")}
            ON ${quoteId("listing_embeddings")}
            (${quoteId("listing_id")}, ${quoteId("embedding_provider")}, ${quoteId("embedding_model")}, ${quoteId("version")})
            `,
        );
        await ensureIndex(
            connection,
            "listing_embeddings",
            "listing_embeddings_listing_id_idx",
            `
            CREATE INDEX ${quoteId("listing_embeddings_listing_id_idx")}
            ON ${quoteId("listing_embeddings")} (${quoteId("listing_id")})
            `,
        );

        await createTableIfMissing(
            connection,
            "search_logs",
            `
            CREATE TABLE ${quoteId("search_logs")} (
                ${quoteId("id")} BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                ${quoteId("user_id")} BIGINT UNSIGNED NULL,
                ${quoteId("query")} VARCHAR(500) NOT NULL,
                ${quoteId("parsed_filters")} ${jsonType} NULL,
                ${quoteId("result_listing_ids")} ${jsonType} NOT NULL,
                ${quoteId("clicked_listing_id")} INT UNSIGNED NULL,
                ${quoteId("booked_listing_id")} INT UNSIGNED NULL,
                ${quoteId("created_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (${quoteId("id")}),
                KEY ${quoteId("search_logs_user_created_idx")} (${quoteId("user_id")}, ${quoteId("created_at")}),
                KEY ${quoteId("search_logs_created_idx")} (${quoteId("created_at")})
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "id",
            `${quoteId("id")} BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "user_id",
            `${quoteId("user_id")} BIGINT UNSIGNED NULL AFTER ${quoteId("id")}`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "query",
            `${quoteId("query")} VARCHAR(500) NOT NULL DEFAULT '' AFTER ${quoteId("user_id")}`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "parsed_filters",
            `${quoteId("parsed_filters")} ${jsonType} NULL AFTER ${quoteId("query")}`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "result_listing_ids",
            `${quoteId("result_listing_ids")} ${jsonType} NULL AFTER ${quoteId("parsed_filters")}`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "clicked_listing_id",
            `${quoteId("clicked_listing_id")} INT UNSIGNED NULL AFTER ${quoteId("result_listing_ids")}`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "booked_listing_id",
            `${quoteId("booked_listing_id")} INT UNSIGNED NULL AFTER ${quoteId("clicked_listing_id")}`,
        );
        await ensureColumn(
            connection,
            "search_logs",
            "created_at",
            `${quoteId("created_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER ${quoteId("booked_listing_id")}`,
        );
        await ensureIndex(
            connection,
            "search_logs",
            "search_logs_user_created_idx",
            `
            CREATE INDEX ${quoteId("search_logs_user_created_idx")}
            ON ${quoteId("search_logs")} (${quoteId("user_id")}, ${quoteId("created_at")})
            `,
        );
        await ensureIndex(
            connection,
            "search_logs",
            "search_logs_created_idx",
            `
            CREATE INDEX ${quoteId("search_logs_created_idx")}
            ON ${quoteId("search_logs")} (${quoteId("created_at")})
            `,
        );

        await createTableIfMissing(
            connection,
            "semantic_synonyms",
            `
            CREATE TABLE ${quoteId("semantic_synonyms")} (
                ${quoteId("id")} BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                ${quoteId("keyword")} VARCHAR(120) NOT NULL,
                ${quoteId("synonyms")} ${jsonType} NOT NULL,
                ${quoteId("created_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                ${quoteId("updated_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (${quoteId("id")}),
                UNIQUE KEY ${quoteId("semantic_synonyms_keyword_unique")} (${quoteId("keyword")})
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `,
        );
        await ensureColumn(
            connection,
            "semantic_synonyms",
            "id",
            `${quoteId("id")} BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST`,
        );
        await ensureColumn(
            connection,
            "semantic_synonyms",
            "keyword",
            `${quoteId("keyword")} VARCHAR(120) NOT NULL DEFAULT '' AFTER ${quoteId("id")}`,
        );
        await ensureColumn(
            connection,
            "semantic_synonyms",
            "synonyms",
            `${quoteId("synonyms")} ${jsonType} NULL AFTER ${quoteId("keyword")}`,
        );
        await ensureColumn(
            connection,
            "semantic_synonyms",
            "created_at",
            `${quoteId("created_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER ${quoteId("synonyms")}`,
        );
        await ensureColumn(
            connection,
            "semantic_synonyms",
            "updated_at",
            `${quoteId("updated_at")} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER ${quoteId("created_at")}`,
        );
        await ensureIndex(
            connection,
            "semantic_synonyms",
            "semantic_synonyms_keyword_unique",
            `
            CREATE UNIQUE INDEX ${quoteId("semantic_synonyms_keyword_unique")}
            ON ${quoteId("semantic_synonyms")} (${quoteId("keyword")})
            `,
        );

        console.info("Semantic search observability schema completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error("Semantic search observability schema failed");
    console.error(error.message);
    process.exitCode = 1;
});
