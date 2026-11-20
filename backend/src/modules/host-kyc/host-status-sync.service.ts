// CONFLICT-RESOLVED: Hợp nhất logic đồng bộ trạng thái chủ nhà giữa `host-applications`, `host-onboarding`,
// `verifications` và `services/host-verification-status-service.ts`; đồng thời bảo toàn vai trò `admin` khi cấp quyền `host`.
import { QueryTypes, type Transaction } from "sequelize";

import sequelize from "../../config/database";
import HostApplication, { type HostApplicationStatus } from "../../models/host-application";
import HostVerification from "../../models/host-verification";
import { getColumnType, getExistingColumns } from "../../common/db-schema";
import { ensureUserRole } from "../auth/auth.service";

/**
 * Truy vấn hồ sơ đăng ký Chủ nhà gần nhất của một người dùng theo thứ tự giảm dần `createdAt` và `applicationId` (hỗ trợ gắn kết giao dịch DB).
 */
export const getLatestHostApplication = async (userId: number, transaction?: Transaction) =>
    HostApplication.findOne({
        where: {
            userId,
        },
        order: [
            ["createdAt", "DESC"],
            ["applicationId", "DESC"],
        ],
        transaction,
    });

/**
 * Giải thuật đồng bộ trạng thái đơn đăng ký Chủ nhà lên bảng `users` có dò lược đồ động:
 * Kiểm tra sự tồn tại thực tế của cột `host_application_status` qua `getExistingColumns` trước khi cập nhật bằng truy vấn tham số hóa chống SQL Injection.
 */
export const updateUserHostApplicationStatus = async (
    userId: number,
    status: HostApplicationStatus | null,
    transaction?: Transaction,
) => {
    const columns = await getExistingColumns("users", ["host_application_status"], transaction);

    if (!columns.has("host_application_status")) {
        return;
    }

    await sequelize.query("UPDATE users SET host_application_status = ? WHERE user_id = ?", {
        replacements: [status, userId],
        transaction,
    });
};

/**
 * Giải thuật nâng cấp quyền và cờ xác minh Chủ nhà nguyên tử trên bảng `users`:
 * 1. Đảm bảo bản ghi vai trò `host` trong bảng liên kết RBAC qua `ensureUserRole`.
 * 2. Dò siêu dữ liệu cột thực tế của bảng `users` để bật đồng bộ các cờ `is_host_verified`, `host_verified`,
 *    `is_verified`, `host_application_status = 'approved'` và cập nhật `full_name` nếu có `contactName`.
 * 3. Bảo toàn tuyệt đối đặc quyền `admin` thông qua biểu thức `CASE WHEN role = 'admin' THEN role ELSE 'host' END`.
 */
export const markUserAsApprovedHost = async (
    userId: number,
    transaction?: Transaction,
    contactName?: string | null,
) => {
    await ensureUserRole(userId, "host", transaction);

    const columns = await getExistingColumns(
        "users",
        ["is_host_verified", "host_verified", "is_verified", "host_application_status", "role", "full_name"],
        transaction,
    );
    const assignments: string[] = [];
    const replacements: unknown[] = [];

    if (columns.has("is_host_verified")) {
        assignments.push("is_host_verified = 1");
    }

    if (columns.has("host_verified")) {
        assignments.push("host_verified = 1");
    }

    if (columns.has("is_verified")) {
        assignments.push("is_verified = 1");
    }

    if (columns.has("host_application_status")) {
        assignments.push("host_application_status = ?");
        replacements.push("approved");
    }

    if (columns.has("role")) {
        const roleColumnType = await getColumnType("users", "role", transaction);

        if (!roleColumnType || roleColumnType.includes("'host'")) {
            // CONFLICT-RESOLVED: Giữ biểu thức CASE bảo vệ quyền 'admin' thay vì ghi đè trực tiếp `role = 'host'` như module `verifications` cũ.
            assignments.push("role = CASE WHEN role = 'admin' THEN role ELSE 'host' END");
        }
    }

    if (columns.has("full_name") && contactName && contactName.trim().length > 0) {
        assignments.push("full_name = ?");
        replacements.push(contactName.trim());
    }

    if (assignments.length > 0) {
        await sequelize.query(
            `
            UPDATE users
            SET ${assignments.join(", ")}
            WHERE user_id = ?
            `,
            {
                replacements: [...replacements, userId],
                transaction,
            },
        );
    }
};

/**
 * Giải thuật đồng bộ phê duyệt cho hồ sơ đăng ký Chủ nhà gần nhất của người dùng:
 * Cập nhật trạng thái `approved`, thông tin người duyệt `reviewedByUserId`, xóa lý do từ chối cũ,
 * đồng bộ cột `host_application_status` và cập nhật `full_name` trên bảng `users` trong cùng giao dịch DB.
 */
export const markLatestHostApplicationApproved = async (
    userId: number,
    adminId: number,
    transaction?: Transaction,
) => {
    const application = await getLatestHostApplication(userId, transaction);

    if (!application) {
        return;
    }

    application.status = "approved";
    application.reviewedByUserId = adminId;
    application.reviewedAt = new Date();
    application.rejectionReason = null;
    await application.save({ transaction });
    await updateUserHostApplicationStatus(userId, "approved", transaction);

    if (application.contactName && application.contactName.trim().length > 0) {
        const userColumns = await getExistingColumns("users", ["full_name"], transaction);
        if (userColumns.has("full_name")) {
            await sequelize.query("UPDATE users SET full_name = ? WHERE user_id = ?", {
                replacements: [application.contactName.trim(), userId],
                transaction,
            });
        }
    }
};

/**
 * Giải thuật kiểm tra trạng thái xác minh danh tính đủ điều kiện đăng tin của chủ nhà (`Host` KYC Verification):
 * 1. Tự động dò siêu dữ liệu lược đồ (`getExistingColumns`) trên bảng `users` để kiểm tra tương thích ngược
 *    các cột cờ xác minh (`is_host_verified`, `host_verified`, `is_verified`) nếu tồn tại và có giá trị bật.
 * 2. Đối chiếu nguồn chuẩn xác thực từ bảng `host_verifications` để xác nhận tồn tại hồ sơ có `status = "approved"`.
 */
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
