import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class SemanticSynonymModel extends Model<
    InferAttributes<SemanticSynonymModel>,
    InferCreationAttributes<SemanticSynonymModel>
> {
    declare id: CreationOptional<number>;
    declare keyword: string;
    declare synonyms: string[];
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

SemanticSynonymModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        keyword: {
            type: DataTypes.STRING(120),
            allowNull: false,
        },
        synonyms: {
            type: DataTypes.JSON,
            allowNull: false,
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "semantic_synonyms",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["keyword"],
            },
        ],
    },
);

export type SemanticSynonymDocument = SemanticSynonymModel;
export default SemanticSynonymModel;
