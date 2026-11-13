import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const hostSheetConflictTypes = [
    "booking_vs_sheet_edit",
    "app_vs_sheet_concurrent",
    "missing_listing_row",
    "duplicate_listing_row",
    "missing_month_tab",
    "bulk_row_block_warning",
    "permission_revoked",
] as const;

export type HostSheetConflictType = (typeof hostSheetConflictTypes)[number];

export const hostSheetConflictSeverities = ["low", "medium", "high", "critical"] as const;
export type HostSheetConflictSeverity = (typeof hostSheetConflictSeverities)[number];

export const hostSheetConflictStatuses = ["open", "auto_repaired", "resolved", "reverted"] as const;
export type HostSheetConflictStatus = (typeof hostSheetConflictStatuses)[number];

class HostSheetSyncConflictModel extends Model<
    InferAttributes<HostSheetSyncConflictModel>,
    InferCreationAttributes<HostSheetSyncConflictModel>
> {
    declare conflictId: CreationOptional<number>;
    declare hostUserId: number;
    declare integrationId: number;
    declare listingId: CreationOptional<number | null>;
    declare bookingId: CreationOptional<number | null>;
    declare conflictDate: CreationOptional<string | null>;
    declare monthTab: CreationOptional<string | null>;
    declare conflictType: HostSheetConflictType;
    declare severity: CreationOptional<HostSheetConflictSeverity>;
    declare status: CreationOptional<HostSheetConflictStatus>;
    declare description: string;
    declare detailsJson: CreationOptional<Record<string, unknown> | null>;
    declare resolvedByUserId: CreationOptional<number | null>;
    declare resolvedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostSheetSyncConflictModel.init(
    {
        conflictId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "conflict_id",
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
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            defaultValue: null,
            field: "booking_id",
        },
        conflictDate: {
            type: DataTypes.DATEONLY,
            allowNull: true,
            defaultValue: null,
            field: "conflict_date",
        },
        monthTab: {
            type: DataTypes.STRING(16),
            allowNull: true,
            defaultValue: null,
            field: "month_tab",
        },
        conflictType: {
            type: DataTypes.ENUM(...hostSheetConflictTypes),
            allowNull: false,
            field: "conflict_type",
        },
        severity: {
            type: DataTypes.ENUM(...hostSheetConflictSeverities),
            allowNull: false,
            defaultValue: "high",
        },
        status: {
            type: DataTypes.ENUM(...hostSheetConflictStatuses),
            allowNull: false,
            defaultValue: "open",
        },
        description: {
            type: DataTypes.STRING(500),
            allowNull: false,
        },
        detailsJson: {
            type: DataTypes.JSON,
            allowNull: true,
            defaultValue: null,
            field: "details_json",
        },
        resolvedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            defaultValue: null,
            field: "resolved_by_user_id",
        },
        resolvedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "resolved_at",
        },
        createdAt: {
            type: DataTypes.DATE,
            field: "created_at",
        },
        updatedAt: {
            type: DataTypes.DATE,
            field: "updated_at",
        },
    },
    {
        sequelize,
        tableName: "host_sheet_sync_conflicts",
        underscored: true,
        timestamps: true,
        indexes: [
            { name: "idx_sheet_conflicts_host_status", fields: ["host_user_id", "status", "created_at"] },
            { name: "idx_sheet_conflicts_listing", fields: ["listing_id", "conflict_date"] },
        ],
    },
);

export type HostSheetSyncConflictDocument = HostSheetSyncConflictModel;
export default HostSheetSyncConflictModel;

