// CONFLICT-RESOLVED: Chuyển tiện ích dò lược đồ không trạng thái từ `src/services/schema-introspection-service.ts` về `src/common/db-schema.ts`.
import { QueryTypes, type Transaction } from "sequelize";

import sequelize from "../config/database";

/**
 * Giải thuật kiểm tra sự tồn tại thực tế của một cột trong bảng MySQL hiện hành qua `information_schema.columns`:
 * - Dùng truy vấn tham số hóa (`?`) gắn với `DATABASE()` hiện tại để hỗ trợ tương thích lược đồ động an toàn chống SQL Injection.
 */
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

/**
 * Giải thuật truy vấn hàng loạt tập hợp các cột đang tồn tại thực tế trên bảng MySQL (`information_schema.columns`):
 * - Trả về `Set<string>` để tra cứu O(1) khi xây dựng câu lệnh SQL thích ứng với các phiên bản migration khác nhau.
 */
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

/**
 * Truy vấn kiểu dữ liệu vật lý đầy đủ (`column_type`, ví dụ `enum(...)`, `varchar(255)`) của một cột trong bảng MySQL hiện hành.
 */
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
