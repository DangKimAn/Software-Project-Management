import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class BlogCategoryModel extends Model<
    InferAttributes<BlogCategoryModel>,
    InferCreationAttributes<BlogCategoryModel>
> {
    declare categoryId: CreationOptional<number>;
    declare name: string;
    declare slug: string;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

BlogCategoryModel.init(
    {
        categoryId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "category_id",
        },
        name: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: true,
        },
        slug: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: true,
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
        tableName: "blog_categories",
        modelName: "BlogCategory",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["slug"],
            },
            {
                unique: true,
                fields: ["name"],
            },
        ],
    },
);

export type BlogCategoryDocument = BlogCategoryModel;
export default BlogCategoryModel;
