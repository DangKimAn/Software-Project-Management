import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const hostSheetIntegrationStatuses = [
    "disconnected",
    "connected",
    "permission_error",
    "structure_error",
    "quota_limited",
    "sync_error",
] as const;

export type HostSheetIntegrationStatus = (typeof hostSheetIntegrationStatuses)[number];

class HostSheetIntegrationModel extends Model<
    InferAttributes<HostSheetIntegrationModel>,
    InferCreationAttributes<HostSheetIntegrationModel>
> {
    declare integrationId: CreationOptional<number>;
    declare hostUserId: number;
    declare spreadsheetId: string;
    declare spreadsheetUrl: string;
    declare spreadsheetTitle: CreationOptional<string | null>;
    declare hostEditorEmail: CreationOptional<string | null>;
    declare serviceAccountEmail: CreationOptional<string | null>;
    declare status: CreationOptional<HostSheetIntegrationStatus>;
    declare autoSyncEnabled: CreationOptional<boolean>;
    declare strictBookingPrecheck: CreationOptional<boolean>;
    declare permissionVerifiedAt: CreationOptional<Date | null>;
    declare canWriteVerified: CreationOptional<boolean>;
    declare schemaVersion: CreationOptional<number>;
    declare syncRevision: CreationOptional<number>;
    declare syncLockToken: CreationOptional<string | null>;
    declare syncLockExpiresAt: CreationOptional<Date | null>;
    declare lastSyncedAt: CreationOptional<Date | null>;
    declare lastPolledAt: CreationOptional<Date | null>;
    declare nextPollAt: CreationOptional<Date | null>;
    declare lastErrorCode: CreationOptional<string | null>;
    declare lastErrorMessage: CreationOptional<string | null>;
    declare consecutiveFailures: CreationOptional<number>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostSheetIntegrationModel.init(
    {
        integrationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "integration_id",
        },
        hostUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_user_id",
        },
        spreadsheetId: {
            type: DataTypes.STRING(128),
            allowNull: false,
            field: "spreadsheet_id",
        },
        spreadsheetUrl: {
            type: DataTypes.STRING(512),
            allowNull: false,
            field: "spreadsheet_url",
        },
        spreadsheetTitle: {
            type: DataTypes.STRING(255),
            allowNull: true,
            defaultValue: null,
            field: "spreadsheet_title",
        },
        hostEditorEmail: {
            type: DataTypes.STRING(255),
            allowNull: true,
            defaultValue: null,
            field: "host_editor_email",
        },
        serviceAccountEmail: {
            type: DataTypes.STRING(255),
            allowNull: true,
            defaultValue: null,
            field: "service_account_email",
        },
        status: {
            type: DataTypes.ENUM(...hostSheetIntegrationStatuses),
            allowNull: false,
            defaultValue: "connected",
        },
        autoSyncEnabled: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "auto_sync_enabled",
        },
        strictBookingPrecheck: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "strict_booking_precheck",
        },
        permissionVerifiedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "permission_verified_at",
        },
        canWriteVerified: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "can_write_verified",
        },
        schemaVersion: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 1,
            field: "schema_version",
        },
        syncRevision: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "sync_revision",
        },
        syncLockToken: {
            type: DataTypes.STRING(64),
            allowNull: true,
            defaultValue: null,
            field: "sync_lock_token",
        },
        syncLockExpiresAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "sync_lock_expires_at",
        },
        lastSyncedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "last_synced_at",
        },
        lastPolledAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "last_polled_at",
        },
        nextPollAt: {
            type: DataTypes.DATE,
            allowNull: true,
            defaultValue: null,
            field: "next_poll_at",
        },
        lastErrorCode: {
            type: DataTypes.STRING(64),
            allowNull: true,
            defaultValue: null,
            field: "last_error_code",
        },
        lastErrorMessage: {
            type: DataTypes.TEXT,
            allowNull: true,
            defaultValue: null,
            field: "last_error_message",
        },
        consecutiveFailures: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "consecutive_failures",
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
        tableName: "host_sheet_integrations",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, name: "uq_host_sheet_host", fields: ["host_user_id"] },
            { unique: true, name: "uq_host_sheet_spreadsheet", fields: ["spreadsheet_id"] },
            { name: "idx_host_sheet_poll", fields: ["auto_sync_enabled", "status", "next_poll_at"] },
        ],
    },
);

export type HostSheetIntegrationDocument = HostSheetIntegrationModel;
export default HostSheetIntegrationModel;

