import fs from "node:fs";
import path from "node:path";
import { GoogleAuth } from "google-auth-library";

import { ApiError } from "../common/api-error";
import { getEnv } from "../config/env";
import { logger } from "../config/logger";

export const GOOGLE_SHEETS_MINIMAL_SCOPES = ["https://www.googleapis.com/auth/spreadsheets"] as const;
const GOOGLE_SHEETS_API_BASE = "https://sheets.googleapis.com/v4/spreadsheets";
const SPREADSHEET_ID_REGEX = /^[a-zA-Z0-9-_]{20,120}$/;

export type GoogleSheetsErrorCode =
    | "NOT_CONFIGURED"
    | "INVALID_SPREADSHEET_INPUT"
    | "PERMISSION_DENIED"
    | "SPREADSHEET_NOT_FOUND"
    | "QUOTA_EXCEEDED"
    | "UPSTREAM_UNAVAILABLE"
    | "INVALID_STRUCTURE";

export class GoogleSheetsClientError extends Error {
    readonly code: GoogleSheetsErrorCode;
    readonly httpStatus: number;
    readonly retryable: boolean;

    constructor(
        code: GoogleSheetsErrorCode,
        message: string,
        options: { httpStatus?: number; retryable?: boolean } = {},
    ) {
        super(message);
        this.name = "GoogleSheetsClientError";
        this.code = code;
        this.httpStatus = options.httpStatus ?? 500;
        this.retryable = options.retryable ?? false;
    }
}

export type SheetRgbColor = {
    red: number;
    green: number;
    blue: number;
};

export const SHEET_COLORS = {
    WHITE: { red: 1, green: 1, blue: 1 } satisfies SheetRgbColor,
    PENDING_HOLD_ORANGE: { red: 1, green: 0.902, blue: 0.8 } satisfies SheetRgbColor, // #FFE6CC
    BOOKED_GREEN: { red: 0.851, green: 0.918, blue: 0.827 } satisfies SheetRgbColor, // #D9EAD3
    BOOKED_BLUE: { red: 0.812, green: 0.886, blue: 0.953 } satisfies SheetRgbColor, // #CFE2F3
    HOST_BLOCKED_RED: { red: 0.957, green: 0.8, blue: 0.8 } satisfies SheetRgbColor, // #F4CCCC
    INVALID_DAY_GRAY: { red: 0.918, green: 0.918, blue: 0.918 } satisfies SheetRgbColor, // #EAEAEA
    HEADER_BG: { red: 0.953, green: 0.957, blue: 0.965 } satisfies SheetRgbColor, // #F3F4F6
    SUBHEADER_BG: { red: 0.976, green: 0.98, blue: 0.984 } satisfies SheetRgbColor, // #F9FAFB
    ARCHIVED_BG: { red: 0.961, green: 0.961, blue: 0.961 } satisfies SheetRgbColor, // #F5F5F5
} as const;

export type RawSheetCell = {
    userEnteredValue?: {
        stringValue?: string;
        numberValue?: number;
        boolValue?: boolean;
        formulaValue?: string;
    };
    userEnteredFormat?: {
        backgroundColorStyle?: {
            rgbColor?: Partial<SheetRgbColor>;
            themeColor?: string;
        };
        backgroundColor?: Partial<SheetRgbColor>;
        textFormat?: {
            bold?: boolean;
            foregroundColorStyle?: {
                rgbColor?: Partial<SheetRgbColor>;
            };
        };
        horizontalAlignment?: string;
        numberFormat?: {
            type?: string;
            pattern?: string;
        };
    };
    // Intentionally excluded in sync logic, typed only so tests can verify we ignore it!
    effectiveFormat?: unknown;
    note?: string;
};

export type RawDeveloperMetadata = {
    metadataId?: number;
    metadataKey: string;
    metadataValue?: string;
    visibility?: "DOCUMENT" | "PROJECT";
    location?: {
        locationType?: "ROW" | "COLUMN" | "SHEET" | "SPREADSHEET";
        spreadsheet?: boolean;
        sheetId?: number;
        dimensionRange?: {
            sheetId?: number;
            dimension?: "ROWS" | "COLUMNS";
            startIndex?: number;
            endIndex?: number;
        };
    };
};

