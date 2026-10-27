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

export const messageTypeValues = ["text", "image", "system", "file"] as const;
export type MessageType = (typeof messageTypeValues)[number];

export type MessageAttachment = {
    url: string;
    type?: string | null;
    name?: string | null;
};

export type MessageRecord = {
    messageId: number;
    conversationId: number;
    senderId: number;
    content: string;
    messageType: MessageType;
    attachments: MessageAttachment[];
    createdAt: Date;
    updatedAt: Date;
};

class MessageModel extends Model<InferAttributes<MessageModel>, InferCreationAttributes<MessageModel>> {
    declare messageId: CreationOptional<number>;
    declare conversationId: number;
    declare senderId: number;
    declare content: string;
    declare messageType: MessageType;
    declare attachments: MessageAttachment[];
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

MessageModel.init(
    {
        messageId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "message_id",
        },
        conversationId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "conversation_id",
        },
        senderId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "sender_id",
        },
        content: {
            type: DataTypes.TEXT,
            allowNull: false,
        },
        messageType: {
            type: DataTypes.ENUM(...messageTypeValues),
            allowNull: false,
            defaultValue: "text",
            field: "message_type",
        },
        attachments: {
            type: DataTypes.TEXT("long"),
            allowNull: true,
            field: "attachments_json",
            get() {
                return parseJsonValue<MessageAttachment[]>(this.getDataValue("attachments"), []);
            },
            set(value: MessageAttachment[]) {
                this.setDataValue("attachments", stringifyJsonValue(value ?? []) as never);
            },
        },
        createdAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "created_at",
        },
        updatedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "updated_at",
        },
    },
    {
        sequelize,
        tableName: "message",
        underscored: true,
        timestamps: true,
    },
);

export type MessageDocument = MessageModel;
type MessageWithHelpers = typeof MessageModel & {
    find(filter?: SimpleFilter<MessageRecord>): MySqlQuery<MessageModel>;
    findOne(options?: FindOptions | SimpleFilter<MessageRecord>): Promise<MessageModel | null>;
    countDocuments(filter?: SimpleFilter<MessageRecord>): Promise<number>;
};

const defaultMessageFindOne = MessageModel.findOne.bind(MessageModel) as (
    options?: FindOptions,
) => Promise<MessageModel | null>;

const Message = MessageModel as MessageWithHelpers;

Message.find = (filter = {}) => buildDocumentQuery<MessageModel, MessageRecord>(MessageModel, filter);

Message.findOne = (options?: FindOptions | SimpleFilter<MessageRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultMessageFindOne(options);
    }

    return findOneByFilter<MessageModel, MessageRecord>({ findOne: defaultMessageFindOne }, options);
};

Message.countDocuments = (filter = {}) =>
    countDocumentsByFilter<MessageModel, MessageRecord>(MessageModel, filter);

export default Message;
