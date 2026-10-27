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

export type PayoutAccountRecord = {
    payoutAccountId: number;
    userId: number;
    bankName: string;
    bankCode: string | null;
    bankShortName: string | null;
    bankBin: string | null;
    accountName: string;
    branchName: string | null;
    accountNumber: string;
    accountNumberEncrypted: string | null;
    accountNumberHash: string | null;
    accountNumberLast4: string | null;
    isDefault: boolean;
    deletedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
};

class PayoutAccountModel extends Model<
    InferAttributes<PayoutAccountModel>,
    InferCreationAttributes<PayoutAccountModel>
> {
    declare payoutAccountId: CreationOptional<number>;
    declare userId: number;
    declare bankName: string;
    declare bankCode: string | null;
    declare bankShortName: CreationOptional<string | null>;
    declare bankBin: CreationOptional<string | null>;
    declare accountName: string;
    declare branchName: CreationOptional<string | null>;
    declare accountNumber: string;
    declare accountNumberEncrypted: CreationOptional<string | null>;
    declare accountNumberHash: CreationOptional<string | null>;
    declare accountNumberLast4: CreationOptional<string | null>;
    declare isDefault: boolean;
    declare deletedAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

PayoutAccountModel.init(
    {
        payoutAccountId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "payout_account_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        bankName: {
            type: DataTypes.STRING(150),
            allowNull: false,
            field: "bank_name",
        },
        bankCode: {
            type: DataTypes.STRING(32),
            allowNull: true,
            field: "bank_code",
        },
        bankShortName: {
            type: DataTypes.STRING(100),
            allowNull: true,
            field: "bank_short_name",
        },
        bankBin: {
            type: DataTypes.STRING(16),
            allowNull: true,
            field: "bank_bin",
        },
        accountName: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "account_name",
        },
        branchName: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "branch_name",
        },
        accountNumber: {
            type: DataTypes.STRING(64),
            allowNull: false,
            field: "account_number",
        },
        accountNumberEncrypted: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "account_number_encrypted",
        },
        accountNumberHash: {
            type: DataTypes.STRING(128),
            allowNull: true,
            field: "account_number_hash",
        },
        accountNumberLast4: {
            type: DataTypes.CHAR(4),
            allowNull: true,
            field: "account_number_last4",
        },
        isDefault: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_default",
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
        tableName: "payout_account",
        underscored: true,
        timestamps: true,
    },
);

export type PayoutAccountDocument = PayoutAccountModel;
type PayoutAccountWithHelpers = typeof PayoutAccountModel & {
    find(filter?: SimpleFilter<PayoutAccountRecord>): MySqlQuery<PayoutAccountModel>;
    findOne(options?: FindOptions | SimpleFilter<PayoutAccountRecord>): Promise<PayoutAccountModel | null>;
    countDocuments(filter?: SimpleFilter<PayoutAccountRecord>): Promise<number>;
};

const defaultPayoutAccountFindOne = PayoutAccountModel.findOne.bind(PayoutAccountModel) as (
    options?: FindOptions,
) => Promise<PayoutAccountModel | null>;

const PayoutAccount = PayoutAccountModel as PayoutAccountWithHelpers;

PayoutAccount.find = (filter = {}) =>
    buildDocumentQuery<PayoutAccountModel, PayoutAccountRecord>(PayoutAccountModel, filter);

PayoutAccount.findOne = (options?: FindOptions | SimpleFilter<PayoutAccountRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultPayoutAccountFindOne(options);
    }

    return findOneByFilter<PayoutAccountModel, PayoutAccountRecord>(
        { findOne: defaultPayoutAccountFindOne },
        options,
    );
};

PayoutAccount.countDocuments = (filter = {}) =>
    countDocumentsByFilter<PayoutAccountModel, PayoutAccountRecord>(PayoutAccountModel, filter);

export default PayoutAccount;
