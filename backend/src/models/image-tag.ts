import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export type ImageTagSource = "ai" | "host" | "admin";

class ImageTagModel extends Model<InferAttributes<ImageTagModel>, InferCreationAttributes<ImageTagModel>> {
    declare id: CreationOptional<number>;
    declare imageId: number;
    declare listingId: number;
    declare tag: string;
    declare tagGroup: string;
    declare confidence: number | string | null;
    declare source: CreationOptional<ImageTagSource>;
    declare createdAt: CreationOptional<Date>;
}

ImageTagModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        imageId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "image_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        tag: {
            type: DataTypes.STRING(80),
            allowNull: false,
        },
        tagGroup: {
            type: DataTypes.STRING(50),
            allowNull: false,
            field: "tag_group",
        },
        confidence: {
            type: DataTypes.DECIMAL(5, 4),
            allowNull: true,
        },
        source: {
            type: DataTypes.ENUM("ai", "host", "admin"),
            allowNull: false,
            defaultValue: "ai",
        },
        createdAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "created_at",
        },
    },
    {
        sequelize,
        tableName: "image_tags",
        underscored: true,
        timestamps: false,
        indexes: [
            {
                fields: ["image_id"],
            },
            {
                fields: ["listing_id", "tag"],
            },
            {
                unique: true,
                fields: ["image_id", "tag"],
            },
        ],
    },
);

export type ImageTagDocument = ImageTagModel;
export default ImageTagModel;
