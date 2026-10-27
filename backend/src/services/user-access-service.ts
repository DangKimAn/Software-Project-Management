import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../common/api-error";
import sequelize from "../config/database";
import { UserRole } from "../models/user";

export type BasicUser = {
    userId: number;
    email: string;
    fullName: string;
    status: string;
};

export const getBasicUserById = async (userId: number, transaction?: Transaction) => {
    const rows = await sequelize.query<BasicUser>(
        `
        SELECT
            user_id AS userId,
            email,
            full_name AS fullName,
            status
        FROM users
        WHERE user_id = ?
        LIMIT 1
        `,
        {
            replacements: [userId],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    return rows[0] ?? null;
};

export const assertBasicUserExists = async (userId: number, transaction?: Transaction) => {
    const user = await getBasicUserById(userId, transaction);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    return user;
};

export const userHasRole = async (userId: number, role: UserRole, transaction?: Transaction) => {
    const rows = await sequelize.query<{ count: number }>(
        `
        SELECT COUNT(*) AS count
        FROM user_role ur
        INNER JOIN roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = ?
          AND r.code = ?
        `,
        {
            replacements: [userId, role],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    return Number(rows[0]?.count ?? 0) > 0;
};

export const assertUserHasRole = async (userId: number, role: UserRole, transaction?: Transaction) => {
    await assertBasicUserExists(userId, transaction);

    if (!(await userHasRole(userId, role, transaction))) {
        throw new ApiError(422, `User must have role ${role}`);
    }
};
