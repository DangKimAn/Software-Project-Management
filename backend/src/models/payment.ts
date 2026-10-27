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
    parseJsonValue,
    SimpleFilter,
    stringifyJsonValue,
} from "./mysql-helpers";

export const paymentMethodValues = ["vnpay", "momo"] as const;
export type PaymentMethod = (typeof paymentMethodValues)[number];

export const paymentStatusValues = ["pending", "paid", "failed", "cancelled", "expired", "refunded"] as const;
export type PaymentStatus = (typeof paymentStatusValues)[number];

export type PaymentRecord = {
    id: number;
    paymentId: number;
    bookingId: number;
    userId: number;
    amount: number;
    currency: string;
    method: PaymentMethod;
    status: PaymentStatus;
    provider: string | null;
    providerTxnRef: string | null;
    providerTransactionNo: string | null;
    providerResponseCode: string | null;
    providerPayload: Record<string, unknown> | null;
    paidAt: Date | null;
    failedAt: Date | null;
    refundedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;

};

class PaymentModel extends Model<InferAttributes<PaymentModel>, InferCreationAttributes<PaymentModel>> {
    declare id: CreationOptional<number>;
    declare paymentId: number;
    declare bookingId: number;
    declare userId: number;
    declare amount: number;
    declare currency: string;
    declare method: PaymentMethod;
    declare status: PaymentStatus;
    declare provider: string | null;
    declare providerTxnRef: string | null;
    declare providerTransactionNo: string | null;
    declare providerResponseCode: string | null;
    declare providerPayload: Record<string, unknown> | null;
    declare paidAt: Date | null;
    declare failedAt: Date | null;
    declare refundedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
    declare expiresAt: Date | null;
    declare expiredAt: Date | null;
}

PaymentModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        paymentId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "payment_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "booking_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
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
        method: {
            type: DataTypes.ENUM(...paymentMethodValues),
            allowNull: false,
        },
        status: {
            type: DataTypes.ENUM(...paymentStatusValues),
            allowNull: false,
            defaultValue: "pending",
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
        providerResponseCode: {
            type: DataTypes.STRING(16),
            allowNull: true,
            field: "provider_response_code",
        },
        providerPayload: {
            type: DataTypes.TEXT("long"),
            allowNull: true,
            field: "provider_payload",
            get() {
                return parseJsonValue<Record<string, unknown> | null>(
                    this.getDataValue("providerPayload"),
                    null,
                );
            },
            set(value: Record<string, unknown> | null) {
                this.setDataValue(
                    "providerPayload",
                    value ? (stringifyJsonValue(value) as never) : null,
                );
            },
        },
        paidAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "paid_at",
        },
        failedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "failed_at",
        },
        refundedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "refunded_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
        expiresAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "expires_at",
        },
        expiredAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "expired_at",
        },
    },
    {
        sequelize,
        tableName: "payments",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["payment_id"],
            },
            {
                fields: ["booking_id", "status"],
            },
            {
                fields: ["user_id", "status"],
            },
            {
                unique: true,
                fields: ["provider_txn_ref"],
            },
            {
                name: "idx_payments_status_expires_at",
                fields: ["status", "expires_at"],
            },
        ],
    },
);

export type PaymentDocument = PaymentModel;
type PaymentWithHelpers = typeof PaymentModel & {
    find(filter?: SimpleFilter<PaymentRecord>): MySqlQuery<PaymentModel>;
    findOne(options?: FindOptions | SimpleFilter<PaymentRecord>): Promise<PaymentModel | null>;
    countDocuments(filter?: SimpleFilter<PaymentRecord>): Promise<number>;
};

const defaultPaymentFindOne = PaymentModel.findOne.bind(PaymentModel) as (
    options?: FindOptions,
) => Promise<PaymentModel | null>;

const Payment = PaymentModel as PaymentWithHelpers;

Payment.find = (filter = {}) => buildDocumentQuery<PaymentModel, PaymentRecord>(PaymentModel, filter);

Payment.findOne = (options?: FindOptions | SimpleFilter<PaymentRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultPaymentFindOne(options);
    }

    return findOneByFilter<PaymentModel, PaymentRecord>({ findOne: defaultPaymentFindOne }, options);
};

Payment.countDocuments = (filter = {}) =>
    countDocumentsByFilter<PaymentModel, PaymentRecord>(PaymentModel, filter);

export default Payment;
