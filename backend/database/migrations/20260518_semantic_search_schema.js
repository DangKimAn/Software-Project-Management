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
        host: process.env.MYSQLHOST || "127.0.0.1",
        port: Number(process.env.MYSQLPORT || 3306),
        user: dbUser,
        password: process.env.MYSQLPASSWORD || "",
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

const getTableCollation = async (connection, tableName) => {
    const [rows] = await connection.execute(
        `
        SELECT table_collation AS tableCollation
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = ?
        LIMIT 1
        `,
        [tableName],
    );

    return rows[0]?.tableCollation || null;
};

const parseEnumValues = (columnType) =>
    Array.from(String(columnType).matchAll(/'((?:''|[^'])*)'/g)).map((match) => match[1].replace(/''/g, "'"));

const ensureColumn = async (connection, tableName, columnName, definition) => {
    if (!(await tableExists(connection, tableName))) {
        console.info(`Skipped ${tableName}.${columnName}: table missing`);
        return;
    }

    if (await columnExists(connection, tableName, columnName)) {
        return;
    }

    await connection.query(`ALTER TABLE ${quoteId(tableName)} ADD COLUMN ${definition}`);
    console.info(`Added column ${tableName}.${columnName}`);
};

const ensureUtf8mb4Table = async (connection, tableName) => {
    if (!(await tableExists(connection, tableName))) {
        console.info(`Skipped charset conversion for ${tableName}: table missing`);
        return;
    }

    const currentCollation = String(await getTableCollation(connection, tableName)).toLowerCase();
    if (currentCollation.startsWith("utf8mb4_")) {
        return;
    }

    await connection.query(
        `ALTER TABLE ${quoteId(tableName)} CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
    console.info(`Converted ${tableName} to utf8mb4_unicode_ci`);
};

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
    await connection.query(
        `ALTER TABLE ${quoteId(tableName)} MODIFY COLUMN ${quoteId(columnName)} ENUM(${enumSql}) ${nullSql} ${defaultSql}`,
    );
    console.info(`Extended enum ${tableName}.${columnName}`);
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

const main = async () => {
    const connection = await createConnection();

    try {
        await ensureUtf8mb4Table(connection, "listings");
        await ensureEnumContains(
            connection,
            "listings",
            "status",
            ["active", "approved", "published"],
            "NOT NULL",
            "DEFAULT 'draft'",
        );

        const embeddingColumnType = (await supportsJsonColumn(connection)) ? "JSON" : "LONGTEXT";

        await ensureColumn(connection, "listings", "search_text", "`search_text` LONGTEXT NULL");
        await ensureColumn(
            connection,
            "listings",
            "search_embedding_json",
            `\`search_embedding_json\` ${embeddingColumnType} NULL`,
        );
        await ensureColumn(
            connection,
            "listings",
            "search_embedding_updated_at",
            "`search_embedding_updated_at` DATETIME NULL",
        );

        console.info("Semantic search schema completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error("Semantic search schema failed");
    console.error(error.message);
    process.exitCode = 1;
});
