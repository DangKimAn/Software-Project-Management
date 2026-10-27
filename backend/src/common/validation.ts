import { Request } from "express";
import { matchedData, validationResult } from "express-validator";

import { ApiError, ApiErrorDetail } from "./api-error";

export const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;
export const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;

export const isValidTime = (value: string) => timePattern.test(value);

export const isValidIsoDate = (value: string) => {
    if (!isoDatePattern.test(value)) {
        return false;
    }

    const date = new Date(`${value}T00:00:00.000Z`);
    return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
};

export const assertValidRequest = (req: Request) => {
    const errors = validationResult(req);

    if (errors.isEmpty()) {
        return;
    }

    const details = errors.array({ onlyFirstError: true }).map<ApiErrorDetail>((item) => ({
        path: "path" in item ? item.path : undefined,
        msg: item.msg,
    }));

    throw new ApiError(422, "Validation error", details);
};

export const getValidatedBody = <T>(req: Request) =>
    (req.validatedData?.body ??
        matchedData(req, {
            includeOptionals: true,
            locations: ["body"],
        })) as T;

export const getValidatedParams = <T>(req: Request) =>
    (req.validatedData?.params ??
        matchedData(req, {
            includeOptionals: true,
            locations: ["params"],
        })) as T;

export const getValidatedQuery = <T>(req: Request) =>
    (req.validatedData?.query ??
        matchedData(req, {
            includeOptionals: true,
            locations: ["query"],
        })) as T;
