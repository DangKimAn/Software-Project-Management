import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import User, { UserDocument, UserRole, UserStatus, userRoleValues } from "../../models/user";
import UserProfile from "../../models/user-profile";

export { User };

export const findUserById = (userId: string | number) => User.findById(userId);

export const findUserByEmail = (email: string) => User.findOne({ email });

export const findUserByPhone = (phone: string) => User.findOne({ phone });

export const findUserByUsername = (username: string) => User.findOne({ username });

export const getUserRoles = async (userId: string | number, transaction?: Transaction): Promise<UserRole[]> => {
    const rows = await sequelize.query<{ code: string }>(
        `
        SELECT r.code
        FROM user_role ur
        INNER JOIN roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = ?
        ORDER BY FIELD(r.code, 'admin', 'moderator', 'host', 'guest')
        `,
        {
            replacements: [Number(userId)],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    const roles = rows
        .map((row) => row.code)
        .filter((role): role is UserRole => (userRoleValues as readonly string[]).includes(role));

    return roles.length > 0 ? roles : ["guest"];
};

const ensureRoleId = async (role: UserRole, transaction?: Transaction) => {
    await sequelize.query(
        `
        INSERT INTO roles (code, name, created_at, updated_at)
        VALUES (?, ?, NOW(), NOW())
        ON DUPLICATE KEY UPDATE name = VALUES(name), updated_at = NOW()
        `,
        {
            replacements: [role, role.charAt(0).toUpperCase() + role.slice(1)],
            transaction,
        },
    );

    const rows = await sequelize.query<{ roleId: number }>(
        `
        SELECT role_id AS roleId
        FROM roles
        WHERE code = ?
        LIMIT 1
        `,
        {
            replacements: [role],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    const roleId = rows[0]?.roleId;

    if (!roleId) {
        throw new ApiError(500, "Unable to resolve user role");
    }

    return Number(roleId);
};

export const replaceUserRoles = async (
    userId: string | number,
    roles: UserRole[],
    transaction?: Transaction,
) => {
    const uniqueRoles = [...new Set(roles)];

    if (uniqueRoles.length === 0) {
        throw new ApiError(422, "User must have at least one role");
    }

    await sequelize.query("DELETE FROM user_role WHERE user_id = ?", {
        replacements: [Number(userId)],
        transaction,
    });

    for (const role of uniqueRoles) {
        const roleId = await ensureRoleId(role, transaction);

        await sequelize.query(
            `
            INSERT INTO user_role (user_id, role_id, assigned_at)
            VALUES (?, ?, NOW())
            `,
            {
                replacements: [Number(userId), roleId],
                transaction,
            },
        );
    }
};

export const countActiveUsersWithRole = async (role: UserRole, transaction?: Transaction) => {
    const rows = await sequelize.query<{ count: number }>(
        `
        SELECT COUNT(DISTINCT u.user_id) AS count
        FROM users u
        INNER JOIN user_role ur ON ur.user_id = u.user_id
        INNER JOIN roles r ON r.role_id = ur.role_id
        WHERE r.code = ?
          AND u.status = 'active'
        `,
        {
            replacements: [role],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    return Number(rows[0]?.count ?? 0);
};

export type UserUpdateAttributes = Partial<{
    username: string | null;
    email: string;
    phone: string | null;
    fullName: string;
    dateOfBirth: Date | null;
    bio: string | null;
    avatarUrl: string | null;
    avatarKey: string | null;
    status: UserStatus;
}>;

export const saveUserUpdates = async (
    user: UserDocument,
    values: UserUpdateAttributes,
    transaction?: Transaction,
) => {
    Object.assign(user, values);
    await user.save({ transaction });
    return user;
};

export type UserProfileUpdateAttributes = Partial<{
    location: string | null;
    job: string | null;
    dreamDestination: string | null;
    school: string | null;
    languages: string[] | null;
}>;

export const findUserProfileByUserId = (
    userId: string | number,
    transaction?: Transaction,
    includeDeleted = false,
) =>
    UserProfile.findOne({
        where: {
            userId: Number(userId),
            ...(includeDeleted ? {} : { deletedAt: null }),
        },
        transaction,
    });

export const saveUserProfileUpdates = async (
    userId: string | number,
    values: UserProfileUpdateAttributes,
    transaction?: Transaction,
) => {
    const profile = await findUserProfileByUserId(userId, transaction, true);

    if (profile) {
        Object.assign(profile, values, { deletedAt: null });
        await profile.save({ transaction });
        return profile;
    }

    return UserProfile.create(
        {
            userId: Number(userId),
            ...values,
        },
        { transaction },
    );
};

export const withTransaction = <T>(callback: (transaction: Transaction) => Promise<T>) =>
    sequelize.transaction(callback);
export type AdminListUsersFilter = {
    search?: string;
    role?: UserRole;
    status?: UserStatus;
    page: number;
    limit: number;
};

export const listUsersForAdmin = async ({ search, role, status, page, limit }: AdminListUsersFilter) => {
    const replacements: Array<string | number> = [];
    const conditions = ["u.deleted_at IS NULL"];

    if (status) {
        conditions.push("u.status = ?");
        replacements.push(status);
    }

    if (search) {
        conditions.push("(u.email LIKE ? OR u.phone LIKE ? OR u.full_name LIKE ? OR u.username LIKE ?)");
        const like = `%${search}%`;
        replacements.push(like, like, like, like);
    }

    if (role) {
        conditions.push(
            "EXISTS (SELECT 1 FROM user_role ur2 INNER JOIN roles r2 ON r2.role_id = ur2.role_id WHERE ur2.user_id = u.user_id AND r2.code = ?)",
        );
        replacements.push(role);
    }

    const whereSql = conditions.join(" AND ");
    const offset = (page - 1) * limit;

    const [rows, countRows] = await Promise.all([
        sequelize.query<{
            userId: number;
            username: string | null;
            email: string;
            phone: string | null;
            fullName: string;
            status: UserStatus;
            isEmailVerified: number | boolean;
            isPhoneVerified: number | boolean;
            isHostVerified: number | boolean;
            hostApplicationStatus: "pending" | "approved" | "rejected" | null;
            createdAt: Date;
            updatedAt: Date;
            roles: string | null;
        }>(
            `
            SELECT
                u.user_id AS userId,
                u.username,
                u.email,
                u.phone,
                u.full_name AS fullName,
                u.status,
                u.is_email_verified AS isEmailVerified,
                u.is_phone_verified AS isPhoneVerified,
                u.is_host_verified AS isHostVerified,
                u.host_application_status AS hostApplicationStatus,
                u.created_at AS createdAt,
                u.updated_at AS updatedAt,
                GROUP_CONCAT(DISTINCT r.code ORDER BY FIELD(r.code, 'admin', 'moderator', 'host', 'guest')) AS roles
            FROM users u
            LEFT JOIN user_role ur ON ur.user_id = u.user_id
            LEFT JOIN roles r ON r.role_id = ur.role_id
            WHERE ${whereSql}
            GROUP BY u.user_id
            ORDER BY u.created_at DESC, u.user_id DESC
            LIMIT ? OFFSET ?
            `,
            {
                replacements: [...replacements, limit, offset],
                type: QueryTypes.SELECT,
            },
        ),
        sequelize.query<{ totalItems: number }>(
            `
            SELECT COUNT(DISTINCT u.user_id) AS totalItems
            FROM users u
            WHERE ${whereSql}
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
    ]);

    const totalItems = Number(countRows[0]?.totalItems ?? 0);

    return {
        items: rows.map((row) => {
            const roles = row.roles
                ? row.roles
                    .split(",")
                    .filter((item): item is UserRole => (userRoleValues as readonly string[]).includes(item))
                : ["guest"];

            return {
                id: String(row.userId),
                userId: String(row.userId),
                username: row.username,
                email: row.email,
                phone: row.phone,
                name: row.fullName,
                fullName: row.fullName,
                status: row.status,
                roles,
                role: roles[0] ?? "guest",
                isEmailVerified: Boolean(row.isEmailVerified),
                isPhoneVerified: Boolean(row.isPhoneVerified),
                isHostVerified: Boolean(row.isHostVerified),
                hostApplicationStatus: row.hostApplicationStatus,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
            };
        }),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};
