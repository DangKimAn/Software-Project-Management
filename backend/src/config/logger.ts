type LogMeta = Record<string, unknown>;

const sensitiveKeyPattern = /(authorization|cookie|otp|password|secret|token|x-refresh-token|set-cookie)/i;
const sensitiveValuePatterns: Array<[RegExp, string]> = [
    [/\bBearer\s+[A-Za-z0-9._~+/=-]+/gi, "Bearer [REDACTED]"],
    [/\b(password|passwordHash|secret|token|otp|authorization|cookie)=([^&\s]+)/gi, "$1=[REDACTED]"],
    [/\b(vnp_SecureHash|vnp_SecureHashType)=([^&\s]+)/gi, "$1=[REDACTED]"],
];

/**
 * Giải thuật che giấu chuỗi bí mật (Bearer token, mật khẩu, mã OTP, chữ ký cổng thanh toán) xuất hiện trực tiếp trong thông điệp văn bản.
 */
const maskString = (value: string) =>
    sensitiveValuePatterns.reduce(
        (maskedValue, [pattern, replacement]) => maskedValue.replace(pattern, replacement),
        value,
    );

/**
 * Giải thuật đệ quy duyệt cây đối tượng siêu dữ liệu nhật ký để biên tập (`[REDACTED]`) mọi khóa và giá trị nhạy cảm trước khi xuất JSON.
 */
const maskValue = (value: unknown): unknown => {
    if (typeof value === "string") {
        return maskString(value);
    }

    if (Array.isArray(value)) {
        return value.map(maskValue);
    }

    if (value && typeof value === "object") {
        return Object.fromEntries(
            Object.entries(value as Record<string, unknown>).map(([key, nestedValue]) => [
                key,
                sensitiveKeyPattern.test(key) ? "[REDACTED]" : maskValue(nestedValue),
            ]),
        );
    }

    return value;
};

/**
 * Giải thuật tuần tự hóa đối tượng `Error` sang cấu trúc JSON an toàn đã lọc thông tin nhạy cảm trên `message` và `stack`.
 */
const serializeError = (error: unknown) => {
    if (error instanceof Error) {
        return {
            name: error.name,
            message: maskString(error.message),
            stack: error.stack ? maskString(error.stack) : undefined,
        };
    }

    return error;
};

/**
 * Giải thuật ghi dòng nhật ký có cấu trúc JSON (Structured JSON Logging) ra luồng chuẩn tương ứng mức độ nghiêm trọng.
 */
const write = (level: "info" | "warn" | "error", message: string, meta?: LogMeta) => {
    const payload = {
        level,
        message,
        time: new Date().toISOString(),
        ...(meta ? { meta: maskValue(meta) } : {}),
    };

    const line = JSON.stringify(payload);

    if (level === "error") {
        console.error(line);
        return;
    }

    if (level === "warn") {
        console.warn(line);
        return;
    }

    process.stdout.write(`${line}\n`);
};

/** Bộ ghi nhật ký tập trung tự động biên tập thông tin xác thực và PII nhạy cảm. */
export const logger = {
    info: (message: string, meta?: LogMeta) => write("info", message, meta),
    warn: (message: string, meta?: LogMeta) => write("warn", message, meta),
    error: (message: string, error?: unknown, meta?: LogMeta) =>
        write("error", message, {
            ...(meta ?? {}),
            ...(error === undefined ? {} : { error: serializeError(error) }),
        }),
};
