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
    parseJsonValue,
    SimpleFilter,
    stringifyJsonValue,
} from "./mysql-helpers";

export const hostVerificationTypeValues = ["identity", "business", "bank"] as const;
export type HostVerificationType = (typeof hostVerificationTypeValues)[number];

export const hostVerificationStatusValues = ["pending", "approved", "rejected"] as const;
export type HostVerificationStatus = (typeof hostVerificationStatusValues)[number];

export type HostVerificationRecord = {
    verificationId: number;
    hostId: number;
    verificationType: HostVerificationType;
    fullName: string;
    idNumber: string | null;
    documentUrls: string[];
    notes: string | null;
    status: HostVerificationStatus;
    reviewedByUserId: number | null;
    reviewedAt: Date | null;
    reviewNotes: string | null;
    rejectionReason: string | null;
    createdAt: Date;
    updatedAt: Date;
};

class HostVerificationModel extends Model<
    InferAttributes<HostVerificationModel>,
    InferCreationAttributes<HostVerificationModel>
> {
    declare verificationId: CreationOptional<number>;
    declare hostId: number;
    declare verificationType: HostVerificationType;
    declare fullName: string;
    declare idNumber: string | null;
    declare documentUrls: string[];
    declare notes: string | null;
    declare status: HostVerificationStatus;
    declare reviewedByUserId: number | null;
    declare reviewedAt: Date | null;
    declare reviewNotes: string | null;
    declare rejectionReason: string | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

HostVerificationModel.init(
    {
        verificationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "verification_id",
        },
        hostId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_id",
        },
        verificationType: {
            type: DataTypes.ENUM(...hostVerificationTypeValues),
            allowNull: false,
            field: "verification_type",
        },
        fullName: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "full_name",
        },
        idNumber: {
            type: DataTypes.STRING(100),
            allowNull: true,
            field: "id_number",
        },
        documentUrls: {
            type: DataTypes.TEXT("long"),
            allowNull: false,
            field: "document_urls_json",
            get() {
                return parseJsonValue<string[]>(this.getDataValue("documentUrls"), []);
            },
            set(value: string[]) {
                this.setDataValue("documentUrls", stringifyJsonValue(value ?? []) as never);
            },
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        status: {
            type: DataTypes.ENUM(...hostVerificationStatusValues),
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
        reviewNotes: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "review_notes",
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
        tableName: "host_verification",
        underscored: true,
        timestamps: true,
    },
);

export type HostVerificationDocument = HostVerificationModel;
type HostVerificationWithHelpers = typeof HostVerificationModel & {
    find(filter?: SimpleFilter<HostVerificationRecord>): MySqlQuery<HostVerificationModel>;
    findOne(
        options?: FindOptions | SimpleFilter<HostVerificationRecord>,
    ): Promise<HostVerificationModel | null>;
    countDocuments(filter?: SimpleFilter<HostVerificationRecord>): Promise<number>;
};

const defaultVerificationFindOne = HostVerificationModel.findOne.bind(HostVerificationModel) as (
    options?: FindOptions,
) => Promise<HostVerificationModel | null>;

const HostVerification = HostVerificationModel as HostVerificationWithHelpers;

HostVerification.find = (filter = {}) =>
    buildDocumentQuery<HostVerificationModel, HostVerificationRecord>(HostVerificationModel, filter);

HostVerification.findOne = (options?: FindOptions | SimpleFilter<HostVerificationRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultVerificationFindOne(options);
    }

    return findOneByFilter<HostVerificationModel, HostVerificationRecord>(
        { findOne: defaultVerificationFindOne },
        options,
    );
};

HostVerification.countDocuments = (filter = {}) =>
    countDocumentsByFilter<HostVerificationModel, HostVerificationRecord>(HostVerificationModel, filter);

export default HostVerification;
