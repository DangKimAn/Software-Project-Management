import type { Response } from "express";

export type ApiSuccessPayload<T> = {
    success: true;
    message: string;
    data: T;
};

export type ApiErrorPayload = {
    success: false;
    message: string;
    code: string;
    details?: unknown;
    errors?: Array<{ path?: string; msg?: string }>;
};

type SuccessOptions<T> = {
    statusCode?: number;
    message?: string;
    data?: T;
};

type EmptyData = Record<string, never>;

const defaultSuccessMessage = "OK";
const defaultErrorMessage = "Internal server error";

const isRecord = (value: unknown): value is Record<string, unknown> =>
    typeof value === "object" && value !== null && !Array.isArray(value);

const toNumber = (value: unknown, fallback = 0) => {
    const parsed = typeof value === "number" ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizePaginationMeta = (value: Record<string, unknown>) => {
    const page = toNumber(value.page, 1);
    const limit = toNumber(value.limit, 10);
    const total = toNumber(value.total ?? value.totalItems, 0);
    const totalPages = toNumber(value.totalPages, Math.max(1, Math.ceil(total / Math.max(1, limit))));

    return {
        page,
        limit,
        total,
        totalPages,
    };
};

const hasFlatPagination = (value: Record<string, unknown>) =>
    Array.isArray(value.items) &&
    (value.page !== undefined || value.limit !== undefined || value.total !== undefined || value.totalItems !== undefined);

const normalizeSuccessData = <T>(data: T | undefined): T | EmptyData | Record<string, unknown> => {
    if (data === undefined) {
        return {};
    }

    if (!isRecord(data)) {
        return data;
    }

    if (isRecord(data.pagination)) {
        return {
            ...data,
            pagination: normalizePaginationMeta(data.pagination),
        };
    }

    if (hasFlatPagination(data)) {
        const {
            page: _page,
            limit: _limit,
            total: _total,
            totalItems: _totalItems,
            totalPages: _totalPages,
            ...rest
        } = data;

        return {
            ...rest,
            pagination: normalizePaginationMeta(data),
        };
    }

    return data;
};

export function sendSuccess<T>(res: Response, options?: SuccessOptions<T>): Response;
export function sendSuccess<T>(res: Response, statusCode?: number, message?: string, data?: T): Response;
export function sendSuccess<T>(
    res: Response,
    optionsOrStatusCode: SuccessOptions<T> | number = {},
    message?: string,
    data?: T,
) {
    const options =
        typeof optionsOrStatusCode === "number"
            ? {
                  statusCode: optionsOrStatusCode,
                  message,
                  data,
              }
            : optionsOrStatusCode;

    const payload: ApiSuccessPayload<T | EmptyData | Record<string, unknown>> = {
        success: true,
        message: options.message ?? defaultSuccessMessage,
        data: normalizeSuccessData(options.data),
    };

    return res.status(options.statusCode ?? 200).json(payload);
}

export const sendError = (
    res: Response,
    statusCode: number,
    message?: string,
    details: unknown = {},
    code?: string,
) => {
    const codeByStatus: Record<number, string> = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        405: "METHOD_NOT_ALLOWED",
        409: "CONFLICT",
        410: "GONE",
        413: "PAYLOAD_TOO_LARGE",
        415: "UNSUPPORTED_MEDIA_TYPE",
        422: "VALIDATION_ERROR",
        423: "LOCKED",
        429: "RATE_LIMITED",
        503: "SERVICE_UNAVAILABLE",
    };
    const payload: ApiErrorPayload = {
        success: false,
        message: message ?? defaultErrorMessage,
        code: code ?? codeByStatus[statusCode] ?? "INTERNAL_ERROR",
        details,
        errors: Array.isArray(details) ? details : undefined,
    };

    return res.status(statusCode).json(payload);
};
