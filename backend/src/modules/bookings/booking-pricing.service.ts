import type { Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import Coupon from "../../models/coupon";
import CouponRedemption from "../../models/coupon-redemption";
import type { ListingDocument } from "../../models/listing";

export type NightlyPriceSource = "basePrice" | "weekendPrice" | "calendar";

export type BookingPricingCalendarEntry = {
    priceOverride?: number | null;
};

export type BookingNightlyPrice = {
    date: string;
    amount: number;
    source: NightlyPriceSource;
    isWeekend: boolean;
};

export type BookingPriceBreakdown = {
    totalNights: number;
    weekdayNights: number;
    weekendNights: number;
    nightlyPrice: number;
    weekendPrice: number | null;
    nightlyPrices: BookingNightlyPrice[];
    subtotalAmount: number;
    subtotal: number;
    cleaningFeeAmount: number;
    cleaningFee: number;
    surchargeAmount: number;
    serviceFeeAmount: number;
    serviceFee: number;
    extraGuestFeeAmount: number;
    extraGuestFee: number;
    discountAmount: number;
    discount: number;
    totalAmount: number;
    couponId: number | null;
    couponCode: string | null;
    extraGuest: {
        includedGuests: number;
        extraGuests: number;
        feePerGuestPerNight: number;
    };
};

export type BookingPricingResult = BookingPriceBreakdown & {
    priceBreakdown: BookingPriceBreakdown;
};

type CouponDiscount = {
    coupon: InstanceType<typeof Coupon> | null;
    discountAmount: number;
};

type ListingWithExtraGuestPricing = ListingDocument & {
    includedGuests?: number | null;
    extraGuestFee?: number | null;
};

const toNumber = (value: unknown) => Number(value ?? 0);

const normalizeCouponCode = (code?: string) => {
    const trimmed = code?.trim();

    return trimmed ? trimmed.toUpperCase() : undefined;
};

const isWeekendDate = (date: string) => {
    const weekday = new Date(`${date}T00:00:00.000Z`).getUTCDay();

    return weekday === 0 || weekday === 6;
};

const getNightlyPrice = (
    listing: ListingDocument,
    date: string,
    calendarByDate: Map<string, BookingPricingCalendarEntry>,
): BookingNightlyPrice => {
    const calendarPrice = calendarByDate.get(date)?.priceOverride;
    const isWeekend = isWeekendDate(date);

    if (calendarPrice !== null && calendarPrice !== undefined) {
        return {
            date,
            amount: toNumber(calendarPrice),
            source: "calendar",
            isWeekend,
        };
    }

    const hasWeekendPrice = listing.weekendPrice !== null && listing.weekendPrice !== undefined;

    return {
        date,
        amount: isWeekend && hasWeekendPrice ? toNumber(listing.weekendPrice) : toNumber(listing.basePrice),
        source: isWeekend && hasWeekendPrice ? "weekendPrice" : "basePrice",
        isWeekend,
    };
};

const getExtraGuestPricing = (listing: ListingDocument, guestCount: number, totalNights: number) => {
    const pricedListing = listing as ListingWithExtraGuestPricing;
    const includedGuests = Math.max(1, Math.floor(toNumber(pricedListing.includedGuests ?? listing.maxGuests)));
    const feePerGuestPerNight = Math.max(0, toNumber(pricedListing.extraGuestFee));
    const extraGuests = Math.max(0, guestCount - includedGuests);

    return {
        includedGuests,
        extraGuests,
        feePerGuestPerNight,
        extraGuestFeeAmount: Math.round(extraGuests * feePerGuestPerNight * totalNights),
    };
};

const getCouponDiscount = async (
    userId: number,
    couponCode: string | undefined,
    preDiscountTotal: number,
    transaction: Transaction,
): Promise<CouponDiscount> => {
    if (!couponCode) {
        return {
            coupon: null,
            discountAmount: 0,
        };
    }

    const coupon = await Coupon.findOne({
        where: {
            code: couponCode,
            isActive: true,
            deletedAt: null,
        },
        transaction,
        lock: transaction.LOCK.UPDATE,
    });

    if (!coupon) {
        throw new ApiError(422, "Coupon is invalid", [
            {
                path: "couponCode",
                msg: "Coupon is invalid",
            },
        ]);
    }

    const now = new Date();

    if (coupon.startDate > now || coupon.endDate < now) {
        throw new ApiError(422, "Coupon is expired or not active");
    }

    if (coupon.totalLimit !== null && coupon.totalLimit !== undefined && coupon.usedCount >= coupon.totalLimit) {
        throw new ApiError(422, "Coupon usage limit has been reached");
    }

    if (coupon.minOrderValue !== null && coupon.minOrderValue !== undefined && preDiscountTotal < toNumber(coupon.minOrderValue)) {
        throw new ApiError(422, "Order value does not meet coupon minimum");
    }

    if (coupon.limitPerUser !== null && coupon.limitPerUser !== undefined) {
        const redemptionCount = await CouponRedemption.count({
            where: {
                couponId: coupon.couponId,
                userId,
            },
            transaction,
        });

        if (redemptionCount >= coupon.limitPerUser) {
            throw new ApiError(422, "Coupon usage limit has been reached");
        }
    }

    const rawDiscount =
        coupon.type === "percent"
            ? preDiscountTotal * (toNumber(coupon.discountValue) / 100)
            : toNumber(coupon.discountValue);
    const cappedDiscount =
        coupon.maxDiscountAmount !== null && coupon.maxDiscountAmount !== undefined
            ? Math.min(rawDiscount, toNumber(coupon.maxDiscountAmount))
            : rawDiscount;

    return {
        coupon,
        discountAmount: Math.min(preDiscountTotal, Math.max(0, Math.round(cappedDiscount))),
    };
};

export const calculateBookingPricing = async (params: {
    userId: number;
    listing: ListingDocument;
    dates: string[];
    calendarByDate: Map<string, BookingPricingCalendarEntry>;
    guestCount: number;
    couponCode?: string;
    transaction: Transaction;
}): Promise<BookingPricingResult> => {
    const {
        userId,
        listing,
        dates,
        calendarByDate,
        guestCount,
        couponCode,
        transaction,
    } = params;
    const nightlyPrices = dates.map((date) => getNightlyPrice(listing, date, calendarByDate));
    const totalNights = dates.length;
    const weekdayNights = nightlyPrices.filter((item) => !item.isWeekend).length;
    const weekendNights = nightlyPrices.length - weekdayNights;
    const subtotalAmount = nightlyPrices.reduce((total, item) => total + item.amount, 0);
    const extraGuestPricing = getExtraGuestPricing(listing, guestCount, totalNights);
    const accommodationAmount = subtotalAmount + extraGuestPricing.extraGuestFeeAmount;
    const cleaningFeeAmount = toNumber(listing.cleaningFee);
    const rawSurcharge = toNumber((listing as ListingDocument & { surchargeAmount?: number | null }).surchargeAmount);
    const surchargeIncludedGuests = Math.max(1, Math.floor(toNumber(
        (listing as ListingWithExtraGuestPricing).includedGuests ?? listing.maxGuests,
    )));
    const surchargeAmount = guestCount > surchargeIncludedGuests ? rawSurcharge : 0;
    const serviceFeeAmount = Math.round(accommodationAmount * (toNumber(listing.serviceFeePct) / 100));
    const preDiscountTotal = accommodationAmount + cleaningFeeAmount + surchargeAmount + serviceFeeAmount;
    const normalizedCouponCode = normalizeCouponCode(couponCode);
    const { coupon, discountAmount } = await getCouponDiscount(
        userId,
        normalizedCouponCode,
        preDiscountTotal,
        transaction,
    );
    const totalAmount = Math.max(0, preDiscountTotal - discountAmount);
    const priceBreakdown: BookingPriceBreakdown = {
        totalNights,
        weekdayNights,
        weekendNights,
        nightlyPrice: toNumber(listing.basePrice),
        weekendPrice: listing.weekendPrice === null || listing.weekendPrice === undefined
            ? null
            : toNumber(listing.weekendPrice),
        nightlyPrices,
        subtotalAmount,
        subtotal: subtotalAmount,
        cleaningFeeAmount,
        cleaningFee: cleaningFeeAmount,
        surchargeAmount,
        serviceFeeAmount,
        serviceFee: serviceFeeAmount,
        extraGuestFeeAmount: extraGuestPricing.extraGuestFeeAmount,
        extraGuestFee: extraGuestPricing.extraGuestFeeAmount,
        discountAmount,
        discount: discountAmount,
        totalAmount,
        couponId: coupon?.couponId ?? null,
        couponCode: coupon?.code ?? normalizedCouponCode ?? null,
        extraGuest: {
            includedGuests: extraGuestPricing.includedGuests,
            extraGuests: extraGuestPricing.extraGuests,
            feePerGuestPerNight: extraGuestPricing.feePerGuestPerNight,
        },
    };

    return {
        ...priceBreakdown,
        priceBreakdown,
    };
};
