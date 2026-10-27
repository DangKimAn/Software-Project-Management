import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class ReviewReplyModel extends Model<
    InferAttributes<ReviewReplyModel>,
    InferCreationAttributes<ReviewReplyModel>
> {
    declare id: CreationOptional<number>;
    declare reviewId: number;
    declare hostId: number;
    declare reply: string;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ReviewReplyModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        reviewId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "review_id",
        },
        hostId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_id",
        },
        reply: {
            type: DataTypes.TEXT,
            allowNull: false,
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "review_replies",
        underscored: true,
        timestamps: true,
        indexes: [
            { unique: true, fields: ["review_id"] },
            { fields: ["host_id"] },
        ],
    },
);

export default ReviewReplyModel;
