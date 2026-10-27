type LogMeta = Record<string, unknown>;

const sensitiveKeyPattern = /(authorization|cookie|otp|password|secret|token|x-refresh-token|set-cookie)/i;
const sensitiveValuePatterns: Array<[RegExp, string]> = [
    [/\bBearer\s+[A-Za-z0-9._~+/=-]+/gi, "Bearer [REDACTED]"],
    [/\b(password|passwordHash|secret|token|otp|authorization|cookie)=([^&\s]+)/gi, "$1=[REDACTED]"],
    [/\b(vnp_SecureHash|vnp_SecureHashType)=([^&\s]+)/gi, "$1=[REDACTED]"],
];

const maskString = (value: string) =>
    sensitiveValuePatterns.reduce(
        (maskedValue, [pattern, replacement]) => maskedValue.replace(pattern, replacement),
        value,
    );

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

export const logger = {
    info: (message: string, meta?: LogMeta) => write("info", message, meta),
    warn: (message: string, meta?: LogMeta) => write("warn", message, meta),
    error: (message: string, error?: unknown, meta?: LogMeta) =>
        write("error", message, {
            ...(meta ?? {}),
            ...(error === undefined ? {} : { error: serializeError(error) }),
        }),
};