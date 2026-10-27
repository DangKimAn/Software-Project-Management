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
    findOneByFilter,
    isFindOptions,
    SimpleFilter,
    updateOneByFilter,
} from "./mysql-helpers";

export type RefreshSessionRecord = {
    id: number;
    sessionId: string;
    userId: number;
    tokenHash: string;
    expiresAt: Date;
    revokedAt: Date | null;
    ipAddress: string | null;
    userAgent: string | null;
    deviceId: string | null;
    deviceName: string | null;
    createdAt: Date;
    updatedAt: Date;
};

class RefreshSessionModel extends Model<
    InferAttributes<RefreshSessionModel, { omit: "_id" | "jti" }>,
    InferCreationAttributes<RefreshSessionModel, { omit: "_id" | "jti" }>
> {
    declare id: CreationOptional<number>;
    declare sessionId: string;
    declare userId: number;
    declare tokenHash: string;
    declare expiresAt: Date;
    declare revokedAt: Date | null;
    declare ipAddress: string | null;
    declare userAgent: string | null;
    declare deviceId: CreationOptional<string | null>;
    declare deviceName: CreationOptional<string | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;

    get _id() {
        return this.id;
    }

    get jti() {
        return this.sessionId;
    }
}

RefreshSessionModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        sessionId: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: true,
            field: "session_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        tokenHash: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: true,
            field: "token_hash",
        },
        expiresAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "expires_at",
        },
        revokedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "revoked_at",
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
        deviceId: {
            type: DataTypes.STRING(128),
            allowNull: true,
            field: "device_id",
        },
        deviceName: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "device_name",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "refresh_sessions",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                fields: ["user_id"],
            },
            {
                fields: ["expires_at"],
            },
        ],
    },
);

export type RefreshSessionDocument = RefreshSessionModel;
type RefreshSessionWithHelpers = typeof RefreshSessionModel & {
    find(filter?: SimpleFilter<RefreshSessionRecord>): MySqlQuery<RefreshSessionModel>;
    findOne(options?: FindOptions | SimpleFilter<RefreshSessionRecord>): Promise<RefreshSessionModel | null>;
    updateOne(
        filter: SimpleFilter<RefreshSessionRecord>,
        update: { $set: Partial<RefreshSessionModel> },
    ): Promise<[number]>;
};

const defaultRefreshSessionFindOne = RefreshSessionModel.findOne.bind(RefreshSessionModel) as (
    options?: FindOptions,
) => Promise<RefreshSessionModel | null>;

const RefreshSession = RefreshSessionModel as RefreshSessionWithHelpers;

RefreshSession.find = (filter = {}) =>
    buildDocumentQuery<RefreshSessionModel, RefreshSessionRecord>(RefreshSessionModel, filter);

RefreshSession.findOne = (options?: FindOptions | SimpleFilter<RefreshSessionRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultRefreshSessionFindOne(options);
    }

    return findOneByFilter<RefreshSessionModel, RefreshSessionRecord>(
        { findOne: defaultRefreshSessionFindOne },
        options,
    );
};

RefreshSession.updateOne = (filter, update) =>
    updateOneByFilter<RefreshSessionModel, RefreshSessionRecord>(
        RefreshSessionModel,
        filter,
        update.$set as Record<string, unknown>,
    );

export default RefreshSession;
