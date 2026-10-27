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

export const hostEntityTypeValues = ["individual", "business"] as const;
export type HostEntityType = (typeof hostEntityTypeValues)[number];

export const hostApplicationStatusValues = ["pending", "approved", "rejected"] as const;
export type HostApplicationStatus = (typeof hostApplicationStatusValues)[number];

export type HostApplicationRecord = {
    applicationId: number;
    userId: number;
    contactName: string | null;
    contactEmail: string | null;
    contactPhone: string;
    businessAddress: string;
    entityType: HostEntityType;
    notes: string | null;
    status: HostApplicationStatus;
    reviewedByUserId: number | null;
    reviewedAt: Date | null;
    rejectionReason: string | null;
    createdAt: Date;
    updatedAt: Date;
};

class HostApplicationModel extends Model<
    InferAttributes<HostApplicationModel>,
    InferCreationAttributes<HostApplicationModel>
> {
    declare applicationId: CreationOptional<number>;
    declare userId: number;
    declare contactName: string | null;
    declare contactEmail: string | null;
    declare contactPhone: string;
    declare businessAddress: string;
    declare entityType: HostEntityType;
    declare notes: string | null;
    declare status: HostApplicationStatus;
    declare reviewedByUserId: number | null;
    declare reviewedAt: Date | null;
    declare rejectionReason: string | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostApplicationModel.init(
    {
        applicationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "application_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "user_id",
        },
        contactName: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "contact_name",
        },
        contactEmail: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "contact_email",
        },
        contactPhone: {
            type: DataTypes.STRING(32),
            allowNull: false,
            field: "contact_phone",
        },
        businessAddress: {
            type: DataTypes.STRING(500),
            allowNull: false,
            field: "business_address",
        },
        entityType: {
            type: DataTypes.ENUM(...hostEntityTypeValues),
            allowNull: false,
            field: "entity_type",
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        status: {
            type: DataTypes.ENUM(...hostApplicationStatusValues),
            allowNull: false,
            defaultValue: "pending",
        },
        reviewedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "reviewed_by_user_id",
        },
        reviewedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "reviewed_at",
        },
        rejectionReason: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "rejection_reason",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "host_applications",
        underscored: true,
        timestamps: true,
    },
);

export type HostApplicationDocument = HostApplicationModel;
type HostApplicationWithHelpers = typeof HostApplicationModel & {
    find(filter?: SimpleFilter<HostApplicationRecord>): MySqlQuery<HostApplicationModel>;
    findOne(
        options?: FindOptions | SimpleFilter<HostApplicationRecord>,
    ): Promise<HostApplicationModel | null>;
    countDocuments(filter?: SimpleFilter<HostApplicationRecord>): Promise<number>;
};

const defaultHostApplicationFindOne = HostApplicationModel.findOne.bind(HostApplicationModel) as (
    options?: FindOptions,
) => Promise<HostApplicationModel | null>;

const HostApplication = HostApplicationModel as HostApplicationWithHelpers;

HostApplication.find = (filter = {}) =>
    buildDocumentQuery<HostApplicationModel, HostApplicationRecord>(HostApplicationModel, filter);

HostApplication.findOne = (options?: FindOptions | SimpleFilter<HostApplicationRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultHostApplicationFindOne(options);
    }

    return findOneByFilter<HostApplicationModel, HostApplicationRecord>(
        { findOne: defaultHostApplicationFindOne },
        options,
    );
};

HostApplication.countDocuments = (filter = {}) =>
    countDocumentsByFilter<HostApplicationModel, HostApplicationRecord>(HostApplicationModel, filter);

export default HostApplication;
