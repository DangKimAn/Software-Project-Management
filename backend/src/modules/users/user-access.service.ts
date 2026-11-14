// CONFLICT-RESOLVED: Di chuyển kiểm tra quyền truy cập người dùng từ `src/services/user-access-service.ts` về `src/modules/users/user-access.service.ts`.
import { QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { UserRole } from "../../models/user";

export type BasicUser = {
    userId: number;
    email: string;
    fullName: string;
    status: string;
};

/**
 * Truy vấn nhanh thông tin định danh và trạng thái cơ bản của người dùng theo khóa chính `user_id`
 * bằng câu lệnh SQL tham số hóa gọn nhẹ (hỗ trợ chạy trong `transaction`).
 */
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

/**
 * Kiểm tra ràng buộc tồn tại người dùng theo `userId`; ném `ApiError(404)` nếu không tìm thấy bản ghi.
 */
export const assertBasicUserExists = async (userId: number, transaction?: Transaction) => {
    const user = await getBasicUserById(userId, transaction);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    return user;
};

/**
 * Giải thuật kiểm tra phân quyền vai trò trực tiếp trên bảng quan hệ `user_role` JOIN `roles`:
 * - Đếm số dòng khớp `(user_id, r.code)` để xác minh quyền thực tế mới nhất trong cơ sở dữ liệu.
 */
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

/**
 * Ràng buộc kiểm tra người dùng vừa tồn tại vừa sở hữu vai trò yêu cầu (`role`),
 * ném `ApiError(404)` nếu thiếu người dùng hoặc `ApiError(422)` nếu chưa được cấp vai trò tương ứng.
 */
export const assertUserHasRole = async (userId: number, role: UserRole, transaction?: Transaction) => {
    await assertBasicUserExists(userId, transaction);

    if (!(await userHasRole(userId, role, transaction))) {
        throw new ApiError(422, `User must have role ${role}`);
    }
};
