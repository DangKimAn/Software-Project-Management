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

async function tableExists(connection, tableName) {
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
}

async function indexExists(connection, tableName, indexName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND INDEX_NAME = ?
        `,
        [tableName, indexName],
    );

    return Number(rows[0].count) > 0;
}

async function assertNoDuplicateCouponBookingUserRedemptions(connection) {
    const [rows] = await connection.query(`
        SELECT coupon_id, user_id, booking_id, COUNT(*) AS count
        FROM coupon_redemptions
        GROUP BY coupon_id, user_id, booking_id
        HAVING COUNT(*) > 1
        LIMIT 1
    `);

    if (rows.length > 0) {
        throw new Error(
            "Cannot add uq_coupon_redemptions_coupon_user_booking: duplicate coupon/user/booking redemptions exist.",
        );
    }
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        if (
            (await tableExists(connection, "coupon_redemptions")) &&
            !(await indexExists(connection, "coupon_redemptions", "uq_coupon_redemptions_coupon_user_booking"))
        ) {
            await assertNoDuplicateCouponBookingUserRedemptions(connection);
            await connection.query(
                "CREATE UNIQUE INDEX `uq_coupon_redemptions_coupon_user_booking` ON `coupon_redemptions` (`coupon_id`, `user_id`, `booking_id`)",
            );
        }

        await connection.commit();
        console.log("20260601_coupon_redemption_booking_user_unique migrated");
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
