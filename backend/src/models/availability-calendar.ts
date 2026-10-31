import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class AvailabilityCalendarModel extends Model<
    InferAttributes<AvailabilityCalendarModel>,
    InferCreationAttributes<AvailabilityCalendarModel>
> {
    declare id: CreationOptional<number>;
    declare listingId: number;
    declare date: string;
    declare isAvailable: boolean;
    declare isBlockedByHost: boolean;
    declare isBlockedByAdmin: CreationOptional<boolean>;
    declare lockSource: CreationOptional<string | null>;
    declare priceOverride: number | null;
    declare minNightsOverride: number | null;
    declare notes: string | null;
    declare syncRevision: CreationOptional<number>;
    declare lastSheetSyncedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

AvailabilityCalendarModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        date: {
            type: DataTypes.DATEONLY,
            allowNull: false,
        },
        isAvailable: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "is_available",
        },
        isBlockedByHost: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_blocked_by_host",
        },
        isBlockedByAdmin: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_blocked_by_admin",
        },
        lockSource: {
            type: DataTypes.STRING(32),
            allowNull: true,
            defaultValue: null,
            field: "lock_source",
        },
        priceOverride: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            field: "price_override",
        },
        minNightsOverride: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "min_nights_override",
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        syncRevision: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "sync_revision",
        },
        lastSheetSyncedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "last_sheet_synced_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "availability_calendars",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["listing_id", "date"],
            },
            {
                fields: ["listing_id"],
            },
            {
                fields: ["date"],
            },
        ],
    },
);

export type AvailabilityCalendarDocument = AvailabilityCalendarModel;
export default AvailabilityCalendarModel;
