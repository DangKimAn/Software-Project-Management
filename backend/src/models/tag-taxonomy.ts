import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class TagTaxonomyModel extends Model<
    InferAttributes<TagTaxonomyModel>,
    InferCreationAttributes<TagTaxonomyModel>
> {
    declare id: CreationOptional<number>;
    declare code: string;
    declare labelVi: string;
    declare group: string;
    declare aliases: string[] | string | null;
    declare isSearchable: CreationOptional<boolean>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

TagTaxonomyModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        code: {
            type: DataTypes.STRING(80),
            allowNull: false,
            unique: true,
        },
        labelVi: {
            type: DataTypes.STRING(120),
            allowNull: false,
            field: "label_vi",
        },
        group: {
            type: DataTypes.STRING(50),
            allowNull: false,
            field: "group",
        },
        aliases: {
            type: DataTypes.JSON,
            allowNull: true,
        },
        isSearchable: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "is_searchable",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "tag_taxonomies",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["code"],
            },
            {
                fields: ["group"],
            },
        ],
    },
);

export type TagTaxonomyDocument = TagTaxonomyModel;
export default TagTaxonomyModel;
