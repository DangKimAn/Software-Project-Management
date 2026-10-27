import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const refundStatusValues = ["pending", "processing", "succeeded", "failed", "cancelled"] as const;
export type RefundStatus = (typeof refundStatusValues)[number];

class RefundModel extends Model<InferAttributes<RefundModel>, InferCreationAttributes<RefundModel>> {
    declare refundId: CreationOptional<number>;
    declare paymentId: number;
    declare bookingId: number;
    declare amount: number;
    declare currency: CreationOptional<string>;
    declare reason: CreationOptional<string | null>;
    declare status: CreationOptional<RefundStatus>;
    declare providerRef: CreationOptional<string | null>;
    declare requestedByUserId: CreationOptional<number | null>;
    declare processedByUserId: CreationOptional<number | null>;
    declare processedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

RefundModel.init(
    {
        refundId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "refund_id",
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
        amount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
        },
        currency: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VND",
        },
        reason: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        status: {
            type: DataTypes.ENUM(...refundStatusValues),
            allowNull: false,
            defaultValue: "pending",
        },
        providerRef: {
            type: DataTypes.STRING(100),
            allowNull: true,
            unique: true,
            field: "provider_ref",
        },
        requestedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "requested_by_user_id",
        },
        processedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "processed_by_user_id",
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
        tableName: "refunds",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, fields: ["provider_ref"] },
            { fields: ["payment_id", "status"] },
            { fields: ["booking_id"] },
            { fields: ["requested_by_user_id"] },
            { fields: ["processed_by_user_id"] },
        ],
    },
);

export default RefundModel;
