import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class CouponRedemptionModel extends Model<
    InferAttributes<CouponRedemptionModel>,
    InferCreationAttributes<CouponRedemptionModel>
> {
    declare id: CreationOptional<number>;
    declare couponId: number;
    declare userId: number;
    declare bookingId: number;
    declare discountAmount: CreationOptional<number>;
    declare redeemedAt: CreationOptional<Date>;
}

CouponRedemptionModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        couponId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "coupon_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "booking_id",
        },
        discountAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            defaultValue: 0,
            field: "discount_amount",
        },
        redeemedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "redeemed_at",
        },
    },
    {
        sequelize,
        tableName: "coupon_redemptions",
        underscored: true,
        timestamps: false,
        indexes: [
            { unique: true, fields: ["coupon_id", "user_id", "booking_id"] },
            { unique: true, fields: ["coupon_id", "booking_id"] },
            { fields: ["coupon_id"] },
            { fields: ["user_id"] },
        ],
    },
);

export default CouponRedemptionModel;
