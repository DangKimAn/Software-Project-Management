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
    SimpleFilter,
    buildDocumentQuery,
    countDocumentsByFilter,
    findOneByFilter,
    isFindOptions,
} from "./mysql-helpers";

export const identityDocumentTypeValues = [
    "cccd",
    "cmnd",
    "passport",
    "driver_license",
    "business_license",
    "other",
] as const;
export type IdentityDocumentType = (typeof identityDocumentTypeValues)[number];

export const identityDocumentSideValues = ["front", "back", "single", "business_license"] as const;
export type IdentityDocumentSide = (typeof identityDocumentSideValues)[number];

export const identityDocumentStatusValues = ["pending", "approved", "rejected"] as const;
export type IdentityDocumentStatus = (typeof identityDocumentStatusValues)[number];

export type HostIdentityDocumentRecord = {
    id: number;
    applicationId: number;
    userId: number;
    documentType: IdentityDocumentType;
    side: IdentityDocumentSide;
    originalFilename: string | null;
    objectKey: string;
    mimeType: string;
    fileSize: number;
    status: IdentityDocumentStatus;
    createdAt: Date;
    updatedAt: Date;
};

class HostIdentityDocumentModel extends Model<
    InferAttributes<HostIdentityDocumentModel>,
    InferCreationAttributes<HostIdentityDocumentModel>
> {
    declare id: CreationOptional<number>;
    declare applicationId: number;
    declare userId: number;
    declare documentType: IdentityDocumentType;
    declare side: IdentityDocumentSide;
    declare originalFilename: string | null;
    declare objectKey: string;
    declare mimeType: string;
    declare fileSize: number;
    declare status: CreationOptional<IdentityDocumentStatus>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostIdentityDocumentModel.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        applicationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "application_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        documentType: {
            type: DataTypes.ENUM(...identityDocumentTypeValues),
            allowNull: false,
            field: "document_type",
        },
        side: {
            type: DataTypes.ENUM(...identityDocumentSideValues),
            allowNull: false,
        },
        originalFilename: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "original_filename",
        },
        objectKey: {
            type: DataTypes.STRING(700),
            allowNull: false,
            field: "object_key",
        },
        mimeType: {
            type: DataTypes.STRING(120),
            allowNull: false,
            field: "mime_type",
        },
        fileSize: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "file_size",
        },
        status: {
            type: DataTypes.ENUM(...identityDocumentStatusValues),
            allowNull: false,
            defaultValue: "pending",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "host_identity_documents",
        underscored: true,
        timestamps: true,
    },
);

export type HostIdentityDocument = HostIdentityDocumentModel;
type HostIdentityDocumentWithHelpers = typeof HostIdentityDocumentModel & {
    find(filter?: SimpleFilter<HostIdentityDocumentRecord>): MySqlQuery<HostIdentityDocumentModel>;
    findOne(
        options?: FindOptions | SimpleFilter<HostIdentityDocumentRecord>,
    ): Promise<HostIdentityDocumentModel | null>;
    countDocuments(filter?: SimpleFilter<HostIdentityDocumentRecord>): Promise<number>;
};

const defaultHostIdentityDocumentFindOne = HostIdentityDocumentModel.findOne.bind(
    HostIdentityDocumentModel,
) as (options?: FindOptions) => Promise<HostIdentityDocumentModel | null>;

const HostIdentityDocument = HostIdentityDocumentModel as HostIdentityDocumentWithHelpers;

HostIdentityDocument.find = (filter = {}) =>
    buildDocumentQuery<HostIdentityDocumentModel, HostIdentityDocumentRecord>(
        HostIdentityDocumentModel,
        filter,
    );

HostIdentityDocument.findOne = (options?: FindOptions | SimpleFilter<HostIdentityDocumentRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultHostIdentityDocumentFindOne(options);
    }

    return findOneByFilter<HostIdentityDocumentModel, HostIdentityDocumentRecord>(
        { findOne: defaultHostIdentityDocumentFindOne },
        options,
    );
};

HostIdentityDocument.countDocuments = (filter = {}) =>
    countDocumentsByFilter<HostIdentityDocumentModel, HostIdentityDocumentRecord>(
        HostIdentityDocumentModel,
        filter,
    );

export default HostIdentityDocument;
