import {
    CreationOptional,
    DataTypes,
    FindOptions,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";
import {
    MySqlQuery,
    buildDocumentQuery,
    countDocumentsByFilter,
    findOneByFilter,
    isFindOptions,
    SimpleFilter,
} from "./mysql-helpers";

export const userRoleValues = ["guest", "host", "moderator", "admin"] as const;
export type UserRole = (typeof userRoleValues)[number];

export const userStatusValues = ["active", "inactive", "blocked", "suspended", "deleted", "locked"] as const;
export type UserStatus = (typeof userStatusValues)[number];

export type UserRecord = {
    userId: number;
    username: string | null;
    email: string;
    phone: string | null;
    fullName: string;
    passwordHash: string;
    dateOfBirth: Date | null;
    bio: string | null;
    avatarUrl: string | null;
    avatarKey: string | null;
    isEmailVerified: boolean;
    isPhoneVerified: boolean;
    isHostVerified: boolean;
    hostApplicationStatus: "pending" | "approved" | "rejected" | null;
    status: UserStatus;
    lastLoginAt: Date | null;
    deletedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
};

const splitFullName = (value: string) => {
    const parts = value.trim().split(/\s+/).filter(Boolean);

    if (parts.length <= 1) {
        return {
            firstName: parts[0] ?? "",
            lastName: "",
        };
    }

    return {
        firstName: parts.slice(0, -1).join(" "),
        lastName: parts[parts.length - 1],
    };
};

class UserModel extends Model<
    InferAttributes<UserModel, { omit: "_id" | "id" | "firstName" | "lastName" | "dob" }>,
    InferCreationAttributes<UserModel, { omit: "_id" | "id" | "firstName" | "lastName" | "dob" }>
> {
    declare userId: CreationOptional<number>;
    declare username: string | null;
    declare email: string;
    declare phone: string | null;
    declare fullName: string;
    declare passwordHash: string;
    declare dateOfBirth: Date | null;
    declare bio: string | null;
    declare avatarUrl: CreationOptional<string | null>;
    declare avatarKey: CreationOptional<string | null>;
    declare isEmailVerified: CreationOptional<boolean>;
    declare isPhoneVerified: CreationOptional<boolean>;
    declare isHostVerified: CreationOptional<boolean>;
    declare hostApplicationStatus: CreationOptional<"pending" | "approved" | "rejected" | null>;
    declare status: UserStatus;
    declare lastLoginAt: CreationOptional<Date | null>;
    declare deletedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;

    get _id() {
        return this.userId;
    }

    get id() {
        return this.userId;
    }

    get firstName() {
        return splitFullName(this.fullName).firstName;
    }

    get lastName() {
        return splitFullName(this.fullName).lastName;
    }

    get dob() {
        return this.dateOfBirth;
    }
}

UserModel.init(
    {
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "user_id",
        },
        username: {
            type: DataTypes.STRING(255),
            allowNull: true,
            unique: true,
        },
        email: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: true,
        },
        phone: {
            type: DataTypes.STRING(32),
            allowNull: true,
            unique: true,
        },
        fullName: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "full_name",
        },
        passwordHash: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "password_hash",
        },
        dateOfBirth: {
            type: DataTypes.DATEONLY,
            allowNull: true,
            field: "date_of_birth",
        },
        bio: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        avatarUrl: {
            type: DataTypes.STRING(1024),
            allowNull: true,
            field: "avatar_url",
        },
        avatarKey: {
            type: DataTypes.STRING(500),
            allowNull: true,
            field: "avatar_key",
        },
        isEmailVerified: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_email_verified",
        },
        isPhoneVerified: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_phone_verified",
        },
        isHostVerified: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_host_verified",
        },
        hostApplicationStatus: {
            type: DataTypes.ENUM("pending", "approved", "rejected"),
            allowNull: true,
            field: "host_application_status",
        },
        status: {
            type: DataTypes.ENUM(...userStatusValues),
            allowNull: false,
            defaultValue: "active",
        },
        lastLoginAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "last_login_at",
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
        tableName: "users",
        underscored: true,
        timestamps: true,
    },
);

export type UserDocument = UserModel;
type UserWithHelpers = typeof UserModel & {
    find(filter?: SimpleFilter<UserRecord>): MySqlQuery<UserModel>;
    findOne(options?: FindOptions | SimpleFilter<UserRecord>): Promise<UserModel | null>;
    findById(id: string | number): Promise<UserModel | null>;
    exists(filter: SimpleFilter<UserRecord>): Promise<boolean>;
    countDocuments(filter?: SimpleFilter<UserRecord>): Promise<number>;
};

const defaultUserFindOne = UserModel.findOne.bind(UserModel) as (
    options?: FindOptions,
) => Promise<UserModel | null>;

const User = UserModel as UserWithHelpers;

User.find = (filter = {}) => buildDocumentQuery<UserModel, UserRecord>(UserModel, filter);

User.findOne = (options?: FindOptions | SimpleFilter<UserRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultUserFindOne(options);
    }

    return findOneByFilter<UserModel, UserRecord>({ findOne: defaultUserFindOne }, options);
};

User.findById = (id) => UserModel.findByPk(Number(id)) as Promise<UserModel | null>;

User.exists = async (filter) => Boolean(await User.findOne(filter));

User.countDocuments = (filter = {}) =>
    countDocumentsByFilter<UserModel, UserRecord>(UserModel, filter);

export default User;
