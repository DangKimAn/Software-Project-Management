import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class AuditLogModel extends Model<
    InferAttributes<AuditLogModel>,
    InferCreationAttributes<AuditLogModel>
> {
    declare id: CreationOptional<number>;
    declare actorId: number | null;
    declare action: string;
    declare targetType: string;
    declare targetId: number | null;
    declare metadataJson: Record<string, unknown> | null;
    declare ipAddress: string | null;
    declare userAgent: string | null;
    declare createdAt: CreationOptional<Date>;
}

AuditLogModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        actorId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "actor_id",
        },
        action: {
            type: DataTypes.STRING(120),
            allowNull: false,
        },
        targetType: {
            type: DataTypes.STRING(80),
            allowNull: false,
            field: "target_type",
        },
        targetId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "target_id",
        },
        metadataJson: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "metadata_json",
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
        createdAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "audit_logs",
        underscored: true,
        timestamps: true,
        updatedAt: false,
    },
);

export default AuditLogModel;
