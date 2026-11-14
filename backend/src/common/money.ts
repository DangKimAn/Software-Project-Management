// CONFLICT-RESOLVED: Hợp nhất tiện ích tính toán tiền tệ BigInt từ `src/utils/money.ts` về `src/common/money.ts` và xóa bỏ thư mục trùng vai trò `src/utils/`.
type MoneyInput = string | number | bigint;

const decimalPattern = /^-?\d+(?:\.\d+)?$/;

/**
 * Giải thuật phân tách chuỗi biểu diễn thập phân của giá trị tiền tệ thành dấu âm, phần nguyên và phần thập phân:
 * - Kiểm định nghiêm ngặt bằng biểu thức chính quy `/^-?\d+(?:\.\d+)?$/` trên chuỗi văn bản,
 *   tránh ép kiểu trực tiếp qua số thực dấu phẩy động IEEE-754 để không phát sinh sai số nhị phân.
 */
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

/**
 * Giải thuật chuyển đổi số thập phân sang số nguyên lớn `BigInt` theo hệ số tỉ lệ $10^{\text{scale}}$ (`scaled integer`):
 * - Đệm chữ số `0` bên phải phần thập phân tới độ dài `scale` và từ chối mọi giá trị có chữ số khác `0` vượt quá độ chính xác `scale`.
 * - Ghép trực tiếp chuỗi phần nguyên với `scale` chữ số thập phân để khởi tạo `BigInt` chính xác tuyệt đối.
 */
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

/**
 * Giải thuật quy đổi giá trị tiền tệ đầu vào sang số nguyên lớn `BigInt` theo đơn vị đồng chẵn VND:
 * - Phóng tỉ lệ thập phân bậc 2 (`scale = 2`), kiểm tra bất biến chia hết cho `100n` (không chấp nhận phần lẻ xu trong VND),
 *   sau đó rút gọn về đơn vị 1 VND bằng phép chia nguyên `scaled / 100n`.
 */
export const moneyToVnd = (value: MoneyInput) => {
    const scaled = decimalToScaledInteger(value, 2);

    if (scaled % 100n !== 0n) {
        throw new Error("VND amount must not contain fractional units");
    }

    return scaled / 100n;
};

/**
 * Giải thuật chuyển đổi an toàn số tiền `BigInt` đồng VND sang kiểu `number` phục vụ tuần tự hóa JSON:
 * - Bắt buộc kiểm tra bất biến `Number.isSafeInteger` ($|x| \le 9\,007\,199\,254\,740\,991$) để ngăn mất mát độ chính xác ở tầng giao vận.
 */
export const vndToNumber = (value: bigint) => {
    const numeric = Number(value);

    if (!Number.isSafeInteger(numeric)) {
        throw new Error("Money value exceeds safe integer range");
    }

    return numeric;
};

/**
 * Giải thuật quy đổi số tiền VND sang định dạng `vnp_Amount` của cổng thanh toán VNPay (`amountVnd * 100n` trên miền `BigInt`).
 */
export const toVnpayAmount = (value: MoneyInput) => moneyToVnd(value) * 100n;

/**
 * Giải thuật tính số tiền chiết khấu coupon trên miền số nguyên lớn `BigInt` (đơn vị đồng VND):
 * 1. Nếu chiết khấu theo tỷ lệ `percent`: phóng tỉ lệ phần trăm lên bậc 2 (`scale = 2`) rồi tính `(amountVnd * scaledRate) / 10000n`.
 * 2. Nếu chiết khấu cố định `fixed_amount`: quy đổi trực tiếp `moneyToVnd(discountValue)`.
 * 3. Áp trần tối đa `maxDiscountAmount` (nếu được cấu hình) và kẹp kết quả trong đoạn bất biến `[0n, amountVnd]`.
 */
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

/**
 * Giải thuật chuẩn hóa hai chiều giá trị tiền tệ đầu vào qua miền `BigInt` đồng VND về số nguyên `number` an toàn.
 */
export const toMoney = (value: MoneyInput) => vndToNumber(moneyToVnd(value));

/**
 * Giải thuật cộng tổng danh sách các khoản tiền trên miền số nguyên lớn `BigInt` (`reduce` khởi đầu từ `0n`)
 * rồi xuất ra `number` an toàn nhằm loại bỏ hoàn toàn sai số cộng dồn dấu phẩy động IEEE-754.
 */
export const addMoney = (...values: MoneyInput[]) =>
    vndToNumber(values.reduce<bigint>((total, value) => total + moneyToVnd(value), 0n));

/**
 * Giải thuật nhân số tiền VND với hệ số nhân thập phân độ chính xác bậc 4 (`scale = 4`) trên miền `BigInt`:
 * thực hiện phép tính nguyên `(amount * scaledMultiplier) / 10000n` và chuyển kết quả về số nguyên `number` an toàn.
 */
export const multiplyMoney = (value: MoneyInput, multiplier: MoneyInput) => {
    const amount = moneyToVnd(value);
    const scaledMultiplier = decimalToScaledInteger(multiplier, 4);

    return vndToNumber((amount * scaledMultiplier) / 10000n);
};
