import { Op, UniqueConstraintError, type Transaction } from "sequelize";
import { ApiError } from "../common/api-error";
import BookingDateLock from "../models/booking-date-lock";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const ISO_DATE_ONLY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

function toUtcMidnightTimestamp(input: Date | string): number {
    if (typeof input === "string") {
        const trimmed = input.trim();
        const match = ISO_DATE_ONLY_PATTERN.exec(trimmed);
        if (match) {
            return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        }
        const parsed = new Date(trimmed);
        parsed.setUTCHours(0, 0, 0, 0);
        return parsed.getTime();
    }

    const cloned = new Date(input.getTime());
    cloned.setUTCHours(0, 0, 0, 0);
    return cloned.getTime();
}

export function buildReservedDates(checkInDate: Date | string, checkOutDate: Date | string): string[] {
    const startMs = toUtcMidnightTimestamp(checkInDate);
    const endMs = toUtcMidnightTimestamp(checkOutDate);

    if (!Number.isFinite(startMs) || !Number.isFinite(endMs) || startMs >= endMs) {
        return [];
    }

    const dates: string[] = [];
    for (let cursor = startMs; cursor < endMs; cursor += MS_PER_DAY) {
        dates.push(new Date(cursor).toISOString().slice(0, 10));
    }

    return dates;
}

export async function createBookingDateLocks(params: {
    bookingId: number;
    listingId: number;
    checkInDate: Date | string;
    checkOutDate: Date | string;
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
