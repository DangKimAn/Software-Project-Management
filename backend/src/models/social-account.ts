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
    deleteOneByFilter,
    findOneByFilter,
    isFindOptions,
    SimpleFilter,
} from "./mysql-helpers";

export const socialProviderValues = ["google"] as const;
export type SocialProvider = (typeof socialProviderValues)[number];
export type SocialAccountRecord = {
    id: number;
    userId: number;
    provider: SocialProvider;
    providerUid: string;
    createdAt: Date;
    updatedAt: Date;
};

class SocialAccountModel extends Model<
    InferAttributes<SocialAccountModel, { omit: "_id" }>,
    InferCreationAttributes<SocialAccountModel, { omit: "_id" }>
> {
    declare id: CreationOptional<number>;
    declare userId: number;
    declare provider: SocialProvider;
    declare providerUid: string;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;

    get _id() {
        return this.id;
    }
}

SocialAccountModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        provider: {
            type: DataTypes.ENUM(...socialProviderValues),
            allowNull: false,
        },
        providerUid: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "provider_uid",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "social_accounts",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["provider", "provider_uid"],
            },
            {
                unique: true,
                fields: ["provider", "user_id"],
            },
        ],
    },
);

export type SocialAccountDocument = SocialAccountModel;
type SocialAccountWithHelpers = typeof SocialAccountModel & {
    find(filter?: SimpleFilter<SocialAccountRecord>): MySqlQuery<SocialAccountModel>;
    findOne(options?: FindOptions | SimpleFilter<SocialAccountRecord>): Promise<SocialAccountModel | null>;
    deleteOne(filter: SimpleFilter<SocialAccountRecord>): Promise<number>;
};

const defaultSocialAccountFindOne = SocialAccountModel.findOne.bind(SocialAccountModel) as (
    options?: FindOptions,
) => Promise<SocialAccountModel | null>;

const SocialAccount = SocialAccountModel as SocialAccountWithHelpers;

SocialAccount.find = (filter = {}) =>
    buildDocumentQuery<SocialAccountModel, SocialAccountRecord>(SocialAccountModel, filter);

SocialAccount.findOne = (options?: FindOptions | SimpleFilter<SocialAccountRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultSocialAccountFindOne(options);
    }

    return findOneByFilter<SocialAccountModel, SocialAccountRecord>(
        { findOne: defaultSocialAccountFindOne },
        options,
    );
};

SocialAccount.deleteOne = (filter) =>
    deleteOneByFilter<SocialAccountModel, SocialAccountRecord>(SocialAccountModel, filter);

export default SocialAccount;
