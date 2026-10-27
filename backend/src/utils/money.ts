type MoneyInput = string | number | bigint;

const decimalPattern = /^-?\d+(?:\.\d+)?$/;

const parseDecimalParts = (value: MoneyInput) => {
    const normalized = String(value).trim();

    if (!decimalPattern.test(normalized)) {
        throw new Error("Invalid money value");
    }

    const negative = normalized.startsWith("-");
    const unsigned = negative ? normalized.slice(1) : normalized;
    const [whole, fraction = ""] = unsigned.split(".");

    return {
        negative,
        whole: whole || "0",
        fraction,
    };
};

export const decimalToScaledInteger = (value: MoneyInput, scale: number) => {
    const { negative, whole, fraction } = parseDecimalParts(value);
    const paddedFraction = fraction.padEnd(scale, "0");
    const extraFraction = paddedFraction.slice(scale);

    if (extraFraction.replace(/0/g, "") !== "") {
        throw new Error("Money value has too many decimal places");
    }

    const integerText = `${whole}${paddedFraction.slice(0, scale)}`.replace(/^0+(?=\d)/, "") || "0";
    const parsed = BigInt(integerText);

    return negative ? -parsed : parsed;
};

export const moneyToVnd = (value: MoneyInput) => {
    const scaled = decimalToScaledInteger(value, 2);

    if (scaled % 100n !== 0n) {
        throw new Error("VND amount must not contain fractional units");
    }

    return scaled / 100n;
};

export const vndToNumber = (value: bigint) => {
    const numeric = Number(value);

    if (!Number.isSafeInteger(numeric)) {
        throw new Error("Money value exceeds safe integer range");
    }

    return numeric;
};

export const toVnpayAmount = (value: MoneyInput) => moneyToVnd(value) * 100n;

export const calculateCouponDiscountVnd = ({
    amount,
    discountType,
    discountValue,
    maxDiscountAmount,
}: {
    amount: MoneyInput;
    discountType: "percent" | "fixed_amount";
    discountValue: MoneyInput;
    maxDiscountAmount?: MoneyInput | null;
}) => {
    const amountVnd = moneyToVnd(amount);
    const rawDiscount =
        discountType === "percent"
            ? (amountVnd * decimalToScaledInteger(discountValue, 2)) / 10000n
            : moneyToVnd(discountValue);
    const cappedDiscount =
        maxDiscountAmount !== null && maxDiscountAmount !== undefined
            ? rawDiscount < moneyToVnd(maxDiscountAmount)
                ? rawDiscount
                : moneyToVnd(maxDiscountAmount)
            : rawDiscount;

    if (cappedDiscount <= 0n) {
        return 0n;
    }

    return cappedDiscount > amountVnd ? amountVnd : cappedDiscount;
};

export const toMoney = (value: MoneyInput) => vndToNumber(moneyToVnd(value));

export const addMoney = (...values: MoneyInput[]) =>
    vndToNumber(values.reduce<bigint>((total, value) => total + moneyToVnd(value), 0n));

export const multiplyMoney = (value: MoneyInput, multiplier: MoneyInput) => {
    const amount = moneyToVnd(value);
    const scaledMultiplier = decimalToScaledInteger(multiplier, 4);

    return vndToNumber((amount * scaledMultiplier) / 10000n);
};
