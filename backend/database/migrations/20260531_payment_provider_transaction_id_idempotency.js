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

async function assertNoDuplicatePaymentProviderRefs(connection) {
    const [rows] = await connection.query(`
        SELECT provider_txn_ref, COUNT(*) AS count
        FROM payments
        WHERE provider_txn_ref IS NOT NULL
          AND provider_txn_ref <> ''
        GROUP BY provider_txn_ref
        HAVING COUNT(*) > 1
        LIMIT 1
    `);

    if (rows.length > 0) {
        throw new Error("Cannot add uq_payments_provider_txn_ref: duplicate payments.provider_txn_ref values exist.");
    }
}

async function assertNoDuplicateProviderTransactionIds(connection) {
    const [rows] = await connection.query(`
        SELECT provider, transaction_type, provider_transaction_no, COUNT(*) AS count
        FROM payment_transactions
        WHERE provider IS NOT NULL
          AND provider <> ''
          AND provider_transaction_no IS NOT NULL
          AND provider_transaction_no <> ''
        GROUP BY provider, transaction_type, provider_transaction_no
        HAVING COUNT(*) > 1
        LIMIT 1
    `);

    if (rows.length > 0) {
        throw new Error(
            "Cannot add uq_payment_transactions_provider_transaction_id: duplicate provider transaction ids exist.",
        );
    }
}

async function addUniqueIndexIfMissing(connection, tableName, indexName, ddl) {
    if (await indexExists(connection, tableName, indexName)) {
        return;
    }

    await connection.query(ddl);
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        if (
            (await tableExists(connection, "payments")) &&
            (await columnExists(connection, "payments", "provider_txn_ref"))
        ) {
            await assertNoDuplicatePaymentProviderRefs(connection);
            await addUniqueIndexIfMissing(
                connection,
                "payments",
                "uq_payments_provider_txn_ref",
                "CREATE UNIQUE INDEX `uq_payments_provider_txn_ref` ON `payments` (`provider_txn_ref`)",
            );
        }

        if (
            (await tableExists(connection, "payment_transactions")) &&
            (await columnExists(connection, "payment_transactions", "provider")) &&
            (await columnExists(connection, "payment_transactions", "transaction_type")) &&
            (await columnExists(connection, "payment_transactions", "provider_transaction_no"))
        ) {
            await assertNoDuplicateProviderTransactionIds(connection);
            await addUniqueIndexIfMissing(
                connection,
                "payment_transactions",
                "uq_payment_transactions_provider_transaction_id",
                "CREATE UNIQUE INDEX `uq_payment_transactions_provider_transaction_id` ON `payment_transactions` (`provider`, `transaction_type`, `provider_transaction_no`)",
            );
        }

        await connection.commit();
        console.log("20260531_payment_provider_transaction_id_idempotency migrated");
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
