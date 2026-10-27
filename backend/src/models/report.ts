import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const reportTargetTypeValues = ["listing", "user", "review", "booking"] as const;
export type ReportTargetType = (typeof reportTargetTypeValues)[number];

export const reportStatusValues = ["open", "resolved", "rejected"] as const;
export type ReportStatus = (typeof reportStatusValues)[number];

class ReportModel extends Model<InferAttributes<ReportModel>, InferCreationAttributes<ReportModel>> {
    declare reportId: CreationOptional<number>;
    declare reporterId: number;
    declare targetType: ReportTargetType;
    declare targetId: number;
    declare reason: string;
    declare description: CreationOptional<string | null>;
    declare status: CreationOptional<ReportStatus>;
    declare resolvedBy: CreationOptional<number | null>;
    declare resolvedAt: CreationOptional<Date | null>;
    declare resolution: CreationOptional<string | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ReportModel.init(
    {
        reportId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "report_id",
        },
        reporterId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "reporter_id",
        },
        targetType: {
            type: DataTypes.ENUM(...reportTargetTypeValues),
            allowNull: false,
            field: "target_type",
        },
        targetId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "target_id",
        },
        reason: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        status: {
            type: DataTypes.ENUM(...reportStatusValues),
            allowNull: false,
            defaultValue: "open",
        },
        resolvedBy: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "resolved_by",
        },
        resolvedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "resolved_at",
        },
        resolution: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "reports",
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ["reporter_id"] },
            { fields: ["target_type", "target_id"] },
            { fields: ["status"] },
        ],
    },
);

export default ReportModel;
