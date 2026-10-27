import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class ListingImageModel extends Model<
    InferAttributes<ListingImageModel>,
    InferCreationAttributes<ListingImageModel>
> {
    declare id: CreationOptional<number>;
    declare listingId: number;
    declare url: string;
    declare objectKey: string | null;
    declare originalFilename: string | null;
    declare caption: string | null;
    declare displayTitle: string | null;
    declare altText: string | null;
    declare aiImageType: string | null;
    declare aiSceneTags: string[] | string | null;
    declare aiAmenityTags: string[] | string | null;
    declare aiDescription: string | null;
    declare aiConfidence: number | string | null;
    declare aiQualityWarnings: string[] | string | null;
    declare aiAnalysisStatus: CreationOptional<"pending" | "analyzed" | "failed">;
    declare aiErrorMessage: string | null;
    declare aiAnalyzedAt: Date | null;
    declare sortOrder: number;
    declare isCover: boolean;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ListingImageModel.init(
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
        url: {
            type: DataTypes.STRING(1024),
            allowNull: false,
        },
        objectKey: {
            type: DataTypes.STRING(1024),
            allowNull: true,
            field: "object_key",
        },
        originalFilename: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "original_filename",
        },
        caption: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        displayTitle: {
            type: DataTypes.STRING(120),
            allowNull: true,
            field: "display_title",
        },
        altText: {
            type: DataTypes.STRING(500),
            allowNull: true,
            field: "alt_text",
        },
        aiImageType: {
            type: DataTypes.STRING(50),
            allowNull: true,
            field: "ai_image_type",
        },
        aiSceneTags: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "ai_scene_tags",
        },
        aiAmenityTags: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "ai_amenity_tags",
        },
        aiDescription: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "ai_description",
        },
        aiConfidence: {
            type: DataTypes.DECIMAL(5, 4),
            allowNull: true,
            field: "ai_confidence",
        },
        aiQualityWarnings: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "ai_quality_warnings",
        },
        aiAnalysisStatus: {
            type: DataTypes.ENUM("pending", "analyzed", "failed"),
            allowNull: false,
            defaultValue: "pending",
            field: "ai_analysis_status",
        },
        aiErrorMessage: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "ai_error_message",
        },
        aiAnalyzedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "ai_analyzed_at",
        },
        sortOrder: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
            field: "sort_order",
        },
        isCover: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "is_cover",
        },
        createdAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "created_at",
        },
        updatedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "updated_at",
        },
    },
    {
        sequelize,
        tableName: "listing_images",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["listing_id", "sort_order"],
            },
            {
                fields: ["listing_id"],
            },
        ],
    },
);

export type ListingImageDocument = ListingImageModel;
export default ListingImageModel;
