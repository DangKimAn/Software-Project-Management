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

const main = async () => {
    const connection = await createConnection();

    try {
        await ensureColumn(connection, "listing_images", "object_key", "`object_key` VARCHAR(500) NULL AFTER `url`");
        await ensureColumn(
            connection,
            "listing_images",
            "original_filename",
            "`original_filename` VARCHAR(255) NULL AFTER `object_key`",
        );
        await ensureColumn(
            connection,
            "listing_images",
            "display_title",
            "`display_title` VARCHAR(120) NULL AFTER `original_filename`",
        );
        await ensureColumn(connection, "listing_images", "alt_text", "`alt_text` VARCHAR(500) NULL AFTER `display_title`");
        await ensureColumn(connection, "listing_images", "caption", "`caption` TEXT NULL AFTER `alt_text`");

        await ensureColumn(connection, "users", "avatar_url", "`avatar_url` VARCHAR(1000) NULL AFTER `bio`");
        await ensureColumn(connection, "users", "avatar_key", "`avatar_key` VARCHAR(500) NULL AFTER `avatar_url`");

        console.info("R2 image metadata schema completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
