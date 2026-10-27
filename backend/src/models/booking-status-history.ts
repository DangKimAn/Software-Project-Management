import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class BookingStatusHistoryModel extends Model<
    InferAttributes<BookingStatusHistoryModel>,
    InferCreationAttributes<BookingStatusHistoryModel>
> {
    declare historyId: CreationOptional<number>;
    declare bookingId: number;
    declare oldStatus: CreationOptional<string | null>;
    declare newStatus: string;
    declare changedByUserId: CreationOptional<number | null>;
    declare reason: CreationOptional<string | null>;
    declare metadataJson: CreationOptional<Record<string, unknown> | null>;
    declare createdAt: CreationOptional<Date>;
}

BookingStatusHistoryModel.init(
    {
        historyId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "history_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "booking_id",
        },
        oldStatus: {
            type: DataTypes.STRING(32),
            allowNull: true,
            field: "old_status",
        },
        newStatus: {
            type: DataTypes.STRING(32),
            allowNull: false,
            field: "new_status",
        },
        changedByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "changed_by_user_id",
        },
        reason: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
        metadataJson: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "metadata_json",
        },
        createdAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "booking_status_history",
        underscored: true,
        timestamps: true,
        updatedAt: false,
        indexes: [
            { fields: ["booking_id", "created_at"] },
            { fields: ["changed_by_user_id"] },
        ],
    },
);

export default BookingStatusHistoryModel;
