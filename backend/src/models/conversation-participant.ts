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

export type ConversationParticipantRecord = {
    conversationId: number;
    userId: number;
    role: "guest" | "host" | "admin" | null;
    joinedAt: Date;
    lastReadAt: Date | null;
};

class ConversationParticipantModel extends Model<
    InferAttributes<ConversationParticipantModel>,
    InferCreationAttributes<ConversationParticipantModel>
> {
    declare conversationId: number;
    declare userId: number;
    declare role: CreationOptional<"guest" | "host" | "admin" | null>;
    declare joinedAt: CreationOptional<Date>;
    declare lastReadAt: Date | null;
}

ConversationParticipantModel.init(
    {
        conversationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            primaryKey: true,
            field: "conversation_id",
        },
        userId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            primaryKey: true,
            field: "user_id",
        },
        role: {
            type: DataTypes.ENUM("guest", "host", "admin"),
            allowNull: true,
            defaultValue: null,
        },
        joinedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "joined_at",
        },
        lastReadAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "last_read_at",
        },
    },
    {
        sequelize,
        tableName: "conversation_participant",
        underscored: true,
        timestamps: false,
    },
);

ConversationParticipantModel.removeAttribute("id");

export type ConversationParticipantDocument = ConversationParticipantModel;
type ConversationParticipantWithHelpers = typeof ConversationParticipantModel & {
    find(filter?: SimpleFilter<ConversationParticipantRecord>): MySqlQuery<ConversationParticipantModel>;
    findOne(
        options?: FindOptions | SimpleFilter<ConversationParticipantRecord>,
    ): Promise<ConversationParticipantModel | null>;
    countDocuments(filter?: SimpleFilter<ConversationParticipantRecord>): Promise<number>;
};

const defaultParticipantFindOne = ConversationParticipantModel.findOne.bind(ConversationParticipantModel) as (
    options?: FindOptions,
) => Promise<ConversationParticipantModel | null>;

const ConversationParticipant = ConversationParticipantModel as ConversationParticipantWithHelpers;

ConversationParticipant.find = (filter = {}) =>
    buildDocumentQuery<ConversationParticipantModel, ConversationParticipantRecord>(
        ConversationParticipantModel,
        filter,
    );

ConversationParticipant.findOne = (
    options?: FindOptions | SimpleFilter<ConversationParticipantRecord>,
) => {
    if (!options || isFindOptions(options)) {
        return defaultParticipantFindOne(options);
    }

    return findOneByFilter<ConversationParticipantModel, ConversationParticipantRecord>(
        { findOne: defaultParticipantFindOne },
        options,
    );
};

ConversationParticipant.countDocuments = (filter = {}) =>
    countDocumentsByFilter<ConversationParticipantModel, ConversationParticipantRecord>(
        ConversationParticipantModel,
        filter,
    );

export default ConversationParticipant;
