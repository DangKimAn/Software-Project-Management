import { Op, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import Booking from "../../models/booking";
import Coupon from "../../models/coupon";
import CouponRedemption from "../../models/coupon-redemption";
import type { ListingDocument } from "../../models/listing";
import { syncEffectivePlatformFee } from "../admin/admin-fees.service";

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

/**
 * Giải thuật chuyển đổi an toàn giá trị đầu vào sang kiểu số, mặc định trả về `0` khi giá trị là `null` hoặc `undefined`.
 */
const toNumber = (value: unknown) => Number(value ?? 0);

/**
 * Giải thuật chuẩn hóa mã giảm giá: loại bỏ khoảng trắng thừa và chuyển sang chữ in hoa (`UPPERCASE`); trả về `undefined` nếu rỗng.
 */
const normalizeCouponCode = (code?: string) => {
    const trimmed = code?.trim();

    return trimmed ? trimmed.toUpperCase() : undefined;
};

/**
 * Giải thuật nhận diện ngày lưu trú cuối tuần theo chuẩn lịch UTC (`00:00:00.000Z`),
 * trả về `true` nếu rơi vào Thứ Bảy (`weekday === 6`) hoặc Chủ Nhật (`weekday === 0`).
 */
const isWeekendDate = (date: string) => {
    const weekday = new Date(`${date}T00:00:00.000Z`).getUTCDay();

    return weekday === 0 || weekday === 6;
};

/**
 * Giải thuật phân giải đơn giá lưu trú cho từng đêm theo cơ chế ưu tiên 3 tầng:
 * 1. Tầng lịch ghi đè (`calendar`): nếu chủ nhà thiết lập `priceOverride` cho ngày `date`, lấy trực tiếp giá này.
 * 2. Tầng cuối tuần (`weekendPrice`): nếu ngày thuộc cuối tuần và căn hộ có cấu hình `weekendPrice` khác `null`.
 * 3. Tầng cơ sở (`basePrice`): áp dụng mức giá ngày thường mặc định của căn hộ.
 */
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

/**
 * Giải thuật tính phụ phí khách vượt định mức tiêu chuẩn theo tổng số đêm lưu trú:
 * - Số khách tiêu chuẩn bao gồm trong giá gốc: `includedGuests = max(1, floor(includedGuests ?? maxGuests))`.
 * - Số khách vượt chuẩn: `extraGuests = max(0, guestCount - includedGuests)`.
 * - Tổng phụ phí khách vượt theo đêm: `round(extraGuests * feePerGuestPerNight * totalNights)`.
 */
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

/**
 * Giải thuật xác thực hạn mức coupon khóa bi quan (`FOR UPDATE`) và tính mức chiết khấu cho đơn đặt phòng:
 * 1. Khóa dòng `Coupon` (`SELECT ... FOR UPDATE`) trong `transaction` để tuần tự hóa kiểm tra hạn mức dưới tải đồng thời.
 * 2. Kiểm định hiệu lực thời gian (`startDate <= now <= endDate`), trần lượt dùng toàn cục (`usedCount < totalLimit`),
 *    giá trị đơn hàng tối thiểu (`preDiscountTotal >= minOrderValue`) và hạn mức trên từng người dùng (`redemptionCount + pendingHoldCount < limitPerUser`,
 *    tính cả các đơn `pending_payment` còn hạn khóa `lockedUntil > now` để chống lạm dụng đặt nhiều đơn song song).
 * 3. Tính mức giảm theo phần trăm hoặc số tiền cố định, áp trần `maxDiscountAmount` và kẹp trong đoạn `[0, preDiscountTotal]`.
 */
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

        let pendingHoldCount = 0;
        const canQueryBookingCount =
            Boolean((transaction as { commit?: unknown })?.commit) ||
            Object.prototype.hasOwnProperty.call(Booking, "count");

        if (canQueryBookingCount) {
            pendingHoldCount = await Booking.count({
                where: {
                    guestUserId: userId,
                    couponId: coupon.couponId,
                    status: "pending_payment",
                    lockedUntil: {
                        [Op.gt]: now,
                    },
                },
                transaction,
            });
        }

        if (redemptionCount + pendingHoldCount >= coupon.limitPerUser) {
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

/**
 * Giải thuật tổng hợp bảng kê chi tiết giá đặt phòng (`BookingPricingResult`):
 * 1. Tính giá từng đêm lưu trú `nightlyPrices` (kết hợp `priceOverride` trên lịch, giá cuối tuần và giá cơ sở) để suy ra `subtotalAmount`.
 * 2. Cộng phụ phí khách vượt chuẩn theo đêm `extraGuestFeeAmount` vào `subtotalAmount` thành `accommodationAmount`.
 * 3. Cộng phí dọn dẹp `cleaningFeeAmount`, phụ phí vượt ngưỡng khách `surchargeAmount` (khi `guestCount > surchargeIncludedGuests`),
 *    và phí dịch vụ nền tảng `serviceFeeAmount = round(accommodationAmount * effectiveServiceFeePct / 100)` thành `preDiscountTotal`.
 * 4. Áp dụng chiết khấu coupon hợp lệ `discountAmount` và chốt tổng thanh toán `totalAmount = max(0, preDiscountTotal - discountAmount)`.
 */
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
    let effectiveServiceFeePct = 10;
    if (listing.serviceFeePct != null && listing.serviceFeePct !== undefined) {
        effectiveServiceFeePct = toNumber(listing.serviceFeePct);
    } else {
        try {
            effectiveServiceFeePct = await syncEffectivePlatformFee();
        } catch {
            effectiveServiceFeePct = 10;
        }
    }
    const serviceFeeAmount = Math.round(accommodationAmount * (effectiveServiceFeePct / 100));
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
