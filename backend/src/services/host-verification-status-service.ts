import { QueryTypes, type Transaction } from "sequelize";

import sequelize from "../config/database";
import HostVerification from "../models/host-verification";
import { getExistingColumns } from "./schema-introspection-service";

export const isHostVerifiedForPublishing = async (hostId: number, transaction?: Transaction) => {
    const columns = await getExistingColumns(
        "users",
        ["is_host_verified", "host_verified", "is_verified"],
        transaction,
    );

    if (columns.size > 0) {
        const selectedColumns = Array.from(columns)
            .map((columnName) => `${columnName} AS ${columnName}`)
            .join(", ");
        const rows = await sequelize.query<Record<string, number | boolean>>(
            `
            SELECT ${selectedColumns}
            FROM users
            WHERE user_id = ?
            LIMIT 1
            `,
            {
                replacements: [hostId],
                type: QueryTypes.SELECT,
                transaction,
            },
        );

        if (rows[0] && Object.values(rows[0]).some(Boolean)) {
            return true;
        }
    }

    const approvedVerification = await HostVerification.findOne({
        where: {
            hostId,
            status: "approved",
        },
        transaction,
    });

    return Boolean(approvedVerification);
};
