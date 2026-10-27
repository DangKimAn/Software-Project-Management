import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class ListingEmbeddingModel extends Model<
    InferAttributes<ListingEmbeddingModel>,
    InferCreationAttributes<ListingEmbeddingModel>
> {
    declare id: CreationOptional<number>;
    declare listingId: number;
    declare embeddingProvider: string;
    declare embeddingModel: string;
    declare embeddingVector: number[] | null;
    declare qdrantPointId: string | null;
    declare searchableText: string;
    declare version: string;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ListingEmbeddingModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        embeddingProvider: {
            type: DataTypes.STRING(64),
            allowNull: false,
            field: "embedding_provider",
        },
        embeddingModel: {
            type: DataTypes.STRING(128),
            allowNull: false,
            field: "embedding_model",
        },
        embeddingVector: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "embedding_vector",
        },
        qdrantPointId: {
            type: DataTypes.STRING(128),
            allowNull: true,
            field: "qdrant_point_id",
        },
        searchableText: {
            type: DataTypes.TEXT("long"),
            allowNull: false,
            field: "searchable_text",
        },
        version: {
            type: DataTypes.STRING(64),
            allowNull: false,
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "listing_embeddings",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["listing_id", "embedding_provider", "embedding_model", "version"],
                name: "listing_embeddings_unique_model_version",
            },
            {
                fields: ["listing_id"],
            },
        ],
    },
);

export type ListingEmbeddingDocument = ListingEmbeddingModel;
export default ListingEmbeddingModel;
