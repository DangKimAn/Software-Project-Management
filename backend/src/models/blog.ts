import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export const blogStatusValues = ["draft", "published"] as const;
export type BlogStatus = (typeof blogStatusValues)[number];

class BlogModel extends Model<InferAttributes<BlogModel>, InferCreationAttributes<BlogModel>> {
    declare blogId: CreationOptional<number>;
    declare slug: string;
    declare title: string;
    declare categoryId: CreationOptional<number | null>;
    declare categoryName: string;
    declare readTime: CreationOptional<string | null>;
    declare location: CreationOptional<string | null>;
    declare excerpt: string;
    declare coverImage: CreationOptional<string | null>;
    declare content: string[];
    declare status: CreationOptional<BlogStatus>;
    declare publishedAt: CreationOptional<Date | null>;
    declare createdByUserId: CreationOptional<number | null>;
    declare updatedByUserId: CreationOptional<number | null>;
    declare deletedAt: CreationOptional<Date | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

BlogModel.init(
    {
        blogId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "blog_id",
        },
        slug: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: true,
        },
        title: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        categoryId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "category_id",
        },
        categoryName: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "category_name",
        },
        readTime: {
            type: DataTypes.STRING(64),
            allowNull: true,
            field: "read_time",
        },
        location: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        excerpt: {
            type: DataTypes.TEXT,
            allowNull: false,
        },
        coverImage: {
            type: DataTypes.STRING(1024),
            allowNull: true,
            field: "cover_image",
        },
        content: {
            type: DataTypes.JSON,
            allowNull: false,
            field: "content_json",
            defaultValue: [],
        },
        status: {
            type: DataTypes.ENUM(...blogStatusValues),
            allowNull: false,
            defaultValue: "published",
        },
        publishedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "published_at",
        },
        createdByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "created_by_user_id",
        },
        updatedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "updated_by_user_id",
        },
        deletedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "deleted_at",
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
        tableName: "blogs",
        modelName: "Blog",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["slug"],
            },
            {
                fields: ["status", "published_at", "deleted_at"],
            },
            {
                fields: ["category_id"],
            },
        ],
    },
);

export type BlogDocument = BlogModel;
export default BlogModel;
