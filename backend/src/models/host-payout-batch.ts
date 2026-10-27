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

export const hostPayoutStatusValues = [
    "pending",
    "approved",
    "processing",
    "paid",
    "failed",
    "rejected",
    "cancelled",
] as const;
export type HostPayoutStatus = (typeof hostPayoutStatusValues)[number];

export type HostPayoutBatchRecord = {
    payoutId: number;
    hostId: number;
    payoutAccountId: number;
    amount: number;
    currency: string;
    status: HostPayoutStatus;
    notes: string | null;
    createdByUserId: number | null;
    approvedByUserId: number | null;
    approvedAt: Date | null;
    rejectedByUserId: number | null;
    rejectedAt: Date | null;
    rejectionReason: string | null;
    paidAt: Date | null;
    paidByUserId: number | null;
    transferReference: string | null;
    createdAt: Date;
    updatedAt: Date;
};

class HostPayoutBatchModel extends Model<
    InferAttributes<HostPayoutBatchModel>,
    InferCreationAttributes<HostPayoutBatchModel>
> {
    declare payoutId: CreationOptional<number>;
    declare hostId: number;
    declare payoutAccountId: number;
    declare amount: number;
    declare currency: string;
    declare status: HostPayoutStatus;
    declare notes: string | null;
    declare createdByUserId: number | null;
    declare approvedByUserId: number | null;
    declare approvedAt: Date | null;
    declare rejectedByUserId: number | null;
    declare rejectedAt: Date | null;
    declare rejectionReason: string | null;
    declare paidAt: Date | null;
    declare paidByUserId: number | null;
    declare transferReference: string | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostPayoutBatchModel.init(
    {
        payoutId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "payout_id",
        },
        hostId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_id",
        },
        payoutAccountId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "payout_account_id",
        },
        amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
        },
        currency: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VND",
        },
        status: {
            type: DataTypes.ENUM(...hostPayoutStatusValues),
            allowNull: false,
            defaultValue: "pending",
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        createdByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "created_by_user_id",
        },
        approvedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "approved_by_user_id",
        },
        approvedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "approved_at",
        },
        rejectedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "rejected_by_user_id",
        },
        rejectedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "rejected_at",
        },
        rejectionReason: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "rejection_reason",
        },
        paidAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "paid_at",
        },
        paidByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "paid_by_user_id",
        },
        transferReference: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "transfer_reference",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "host_payout_batch",
        underscored: true,
        timestamps: true,
    },
);

export type HostPayoutBatchDocument = HostPayoutBatchModel;
type HostPayoutBatchWithHelpers = typeof HostPayoutBatchModel & {
    find(filter?: SimpleFilter<HostPayoutBatchRecord>): MySqlQuery<HostPayoutBatchModel>;
    findOne(
        options?: FindOptions | SimpleFilter<HostPayoutBatchRecord>,
    ): Promise<HostPayoutBatchModel | null>;
    countDocuments(filter?: SimpleFilter<HostPayoutBatchRecord>): Promise<number>;
};

const defaultHostPayoutFindOne = HostPayoutBatchModel.findOne.bind(HostPayoutBatchModel) as (
    options?: FindOptions,
) => Promise<HostPayoutBatchModel | null>;

const HostPayoutBatch = HostPayoutBatchModel as HostPayoutBatchWithHelpers;

HostPayoutBatch.find = (filter = {}) =>
    buildDocumentQuery<HostPayoutBatchModel, HostPayoutBatchRecord>(HostPayoutBatchModel, filter);

HostPayoutBatch.findOne = (options?: FindOptions | SimpleFilter<HostPayoutBatchRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultHostPayoutFindOne(options);
    }

    return findOneByFilter<HostPayoutBatchModel, HostPayoutBatchRecord>(
        { findOne: defaultHostPayoutFindOne },
        options,
    );
};

HostPayoutBatch.countDocuments = (filter = {}) =>
    countDocumentsByFilter<HostPayoutBatchModel, HostPayoutBatchRecord>(HostPayoutBatchModel, filter);

export default HostPayoutBatch;
