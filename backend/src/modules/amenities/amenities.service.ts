import { Op, QueryTypes, UniqueConstraintError } from "sequelize";

import { ApiError } from "../../common/api-error";
import { sanitizeNullableSingleLineText, sanitizeSingleLineText } from "../../common/sanitization";
import sequelize from "../../config/database";
import Amenity, { AmenityDocument } from "../../models/amenity";
import type { AuthenticatedUser } from "../auth/auth.service";
import { writeAuditLog } from "../../services/audit-log.service";

export type AmenityInput = {
    name: string;
    icon?: string | null;
    isActive?: boolean;
};

/**
 * Giải thuật làm sạch chuỗi tên tiện ích trên một dòng chống chèn mã độc XSS.
 */
const normalizeName = (name: string) => sanitizeSingleLineText(name);

/**
 * Giải thuật làm sạch chuỗi định danh biểu tượng tiện ích tùy chọn trên một dòng.
 */
const normalizeIcon = (icon?: string | null) => sanitizeNullableSingleLineText(icon);

/**
 * Giải thuật tuần tự hóa bản ghi tiện ích cho cổng quản trị, hợp nhất trạng thái hiệu lực thực tế theo điều kiện `active && isActive && deletedAt === null`.
 */
const serializeAmenity = (amenity: AmenityDocument) => ({
    amenityId: amenity.amenityId,
    name: amenity.name,
    icon: amenity.icon ?? null,
    isActive: amenity.active && amenity.isActive && amenity.deletedAt === null,
    createdAt: amenity.createdAt,
    updatedAt: amenity.updatedAt,
});

/**
 * Giải thuật tra cứu tiện ích theo tên không phân biệt chữ hoa/thường (`LOWER(name) = LOWER(?)`) bằng truy vấn tham số hóa an toàn,
 * phục vụ kiểm tra chống trùng lặp và khôi phục tiện ích từng bị xóa mềm.
 */
const findAmenityByName = async (name: string) => {
    const rows = await sequelize.query<{ amenityId: number }>(
        `
        SELECT amenity_id AS amenityId
        FROM amenities
        WHERE LOWER(name) = LOWER(?)
        LIMIT 1
        `,
        {
            replacements: [name],
            type: QueryTypes.SELECT,
        },
    );

    const amenityId = rows[0]?.amenityId;

    if (!amenityId) {
        return null;
    }

    return Amenity.findOne({ amenityId });
};

/**
 * Giải thuật cấp phát khóa định danh tuần tự kế tiếp cho tiện ích mới theo công thức `COALESCE(MAX(amenity_id), 0) + 1`.
 */
const getNextAmenityId = async () => {
    const rows = await sequelize.query<{ nextId: number }>(
        "SELECT COALESCE(MAX(amenity_id), 0) + 1 AS nextId FROM amenities",
        {
            type: QueryTypes.SELECT,
        },
    );

    return Number(rows[0]?.nextId ?? 1);
};

/**
 * Giải thuật ghi nhận nhật ký kiểm toán (`audit_logs`) cho các thao tác quản trị danh mục tiện ích.
 */
const writeAmenityAudit = async (
    actor: AuthenticatedUser,
    action: string,
    amenityId: number,
    metadata?: Record<string, unknown>,
) => {
    await writeAuditLog({
        actorId: Number(actor.id),
        action,
        targetType: "amenity",
        targetId: amenityId,
        metadata,
    });
};

/**
 * Giải thuật truy xuất danh sách tiện ích công khai đang kích hoạt (`active = true`, `isActive = true`, `deletedAt = null`) sắp xếp tăng dần theo `amenityId`.
 */
export const listPublicAmenities = async () => {
    const items = await Amenity.find({
        active: true,
        isActive: true,
        deletedAt: null,
    }).sort({ amenityId: 1 });

    return {
        items: items.map((amenity) => ({
            amenityId: amenity.amenityId,
            name: amenity.name,
            icon: amenity.icon ?? null,
        })),
    };
};

/**
 * Giải thuật truy xuất toàn bộ tiện ích chưa xóa mềm phục vụ trang quản trị (bao gồm cả các tiện ích đang tạm tắt `isActive = false`).
 */
export const listAdminAmenities = async () => {
    const items = await Amenity.findAll({
        where: {
            deletedAt: {
                [Op.is]: null,
            },
        },
        order: [["amenityId", "ASC"]],
    });

    return {
        items: items.map(serializeAmenity),
    };
};

