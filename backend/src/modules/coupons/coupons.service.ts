import { Op } from "sequelize";

import { ApiError } from "../../common/api-error";
import { parseVietnamDateBoundary } from "../../common/date-time";
import sequelize from "../../config/database";
import type { AuthenticatedUser } from "../auth/auth.service";
import Coupon, { CouponType } from "../../models/coupon";
import CouponRedemption from "../../models/coupon-redemption";
import { calculateCouponDiscountVnd, moneyToVnd, vndToNumber } from "../../common/money";
import { writeAuditLog } from "../../services/audit-log.service";

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

/**
 * Giải thuật kiểm tra quyền quản trị viên (`admin`) của người dùng xác thực; ném lỗi `403 Forbidden` nếu không đủ thẩm quyền.
 */
const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật chuẩn hóa mã giảm giá: loại bỏ khoảng trắng hai đầu và chuyển toàn bộ ký tự sang chữ in hoa (`UPPERCASE`).
 */
const normalizeCode = (code: string) => code.trim().toUpperCase();

/**
 * Giải thuật chuyển đổi giá trị chuỗi/số tùy chọn sang kiểu `number` hoặc `null` khi không được cung cấp.
 */
const toNullableNumber = (value: string | number | null | undefined) => {
    if (value === null || value === undefined) {
        return value ?? null;
    }

    return Number(value);
};

// Giải thuật chuyển đổi ngày hiệu lực coupon theo biên giờ Việt Nam (UTC+7):
// Khi truyền chuỗi YYYY-MM-DD, ngày bắt đầu tính từ 00:00:00+07:00 và ngày kết thúc tính tới 23:59:59.999+07:00.
/**
 * Giải thuật phân tích chuỗi ngày đầu vào thành mốc `Date` theo biên đầu ngày (`00:00:00.000+07:00`)
 * hoặc cuối ngày (`23:59:59.999+07:00`) giờ Việt Nam; ném lỗi `422` nếu định dạng thời gian không hợp lệ.
 */
const toDate = (value: string, boundary: "start" | "end" = "start") => {
    const date = parseVietnamDateBoundary(value, boundary);

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

/**
 * Giải thuật kiểm định và quy đổi giá trị tiền tệ sang số nguyên lớn `BigInt` đồng chẵn VND;
 * ném lỗi `422 Validation error` gắn đúng đường dẫn trường `path` nếu chứa phần lẻ thập phân hoặc sai định dạng.
 */
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

/**
 * Giải thuật tuần tự hóa đầy đủ thực thể `Coupon` cho phân hệ quản trị, chuẩn hóa các trường tiền tệ qua `BigInt` VND sang `number` an toàn.
 */
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

/**
 * Giải thuật tuần tự hóa thông tin `Coupon` công khai cho phía khách hàng (lược bỏ số liệu nội bộ `usedCount`, `totalLimit`, `deletedAt`).
 */
const serializePublicCoupon = (coupon: InstanceType<typeof Coupon>) => ({
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
    limitPerUser: coupon.limitPerUser ?? null,
    isActive: coupon.isActive,
});

/**
 * Giải thuật đóng gói kết quả từ chối áp dụng mã giảm giá kèm nguyên nhân cụ thể.
 */
const buildInvalidCouponResult = (reason: string) => ({
    valid: false,
    reason,
    coupon: null,
    discountAmount: 0,
    finalAmount: null,
});

/**
 * Giải thuật kiểm định tính khả dụng của coupon và tính toán chiết khấu bằng số học nguyên lớn `BigInt`:
 * 1. Kiểm tra tồn tại, chưa xóa mềm (`deletedAt === null`), đang kích hoạt (`isActive === true`) và nằm trong khung giờ hiệu lực `startDate <= now <= endDate`.
 * 2. Kiểm tra hạn mức lượt dùng toàn cục (`usedCount < totalLimit`), tổng tiền đơn tối thiểu (`bookingAmountVnd >= minOrderValue`),
 *    và hạn mức quy đổi lũy kế theo người dùng trên bảng `CouponRedemption` (`redemptionCount < limitPerUser`).
 * 3. Tính mức giảm có áp trần `maxDiscountAmount` qua `calculateCouponDiscountVnd` và trả về số tiền sau chiết khấu `bookingAmountVnd - discountAmountVnd`.
 */
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
        coupon: serializePublicCoupon(coupon),
        discountAmount: vndToNumber(discountAmountVnd),
        finalAmount: vndToNumber(bookingAmountVnd - discountAmountVnd),
    };
};

