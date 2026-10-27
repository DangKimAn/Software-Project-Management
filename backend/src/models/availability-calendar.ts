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
    declare priceOverride: number | null;
    declare minNightsOverride: number | null;
    declare notes: string | null;
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
