import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const userProfileGenderValues = ["male", "female", "other", "prefer_not_to_say"] as const;
export type UserProfileGender = (typeof userProfileGenderValues)[number];

class UserProfileModel extends Model<
    InferAttributes<UserProfileModel>,
    InferCreationAttributes<UserProfileModel>
> {
    declare profileId: CreationOptional<number>;
    declare userId: number;
    declare firstName: CreationOptional<string | null>;
    declare lastName: CreationOptional<string | null>;
    declare avatarUrl: CreationOptional<string | null>;
    declare dateOfBirth: CreationOptional<string | null>;
    declare gender: CreationOptional<UserProfileGender | null>;
    declare location: CreationOptional<string | null>;
    declare job: CreationOptional<string | null>;
    declare dreamDestination: CreationOptional<string | null>;
    declare school: CreationOptional<string | null>;
    declare languages: CreationOptional<string[] | null>;
    declare addressLine: CreationOptional<string | null>;
    declare ward: CreationOptional<string | null>;
    declare district: CreationOptional<string | null>;
    declare city: CreationOptional<string | null>;
    declare country: CreationOptional<string>;
    declare emergencyContactName: CreationOptional<string | null>;
    declare emergencyContactPhone: CreationOptional<string | null>;
    declare deletedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

UserProfileModel.init(
    {
        profileId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "profile_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "user_id",
        },
        firstName: {
            type: DataTypes.STRING(120),
            allowNull: true,
            field: "first_name",
        },
        lastName: {
            type: DataTypes.STRING(120),
            allowNull: true,
            field: "last_name",
        },
        avatarUrl: {
            type: DataTypes.STRING(1024),
            allowNull: true,
            field: "avatar_url",
        },
        dateOfBirth: {
            type: DataTypes.DATEONLY,
            allowNull: true,
            field: "date_of_birth",
        },
        gender: {
            type: DataTypes.ENUM(...userProfileGenderValues),
            allowNull: true,
        },
        location: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        job: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        dreamDestination: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "dream_destination",
        },
        school: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        languages: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "languages_json",
        },
        addressLine: {
            type: DataTypes.STRING(500),
            allowNull: true,
            field: "address_line",
        },
        ward: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        district: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        city: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        country: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VN",
        },
        emergencyContactName: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "emergency_contact_name",
        },
        emergencyContactPhone: {
            type: DataTypes.STRING(32),
            allowNull: true,
            field: "emergency_contact_phone",
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
        tableName: "user_profiles",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, fields: ["user_id"] },
            { fields: ["city", "district"] },
            { fields: ["deleted_at"] },
        ],
    },
);

export default UserProfileModel;
