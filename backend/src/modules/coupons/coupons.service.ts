import { Op } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import type { AuthenticatedUser } from "../auth/auth.service";
import Coupon, { CouponType } from "../../models/coupon";
import CouponRedemption from "../../models/coupon-redemption";
import { calculateCouponDiscountVnd, moneyToVnd, vndToNumber } from "../../utils/money";
import { writeAuditLog } from "../../services/audit-log-service";

export type ValidateCouponInput = {
    code: string;
    bookingAmount: string;
    listingId?: number;
};

export type ListCouponsQuery = {
    active?: boolean;
    page?: number;
    limit?: number;
};

export type CreateCouponInput = {
    code: string;
    title: string;
    description?: string | null;
    type: CouponType;
    discountValue: string;
    maxDiscountAmount?: string | null;
    minOrderValue?: string | null;
    startDate: string;
    endDate: string;
    totalLimit?: number | null;
    limitPerUser?: number | null;
    isActive?: boolean;
};

export type UpdateCouponInput = Partial<CreateCouponInput>;

type AuditContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

const normalizeCode = (code: string) => code.trim().toUpperCase();

const toNullableNumber = (value: string | number | null | undefined) => {
    if (value === null || value === undefined) {
        return value ?? null;
    }

    return Number(value);
};

const toDate = (value: string) => {
    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "date",
                msg: "date must be a valid ISO datetime",
            },
        ]);
    }

    return date;
};

