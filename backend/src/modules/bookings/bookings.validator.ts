import { z } from "zod";

import { isValidIsoDate } from "../../common/validation";
import { bookingStatusValues } from "../../models/booking";

export const bookingIdParamSchema = z.object({
    bookingId: z.coerce.number().int().positive(),
});

const isoDateSchema = z.string().refine(isValidIsoDate, {
    message: "Date must use YYYY-MM-DD format",
});

export const createBookingBodySchema = z.object({
    listingId: z.coerce.number().int().positive(),
    checkInDate: isoDateSchema.optional(),
    checkIn: isoDateSchema.optional(),
    checkOutDate: isoDateSchema.optional(),
    checkOut: isoDateSchema.optional(),
    guestCount: z.coerce.number().int().positive().optional(),
    guests: z.coerce.number().int().positive().optional(),
    guestsCount: z.coerce.number().int().positive().optional(),
    couponCode: z.string().trim().min(1).max(64).optional(),
}).superRefine((value, ctx) => {
    const checkInDate = value.checkInDate ?? value.checkIn;
    const checkOutDate = value.checkOutDate ?? value.checkOut;
    const guestCount = value.guestCount ?? value.guests ?? value.guestsCount;

    if (!checkInDate) {
        ctx.addIssue({
            code: "custom",
            path: ["checkInDate"],
            message: "checkInDate is required",
        });
    }

    if (!checkOutDate) {
        ctx.addIssue({
            code: "custom",
            path: ["checkOutDate"],
            message: "checkOutDate is required",
        });
    }

    if (!guestCount) {
        ctx.addIssue({
            code: "custom",
            path: ["guestCount"],
            message: "guestCount is required",
        });
    }

    if (checkInDate && checkOutDate && checkInDate >= checkOutDate) {
        ctx.addIssue({
            code: "custom",
            path: ["checkOutDate"],
            message: "checkOutDate must be after checkInDate",
        });
    }
}).transform((value) => ({
    listingId: value.listingId,
    checkInDate: value.checkInDate ?? value.checkIn!,
    checkOutDate: value.checkOutDate ?? value.checkOut!,
    guestCount: value.guestCount ?? value.guests ?? value.guestsCount!,
    couponCode: value.couponCode,
}));

export const createBulkBookingBodySchema = z.object({
    items: z.array(createBookingBodySchema).min(1).max(10),
});

export const cancelBookingBodySchema = z.object({
    reason: z.string().trim().max(2000).optional(),
});

export const bookingsQuerySchema = z.object({
    status: z
        .enum([
            ...bookingStatusValues,
            "pending",
            "pending_host",
            "pending_host_confirmation",
            "cancelled",
            "host_cancelled",
            "expired",
        ])
        .optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
});