export type RawSheetTab = {
    properties: {
        sheetId: number;
        title: string;
        index?: number;
        gridProperties?: {
            rowCount?: number;
            columnCount?: number;
            frozenRowCount?: number;
            frozenColumnCount?: number;
        };
    };
    developerMetadata?: RawDeveloperMetadata[];
    protectedRanges?: Array<{
        protectedRangeId?: number;
        description?: string;
        warningOnly?: boolean;
    }>;
    data?: Array<{
        startRow?: number;
        startColumn?: number;
        rowData?: Array<{
            values?: RawSheetCell[];
        }>;
        rowMetadata?: Array<{
            developerMetadata?: RawDeveloperMetadata[];
        }>;
    }>;
};

export type RawSpreadsheetResponse = {
    spreadsheetId: string;
    properties?: {
        title?: string;
        timeZone?: string;
    };
    developerMetadata?: RawDeveloperMetadata[];
    sheets?: RawSheetTab[];
};

export type GoogleSheetsTransport = {
    getServiceAccountEmail(): Promise<string | null>;
    getSpreadsheet(params: {
        spreadsheetId: string;
        ranges?: string[];
        includeGridData?: boolean;
        fields?: string;
    }): Promise<RawSpreadsheetResponse>;
    batchUpdate(params: {
        spreadsheetId: string;
        requests: Array<Record<string, unknown>>;
    }): Promise<Record<string, unknown>>;
};

export type ParsedCellClassification = {
    state: "empty" | "host_blocked" | "pending_hold" | "booked" | "invalid_day";
    rawValue: string;
    bgHex: string | null;
    bookingIdFromMarker: number | null;
};

const FORMULA_TRIGGER_CHARS = new Set(["=", "+", "-", "@", "\t", "\r", "\n"]);

/**
 * Sanitizes text written into Google Sheets cells so user-controlled strings
 * (listing titles, notes, statuses) can never execute formulas (=IMPORTXML, +CMD, etc.).
 */
export const sanitizeSheetTextValue = (input: string | null | undefined, maxLength = 250): string => {
    if (!input) {
        return "";
    }

    const cleaned = String(input)
        .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, " ")
        .replace(/\r?\n/g, " ")
        .trim()
        .slice(0, maxLength);

    if (!cleaned) {
        return "";
    }

    if (FORMULA_TRIGGER_CHARS.has(cleaned[0])) {
        return `'${cleaned}`;
    }

    return cleaned;
};

/**
 * Strict anti-SSRF parser & validator for Google Spreadsheet URL or ID.
 * Only permits `https://docs.google.com/spreadsheets/d/<id>` or a clean `<id>`.
 */
export const parseAndValidateSpreadsheetInput = (
    rawInput: string,
): { spreadsheetId: string; canonicalUrl: string } => {
    const trimmed = String(rawInput ?? "").trim();

    if (!trimmed) {
        throw new ApiError(422, "Validation error", [
            {
                path: "spreadsheetUrlOrId",
                msg: "Vui lòng nhập liên kết hoặc mã Google Sheets",
            },
        ]);
    }

    if (SPREADSHEET_ID_REGEX.test(trimmed) && !trimmed.includes("://") && !trimmed.includes("/")) {
        return {
            spreadsheetId: trimmed,
            canonicalUrl: `https://docs.google.com/spreadsheets/d/${trimmed}/edit`,
        };
    }

    let parsedUrl: URL;
    try {
        parsedUrl = new URL(trimmed);
    } catch {
        throw new ApiError(422, "Validation error", [
            {
                path: "spreadsheetUrlOrId",
                msg: "Liên kết Google Sheets không hợp lệ",
            },
        ]);
    }

    if (
        parsedUrl.protocol !== "https:" ||
        parsedUrl.hostname.toLowerCase() !== "docs.google.com" ||
        parsedUrl.username ||
        parsedUrl.password ||
        parsedUrl.port
    ) {
        throw new ApiError(422, "Validation error", [
            {
                path: "spreadsheetUrlOrId",
                msg: "Chỉ chấp nhận liên kết chính thức từ https://docs.google.com/spreadsheets/d/...",
            },
        ]);
    }

    const decodedPath = decodeURIComponent(parsedUrl.pathname);
    if (decodedPath.includes("..")) {
        throw new ApiError(422, "Validation error", [
            {
                path: "spreadsheetUrlOrId",
                msg: "Đường dẫn Google Sheets không hợp lệ",
            },
        ]);
    }

    const match = /^\/spreadsheets\/d\/([a-zA-Z0-9-_]{20,120})(?:\/.*)?$/.exec(parsedUrl.pathname);
    if (!match) {
        throw new ApiError(422, "Validation error", [
            {
                path: "spreadsheetUrlOrId",
                msg: "Không tìm thấy mã Spreadsheet hợp lệ trong liên kết Google Sheets",
            },
        ]);
    }

    const spreadsheetId = match[1];
    return {
        spreadsheetId,
        canonicalUrl: `https://docs.google.com/spreadsheets/d/${spreadsheetId}/edit`,
    };
};