/**
 * Giải thuật tạo mới hoặc khôi phục thông minh tiện ích trùng tên trong giao dịch CSDL:
 * - Làm sạch tên và đối chiếu không phân biệt hoa/thường qua `findAmenityByName`; ném lỗi 409 nếu tiện ích trùng tên đang hoạt động.
 * - Nếu bản ghi trùng tên từng bị xóa mềm hoặc tắt kích hoạt, tự động khôi phục lại bản ghi cũ (`deletedAt = null`) để giữ nguyên `amenityId` lịch sử;
 *   ngược lại tạo bản ghi mới và bắt ngoại lệ `UniqueConstraintError` chống xung đột đồng thời.
 */
export const createAmenity = async (actor: AuthenticatedUser, input: AmenityInput) => {
    const name = normalizeName(input.name);

    if (!name) {
        throw new ApiError(422, "Validation error", [
            {
                path: "name",
                msg: "name cannot be empty after sanitization",
            },
        ]);
    }

    const existing = await findAmenityByName(name);

    if (existing?.active && existing.isActive && existing.deletedAt === null) {
        throw new ApiError(409, "Amenity already exists");
    }

    const amenity = await sequelize.transaction(async (transaction) => {
        if (existing) {
            existing.name = name;
            existing.icon = normalizeIcon(input.icon);
            existing.active = input.isActive ?? true;
            existing.isActive = input.isActive ?? true;
            existing.deletedAt = null;
            await existing.save({ transaction });
            await writeAmenityAudit(actor, "admin_amenity.restore", existing.amenityId, {
                name,
            });
            return existing;
        }

        try {
            const created = await Amenity.create(
                {
                    amenityId: await getNextAmenityId(),
                    name,
                    icon: normalizeIcon(input.icon),
                    active: input.isActive ?? true,
                    isActive: input.isActive ?? true,
                    deletedAt: null,
                },
                { transaction },
            );
            await writeAmenityAudit(actor, "admin_amenity.create", created.amenityId, {
                name,
            });
            return created;
        } catch (error) {
            if (error instanceof UniqueConstraintError) {
                throw new ApiError(409, "Amenity already exists");
            }
            throw error;
        }
    });

    return serializeAmenity(amenity);
};

/**
 * Giải thuật cập nhật thông tin tiện ích quản trị:
 * Xác thực tiện ích tồn tại và chưa xóa mềm, kiểm tra chống đổi tên trùng với một tiện ích đang hoạt động khác (`existing.amenityId !== amenity.amenityId`),
 * đồng bộ cặp cờ `active`/`isActive` và ghi nhận nhật ký kiểm toán.
 */
export const updateAmenity = async (
    actor: AuthenticatedUser,
    amenityId: number,
    input: Partial<AmenityInput>,
) => {
    const amenity = await Amenity.findOne({ amenityId });

    if (!amenity || amenity.deletedAt !== null) {
        throw new ApiError(404, "Amenity not found");
    }

    if (input.name !== undefined) {
        const name = normalizeName(input.name);

        if (!name) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "name",
                    msg: "name cannot be empty after sanitization",
                },
            ]);
        }

        const existing = await findAmenityByName(name);

        if (existing && existing.amenityId !== amenity.amenityId && existing.active && existing.isActive) {
            throw new ApiError(409, "Amenity already exists");
        }
    }

    if (input.name !== undefined) {
        amenity.name = normalizeName(input.name);
    }

    if (Object.prototype.hasOwnProperty.call(input, "icon")) {
        amenity.icon = normalizeIcon(input.icon);
    }

    if (input.isActive !== undefined) {
        amenity.active = input.isActive;
        amenity.isActive = input.isActive;
    }

    await amenity.save();
    await writeAmenityAudit(actor, "admin_amenity.update", amenity.amenityId, {
        changedFields: Object.keys(input),
    });

    return serializeAmenity(amenity);
};

/**
 * Giải thuật xóa mềm tiện ích quản trị:
 * Hạ đồng thời hai cờ `active = false`, `isActive = false` và gán mốc `deletedAt` nhằm ẩn tiện ích khỏi bộ lọc tìm kiếm mới mà vẫn bảo toàn toàn vẹn tham chiếu lịch sử.
 */
export const deleteAmenity = async (actor: AuthenticatedUser, amenityId: number) => {
    const amenity = await Amenity.findOne({ amenityId });

    if (!amenity || amenity.deletedAt !== null) {
        throw new ApiError(404, "Amenity not found");
    }

    amenity.active = false;
    amenity.isActive = false;
    amenity.deletedAt = new Date();
    await amenity.save();
    await writeAmenityAudit(actor, "admin_amenity.delete", amenity.amenityId, {
        name: amenity.name,
    });
};
