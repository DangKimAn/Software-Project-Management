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

async function columnExists(connection, tableName, columnName) {
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
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        if (!(await tableExists(connection, "bookings"))) {
            console.log("Skipped booking payment expiration cleanup: bookings table missing");
            return;
        }

        await connection.beginTransaction();

        await connection.query(`
            ALTER TABLE bookings
            MODIFY COLUMN status ENUM(
                'pending',
                'pending_host',
                'pending_payment',
                'payment_expired',
                'confirmed',
                'paid',
                'checked_in',
                'checked_out',
                'completed',
                'cancelled',
                'cancelled_by_guest',
                'cancelled_by_host',
                'cancelled_by_admin',
                'rejected',
                'expired'
            ) NOT NULL DEFAULT 'pending_payment'
        `);

        const hasLockedUntil = await columnExists(connection, "bookings", "locked_until");
        const hasCancellationReason = await columnExists(connection, "bookings", "cancellation_reason");
        const hasCancelledAt = await columnExists(connection, "bookings", "cancelled_at");
        const hasCancelledByUserId = await columnExists(connection, "bookings", "cancelled_by_user_id");
        const hasVersion = await columnExists(connection, "bookings", "version");

        const updates = [
            "status = 'payment_expired'",
            hasCancellationReason ? "cancellation_reason = 'PAYMENT_EXPIRED'" : null,
            hasCancelledAt
                ? hasLockedUntil
                    ? "cancelled_at = COALESCE(cancelled_at, locked_until, updated_at, UTC_TIMESTAMP())"
                    : "cancelled_at = COALESCE(cancelled_at, updated_at, UTC_TIMESTAMP())"
                : null,
            hasCancelledByUserId ? "cancelled_by_user_id = NULL" : null,
            hasLockedUntil ? "locked_until = NULL" : null,
            hasVersion ? "version = version + 1" : null,
        ].filter(Boolean);

        const expirationWhere = hasLockedUntil
            ? `
                status = 'expired'
                OR (
                    status = 'pending_payment'
                    AND (
                        locked_until <= UTC_TIMESTAMP()
                        OR (locked_until IS NULL AND created_at <= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 15 MINUTE))
                    )
                )
            `
            : `
                status = 'expired'
                OR (
                    status = 'pending_payment'
                    AND created_at <= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 15 MINUTE)
                )
            `;

        await connection.query(
            `
            UPDATE bookings
            SET ${updates.join(", ")}
            WHERE ${expirationWhere}
            `,
        );

        if (await tableExists(connection, "payments")) {
            const hasPaymentExpiredAt = await columnExists(connection, "payments", "expired_at");
            const hasPaymentFailedAt = await columnExists(connection, "payments", "failed_at");
            const paymentUpdates = [
                "p.status = 'expired'",
                hasPaymentExpiredAt ? "p.expired_at = COALESCE(p.expired_at, UTC_TIMESTAMP())" : null,
                hasPaymentFailedAt ? "p.failed_at = COALESCE(p.failed_at, UTC_TIMESTAMP())" : null,
            ].filter(Boolean);

            await connection.query(
                `
                UPDATE payments p
                INNER JOIN bookings b ON b.booking_id = p.booking_id
                SET ${paymentUpdates.join(", ")}
                WHERE b.status = 'payment_expired'
                  ${hasCancellationReason ? "AND b.cancellation_reason = 'PAYMENT_EXPIRED'" : ""}
                  AND p.status = 'pending'
                `,
            );
        }

        if (await tableExists(connection, "booking_date_locks")) {
            await connection.query(
                `
                UPDATE booking_date_locks l
                INNER JOIN bookings b ON b.booking_id = l.booking_id
                SET l.status = 'released',
                    l.released_at = COALESCE(l.released_at, UTC_TIMESTAMP())
                WHERE b.status = 'payment_expired'
                  ${hasCancellationReason ? "AND b.cancellation_reason = 'PAYMENT_EXPIRED'" : ""}
                  AND l.released_at IS NULL
                `,
            );
        }

        await connection.commit();
        console.log("20260528_booking_payment_expired_status_cleanup migrated");
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
