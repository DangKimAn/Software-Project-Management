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

const newBookingStatuses = [
    "pending_payment",
    "payment_expired",
    "paid",
    "confirmed",
    "checked_in",
    "checked_out",
    "completed",
    "cancelled_by_guest",
    "cancelled_by_host",
    "cancelled_by_admin",
    "rejected",
];

const transitionBookingStatuses = [
    "pending",
    "pending_host",
    ...newBookingStatuses,
    "cancelled",
    "expired",
];

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

const enumSql = (values) => values.map((value) => `'${value}'`).join(",");

async function modifyBookingStatusEnum(connection, values) {
    await connection.query(`
        ALTER TABLE bookings
        MODIFY COLUMN status ENUM(${enumSql(values)}) NOT NULL DEFAULT 'pending_payment'
    `);
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        if (!(await tableExists(connection, "bookings"))) {
            console.log("Skipped booking state machine status migration: bookings table missing");
            return;
        }

        await connection.beginTransaction();

        await modifyBookingStatusEnum(connection, transitionBookingStatuses);

        const hasPaidAt = await columnExists(connection, "bookings", "paid_at");
        const hasCancelledByUserId = await columnExists(connection, "bookings", "cancelled_by_user_id");
        const hasCancellationReason = await columnExists(connection, "bookings", "cancellation_reason");
        const hasCancelledAt = await columnExists(connection, "bookings", "cancelled_at");
        const hasLockedUntil = await columnExists(connection, "bookings", "locked_until");
        const hasVersion = await columnExists(connection, "bookings", "version");

        await connection.query(`
            CREATE TEMPORARY TABLE tmp_booking_status_migration (
                booking_id INT UNSIGNED NOT NULL PRIMARY KEY,
                old_status VARCHAR(32) NOT NULL,
                new_status VARCHAR(32) NOT NULL
            )
        `);

        const paidExistsSql = `
            EXISTS (
                SELECT 1
                FROM payments p
                WHERE p.booking_id = b.booking_id
                  AND p.status = 'paid'
                LIMIT 1
            )
        `;

        const paidCondition = hasPaidAt
            ? `(b.paid_at IS NOT NULL OR ${paidExistsSql})`
            : paidExistsSql;

        const cancelledByGuestCondition = hasCancelledByUserId
            ? "b.cancelled_by_user_id = b.guest_user_id"
            : "FALSE";
        const cancelledByHostCondition = hasCancelledByUserId
            ? "b.cancelled_by_user_id = b.host_user_id"
            : "FALSE";
        const reasonSql = hasCancellationReason ? "b.cancellation_reason" : "NULL";

        await connection.query(`
            INSERT INTO tmp_booking_status_migration (booking_id, old_status, new_status)
            SELECT
                b.booking_id,
                b.status,
                CASE
                    WHEN b.status = 'expired' THEN 'payment_expired'
                    WHEN b.status = 'cancelled' AND ${reasonSql} = 'PAYMENT_EXPIRED' THEN 'payment_expired'
                    WHEN b.status = 'cancelled' AND ${reasonSql} = 'ADMIN_CANCELLED' THEN 'cancelled_by_admin'
                    WHEN b.status = 'cancelled' AND ${reasonSql} = 'HOST_REJECTED' THEN 'rejected'
                    WHEN b.status = 'cancelled' AND ${cancelledByHostCondition} THEN 'cancelled_by_host'
                    WHEN b.status = 'cancelled' AND ${cancelledByGuestCondition} THEN 'cancelled_by_guest'
                    WHEN b.status = 'cancelled' THEN 'cancelled_by_guest'
                    WHEN b.status IN ('pending', 'pending_host') AND ${paidCondition} THEN 'paid'
                    WHEN b.status IN ('pending', 'pending_host') THEN 'pending_payment'
                    ELSE b.status
                END AS new_status
            FROM bookings b
            WHERE b.status IN ('pending','pending_host','cancelled','expired')
        `);

        const updateParts = [
            "b.status = m.new_status",
            hasCancellationReason
                ? "b.cancellation_reason = CASE WHEN m.new_status = 'payment_expired' THEN COALESCE(b.cancellation_reason, 'PAYMENT_EXPIRED') ELSE b.cancellation_reason END"
                : null,
            hasCancelledAt
                ? "b.cancelled_at = CASE WHEN m.new_status IN ('payment_expired','cancelled_by_guest','cancelled_by_host','cancelled_by_admin','rejected') THEN COALESCE(b.cancelled_at, UTC_TIMESTAMP()) ELSE b.cancelled_at END"
                : null,
            hasLockedUntil
                ? "b.locked_until = CASE WHEN m.new_status IN ('payment_expired','cancelled_by_guest','cancelled_by_host','cancelled_by_admin','rejected') THEN NULL ELSE b.locked_until END"
                : null,
            hasVersion ? "b.version = b.version + 1" : null,
        ].filter(Boolean);

        await connection.query(`
            UPDATE bookings b
            INNER JOIN tmp_booking_status_migration m ON m.booking_id = b.booking_id
            SET ${updateParts.join(", ")}
            WHERE m.old_status <> m.new_status
        `);

        if (await tableExists(connection, "booking_status_history")) {
            await connection.query(`
                INSERT INTO booking_status_history (
                    booking_id,
                    old_status,
                    new_status,
                    changed_by_user_id,
                    reason,
                    metadata_json,
                    created_at
                )
                SELECT
                    m.booking_id,
                    m.old_status,
                    m.new_status,
                    NULL,
                    'booking_state_machine_status_migration',
                    JSON_OBJECT('migration', '20260531_booking_state_machine_statuses'),
                    UTC_TIMESTAMP()
                FROM tmp_booking_status_migration m
                WHERE m.old_status <> m.new_status
            `);
        }

        if (await tableExists(connection, "payments")) {
            const hasPaymentExpiredAt = await columnExists(connection, "payments", "expired_at");
            const hasPaymentFailedAt = await columnExists(connection, "payments", "failed_at");
            const paymentUpdates = [
                "p.status = 'expired'",
                hasPaymentExpiredAt ? "p.expired_at = COALESCE(p.expired_at, UTC_TIMESTAMP())" : null,
                hasPaymentFailedAt ? "p.failed_at = COALESCE(p.failed_at, UTC_TIMESTAMP())" : null,
            ].filter(Boolean);

            await connection.query(`
                UPDATE payments p
                INNER JOIN bookings b ON b.booking_id = p.booking_id
                SET ${paymentUpdates.join(", ")}
                WHERE b.status = 'payment_expired'
                  AND p.status = 'pending'
            `);
        }

        if (await tableExists(connection, "booking_date_locks")) {
            await connection.query(`
                UPDATE booking_date_locks l
                INNER JOIN bookings b ON b.booking_id = l.booking_id
                SET l.status = 'released',
                    l.released_at = COALESCE(l.released_at, UTC_TIMESTAMP())
                WHERE b.status IN ('payment_expired','cancelled_by_guest','cancelled_by_host','cancelled_by_admin','rejected')
                  AND l.released_at IS NULL
            `);
        }

        await modifyBookingStatusEnum(connection, newBookingStatuses);

        await connection.commit();
        console.log("20260531_booking_state_machine_statuses migrated");
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
