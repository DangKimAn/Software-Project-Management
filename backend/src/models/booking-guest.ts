import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class BookingGuestModel extends Model<
    InferAttributes<BookingGuestModel>,
    InferCreationAttributes<BookingGuestModel>
> {
    declare bookingGuestId: CreationOptional<number>;
    declare bookingId: number;
    declare fullName: string;
    declare email: CreationOptional<string | null>;
    declare phone: CreationOptional<string | null>;
    declare age: CreationOptional<number | null>;
    declare documentType: CreationOptional<string | null>;
    declare documentNumberHash: CreationOptional<string | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

BookingGuestModel.init(
    {
        bookingGuestId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "booking_guest_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "booking_id",
        },
        fullName: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "full_name",
        },
        email: {
            type: DataTypes.STRING(255),
            allowNull: true,
        },
        phone: {
            type: DataTypes.STRING(32),
            allowNull: true,
        },
        age: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
        },
        documentType: {
            type: DataTypes.STRING(64),
            allowNull: true,
            field: "document_type",
        },
        documentNumberHash: {
            type: DataTypes.STRING(128),
            allowNull: true,
            field: "document_number_hash",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "booking_guests",
        underscored: true,
        timestamps: true,
        indexes: [
            { fields: ["booking_id"] },
            { fields: ["document_number_hash"] },
        ],
    },
);

export default BookingGuestModel;
