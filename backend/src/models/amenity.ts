import {
    CreationOptional,
    DataTypes,
    FindOptions,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";
import {
    MySqlQuery,
    buildDocumentQuery,
    countDocumentsByFilter,
    findOneByFilter,
    isFindOptions,
    SimpleFilter,
} from "./mysql-helpers";

export type AmenityRecord = {
    amenityId: number;
    name: string;
    icon: string | null;
    active: boolean;
    isActive: boolean;
    deletedAt: Date | null;
};

class AmenityModel extends Model<InferAttributes<AmenityModel>, InferCreationAttributes<AmenityModel>> {
    declare id: CreationOptional<number>;
    declare amenityId: number;
    declare name: string;
    declare icon: string | null;
    declare active: boolean;
    declare isActive: boolean;
    declare deletedAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

AmenityModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        amenityId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "amenity_id",
        },
        name: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        icon: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        active: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
        },
        isActive: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "is_active",
        },
        deletedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "deleted_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "amenities",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                fields: ["amenity_id"],
                unique: true,
            },
            {
                fields: ["is_active"],
            },
        ],
    },
);

export const defaultAmenities: AmenityRecord[] = [
    { amenityId: 1, name: "WiFi", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 2, name: "Air conditioning", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 3, name: "Washer", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 4, name: "Kitchen", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 5, name: "Pool", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 6, name: "Parking", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 7, name: "TV", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 8, name: "Balcony", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 9, name: "Fireplace", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 10, name: "Refrigerator", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 11, name: "Hair dryer", icon: null, active: true, isActive: true, deletedAt: null },
    { amenityId: 12, name: "Iron", icon: null, active: true, isActive: true, deletedAt: null },
];

export type AmenityDocument = AmenityModel;

export const ensureDefaultAmenities = async () => {
    const existingCount = await Amenity.countDocuments();

    if (existingCount > 0) {
        return;
    }

    await Amenity.insertMany(defaultAmenities);
};
type AmenityWithHelpers = typeof AmenityModel & {
    find(filter?: SimpleFilter<AmenityRecord>): MySqlQuery<AmenityModel>;
    findOne(options?: FindOptions | SimpleFilter<AmenityRecord>): Promise<AmenityModel | null>;
    countDocuments(filter?: SimpleFilter<AmenityRecord>): Promise<number>;
    insertMany(items: AmenityRecord[]): Promise<AmenityModel[]>;
};

const defaultAmenityFindOne = AmenityModel.findOne.bind(AmenityModel) as (
    options?: FindOptions,
) => Promise<AmenityModel | null>;

const Amenity = AmenityModel as AmenityWithHelpers;

Amenity.find = (filter = {}) => buildDocumentQuery<AmenityModel, AmenityRecord>(AmenityModel, filter);

Amenity.findOne = (options?: FindOptions | SimpleFilter<AmenityRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultAmenityFindOne(options);
    }

    return findOneByFilter<AmenityModel, AmenityRecord>({ findOne: defaultAmenityFindOne }, options);
};

Amenity.countDocuments = (filter = {}) =>
    countDocumentsByFilter<AmenityModel, AmenityRecord>(AmenityModel, filter);

Amenity.insertMany = (items) => AmenityModel.bulkCreate(items);

export default Amenity;