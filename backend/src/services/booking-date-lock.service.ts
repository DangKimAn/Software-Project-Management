import { Op, UniqueConstraintError, type Transaction } from "sequelize";
import { ApiError } from "../common/api-error";
import BookingDateLock from "../models/booking-date-lock";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export function buildReservedDates(checkInDate: Date, checkOutDate: Date): string[] {
    const start = new Date(checkInDate);
    const end = new Date(checkOutDate);
    const dates: string[] = [];

    start.setHours(0, 0, 0, 0);
    end.setHours(0, 0, 0, 0);

    for (let cursor = start.getTime(); cursor < end.getTime(); cursor += MS_PER_DAY) {
        dates.push(new Date(cursor).toISOString().slice(0, 10));
    }

    return dates;
}

export async function createBookingDateLocks(params: {
    bookingId: number;
    listingId: number;
    checkInDate: Date;
    checkOutDate: Date;
    transaction?: Transaction;
}): Promise<void> {
    const reservedDates = buildReservedDates(params.checkInDate, params.checkOutDate);

    if (reservedDates.length === 0) {
        return;
    }

    try {
        await BookingDateLock.bulkCreate(
            reservedDates.map((reservedDate) => ({
                bookingId: params.bookingId,
                listingId: params.listingId,
                reservedDate,
                status: "held",
                releasedAt: null,
            })),
            {
                transaction: params.transaction,
            },
        );
    } catch (error) {
        if (error instanceof UniqueConstraintError) {
            throw new ApiError(409, "Listing is already booked for the selected dates");
        }

        throw error;
    }
}

export async function releaseBookingDateLocksForBooking(params: {
    bookingId: number;
    transaction?: Transaction;
}): Promise<number> {
    const [affectedRows] = await BookingDateLock.update(
        {
            status: "released",
            releasedAt: new Date(),
        },
        {
            where: {
                bookingId: params.bookingId,
                releasedAt: {
                    [Op.is]: null,
                },
            },
            transaction: params.transaction,
        },
    );

    return affectedRows;
}

export async function releaseBookingDateLocks(params: {
    listingId: number;
    reservedDates: string[];
    transaction?: Transaction;
}): Promise<number> {
    if (params.reservedDates.length === 0) {
        return 0;
    }

    const [affectedRows] = await BookingDateLock.update(
        {
            status: "released",
            releasedAt: new Date(),
        },
        {
            where: {
                listingId: params.listingId,
                reservedDate: {
                    [Op.in]: params.reservedDates,
                },
                releasedAt: {
                    [Op.is]: null,
                },
            },
            transaction: params.transaction,
        },
    );

    return affectedRows;
}
