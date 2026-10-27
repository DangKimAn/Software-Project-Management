import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const securityLogSeverityValues = ["info", "warning", "high", "critical"] as const;
export type SecurityLogSeverity = (typeof securityLogSeverityValues)[number];

class SecurityLogModel extends Model<
    InferAttributes<SecurityLogModel>,
    InferCreationAttributes<SecurityLogModel>
> {
    declare securityLogId: CreationOptional<number>;
    declare userId: CreationOptional<number | null>;
    declare eventType: string;
    declare severity: CreationOptional<SecurityLogSeverity>;
    declare ipAddress: CreationOptional<string | null>;
    declare userAgent: CreationOptional<string | null>;
    declare metadataJson: CreationOptional<Record<string, unknown> | null>;
    declare createdAt: CreationOptional<Date>;
}

SecurityLogModel.init(
    {
        securityLogId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "security_log_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "user_id",
        },
        eventType: {
            type: DataTypes.STRING(120),
            allowNull: false,
            field: "event_type",
        },
        severity: {
            type: DataTypes.ENUM(...securityLogSeverityValues),
            allowNull: false,
            defaultValue: "info",
        },
        ipAddress: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "ip_address",
        },
        userAgent: {
            type: DataTypes.STRING(1024),
            allowNull: true,
            field: "user_agent",
        },
        metadataJson: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "metadata_json",
        },
        createdAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "security_logs",
        underscored: true,
        timestamps: true,
        updatedAt: false,
        indexes: [
            { fields: ["user_id"] },
            { fields: ["event_type"] },
            { fields: ["severity"] },
            { fields: ["created_at"] },
        ],
    },
);

export default SecurityLogModel;
