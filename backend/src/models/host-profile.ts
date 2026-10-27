import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const hostProfileVerificationStatusValues = ["pending", "approved", "rejected"] as const;
export type HostProfileVerificationStatus = (typeof hostProfileVerificationStatusValues)[number];

class HostProfileModel extends Model<
    InferAttributes<HostProfileModel>,
    InferCreationAttributes<HostProfileModel>
> {
    declare hostProfileId: CreationOptional<number>;
    declare userId: number;
    declare displayName: CreationOptional<string | null>;
    declare bio: CreationOptional<string | null>;
    declare businessName: CreationOptional<string | null>;
    declare businessTaxIdHash: CreationOptional<string | null>;
    declare responseRate: CreationOptional<number | null>;
    declare responseTimeMinutes: CreationOptional<number | null>;
    declare isSuperhost: CreationOptional<boolean>;
    declare verificationStatus: CreationOptional<HostProfileVerificationStatus>;
    declare approvedBy: CreationOptional<number | null>;
    declare approvedAt: CreationOptional<Date | null>;
    declare deletedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostProfileModel.init(
    {
        hostProfileId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "host_profile_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "user_id",
        },
        displayName: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "display_name",
        },
        bio: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        businessName: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "business_name",
        },
        businessTaxIdHash: {
            type: DataTypes.STRING(128),
            allowNull: true,
            field: "business_tax_id_hash",
        },
        responseRate: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: true,
            field: "response_rate",
        },
        responseTimeMinutes: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "response_time_minutes",
        },
        isSuperhost: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_superhost",
        },
        verificationStatus: {
            type: DataTypes.ENUM(...hostProfileVerificationStatusValues),
            allowNull: false,
            defaultValue: "pending",
            field: "verification_status",
        },
        approvedBy: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "approved_by",
        },
        approvedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "approved_at",
        },
        deletedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "deleted_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "host_profiles",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, fields: ["user_id"] },
            { fields: ["verification_status", "deleted_at"] },
            { fields: ["approved_by"] },
        ],
    },
);

export default HostProfileModel;
