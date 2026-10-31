import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const hostSheetSyncJobTypes = [
    "init_standard_calendar",
    "booking_changed",
    "listing_created",
    "listing_updated",
    "listing_archived",
    "listing_restored",
    "listing_transferred",
    "app_calendar_updated",
    "manual_sync",
    "periodic_poll",
    "structure_repair",
] as const;

export type HostSheetSyncJobType = (typeof hostSheetSyncJobTypes)[number];

export const hostSheetSyncJobStatuses = [
    "pending",
    "processing",
    "succeeded",
    "failed",
    "cancelled",
] as const;

export type HostSheetSyncJobStatus = (typeof hostSheetSyncJobStatuses)[number];

class HostSheetSyncJobModel extends Model<
    InferAttributes<HostSheetSyncJobModel>,
    InferCreationAttributes<HostSheetSyncJobModel>
> {
    declare jobId: CreationOptional<number>;
    declare hostUserId: number;
    declare integrationId: CreationOptional<number | null>;
    declare listingId: CreationOptional<number | null>;
    declare bookingId: CreationOptional<number | null>;
    declare jobType: HostSheetSyncJobType;
    declare priority: CreationOptional<number>;
    declare dedupeKey: CreationOptional<string | null>;
    declare payloadJson: CreationOptional<Record<string, unknown> | null>;
    declare status: CreationOptional<HostSheetSyncJobStatus>;
    declare attempts: CreationOptional<number>;
    declare maxAttempts: CreationOptional<number>;
    declare availableAt: CreationOptional<Date>;
    declare lockedBy: CreationOptional<string | null>;
    declare lockedUntil: CreationOptional<Date | null>;
    declare lastError: CreationOptional<string | null>;
    declare completedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostSheetSyncJobModel.init(
    {
        jobId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "job_id",
        },
        hostUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_user_id",
        },
        integrationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            defaultValue: null,
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
        jobType: {
            type: DataTypes.ENUM(...hostSheetSyncJobTypes),
            allowNull: false,
            field: "job_type",
        },
        priority: {
            type: DataTypes.TINYINT.UNSIGNED,
            allowNull: false,
            defaultValue: 50,
        },
        dedupeKey: {
            type: DataTypes.STRING(191),
            allowNull: true,
            defaultValue: null,
            field: "dedupe_key",
        },
        payloadJson: {
            type: DataTypes.JSON,
            allowNull: true,
            defaultValue: null,
            field: "payload_json",
        },
        status: {
            type: DataTypes.ENUM(...hostSheetSyncJobStatuses),
            allowNull: false,
            defaultValue: "pending",
        },
        attempts: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
        },
        maxAttempts: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 5,
            field: "max_attempts",
        },
        availableAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "available_at",
        },
        lockedBy: {
            type: DataTypes.STRING(64),
            allowNull: true,
            defaultValue: null,
            field: "locked_by",
        },
        lockedUntil: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "locked_until",
        },
        lastError: {
            type: DataTypes.TEXT,
            allowNull: true,
            defaultValue: null,
            field: "last_error",
        },
        completedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "completed_at",
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
        tableName: "host_sheet_sync_jobs",
        underscored: true,
        timestamps: true,
        indexes: [
            { name: "idx_sheet_jobs_claim", fields: ["status", "available_at", "priority", "job_id"] },
            { name: "idx_sheet_jobs_host_status", fields: ["host_user_id", "status"] },
            { name: "idx_sheet_jobs_dedupe", fields: ["dedupe_key", "status"] },
        ],
    },
);

export type HostSheetSyncJobDocument = HostSheetSyncJobModel;
export default HostSheetSyncJobModel;

