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

export const bookingStatusValues = [
    "pending_payment",
    "payment_expired",
    "paid",
    "confirmed",
    "checked_in",
    "checked_out",
    "completed",
    "cancelled_by_guest",
    "cancelled_by_host",
    "cancelled_by_admin",
    "rejected",
] as const;
export type BookingStatus = (typeof bookingStatusValues)[number];

export type BookingRecord = {
    id: number;
    bookingId: number;
    listingId: number;
    guestUserId: number;
    hostUserId: number;
    checkInDate: string;
    checkOutDate: string;
    guestCount: number;
    nights: number | null;
    totalNights: number | null;
    status: BookingStatus;
    version: number;
    lockedUntil: Date | null;
    currency: string;
    couponId: number | null;
    subtotalAmount: number;
    cleaningFeeAmount: number;
    serviceFeeAmount: number;
    discountAmount: number;
    totalAmount: number;
    priceBreakdown: Record<string, unknown> | null;
    bookingNote: string | null;
    cancellationReason: string | null;
    cancelledByUserId: number | null;
    cancelledAt: Date | null;
    checkedInAt: Date | null;
    checkedOutAt: Date | null;
    paidAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
};

class BookingModel extends Model<InferAttributes<BookingModel>, InferCreationAttributes<BookingModel>> {
    declare id: CreationOptional<number>;
    declare bookingId: number;
    declare listingId: number;
    declare guestUserId: number;
    declare hostUserId: number;
    declare checkInDate: string;
    declare checkOutDate: string;
    declare guestCount: number;
    declare nights: CreationOptional<number | null>;
    declare totalNights: CreationOptional<number | null>;
    declare status: BookingStatus;
    declare version: CreationOptional<number>;
    declare lockedUntil: CreationOptional<Date | null>;
    declare currency: string;
    declare couponId: CreationOptional<number | null>;
    declare subtotalAmount: number;
    declare cleaningFeeAmount: CreationOptional<number>;
    declare serviceFeeAmount: number;
    declare discountAmount: CreationOptional<number>;
    declare totalAmount: number;
    declare priceBreakdown: CreationOptional<Record<string, unknown> | null>;
    declare bookingNote: CreationOptional<string | null>;
    declare cancellationReason: CreationOptional<string | null>;
    declare cancelledByUserId: CreationOptional<number | null>;
    declare cancelledAt: CreationOptional<Date | null>;
    declare checkedInAt: CreationOptional<Date | null>;
    declare checkedOutAt: CreationOptional<Date | null>;
    declare paidAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

BookingModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        bookingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "booking_id",
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "listing_id",
        },
        guestUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "guest_user_id",
        },
        hostUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_user_id",
        },
        checkInDate: {
            type: DataTypes.DATEONLY,
            allowNull: false,
            field: "check_in_date",
        },
        checkOutDate: {
            type: DataTypes.DATEONLY,
            allowNull: false,
            field: "check_out_date",
        },
        guestCount: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "guest_count",
        },
        nights: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
        },
        totalNights: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "total_nights",
        },
        status: {
            type: DataTypes.ENUM(...bookingStatusValues),
            allowNull: false,
            defaultValue: "pending_payment",
        },
        version: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
        },
        lockedUntil: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "locked_until",
        },
        currency: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VND",
        },
        couponId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "coupon_id",
        },
        subtotalAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            field: "subtotal_amount",
        },
        cleaningFeeAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            defaultValue: 0,
            field: "cleaning_fee_amount",
        },
        serviceFeeAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            defaultValue: 0,
            field: "service_fee_amount",
        },
        discountAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            defaultValue: 0,
            field: "discount_amount",
        },
        totalAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            field: "total_amount",
        },
        priceBreakdown: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "price_breakdown_json",
        },
        bookingNote: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "booking_note",
        },
        cancellationReason: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "cancellation_reason",
        },
        cancelledByUserId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "cancelled_by_user_id",
        },
        cancelledAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "cancelled_at",
        },
        checkedInAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "checked_in_at",
        },
        checkedOutAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "checked_out_at",
        },
        paidAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "paid_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "bookings",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["booking_id"],
            },
            {
                fields: ["guest_user_id", "status"],
            },
            {
                fields: ["host_user_id", "status"],
            },
            {
                fields: ["listing_id", "check_in_date", "check_out_date", "status"],
            },
        ],
    },
);

export type BookingDocument = BookingModel;
type BookingWithHelpers = typeof BookingModel & {
    find(filter?: SimpleFilter<BookingRecord>): MySqlQuery<BookingModel>;
    findOne(options?: FindOptions | SimpleFilter<BookingRecord>): Promise<BookingModel | null>;
    countDocuments(filter?: SimpleFilter<BookingRecord>): Promise<number>;
};

const defaultBookingFindOne = BookingModel.findOne.bind(BookingModel) as (
    options?: FindOptions,
) => Promise<BookingModel | null>;

const Booking = BookingModel as BookingWithHelpers;

Booking.find = (filter = {}) => buildDocumentQuery<BookingModel, BookingRecord>(BookingModel, filter);

Booking.findOne = (options?: FindOptions | SimpleFilter<BookingRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultBookingFindOne(options);
    }

    return findOneByFilter<BookingModel, BookingRecord>({ findOne: defaultBookingFindOne }, options);
};

Booking.countDocuments = (filter = {}) =>
    countDocumentsByFilter<BookingModel, BookingRecord>(BookingModel, filter);

export default Booking;
