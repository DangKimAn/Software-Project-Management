import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class BookingDateLockModel extends Model<
    InferAttributes<BookingDateLockModel>,
    InferCreationAttributes<BookingDateLockModel>
> {
    declare bookingDateLockId: CreationOptional<number>;
    declare bookingId: number;
    declare listingId: number;
    declare reservedDate: string;
    declare status: CreationOptional<string>;
    declare releasedAt: CreationOptional<Date | null>;
    declare activeLockKey: CreationOptional<number | null>;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

BookingDateLockModel.init(
    {
        bookingDateLockId: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "booking_date_lock_id",
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "booking_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        reservedDate: {
            type: DataTypes.DATEONLY,
            allowNull: false,
            field: "reserved_date",
        },
        status: {
            type: DataTypes.STRING(32),
            allowNull: false,
            defaultValue: "held",
        },
        releasedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "released_at",
        },
        activeLockKey: {
            type: DataTypes.TINYINT,
            allowNull: true,
            field: "active_lock_key",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "booking_date_locks",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                name: "uq_booking_date_locks_booking_date",
                unique: true,
                fields: ["booking_id", "reserved_date"],
            },
            {
                name: "uq_booking_date_locks_active",
                unique: true,
                fields: ["listing_id", "reserved_date", "active_lock_key"],
            },
            {
                name: "idx_booking_date_locks_listing_date",
                fields: ["listing_id", "reserved_date"],
            },
            {
                name: "idx_booking_date_locks_released_at",
                fields: ["released_at"],
            },
        ],
    },
);

export default BookingDateLockModel;
