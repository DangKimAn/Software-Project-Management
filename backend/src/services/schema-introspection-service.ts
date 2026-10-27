import { QueryTypes, type Transaction } from "sequelize";

import sequelize from "../config/database";

export const columnExists = async (
    tableName: string,
    columnName: string,
    transaction?: Transaction,
) => {
    const rows = await sequelize.query<{ count: number }>(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        `,
        {
            replacements: [tableName, columnName],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    return Number(rows[0]?.count ?? 0) > 0;
};

export const getExistingColumns = async (
    tableName: string,
    columnNames: string[],
    transaction?: Transaction,
) => {
    if (columnNames.length === 0) {
        return new Set<string>();
    }

    const rows = await sequelize.query<{ columnName: string }>(
        `
        SELECT column_name AS columnName
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = :tableName
          AND column_name IN (:columnNames)
        `,
        {
            replacements: {
                tableName,
                columnNames,
            },
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    return new Set(rows.map((row) => row.columnName));
};

export const getColumnType = async (
    tableName: string,
    columnName: string,
    transaction?: Transaction,
) => {
    const rows = await sequelize.query<{ columnType: string }>(
        `
        SELECT column_type AS columnType
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        LIMIT 1
        `,
        {
            replacements: [tableName, columnName],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    return rows[0]?.columnType ?? null;
};
