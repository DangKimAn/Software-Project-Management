import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export type ImageAnalysisStatus = "pending" | "analyzed" | "failed";

class ImageAnalysisResultModel extends Model<
    InferAttributes<ImageAnalysisResultModel>,
    InferCreationAttributes<ImageAnalysisResultModel>
> {
    declare id: CreationOptional<number>;
    declare imageId: number;
    declare provider: string | null;
    declare model: string | null;
    declare status: CreationOptional<ImageAnalysisStatus>;
    declare caption: string | null;
    declare roomType: string | null;
    declare detectedObjects: string[] | string | null;
    declare amenities: string[] | string | null;
    declare styleTags: string[] | string | null;
    declare qualityTags: string[] | string | null;
    declare rawResponse: Record<string, unknown> | string | null;
    declare confidence: number | string | null;
    declare errorMessage: string | null;
    declare analyzedAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ImageAnalysisResultModel.init(
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
        provider: {
            type: DataTypes.STRING(64),
            allowNull: true,
        },
        model: {
            type: DataTypes.STRING(120),
            allowNull: true,
        },
        status: {
            type: DataTypes.ENUM("pending", "analyzed", "failed"),
            allowNull: false,
            defaultValue: "pending",
        },
        caption: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        roomType: {
            type: DataTypes.STRING(64),
            allowNull: true,
            field: "room_type",
        },
        detectedObjects: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "detected_objects",
        },
        amenities: {
            type: DataTypes.JSON,
            allowNull: true,
        },
        styleTags: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "style_tags",
        },
        qualityTags: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "quality_tags",
        },
        rawResponse: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "raw_response",
        },
        confidence: {
            type: DataTypes.DECIMAL(5, 4),
            allowNull: true,
        },
        errorMessage: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "error_message",
        },
        analyzedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "analyzed_at",
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
        tableName: "image_analysis_results",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                fields: ["image_id", "status"],
            },
            {
                fields: ["image_id", "analyzed_at"],
            },
        ],
    },
);

export type ImageAnalysisResultDocument = ImageAnalysisResultModel;
export default ImageAnalysisResultModel;
