import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class WishlistModel extends Model<InferAttributes<WishlistModel>, InferCreationAttributes<WishlistModel>> {
    declare wishlistId: CreationOptional<number>;
    declare userId: number;
    declare listingId: number;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

WishlistModel.init(
    {
        wishlistId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "wishlist_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        createdAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "created_at",
        },
        updatedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "updated_at",
        },
    },
    {
        sequelize,
        tableName: "wishlists",
        modelName: "Wishlist",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                name: "uniq_wishlists_user_listing",
                fields: ["user_id", "listing_id"],
            },
            {
                name: "idx_wishlists_user_created",
                fields: ["user_id", "created_at"],
            },
            {
                name: "idx_wishlists_listing",
                fields: ["listing_id"],
            },
        ],
    },
);

export type WishlistDocument = WishlistModel;
export default WishlistModel;
