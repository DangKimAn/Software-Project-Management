import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class SearchLogModel extends Model<
    InferAttributes<SearchLogModel>,
    InferCreationAttributes<SearchLogModel>
> {
    declare id: CreationOptional<number>;
    declare userId: number | null;
    declare query: string;
    declare parsedFilters: Record<string, unknown> | null;
    declare resultListingIds: number[];
    declare clickedListingId: number | null;
    declare bookedListingId: number | null;
    declare createdAt: CreationOptional<Date>;
}

SearchLogModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "user_id",
        },
        query: {
            type: DataTypes.STRING(500),
            allowNull: false,
        },
        parsedFilters: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "parsed_filters",
        },
        resultListingIds: {
            type: DataTypes.JSON,
            allowNull: false,
            field: "result_listing_ids",
        },
        clickedListingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "clicked_listing_id",
        },
        bookedListingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "booked_listing_id",
        },
        createdAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "search_logs",
        underscored: true,
        timestamps: true,
        updatedAt: false,
        indexes: [
            {
                fields: ["user_id", "created_at"],
            },
            {
                fields: ["created_at"],
            },
        ],
    },
);

export type SearchLogDocument = SearchLogModel;
export default SearchLogModel;
