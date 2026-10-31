import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const hostSheetCellStates = [
    "empty",
    "host_blocked",
    "pending_hold",
    "booked",
    "conflict",
] as const;

export type HostSheetCellState = (typeof hostSheetCellStates)[number];

export const hostSheetLockSources = [
    "none",
    "sheet_manual",
    "app_manual",
    "booking_hold",
    "booking_paid",
    "admin_lock",
    "listing_inactive",
] as const;

export type HostSheetLockSource = (typeof hostSheetLockSources)[number];

class HostSheetCellSnapshotModel extends Model<
    InferAttributes<HostSheetCellSnapshotModel>,
    InferCreationAttributes<HostSheetCellSnapshotModel>
> {
    declare snapshotId: CreationOptional<number>;
    declare hostUserId: number;
    declare listingId: number;
    declare date: string;
    declare lastSheetState: CreationOptional<HostSheetCellState>;
    declare lastSheetRawValue: CreationOptional<string | null>;
    declare lastSheetBgHex: CreationOptional<string | null>;
    declare lastAppBlockedByHost: CreationOptional<boolean>;
    declare lastActiveBookingId: CreationOptional<number | null>;
    declare lockSource: CreationOptional<HostSheetLockSource>;
    declare syncRevision: CreationOptional<number>;
    declare syncedAt: CreationOptional<Date>;
}

HostSheetCellSnapshotModel.init(
    {
        snapshotId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "snapshot_id",
        },
        hostUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_user_id",
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
        lastSheetState: {
            type: DataTypes.ENUM(...hostSheetCellStates),
            allowNull: false,
            defaultValue: "empty",
            field: "last_sheet_state",
        },
        lastSheetRawValue: {
            type: DataTypes.STRING(255),
            allowNull: true,
            defaultValue: null,
            field: "last_sheet_raw_value",
        },
        lastSheetBgHex: {
            type: DataTypes.STRING(16),
            allowNull: true,
            defaultValue: null,
            field: "last_sheet_bg_hex",
        },
        lastAppBlockedByHost: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "last_app_blocked_by_host",
        },
        lastActiveBookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            defaultValue: null,
            field: "last_active_booking_id",
        },
        lockSource: {
            type: DataTypes.ENUM(...hostSheetLockSources),
            allowNull: false,
            defaultValue: "none",
            field: "lock_source",
        },
        syncRevision: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "sync_revision",
        },
        syncedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "synced_at",
        },
    },
    {
        sequelize,
        tableName: "host_sheet_cell_snapshots",
        underscored: true,
        timestamps: false,
        indexes: [
            { unique: true, name: "uq_sheet_snapshot_listing_date", fields: ["listing_id", "date"] },
            { name: "idx_sheet_snapshot_host", fields: ["host_user_id", "date"] },
        ],
    },
);

export type HostSheetCellSnapshotDocument = HostSheetCellSnapshotModel;
export default HostSheetCellSnapshotModel;

