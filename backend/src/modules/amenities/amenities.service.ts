import { Op, QueryTypes } from "sequelize";

import { ApiError } from "../../common/api-error";
import { sanitizeNullableSingleLineText, sanitizeSingleLineText } from "../../common/sanitization";
import sequelize from "../../config/database";
import Amenity, { AmenityDocument } from "../../models/amenity";
import type { AuthenticatedUser } from "../auth/auth.service";
import { writeAuditLog } from "../../services/audit-log-service";

export type AmenityInput = {
    name: string;
    icon?: string | null;
    isActive?: boolean;
};

const normalizeName = (name: string) => sanitizeSingleLineText(name);
const normalizeIcon = (icon?: string | null) => sanitizeNullableSingleLineText(icon);

const serializeAmenity = (amenity: AmenityDocument) => ({
    amenityId: amenity.amenityId,
    name: amenity.name,
    icon: amenity.icon ?? null,
    isActive: amenity.active && amenity.isActive && amenity.deletedAt === null,
    createdAt: amenity.createdAt,
    updatedAt: amenity.updatedAt,
});

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

const getNextAmenityId = async () => {
    const rows = await sequelize.query<{ nextId: number }>(
        "SELECT COALESCE(MAX(amenity_id), 0) + 1 AS nextId FROM amenities",
        {
            type: QueryTypes.SELECT,
        },
    );

    return Number(rows[0]?.nextId ?? 1);
};

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
    });

    return serializeAmenity(amenity);
};

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