/**
 * Giải thuật tra cứu coupon theo mã chuẩn hóa chưa xóa mềm và xác thực hiệu lực áp dụng cho người dùng hiện tại.
 */
export const validateCouponForUser = async (user: AuthenticatedUser, input: ValidateCouponInput) => {
    const coupon = await Coupon.findOne({
        where: {
            code: normalizeCode(input.code),
            deletedAt: null,
        },
    });

    return validateCouponAvailability(coupon, Number(user.id), input.bookingAmount);
};

/**
 * Giải thuật chuẩn hóa tải dữ liệu tạo/cập nhật coupon: cắt khoảng trắng chuỗi, chuẩn hóa mã chữ hoa,
 * chuyển đổi các trường số và biên thời gian bắt đầu/kết thúc theo giờ Việt Nam (`UTC+7`).
 */
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
    ...(input.startDate !== undefined ? { startDate: toDate(input.startDate, "start") } : {}),
    ...(input.endDate !== undefined ? { endDate: toDate(input.endDate, "end") } : {}),
    ...(input.totalLimit !== undefined ? { totalLimit: input.totalLimit } : {}),
    ...(input.limitPerUser !== undefined ? { limitPerUser: input.limitPerUser } : {}),
    ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
});

/**
 * Giải thuật kiểm tra bất biến nghiệp vụ cấu hình mã giảm giá:
 * - Loại `percent`: giá trị giảm phải thuộc nửa khoảng `(0, 100]`.
 * - Loại `fixed_amount`, `maxDiscountAmount` và `minOrderValue`: phải là số nguyên đồng chẵn VND hợp lệ.
 * - Khoảng hiệu lực thời gian phải thỏa mãn bất đẳng thức chặt `startDate < endDate`.
 */
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

    if (input.startDate && input.endDate && toDate(input.startDate, "start") >= toDate(input.endDate, "end")) {
        throw new ApiError(422, "Validation error", [
            {
                path: "endDate",
                msg: "endDate must be after startDate",
            },
        ]);
    }
};

/**
 * Giải thuật liệt kê danh sách coupon có phân trang dành cho quản trị viên, lọc các bản ghi chưa xóa mềm
 * và sắp xếp giảm dần theo thời điểm tạo (`createdAt DESC, couponId DESC`).
 */
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

/**
 * Giải thuật khởi tạo mã giảm giá mới nguyên tử trong giao dịch ACID:
 * kiểm tra quyền Admin, xác thực quy tắc nghiệp vụ, chống trùng lặp mã `code` đang hoạt động,
 * khởi tạo `usedCount = 0` và ghi vết kiểm toán (`coupon.create`) trong cùng `transaction`.
 */
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

/**
 * Giải thuật cập nhật cấu hình mã giảm giá nguyên tử trong giao dịch ACID:
 * hợp nhất trường cập nhật với dữ liệu hiện hữu để tái kiểm định toàn vẹn quy tắc nghiệp vụ,
 * kiểm tra xung đột mã `code` với các bản ghi khác và lưu nhật ký kiểm toán (`coupon.update`).
 */
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

/**
 * Giải thuật xóa mềm (soft-delete) mã giảm giá nguyên tử trong giao dịch ACID:
 * vô hiệu hóa cờ `isActive = false`, đánh dấu `deletedAt = now` và ghi nhật ký kiểm toán (`coupon.delete`)
 * nhằm giữ nguyên tính toàn vẹn tham chiếu cho các đơn đặt phòng và lịch sử quy đổi cũ.
 */
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