const parseIntegerVndOrThrow = (value: string | number, path: string) => {
    try {
        return moneyToVnd(value);
    } catch {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} must be an integer VND amount`,
            },
        ]);
    }
};

const serializeCoupon = (coupon: InstanceType<typeof Coupon>) => ({
    couponId: coupon.couponId,
    code: coupon.code,
    title: coupon.title,
    description: coupon.description ?? null,
    type: coupon.type,
    discountValue:
        coupon.type === "percent" ? Number(coupon.discountValue) : vndToNumber(moneyToVnd(coupon.discountValue)),
    maxDiscountAmount:
        coupon.maxDiscountAmount === null || coupon.maxDiscountAmount === undefined
            ? null
            : vndToNumber(moneyToVnd(coupon.maxDiscountAmount)),
    minOrderValue:
        coupon.minOrderValue === null || coupon.minOrderValue === undefined
            ? null
            : vndToNumber(moneyToVnd(coupon.minOrderValue)),
    startDate: coupon.startDate,
    endDate: coupon.endDate,
    totalLimit: coupon.totalLimit ?? null,
    usedCount: coupon.usedCount,
    limitPerUser: coupon.limitPerUser ?? null,
    isActive: coupon.isActive,
    deletedAt: coupon.deletedAt ?? null,
    createdAt: coupon.createdAt,
    updatedAt: coupon.updatedAt,
});

const buildInvalidCouponResult = (reason: string) => ({
    valid: false,
    reason,
    coupon: null,
    discountAmount: 0,
    finalAmount: null,
});

const validateCouponAvailability = async (
    coupon: InstanceType<typeof Coupon> | null,
    userId: number,
    bookingAmount: string,
) => {
    if (!coupon || coupon.deletedAt) {
        return buildInvalidCouponResult("Coupon is invalid");
    }

    const now = new Date();

    if (!coupon.isActive || coupon.startDate > now || coupon.endDate < now) {
        return buildInvalidCouponResult("Coupon is expired or not active");
    }

    if (coupon.totalLimit !== null && coupon.totalLimit !== undefined && coupon.usedCount >= coupon.totalLimit) {
        return buildInvalidCouponResult("Coupon usage limit has been reached");
    }

    const bookingAmountVnd = parseIntegerVndOrThrow(bookingAmount, "bookingAmount");

    if (
        coupon.minOrderValue !== null &&
        coupon.minOrderValue !== undefined &&
        bookingAmountVnd < moneyToVnd(coupon.minOrderValue)
    ) {
        return buildInvalidCouponResult("Order value does not meet coupon minimum");
    }

    if (coupon.limitPerUser !== null && coupon.limitPerUser !== undefined) {
        const redemptionCount = await CouponRedemption.count({
            where: {
                couponId: coupon.couponId,
                userId,
            },
        });

        if (redemptionCount >= coupon.limitPerUser) {
            return buildInvalidCouponResult("Coupon usage limit has been reached");
        }
    }

    const discountAmountVnd = calculateCouponDiscountVnd({
        amount: bookingAmount,
        discountType: coupon.type,
        discountValue: coupon.discountValue,
        maxDiscountAmount: coupon.maxDiscountAmount,
    });

    return {
        valid: true,
        reason: null,
        coupon: serializeCoupon(coupon),
        discountAmount: vndToNumber(discountAmountVnd),
        finalAmount: vndToNumber(bookingAmountVnd - discountAmountVnd),
    };
};

export const validateCouponForUser = async (user: AuthenticatedUser, input: ValidateCouponInput) => {
    const coupon = await Coupon.findOne({
        where: {
            code: normalizeCode(input.code),
            deletedAt: null,
        },
    });

    return validateCouponAvailability(coupon, Number(user.id), input.bookingAmount);
};

const normalizeCouponPayload = (input: CreateCouponInput | UpdateCouponInput) => ({
    ...(input.code !== undefined ? { code: normalizeCode(input.code) } : {}),
    ...(input.title !== undefined ? { title: input.title.trim() } : {}),
    ...(input.description !== undefined
        ? { description: input.description?.trim() ? input.description.trim() : null }
        : {}),
    ...(input.type !== undefined ? { type: input.type } : {}),
    ...(input.discountValue !== undefined ? { discountValue: Number(input.discountValue) } : {}),
    ...(input.maxDiscountAmount !== undefined ? { maxDiscountAmount: toNullableNumber(input.maxDiscountAmount) } : {}),
    ...(input.minOrderValue !== undefined ? { minOrderValue: toNullableNumber(input.minOrderValue) } : {}),
    ...(input.startDate !== undefined ? { startDate: toDate(input.startDate) } : {}),
    ...(input.endDate !== undefined ? { endDate: toDate(input.endDate) } : {}),
    ...(input.totalLimit !== undefined ? { totalLimit: input.totalLimit } : {}),
    ...(input.limitPerUser !== undefined ? { limitPerUser: input.limitPerUser } : {}),
    ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
});

const assertCouponBusinessRules = (input: CreateCouponInput | UpdateCouponInput) => {
    if (input.type === "percent" && input.discountValue !== undefined) {
        const percentValue = Number(input.discountValue);

        if (!Number.isFinite(percentValue) || percentValue <= 0 || percentValue > 100) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "discountValue",
                    msg: "percent discountValue must be between 0 and 100",
                },
            ]);
        }
    }

    if (input.type === "fixed_amount" && input.discountValue !== undefined) {
        parseIntegerVndOrThrow(input.discountValue, "discountValue");
    }

    for (const [field, value] of [
        ["maxDiscountAmount", input.maxDiscountAmount],
        ["minOrderValue", input.minOrderValue],
    ] as const) {
        if (value === null || value === undefined) {
            continue;
        }

        parseIntegerVndOrThrow(value, field);
    }

    if (input.startDate && input.endDate && toDate(input.startDate) >= toDate(input.endDate)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "endDate",
                msg: "endDate must be after startDate",
            },
        ]);
    }
};

export const listAdminCoupons = async (admin: AuthenticatedUser, query: ListCouponsQuery) => {
    assertAdmin(admin);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where = {
        deletedAt: null,
        ...(query.active === undefined ? {} : { isActive: query.active }),
    };
    const { rows, count } = await Coupon.findAndCountAll({
        where,
        order: [["createdAt", "DESC"], ["couponId", "DESC"]],
        offset: (page - 1) * limit,
        limit,
    });

    return {
        items: rows.map(serializeCoupon),
        page,
        limit,
        total: count,
        totalPages: Math.max(1, Math.ceil(count / limit)),
    };
};

export const createAdminCoupon = async (
    admin: AuthenticatedUser,
    input: CreateCouponInput,
    context: AuditContext = {},
) => {
    assertAdmin(admin);
    assertCouponBusinessRules(input);

    const code = normalizeCode(input.code);
    const existingCoupon = await Coupon.findOne({
        where: {
            code,
            deletedAt: {
                [Op.is]: null,
            },
        },
    });

    if (existingCoupon) {
        throw new ApiError(409, "Coupon code already exists");
    }

    return sequelize.transaction(async (transaction) => {
        const coupon = await Coupon.create(
            {
                ...normalizeCouponPayload(input),
                code,
                usedCount: 0,
                isActive: input.isActive ?? true,
                deletedAt: null,
            } as never,
            { transaction },
        );

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "coupon.create",
            targetType: "coupon",
            targetId: coupon.couponId,
            metadata: {
                code: coupon.code,
                type: coupon.type,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return serializeCoupon(coupon);
    });
};

export const updateAdminCoupon = async (
    admin: AuthenticatedUser,
    couponId: number,
    input: UpdateCouponInput,
    context: AuditContext = {},
) => {
    assertAdmin(admin);

    const coupon = await Coupon.findOne({
        where: {
            couponId,
            deletedAt: null,
        },
    });

    if (!coupon) {
        throw new ApiError(404, "Coupon not found");
    }

    const mergedInput = {
        type: input.type ?? coupon.type,
        discountValue: input.discountValue ?? String(coupon.discountValue),
        startDate: input.startDate ?? coupon.startDate.toISOString(),
        endDate: input.endDate ?? coupon.endDate.toISOString(),
        ...input,
    };

    assertCouponBusinessRules(mergedInput);

    if (input.code !== undefined) {
        const duplicate = await Coupon.findOne({
            where: {
                code: normalizeCode(input.code),
                couponId: {
                    [Op.ne]: coupon.couponId,
                },
                deletedAt: null,
            },
        });

        if (duplicate) {
            throw new ApiError(409, "Coupon code already exists");
        }
    }

    return sequelize.transaction(async (transaction) => {
        coupon.set(normalizeCouponPayload(input));
        await coupon.save({ transaction });

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "coupon.update",
            targetType: "coupon",
            targetId: coupon.couponId,
            metadata: {
                code: coupon.code,
                fields: Object.keys(input),
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });

        return serializeCoupon(coupon);
    });
};

export const deleteAdminCoupon = async (
    admin: AuthenticatedUser,
    couponId: number,
    context: AuditContext = {},
) => {
    assertAdmin(admin);

    const coupon = await Coupon.findOne({
        where: {
            couponId,
            deletedAt: null,
        },
    });

    if (!coupon) {
        throw new ApiError(404, "Coupon not found");
    }

    await sequelize.transaction(async (transaction) => {
        coupon.isActive = false;
        coupon.deletedAt = new Date();
        await coupon.save({ transaction });

        await writeAuditLog({
            actorId: Number(admin.id),
            action: "coupon.delete",
            targetType: "coupon",
            targetId: coupon.couponId,
            metadata: {
                code: coupon.code,
            },
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            transaction,
        });
    });
};
