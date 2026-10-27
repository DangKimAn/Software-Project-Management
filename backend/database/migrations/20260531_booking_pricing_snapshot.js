require("dotenv/config");
const mysql = require("mysql2/promise");

const dbUser = process.env.MYSQLUSER || process.env.MYSQL_USER || "booking_app";

if (
    dbUser.toLowerCase() === "root" &&
    process.env.ALLOW_DATABASE_ROOT_USER !== "true"
) {
    throw new Error("Refusing to run migration with MySQL root user.");
}

const fs = require("node:fs");
const path = require("node:path");

const ssl =
    process.env.MYSQL_SSL === "true"
        ? {
              rejectUnauthorized: true,
              ...(process.env.MYSQL_SSL_CA && fs.existsSync(path.resolve(process.cwd(), process.env.MYSQL_SSL_CA))
                  ? { ca: fs.readFileSync(path.resolve(process.cwd(), process.env.MYSQL_SSL_CA), "utf8") }
                  : {}),
          }
        : undefined;

const config = {
    host: process.env.MYSQLHOST || process.env.MYSQL_HOST || "localhost",
    port: Number(process.env.MYSQLPORT || process.env.MYSQL_PORT || 3306),
    user: dbUser,
    password: process.env.MYSQLPASSWORD || process.env.MYSQL_PASSWORD || "",
    database: process.env.MYSQLDATABASE || process.env.MYSQL_DATABASE || "booking_room",
    ssl,
    multipleStatements: false,
};

const tableExists = async (connection, tableName) => {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
        `,
        [tableName],
    );

    return Number(rows[0].count) > 0;
};

const columnExists = async (connection, tableName, columnName) => {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
        `,
        [tableName, columnName],
    );

    return Number(rows[0].count) > 0;
};

const addColumnIfMissing = async (connection, tableName, columnName, definition) => {
    if (!(await tableExists(connection, tableName))) {
        console.log(`Skipped ${tableName}.${columnName}: table missing`);
        return;
    }

    if (await columnExists(connection, tableName, columnName)) {
        return;
    }

    await connection.query(`ALTER TABLE \`${tableName}\` ADD COLUMN ${definition}`);
};

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        await addColumnIfMissing(
            connection,
            "bookings",
            "total_nights",
            "`total_nights` INT UNSIGNED NULL AFTER `nights`",
        );
        await addColumnIfMissing(
            connection,
            "bookings",
            "subtotal_amount",
            "`subtotal_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `coupon_id`",
        );
        await addColumnIfMissing(
            connection,
            "bookings",
            "cleaning_fee_amount",
            "`cleaning_fee_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `subtotal_amount`",
        );
        await addColumnIfMissing(
            connection,
            "bookings",
            "service_fee_amount",
            "`service_fee_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `cleaning_fee_amount`",
        );
        await addColumnIfMissing(
            connection,
            "bookings",
            "discount_amount",
            "`discount_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `service_fee_amount`",
        );
        await addColumnIfMissing(
            connection,
            "bookings",
            "total_amount",
            "`total_amount` DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER `discount_amount`",
        );
        await addColumnIfMissing(
            connection,
            "bookings",
            "price_breakdown_json",
            "`price_breakdown_json` JSON NULL AFTER `total_amount`",
        );
        await addColumnIfMissing(
            connection,
            "listings",
            "included_guests",
            "`included_guests` INT UNSIGNED NULL AFTER `max_guests`",
        );
        await addColumnIfMissing(
            connection,
            "listings",
            "extra_guest_fee",
            "`extra_guest_fee` DECIMAL(15,2) NULL AFTER `service_fee_pct`",
        );

        if (
            (await tableExists(connection, "bookings")) &&
            (await columnExists(connection, "bookings", "total_nights")) &&
            (await columnExists(connection, "bookings", "nights"))
        ) {
            await connection.query("UPDATE `bookings` SET `total_nights` = `nights` WHERE `total_nights` IS NULL");
        }

        await connection.commit();
        console.log("20260531_booking_pricing_snapshot migrated");
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
