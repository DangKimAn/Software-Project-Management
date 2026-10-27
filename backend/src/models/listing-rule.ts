import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class ListingRuleModel extends Model<
    InferAttributes<ListingRuleModel>,
    InferCreationAttributes<ListingRuleModel>
> {
    declare id: CreationOptional<number>;
    declare listingId: number;
    declare checkInFrom: string | null;
    declare checkOutBefore: string | null;
    declare smokingAllowed: boolean;
    declare petsAllowed: boolean;
    declare partyAllowed: boolean;
    declare quietHours: string | null;
    declare extraRules: string | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ListingRuleModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "listing_id",
        },
        checkInFrom: {
            type: DataTypes.TIME,
            allowNull: true,
            field: "check_in_from",
        },
        checkOutBefore: {
            type: DataTypes.TIME,
            allowNull: true,
            field: "check_out_before",
        },
        smokingAllowed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "smoking_allowed",
        },
        petsAllowed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "pets_allowed",
        },
        partyAllowed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "party_allowed",
        },
        quietHours: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "quiet_hours",
        },
        extraRules: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "extra_rules",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "listing_rules",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["listing_id"],
            },
        ],
    },
);

export type ListingRuleDocument = ListingRuleModel;
export default ListingRuleModel;
