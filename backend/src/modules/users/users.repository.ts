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
        ORDER BY FIELD(r.code, 'admin', 'host', 'guest')
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

export const syncUserHostDemotion = async (
    userId: string | number,
    adminId: string | number,
    transaction?: Transaction,
) => {
    await sequelize.query(
        "UPDATE users SET is_host_verified = 0, host_application_status = 'rejected' WHERE user_id = ?",
        {
            replacements: [Number(userId)],
            transaction,
        },
    );
    await sequelize.query(
        "UPDATE host_applications SET status = 'rejected', rejection_reason = ?, reviewed_at = NOW(), reviewed_by_user_id = ? WHERE user_id = ? AND status = 'approved'",
        {
            replacements: [
                "Quyền Host đã được quản trị viên điều chỉnh về Guest.",
                Number(adminId),
                Number(userId),
            ],
            transaction,
        },
    );
};

export const syncUserHostPromotion = async (
    userId: string | number,
    transaction?: Transaction,
) => {
    await sequelize.query(
        "UPDATE users SET is_host_verified = 1, host_application_status = 'approved' WHERE user_id = ?",
        {
            replacements: [Number(userId)],
            transaction,
        },
    );
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
    isPhoneVerified: boolean;
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

const adminUserRoleOrder: Record<string, number> = {
    guest: 0,
    host: 1,
    admin: 2,
};

const adminVietnameseNameCollator = new Intl.Collator("vi", {
    sensitivity: "accent",
    numeric: true,
});

const resolveAdminItemPrimaryRole = (item: {
    role?: string | null;
    roles?: readonly string[] | null;
}): string => {
    const directRole = typeof item.role === "string" ? item.role.trim().toLowerCase() : "";
    if (directRole) {
        return directRole;
    }

    if (Array.isArray(item.roles) && item.roles.length > 0) {
        const normalized = item.roles.map((r) => String(r).trim().toLowerCase()).filter(Boolean);
        if (normalized.includes("admin")) return "admin";
        if (normalized.includes("host")) return "host";
        if (normalized.includes("guest")) return "guest";
        if (normalized.length > 0) return normalized[0];
    }

    return "guest";
};

const resolveAdminItemDisplayName = (item: {
    fullName?: string | null;
    name?: string | null;
    username?: string | null;
    email?: string | null;
    userId?: string | number | null;
    id?: string | number | null;
}): string => {
    for (const candidate of [item.fullName, item.name, item.username]) {
        const trimmed = typeof candidate === "string" ? candidate.trim() : "";
        if (trimmed) {
            return trimmed;
        }
    }

    const fallbackId = String(item.userId ?? item.id ?? "").trim();
    return fallbackId ? `User #${fallbackId}` : "";
};

export const sortAdminUserItems = <
    T extends {
        role?: string | null;
        roles?: readonly string[] | null;
        fullName?: string | null;
        name?: string | null;
        username?: string | null;
        email?: string | null;
        userId?: string | number | null;
        id?: string | number | null;
    },
>(
    items: readonly T[],
): T[] => {
    return [...items].sort((left, right) => {
        const leftRoleRank = adminUserRoleOrder[resolveAdminItemPrimaryRole(left)] ?? 3;
        const rightRoleRank = adminUserRoleOrder[resolveAdminItemPrimaryRole(right)] ?? 3;
        if (leftRoleRank !== rightRoleRank) {
            return leftRoleRank - rightRoleRank;
        }

        const leftName = resolveAdminItemDisplayName(left).replace(/\s+/g, " ");
        const rightName = resolveAdminItemDisplayName(right).replace(/\s+/g, " ");
        const nameCmp = adminVietnameseNameCollator.compare(leftName, rightName);
        if (nameCmp !== 0) {
            return nameCmp;
        }

        const leftEmail = String(left.email ?? "").trim().toLowerCase();
        const rightEmail = String(right.email ?? "").trim().toLowerCase();
        if (leftEmail !== rightEmail) {
            return leftEmail < rightEmail ? -1 : 1;
        }

        const leftIdRaw = String(left.userId ?? left.id ?? "").trim();
        const rightIdRaw = String(right.userId ?? right.id ?? "").trim();
        const leftIdNum = Number(leftIdRaw);
        const rightIdNum = Number(rightIdRaw);
        if (Number.isFinite(leftIdNum) && Number.isFinite(rightIdNum) && leftIdRaw !== "" && rightIdRaw !== "") {
            return leftIdNum - rightIdNum;
        }

        return leftIdRaw.localeCompare(rightIdRaw);
    });
};

export const listUsersForAdmin = async ({ search, role, status, page, limit }: AdminListUsersFilter) => {
    const replacements: Array<string | number> = [];
    const conditions = ["u.deleted_at IS NULL"];

    if (status) {
        conditions.push("u.status = ?");
        replacements.push(status);
    }

    if (search) {
        const escapedSearch = search.replace(/[\\%_]/g, "\\$&");
        conditions.push(
            "(u.email LIKE ? ESCAPE '\\\\' OR u.phone LIKE ? ESCAPE '\\\\' OR u.full_name LIKE ? ESCAPE '\\\\' OR u.username LIKE ? ESCAPE '\\\\')",
        );
        const like = `%${escapedSearch}%`;
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
            avatarUrl: string | null;
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
                u.avatar_url AS avatarUrl,
                u.status,
                u.is_email_verified AS isEmailVerified,
                u.is_phone_verified AS isPhoneVerified,
                u.is_host_verified AS isHostVerified,
                u.host_application_status AS hostApplicationStatus,
                u.created_at AS createdAt,
                u.updated_at AS updatedAt,
                GROUP_CONCAT(DISTINCT r.code ORDER BY FIELD(r.code, 'admin', 'host', 'guest')) AS roles
            FROM users u
            LEFT JOIN user_role ur ON ur.user_id = u.user_id
            LEFT JOIN roles r ON r.role_id = ur.role_id
            WHERE ${whereSql}
            GROUP BY u.user_id
            ORDER BY
                COALESCE(
                    MAX(
                        CASE r.code
                            WHEN 'admin' THEN 2
                            WHEN 'host' THEN 1
                            WHEN 'guest' THEN 0
                            ELSE 0
                        END
                    ),
                    0
                ) ASC,
                CONVERT(
                    TRIM(COALESCE(NULLIF(TRIM(u.full_name), ''), u.username, u.email, ''))
                    USING utf8mb4
                ) COLLATE utf8mb4_unicode_ci ASC,
                LOWER(u.email) ASC,
                u.user_id ASC
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

    const mappedItems = rows.map((row) => {
        const parsedRoles = row.roles
            ? row.roles
                .split(",")
                .filter((item): item is UserRole => (userRoleValues as readonly string[]).includes(item))
            : [];
        const roles: UserRole[] = parsedRoles.length > 0 ? parsedRoles : ["guest"];

        return {
            id: String(row.userId),
            userId: String(row.userId),
            username: row.username,
            email: row.email,
            phone: row.phone,
            name: row.fullName,
            fullName: row.fullName,
            avatarUrl: row.avatarUrl ?? null,
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
    });

    return {
        items: sortAdminUserItems(mappedItems),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};
