import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class ListingAmenityModel extends Model<
    InferAttributes<ListingAmenityModel>,
    InferCreationAttributes<ListingAmenityModel>
> {
    declare listingId: number;
    declare amenityId: number;
    declare createdAt: CreationOptional<Date>;
}

ListingAmenityModel.init(
    {
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            primaryKey: true,
            field: "listing_id",
        },
        amenityId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            primaryKey: true,
            field: "amenity_id",
        },
        createdAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "listing_amenities",
        underscored: true,
        timestamps: false,
        indexes: [
            {
                fields: ["amenity_id"],
            },
        ],
    },
);

ListingAmenityModel.removeAttribute("id");

export type ListingAmenityDocument = ListingAmenityModel;
export default ListingAmenityModel;
