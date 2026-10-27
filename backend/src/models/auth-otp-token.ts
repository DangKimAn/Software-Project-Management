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

export const authOtpPurposeValues = ["sign_up", "forgot_password", "verify_email", "verify_phone"] as const;
export type AuthOtpPurpose = (typeof authOtpPurposeValues)[number];

export type AuthOtpTokenRecord = {
    otpTokenId: number;
    userId: number | null;
    identifier: string;
    purpose: AuthOtpPurpose;
    tokenHash: string;
    expiresAt: Date;
    consumedAt: Date | null;
    usedAt: Date | null;
    attemptCount: number;
    sentAt: Date;
    ipAddress: string | null;
    userAgent: string | null;
    createdAt: Date;
    updatedAt: Date;
};

class AuthOtpTokenModel extends Model<
    InferAttributes<AuthOtpTokenModel>,
    InferCreationAttributes<AuthOtpTokenModel>
> {
    declare otpTokenId: CreationOptional<number>;
    declare userId: number | null;
    declare identifier: string;
    declare purpose: AuthOtpPurpose;
    declare tokenHash: string;
    declare expiresAt: Date;
    declare consumedAt: Date | null;
    declare usedAt: CreationOptional<Date | null>;
    declare attemptCount: CreationOptional<number>;
    declare sentAt: Date;
    declare ipAddress: string | null;
    declare userAgent: string | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

AuthOtpTokenModel.init(
    {
        otpTokenId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "otp_token_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "user_id",
        },
        identifier: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        purpose: {
            type: DataTypes.ENUM(...authOtpPurposeValues),
            allowNull: false,
        },
        tokenHash: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "token_hash",
        },
        expiresAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "expires_at",
        },
        consumedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "consumed_at",
        },
        usedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "used_at",
        },
        attemptCount: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "attempt_count",
        },
        sentAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "sent_at",
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
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "auth_otp_tokens",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                fields: ["user_id", "purpose", "expires_at"],
            },
            {
                fields: ["identifier", "purpose", "sent_at"],
            },
            {
                fields: ["token_hash"],
            },
        ],
    },
);

export type AuthOtpTokenDocument = AuthOtpTokenModel;
type AuthOtpTokenWithHelpers = typeof AuthOtpTokenModel & {
    find(filter?: SimpleFilter<AuthOtpTokenRecord>): MySqlQuery<AuthOtpTokenModel>;
    findOne(options?: FindOptions | SimpleFilter<AuthOtpTokenRecord>): Promise<AuthOtpTokenModel | null>;
    countDocuments(filter?: SimpleFilter<AuthOtpTokenRecord>): Promise<number>;
};

const defaultAuthOtpTokenFindOne = AuthOtpTokenModel.findOne.bind(AuthOtpTokenModel) as (
    options?: FindOptions,
) => Promise<AuthOtpTokenModel | null>;

const AuthOtpToken = AuthOtpTokenModel as AuthOtpTokenWithHelpers;

AuthOtpToken.find = (filter = {}) =>
    buildDocumentQuery<AuthOtpTokenModel, AuthOtpTokenRecord>(AuthOtpTokenModel, filter);

AuthOtpToken.findOne = (options?: FindOptions | SimpleFilter<AuthOtpTokenRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultAuthOtpTokenFindOne(options);
    }

    return findOneByFilter<AuthOtpTokenModel, AuthOtpTokenRecord>(
        { findOne: defaultAuthOtpTokenFindOne },
        options,
    );
};

AuthOtpToken.countDocuments = (filter = {}) =>
    countDocumentsByFilter<AuthOtpTokenModel, AuthOtpTokenRecord>(AuthOtpTokenModel, filter);

export default AuthOtpToken;
