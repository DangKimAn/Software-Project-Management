import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const paymentTransactionTypeValues = ["authorization", "capture", "payment", "refund", "void"] as const;
export type PaymentTransactionType = (typeof paymentTransactionTypeValues)[number];

export const paymentTransactionStatusValues = ["pending", "succeeded", "failed", "cancelled"] as const;
export type PaymentTransactionStatus = (typeof paymentTransactionStatusValues)[number];

class PaymentTransactionModel extends Model<
    InferAttributes<PaymentTransactionModel>,
    InferCreationAttributes<PaymentTransactionModel>
> {
    declare transactionId: CreationOptional<number>;
    declare paymentId: number;
    declare bookingId: number;
    declare provider: CreationOptional<string | null>;
    declare providerTxnRef: CreationOptional<string | null>;
    declare providerTransactionNo: CreationOptional<string | null>;
    declare transactionType: CreationOptional<PaymentTransactionType>;
    declare status: CreationOptional<PaymentTransactionStatus>;
    declare amount: number;
    declare currency: CreationOptional<string>;
    declare rawPayloadJson: CreationOptional<Record<string, unknown> | null>;
    declare processedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

PaymentTransactionModel.init(
    {
        transactionId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "transaction_id",
        },
        paymentId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "payment_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "booking_id",
        },
        provider: {
            type: DataTypes.STRING(64),
            allowNull: true,
        },
        providerTxnRef: {
            type: DataTypes.STRING(100),
            allowNull: true,
            unique: true,
            field: "provider_txn_ref",
        },
        providerTransactionNo: {
            type: DataTypes.STRING(64),
            allowNull: true,
            field: "provider_transaction_no",
        },
        transactionType: {
            type: DataTypes.ENUM(...paymentTransactionTypeValues),
            allowNull: false,
            defaultValue: "payment",
            field: "transaction_type",
        },
        status: {
            type: DataTypes.ENUM(...paymentTransactionStatusValues),
            allowNull: false,
            defaultValue: "pending",
        },
        amount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
        },
        currency: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VND",
        },
        rawPayloadJson: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "raw_payload_json",
        },
        processedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "processed_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "payment_transactions",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, fields: ["provider_txn_ref"] },
            {
                name: "uq_payment_transactions_provider_transaction_id",
                unique: true,
                fields: ["provider", "transaction_type", "provider_transaction_no"],
            },
            { fields: ["payment_id", "status"] },
            { fields: ["booking_id"] },
            { fields: ["provider_transaction_no"] },
        ],
    },
);

export default PaymentTransactionModel;
