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

export type ConversationRecord = {
    conversationId: number;
    createdByUserId: number | null;
    listingId: number | null;
    guestUserId: number | null;
    hostUserId: number | null;
    bookingOrderId: number | null;
    dedupeKey: string | null;
    lastMessage: string | null;
    lastMessageAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
};

class ConversationModel extends Model<
    InferAttributes<ConversationModel>,
    InferCreationAttributes<ConversationModel>
> {
    declare conversationId: CreationOptional<number>;
    declare createdByUserId: number | null;
    declare listingId: number | null;
    declare guestUserId: number | null;
    declare hostUserId: number | null;
    declare bookingOrderId: number | null;
    declare dedupeKey: string | null;
    declare lastMessage: string | null;
    declare lastMessageAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

ConversationModel.init(
    {
        conversationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "conversation_id",
        },
        createdByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "created_by_user_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "listing_id",
        },
        guestUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "guest_user_id",
        },
        hostUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "host_user_id",
        },
        bookingOrderId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "booking_order_id",
        },
        dedupeKey: {
            type: DataTypes.STRING(255),
            allowNull: true,
            unique: true,
            field: "dedupe_key",
        },
        lastMessage: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "last_message",
        },
        lastMessageAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "last_message_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "conversation",
        underscored: true,
        timestamps: true,
    },
);

export type ConversationDocument = ConversationModel;
type ConversationWithHelpers = typeof ConversationModel & {
    find(filter?: SimpleFilter<ConversationRecord>): MySqlQuery<ConversationModel>;
    findOne(options?: FindOptions | SimpleFilter<ConversationRecord>): Promise<ConversationModel | null>;
    countDocuments(filter?: SimpleFilter<ConversationRecord>): Promise<number>;
};

const defaultConversationFindOne = ConversationModel.findOne.bind(ConversationModel) as (
    options?: FindOptions,
) => Promise<ConversationModel | null>;

const Conversation = ConversationModel as ConversationWithHelpers;

Conversation.find = (filter = {}) =>
    buildDocumentQuery<ConversationModel, ConversationRecord>(ConversationModel, filter);

Conversation.findOne = (options?: FindOptions | SimpleFilter<ConversationRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultConversationFindOne(options);
    }

    return findOneByFilter<ConversationModel, ConversationRecord>(
        { findOne: defaultConversationFindOne },
        options,
    );
};

Conversation.countDocuments = (filter = {}) =>
    countDocumentsByFilter<ConversationModel, ConversationRecord>(ConversationModel, filter);

export default Conversation;
