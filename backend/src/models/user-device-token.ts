import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export type DevicePlatform = "android" | "ios" | "web";

class UserDeviceToken extends Model<
    InferAttributes<UserDeviceToken>,
    InferCreationAttributes<UserDeviceToken>
> {
    declare deviceTokenId: CreationOptional<number>;
    declare userId: number;
    declare fcmToken: string;
    declare tokenHash: string;
    declare platform: CreationOptional<DevicePlatform>;
    declare appFlavor: CreationOptional<string | null>;
    declare deviceLabel: CreationOptional<string | null>;
    declare isActive: CreationOptional<boolean>;
    declare lastSeenAt: CreationOptional<Date>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

UserDeviceToken.init(
    {
        deviceTokenId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "device_token_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        fcmToken: {
            type: DataTypes.STRING(512),
            allowNull: false,
            field: "fcm_token",
        },
        tokenHash: {
            type: DataTypes.CHAR(64),
            allowNull: false,
            field: "token_hash",
        },
        platform: {
            type: DataTypes.ENUM("android", "ios", "web"),
            allowNull: false,
            defaultValue: "android",
        },
        appFlavor: {
            type: DataTypes.STRING(32),
            allowNull: true,
            field: "app_flavor",
        },
        deviceLabel: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "device_label",
        },
        isActive: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "is_active",
        },
        lastSeenAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "last_seen_at",
        },
        createdAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "created_at",
        },
        updatedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "updated_at",
        },
    },
    {
        sequelize,
        tableName: "user_device_tokens",
        modelName: "UserDeviceToken",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                name: "uq_user_device_tokens_hash",
                fields: ["token_hash"],
            },
            {
                name: "idx_user_device_tokens_user_active",
                fields: ["user_id", "is_active"],
            },
        ],
    },
);

export default UserDeviceToken;

