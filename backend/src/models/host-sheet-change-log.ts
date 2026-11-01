import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const hostSheetChangeDirections = [
    "sheet_to_app",
    "app_to_sheet",
    "structure_repair",
] as const;

export type HostSheetChangeDirection = (typeof hostSheetChangeDirections)[number];

class HostSheetChangeLogModel extends Model<
    InferAttributes<HostSheetChangeLogModel>,
    InferCreationAttributes<HostSheetChangeLogModel>
> {
    declare logId: CreationOptional<number>;
    declare hostUserId: number;
    declare integrationId: number;
    declare listingId: CreationOptional<number | null>;
    declare targetDate: CreationOptional<string | null>;
    declare direction: HostSheetChangeDirection;
    declare action: string;
    declare previousValue: CreationOptional<string | null>;
    declare newValue: CreationOptional<string | null>;
    declare metadataJson: CreationOptional<Record<string, unknown> | null>;
    declare detectedAt: CreationOptional<Date>;
}

HostSheetChangeLogModel.init(
    {
        logId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "log_id",
        },
        hostUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_user_id",
        },
        integrationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "integration_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            defaultValue: null,
            field: "listing_id",
        },
        targetDate: {
            type: DataTypes.DATEONLY,
            allowNull: true,
            defaultValue: null,
            field: "target_date",
        },
        direction: {
            type: DataTypes.ENUM(...hostSheetChangeDirections),
            allowNull: false,
        },
        action: {
            type: DataTypes.STRING(64),
            allowNull: false,
        },
        previousValue: {
            type: DataTypes.STRING(255),
            allowNull: true,
            defaultValue: null,
            field: "previous_value",
        },
        newValue: {
            type: DataTypes.STRING(255),
            allowNull: true,
            defaultValue: null,
            field: "new_value",
        },
        metadataJson: {
            type: DataTypes.JSON,
            allowNull: true,
            defaultValue: null,
            field: "metadata_json",
        },
        detectedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "detected_at",
        },
    },
    {
        sequelize,
        tableName: "host_sheet_change_logs",
        underscored: true,
        timestamps: false,
        indexes: [
            { name: "idx_sheet_change_logs_host", fields: ["host_user_id", "detected_at"] },
            { name: "idx_sheet_change_logs_listing", fields: ["listing_id", "target_date"] },
        ],
    },
);

export type HostSheetChangeLogDocument = HostSheetChangeLogModel;
export default HostSheetChangeLogModel;