const clampChannel = (value: number | undefined): number => {
    if (typeof value !== "number" || !Number.isFinite(value)) {
        return 0;
    }
    return Math.min(1, Math.max(0, value));
};

export const rgbToHex = (rgb?: Partial<SheetRgbColor> | null): string | null => {
    if (!rgb || (rgb.red === undefined && rgb.green === undefined && rgb.blue === undefined)) {
        return null;
    }
    const r = Math.round(clampChannel(rgb.red ?? 0) * 255);
    const g = Math.round(clampChannel(rgb.green ?? 0) * 255);
    const b = Math.round(clampChannel(rgb.blue ?? 0) * 255);
    return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`.toUpperCase();
};

const colorDistance = (a: SheetRgbColor, b: SheetRgbColor): number => {
    const dr = a.red - b.red;
    const dg = a.green - b.green;
    const db = a.blue - b.blue;
    return Math.sqrt(dr * dr + dg * dg + db * db);
};

/**
 * Reads ONLY `userEnteredFormat.backgroundColorStyle.rgbColor` (with fallback to `userEnteredFormat.backgroundColor`).
 * NEVER inspects `effectiveFormat` so conditional formatting rules on Sheet cannot trigger false locks!
 */
export const extractUserEnteredRgb = (cell?: RawSheetCell | null): SheetRgbColor | null => {
    if (!cell?.userEnteredFormat) {
        return null;
    }

    const styleRgb = cell.userEnteredFormat.backgroundColorStyle?.rgbColor;
    if (
        styleRgb &&
        (styleRgb.red !== undefined || styleRgb.green !== undefined || styleRgb.blue !== undefined)
    ) {
        return {
            red: clampChannel(styleRgb.red ?? 0),
            green: clampChannel(styleRgb.green ?? 0),
            blue: clampChannel(styleRgb.blue ?? 0),
        };
    }

    const themeColor = cell.userEnteredFormat.backgroundColorStyle?.themeColor;
    if (themeColor && themeColor !== "BACKGROUND") {
        // Deliberate non-background theme fill chosen by user
        return { red: 0.9, green: 0.5, blue: 0.5 };
    }

    const legacyRgb = cell.userEnteredFormat.backgroundColor;
    if (
        legacyRgb &&
        (legacyRgb.red !== undefined || legacyRgb.green !== undefined || legacyRgb.blue !== undefined)
    ) {
        return {
            red: clampChannel(legacyRgb.red ?? 0),
            green: clampChannel(legacyRgb.green ?? 0),
            blue: clampChannel(legacyRgb.blue ?? 0),
        };
    }

    return null;
};

export const extractCellRawText = (cell?: RawSheetCell | null): string => {
    const val = cell?.userEnteredValue;
    if (!val) {
        return "";
    }
    if (val.stringValue !== undefined) {
        return String(val.stringValue).trim();
    }
    if (val.numberValue !== undefined) {
        return String(val.numberValue).trim();
    }
    if (val.boolValue !== undefined) {
        return String(val.boolValue).trim();
    }
    if (val.formulaValue !== undefined) {
        return String(val.formulaValue).trim();
    }
    return "";
};

const SYSTEM_HOLD_MARKER_REGEX = /^G\s*#(\d+)$/i;
const SYSTEM_BOOKED_MARKER_REGEX = /^(?:Đ|D)\s*#(\d+)$/i;

export const classifySheetCalendarCell = (cell?: RawSheetCell | null): ParsedCellClassification => {
    const rawValue = extractCellRawText(cell);
    const rgb = extractUserEnteredRgb(cell);
    const bgHex = rgb ? rgbToHex(rgb) : null;

    if (rawValue === "✕") {
        return {
            state: "invalid_day",
            rawValue,
            bgHex,
            bookingIdFromMarker: null,
        };
    }

    const isWhiteOrUnset =
        !rgb || (rgb.red >= 0.965 && rgb.green >= 0.965 && rgb.blue >= 0.965);

    const holdMatch = SYSTEM_HOLD_MARKER_REGEX.exec(rawValue);
    if (holdMatch) {
        const isHoldColor =
            !rgb ||
            isWhiteOrUnset ||
            colorDistance(rgb, SHEET_COLORS.PENDING_HOLD_ORANGE) <= 0.18;
        if (isHoldColor) {
            return {
                state: "pending_hold",
                rawValue,
                bgHex,
                bookingIdFromMarker: Number(holdMatch[1]),
            };
        }
    }

    const bookedMatch = SYSTEM_BOOKED_MARKER_REGEX.exec(rawValue);
    if (bookedMatch) {
        const isBookedColor =
            !rgb ||
            isWhiteOrUnset ||
            colorDistance(rgb, SHEET_COLORS.BOOKED_GREEN) <= 0.2 ||
            colorDistance(rgb, SHEET_COLORS.BOOKED_BLUE) <= 0.2;
        if (isBookedColor) {
            return {
                state: "booked",
                rawValue,
                bgHex,
                bookingIdFromMarker: Number(bookedMatch[1]),
            };
        }
    }

    if (isWhiteOrUnset && rawValue === "") {
        return {
            state: "empty",
            rawValue: "",
            bgHex,
            bookingIdFromMarker: null,
        };
    }

    // If cell has system Orange/Green color WITHOUT text (e.g. Host deleted text on a booked cell),
    // treat as empty/tampered rather than a new Host manual block unless it's Red or custom!
    if (rawValue === "" && rgb) {
        if (colorDistance(rgb, SHEET_COLORS.PENDING_HOLD_ORANGE) <= 0.08) {
            return {
                state: "pending_hold",
                rawValue: "",
                bgHex,
                bookingIdFromMarker: null,
            };
        }
        if (
            colorDistance(rgb, SHEET_COLORS.BOOKED_GREEN) <= 0.08 ||
            colorDistance(rgb, SHEET_COLORS.BOOKED_BLUE) <= 0.08
        ) {
            return {
                state: "booked",
                rawValue: "",
                bgHex,
                bookingIdFromMarker: null,
            };
        }
        if (colorDistance(rgb, SHEET_COLORS.INVALID_DAY_GRAY) <= 0.05) {
            return {
                state: "empty",
                rawValue: "",
                bgHex,
                bookingIdFromMarker: null,
            };
        }
    }

    return {
        state: "host_blocked",
        rawValue,
        bgHex,
        bookingIdFromMarker: null,
    };
};

export const buildCalendarCellWriteData = (params: {
    text: string;
    bgColor: SheetRgbColor;
    bold?: boolean;
    note?: string | null;
    forcePlainText?: boolean;
}): { cell: RawSheetCell; fields: string } => {
    const safeText = params.forcePlainText
        ? String(params.text ?? "").trim()
        : sanitizeSheetTextValue(params.text);

    const cell: RawSheetCell = {
        userEnteredValue: {
            stringValue: safeText,
        },
        userEnteredFormat: {
            backgroundColorStyle: {
                rgbColor: params.bgColor,
            },
            horizontalAlignment: "CENTER",
            textFormat: {
                bold: Boolean(params.bold),
            },
            ...(params.forcePlainText
                ? {
                      numberFormat: {
                          type: "TEXT",
                      },
                  }
                : {}),
        },
        note: params.note ? sanitizeSheetTextValue(params.note, 450) : "",
    };

    const fields = params.forcePlainText
        ? "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold,numberFormat),note"
        : "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold),note";

    return { cell, fields };
};

// Sliding-window rate limiter to stay safely under Google Sheets 60 req/min project quota
class SlidingWindowRateLimiter {
    private timestamps: number[] = [];

    async acquire(maxPerMinute: number): Promise<void> {
        const safeLimit = Math.max(5, maxPerMinute);
        while (true) {
            const now = Date.now();
            this.timestamps = this.timestamps.filter((t) => now - t < 60_000);
            if (this.timestamps.length < safeLimit) {
                this.timestamps.push(now);
                return;
            }
            const oldest = this.timestamps[0];
            const waitMs = Math.max(50, Math.min(2_500, 60_000 - (now - oldest) + 25));
            await new Promise((resolve) => setTimeout(resolve, waitMs));
        }
    }
}

const rateLimiter = new SlidingWindowRateLimiter();

type ServiceAccountCredentials = {
    client_email: string;
    private_key: string;
    project_id?: string;
};

const loadServiceAccountCredentials = (): ServiceAccountCredentials | null => {
    const env = getEnv();

    if (env.googleServiceAccountEmail?.trim() && env.googleServiceAccountPrivateKey?.trim()) {
        return {
            client_email: env.googleServiceAccountEmail.trim(),
            private_key: env.googleServiceAccountPrivateKey
                .trim()
                .replace(/^["']|["']$/g, "")
                .replace(/\\n/g, "\n"),
        };
    }

    const candidates: Array<{ rawJson?: string; filePath?: string }> = [
        { rawJson: env.googleSheetsServiceAccountJson, filePath: env.googleSheetsServiceAccountPath },
        { rawJson: env.firebaseServiceAccountJson, filePath: env.firebaseServiceAccountPath },
    ];

    for (const candidate of candidates) {
        if (candidate.rawJson) {
            try {
                const parsed = JSON.parse(candidate.rawJson) as Partial<ServiceAccountCredentials>;
                if (parsed.client_email && parsed.private_key) {
                    return {
                        client_email: parsed.client_email,
                        private_key: parsed.private_key.replace(/\\n/g, "\n"),
                        project_id: parsed.project_id,
                    };
                }
            } catch {
                logger.warn("Invalid inline service account JSON for Google Sheets integration");
            }
        }

        if (candidate.filePath) {
            const resolvedPath = path.resolve(process.cwd(), candidate.filePath);
            if (fs.existsSync(resolvedPath)) {
                try {
                    const fileContent = fs.readFileSync(resolvedPath, "utf8");
                    const parsed = JSON.parse(fileContent) as Partial<ServiceAccountCredentials>;
                    if (parsed.client_email && parsed.private_key) {
                        return {
                            client_email: parsed.client_email,
                            private_key: parsed.private_key.replace(/\\n/g, "\n"),
                            project_id: parsed.project_id,
                        };
                    }
                } catch {
                    logger.warn("Failed to parse service account file for Google Sheets integration");
                }
            }
        }
    }

    return null;
};

let cachedGoogleAuth: GoogleAuth | null = null;
let cachedCredentialsEmail: string | null = null;

const getGoogleAuthClient = (): { auth: GoogleAuth; clientEmail: string } => {
    const credentials = loadServiceAccountCredentials();
    if (!credentials) {
        throw new GoogleSheetsClientError(
            "NOT_CONFIGURED",
            "Chưa cấu hình tài khoản dịch vụ Google Sheets (GOOGLE_SHEETS_SERVICE_ACCOUNT_PATH / JSON)",
            { httpStatus: 503, retryable: false },
        );
    }

    if (!cachedGoogleAuth || cachedCredentialsEmail !== credentials.client_email) {
        cachedGoogleAuth = new GoogleAuth({
            credentials: {
                client_email: credentials.client_email,
                private_key: credentials.private_key,
                project_id: credentials.project_id,
            },
            scopes: [...GOOGLE_SHEETS_MINIMAL_SCOPES],
        });
        cachedCredentialsEmail = credentials.client_email;
    }

    return {
        auth: cachedGoogleAuth,
        clientEmail: credentials.client_email,
    };
};

const sleepWithJitter = async (attempt: number) => {
    const baseMs = Math.min(4_000, 350 * Math.pow(2, attempt));
    const jitterMs = Math.floor(Math.random() * 200);
    await new Promise((resolve) => setTimeout(resolve, baseMs + jitterMs));
};

const executeSheetsHttpRequest = async <T>(
    url: string,
    init: { method: "GET" | "POST"; body?: string },
): Promise<T> => {
    const env = getEnv();
    const { auth } = getGoogleAuthClient();
    const maxAttempts = 3;

    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
        await rateLimiter.acquire(env.googleSheetsRateLimitPerMinute);
        const client = await auth.getClient();
        const tokenResponse = await client.getAccessToken();
        const accessToken = typeof tokenResponse === "string" ? tokenResponse : tokenResponse?.token;

        if (!accessToken) {
            throw new GoogleSheetsClientError(
                "NOT_CONFIGURED",
                "Không lấy được access token cho dịch vụ Google Sheets",
                { httpStatus: 503, retryable: true },
            );
        }

        const controller = new AbortController();
        const timeoutHandle = setTimeout(() => controller.abort(), env.googleSheetsRequestTimeoutMs);

        try {
            const response = await fetch(url, {
                method: init.method,
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                    "Content-Type": "application/json",
                    Accept: "application/json",
                },
                body: init.body,
                signal: controller.signal,
            });

            if (response.ok) {
                return (await response.json()) as T;
            }

            if ((response.status === 429 || response.status === 503 || response.status === 502) && attempt + 1 < maxAttempts) {
                await sleepWithJitter(attempt);
                continue;
            }

            if (response.status === 401 || response.status === 403) {
                throw new GoogleSheetsClientError(
                    "PERMISSION_DENIED",
                    "Tài khoản dịch vụ chưa được cấp quyền Chỉnh sửa (Editor) trên Google Sheets này",
                    { httpStatus: 403, retryable: false },
                );
            }

            if (response.status === 404) {
                throw new GoogleSheetsClientError(
                    "SPREADSHEET_NOT_FOUND",
                    "Không tìm thấy Google Sheets. Vui lòng kiểm tra lại liên kết hoặc quyền chia sẻ",
                    { httpStatus: 404, retryable: false },
                );
            }

            if (response.status === 429) {
                throw new GoogleSheetsClientError(
                    "QUOTA_EXCEEDED",
                    "Google Sheets đang giới hạn tần suất truy cập tạm thời (429). Hệ thống sẽ tự thử lại",
                    { httpStatus: 429, retryable: true },
                );
            }

            throw new GoogleSheetsClientError(
                "UPSTREAM_UNAVAILABLE",
                `Google Sheets API phản hồi lỗi HTTP ${response.status}`,
                { httpStatus: 503, retryable: response.status >= 500 },
            );
        } catch (error) {
            if (error instanceof GoogleSheetsClientError) {
                throw error;
            }
            if (attempt + 1 < maxAttempts) {
                await sleepWithJitter(attempt);
                continue;
            }
            throw new GoogleSheetsClientError(
                "UPSTREAM_UNAVAILABLE",
                "Không thể kết nối tới Google Sheets API vào lúc này",
                { httpStatus: 503, retryable: true },
            );
        } finally {
            clearTimeout(timeoutHandle);
        }
    }

    throw new GoogleSheetsClientError(
        "UPSTREAM_UNAVAILABLE",
        "Google Sheets API tạm thời không phản hồi",
        { httpStatus: 503, retryable: true },
    );
};

const defaultHttpTransport: GoogleSheetsTransport = {
    async getServiceAccountEmail() {
        const creds = loadServiceAccountCredentials();
        return creds?.client_email ?? null;
    },

    async getSpreadsheet({ spreadsheetId, ranges, includeGridData, fields }) {
        const { spreadsheetId: safeId } = parseAndValidateSpreadsheetInput(spreadsheetId);
        const query = new URLSearchParams();
        if (includeGridData) {
            query.set("includeGridData", "true");
        }
        if (fields) {
            query.set("fields", fields);
        }
        if (ranges && ranges.length > 0) {
            for (const range of ranges) {
                query.append("ranges", range);
            }
        }
        const qs = query.toString();
        const url = `${GOOGLE_SHEETS_API_BASE}/${encodeURIComponent(safeId)}${qs ? `?${qs}` : ""}`;
        return executeSheetsHttpRequest<RawSpreadsheetResponse>(url, { method: "GET" });
    },

    async batchUpdate({ spreadsheetId, requests }) {
        if (requests.length === 0) {
            return {};
        }
        const { spreadsheetId: safeId } = parseAndValidateSpreadsheetInput(spreadsheetId);
        const url = `${GOOGLE_SHEETS_API_BASE}/${encodeURIComponent(safeId)}:batchUpdate`;
        return executeSheetsHttpRequest<Record<string, unknown>>(url, {
            method: "POST",
            body: JSON.stringify({ requests }),
        });
    },
};

let activeTransport: GoogleSheetsTransport = defaultHttpTransport;

export const getGoogleSheetsTransport = (): GoogleSheetsTransport => activeTransport;

export const setGoogleSheetsTransportForTesting = (transport: GoogleSheetsTransport): void => {
    activeTransport = transport;
};

export const resetGoogleSheetsTransportForTesting = (): void => {
    activeTransport = defaultHttpTransport;
};

export const getConfiguredServiceAccountEmail = async (): Promise<string | null> => {
    return activeTransport.getServiceAccountEmail();
};

/**
 * Verifies BOTH read access AND real Editor (write) permission on the target Spreadsheet
 * by performing a non-destructive DeveloperMetadata ping write (`agy_agency_ping`).
 */
export const verifySpreadsheetEditorAccess = async (
    spreadsheetId: string,
): Promise<{
    spreadsheetId: string;
    title: string;
    serviceAccountEmail: string | null;
    canWrite: boolean;
}> => {
    const { spreadsheetId: safeId } = parseAndValidateSpreadsheetInput(spreadsheetId);
    const transport = getGoogleSheetsTransport();
    const serviceAccountEmail = await transport.getServiceAccountEmail();

    const meta = await transport.getSpreadsheet({
        spreadsheetId: safeId,
        includeGridData: false,
        fields: "spreadsheetId,properties.title,developerMetadata(metadataId,metadataKey,metadataValue)",
    });

    const existingPing = (meta.developerMetadata ?? []).find(
        (item) => item.metadataKey === "agy_agency_ping",
    );
    const nowIso = new Date().toISOString();

    const writeRequest = existingPing?.metadataId
        ? {
              updateDeveloperMetadata: {
                  dataFilters: [
                      {
                          developerMetadataLookup: {
                              metadataId: existingPing.metadataId,
                          },
                      },
                  ],
                  developerMetadata: {
                      metadataKey: "agy_agency_ping",
                      metadataValue: nowIso,
                      visibility: "DOCUMENT",
                  },
                  fields: "metadataValue",
              },
          }
        : {
              createDeveloperMetadata: {
                  developerMetadata: {
                      metadataKey: "agy_agency_ping",
                      metadataValue: nowIso,
                      location: {
                          spreadsheet: true,
                      },
                      visibility: "DOCUMENT",
                  },
              },
          };

    await transport.batchUpdate({
        spreadsheetId: safeId,
        requests: [writeRequest],
    });

    return {
        spreadsheetId: safeId,
        title: meta.properties?.title?.trim() || "Lịch quản lý chỗ nghỉ",
        serviceAccountEmail,
        canWrite: true,
    };
};
