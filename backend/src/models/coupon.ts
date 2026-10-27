import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const couponTypeValues = ["percent", "fixed_amount"] as const;
export type CouponType = (typeof couponTypeValues)[number];

class CouponModel extends Model<InferAttributes<CouponModel>, InferCreationAttributes<CouponModel>> {
    declare couponId: CreationOptional<number>;
    declare code: string;
    declare title: string;
    declare description: CreationOptional<string | null>;
    declare type: CouponType;
    declare discountValue: number;
    declare maxDiscountAmount: CreationOptional<number | null>;
    declare minOrderValue: CreationOptional<number | null>;
    declare startDate: Date;
    declare endDate: Date;
    declare totalLimit: CreationOptional<number | null>;
    declare usedCount: CreationOptional<number>;
    declare limitPerUser: CreationOptional<number | null>;
    declare isActive: CreationOptional<boolean>;
    declare deletedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

CouponModel.init(
    {
        couponId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "coupon_id",
        },
        code: {
            type: DataTypes.STRING(64),
            allowNull: false,
            unique: true,
        },
        title: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        type: {
            type: DataTypes.ENUM(...couponTypeValues),
            allowNull: false,
        },
        discountValue: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            field: "discount_value",
        },
        maxDiscountAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            field: "max_discount_amount",
        },
        minOrderValue: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            field: "min_order_value",
        },
        startDate: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "start_date",
        },
        endDate: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "end_date",
        },
        totalLimit: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "total_limit",
        },
        usedCount: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "used_count",
        },
        limitPerUser: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "limit_per_user",
        },
        isActive: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "is_active",
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
        tableName: "coupons",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, fields: ["code"] },
            { fields: ["is_active", "start_date", "end_date"] },
            { fields: ["deleted_at"] },
        ],
    },
);

export default CouponModel;
