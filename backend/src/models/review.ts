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

export type ReviewRecord = {
    id: number;
    reviewId: number;
    bookingId: number | null;
    listingId: number;
    reviewerUserId: number | null;
    reviewerName: string;
    rating: number;
    comment: string;
    hostReply: string | null;
    isVisible: boolean;
    deletedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
};

class ReviewModel extends Model<InferAttributes<ReviewModel>, InferCreationAttributes<ReviewModel>> {
    declare id: CreationOptional<number>;
    declare reviewId: number;
    declare bookingId: number | null;
    declare listingId: number;
    declare reviewerUserId: number | null;
    declare reviewerName: string;
    declare rating: number;
    declare comment: string;
    declare hostReply: string | null;
    declare isVisible: boolean;
    declare deletedAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;

}

ReviewModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        reviewId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "review_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            unique: true,
            field: "booking_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        reviewerUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "reviewer_user_id",
        },
        reviewerName: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "reviewer_name",
        },
        rating: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
        },
        comment: {
            type: DataTypes.TEXT,
            allowNull: false,
        },
        hostReply: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "host_reply",
        },
        isVisible: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true,
            field: "is_visible",
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
        tableName: "reviews",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["review_id"],
            },
            {
                fields: ["listing_id", "is_visible", "created_at"],
            },
            {
                unique: true,
                fields: ["booking_id"],
            },
        ],
    },
);

export type ReviewDocument = ReviewModel;
type ReviewWithHelpers = typeof ReviewModel & {
    find(filter?: SimpleFilter<ReviewRecord>): MySqlQuery<ReviewModel>;
    findOne(options?: FindOptions | SimpleFilter<ReviewRecord>): Promise<ReviewModel | null>;
    countDocuments(filter?: SimpleFilter<ReviewRecord>): Promise<number>;
};

const defaultReviewFindOne = ReviewModel.findOne.bind(ReviewModel) as (
    options?: FindOptions,
) => Promise<ReviewModel | null>;

const Review = ReviewModel as ReviewWithHelpers;

Review.find = (filter = {}) => buildDocumentQuery<ReviewModel, ReviewRecord>(ReviewModel, filter);

Review.findOne = (options?: FindOptions | SimpleFilter<ReviewRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultReviewFindOne(options);
    }

    return findOneByFilter<ReviewModel, ReviewRecord>({ findOne: defaultReviewFindOne }, options);
};

Review.countDocuments = (filter = {}) =>
    countDocumentsByFilter<ReviewModel, ReviewRecord>(ReviewModel, filter);

export default Review;
