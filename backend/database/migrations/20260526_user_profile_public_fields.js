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

const run = async () => {
    const connection = await createConnection();

    try {
        await ensureColumn(connection, "user_profiles", "location", "`location` VARCHAR(255) NULL AFTER `gender`");
        await ensureColumn(connection, "user_profiles", "job", "`job` VARCHAR(255) NULL AFTER `location`");
        await ensureColumn(
            connection,
            "user_profiles",
            "dream_destination",
            "`dream_destination` VARCHAR(255) NULL AFTER `job`",
        );
        await ensureColumn(connection, "user_profiles", "school", "`school` VARCHAR(255) NULL AFTER `dream_destination`");
        await ensureColumn(connection, "user_profiles", "languages_json", "`languages_json` JSON NULL AFTER `school`");
    } finally {
        await connection.end();
    }
};

run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
