// CONFLICT-RESOLVED: Chuyển khách giao tiếp Google Sheets từ `src/services/google-sheets-client.service.ts` về `src/modules/host-sheet-sync/google-sheets.client.ts`.
import fs from "node:fs";
import path from "node:path";
import { GoogleAuth } from "google-auth-library";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";

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

/**
 * Lớp ngoại lệ chuyên biệt chuẩn hóa các sự cố giao tiếp Google Sheets API v4,
 * đính kèm mã phân loại lỗi nghiệp vụ (`code`), mã HTTP và cờ cho phép thử lại (`retryable`).
 */
export class GoogleSheetsClientError extends Error {
    readonly code: GoogleSheetsErrorCode;
    readonly httpStatus: number;
    readonly retryable: boolean;

    /**
     * Khởi tạo ngoại lệ khách Google Sheets với thông tin trạng thái HTTP và khả năng tự thử lại.
     */
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
        columnMetadata?: Array<{
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
 * Giải thuật làm sạch chuỗi văn bản trước khi ghi vào ô Google Sheets nhằm triệt tiêu lỗ hổng
 * chèn công thức độc hại (Spreadsheet Formula Injection / CSV Injection):
 * 1. Khử các ký tự điều khiển ASCII không in được, chuẩn hóa xuống dòng thành dấu cách, cắt khoảng trắng thừa
 *    và giới hạn độ dài tối đa `maxLength`.
 * 2. Nếu ký tự đầu tiên thuộc tập kích hoạt công thức (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n`), tự động chèn
 *    tiền tố dấu nháy đơn `'` để buộc Google Sheets lưu trữ dưới dạng văn bản thuần.
 *
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
 * Giải thuật phân tích và xác thực nghiêm ngặt liên kết hoặc mã định danh Google Spreadsheet
 * chống tấn công giả mạo yêu cầu phía máy chủ (Anti-SSRF) và leo thang đường dẫn (Path Traversal):
 * - Trường hợp nhập trực tiếp ID: Kiểm tra khớp biểu thức `/^[a-zA-Z0-9-_]{20,120}$/` và không chứa dấu phân tách URL.
 * - Trường hợp nhập URL: Bắt buộc giao thức `https:`, tên miền chính xác `docs.google.com`, từ chối thông tin
 *   đăng nhập nhúng (`username`/`password`), từ chối cổng tùy chỉnh (`port`) và chuỗi `..` sau giải mã URI,
 *   trích xuất `spreadsheetId` từ mẫu `/spreadsheets/d/<id>` và chuẩn hóa về URL chính tắc.
 *
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

/**
 * Giải thuật kẹp biên giá trị kênh màu đơn sắc về đoạn chuẩn hóa `[0, 1]` (`min(1, max(0, value))`),
 * trả về `0` an toàn nếu đầu vào bị khuyết hoặc không phải số thực hữu hạn.
 */
const clampChannel = (value: number | undefined): number => {
    if (typeof value !== "number" || !Number.isFinite(value)) {
        return 0;
    }
    return Math.min(1, Math.max(0, value));
};

/**
 * Giải thuật chuyển đổi màu RGB chuẩn hóa trong đoạn `[0, 1]` của Google Sheets sang chuỗi mã màu
 * thập lục phân `#RRGGBB` viết hoa bằng cách kẹp biên từng kênh màu, nhân `255` và làm tròn nguyên.
 */
export const rgbToHex = (rgb?: Partial<SheetRgbColor> | null): string | null => {
    if (!rgb || (rgb.red === undefined && rgb.green === undefined && rgb.blue === undefined)) {
        return null;
    }
    const r = Math.round(clampChannel(rgb.red ?? 0) * 255);
    const g = Math.round(clampChannel(rgb.green ?? 0) * 255);
    const b = Math.round(clampChannel(rgb.blue ?? 0) * 255);
    return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`.toUpperCase();
};

/**
 * Giải thuật tính khoảng cách Euclid trong không gian màu ba chiều RGB chuẩn hóa `[0, 1]^3`:
 * - Công thức toán học: `d(a, b) = sqrt((a.red - b.red)^2 + (a.green - b.green)^2 + (a.blue - b.blue)^2)`,
 *   với miền giá trị thuộc đoạn `[0, sqrt(3)]` (`sqrt(3) ~ 1.732`).
 * - Cơ chế chịu lỗi sắc độ: Cho phép nhận diện chính xác nhóm màu ngữ nghĩa của ô lịch (cam giữ chỗ,
 *   xanh lá/xanh dương đã đặt, xám vô hiệu) ngay cả khi người dùng tô màu thủ công bị lệch nhẹ sắc độ
 *   hoặc khác bảng màu thiết bị.
 */
const colorDistance = (a: SheetRgbColor, b: SheetRgbColor): number => {
    const dr = a.red - b.red;
    const dg = a.green - b.green;
    const db = a.blue - b.blue;
    return Math.sqrt(dr * dr + dg * dg + db * db);
};

/**
 * Giải thuật trích xuất màu nền trực tiếp từ `userEnteredFormat` của ô Google Sheets:
 * - Chỉ đọc `backgroundColorStyle.rgbColor` (hoặc dự phòng `backgroundColor` kế thừa) và ánh xạ các
 *   màu chủ đề `themeColor` khác nền mặc định về sắc đỏ nhận diện khóa `{0.9, 0.5, 0.5}`.
 * - Tuyệt đối bỏ qua `effectiveFormat` để các quy tắc định dạng có điều kiện (Conditional Formatting)
 *   trên trang tính không bao giờ kích hoạt khóa phòng giả.
 *
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

/**
 * Giải thuật trích xuất văn bản hiển thị thô từ `userEnteredValue` của ô theo thứ tự ưu tiên
 * `stringValue -> numberValue -> boolValue -> formulaValue` và chuẩn hóa cắt khoảng trắng hai đầu.
 */
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

/**
 * Giải thuật phân loại ngữ nghĩa ô lịch Google Sheets kết hợp cả ký hiệu văn bản lẫn khoảng cách Euclid màu nền RGB:
 * 1. Ngày không hợp lệ (`invalid_day`): Khi văn bản ô mang dấu gạch chéo đánh dấu ngày không tồn tại trong tháng.
 * 2. Xác định nền trắng/mặc định (`isWhiteOrUnset`): Khi ô chưa tô màu hoặc cả 3 kênh `R, G, B >= 0.965`.
 * 3. Trạng thái giữ chỗ chờ thanh toán (`pending_hold`): Văn bản khớp mẫu `G #<bookingId>` đi kèm nền trắng/mặc định
 *    hoặc khoảng cách màu `colorDistance(rgb, PENDING_HOLD_ORANGE) <= 0.18`.
 * 4. Trạng thái đã đặt phòng (`booked`): Văn bản khớp mẫu `Đ #<bookingId>` / `D #<bookingId>` đi kèm nền trắng/mặc định
 *    hoặc khoảng cách màu tới xanh lá (`BOOKED_GREEN`) hay xanh dương (`BOOKED_BLUE`) `<= 0.20`.
 * 5. Trạng thái trống (`empty`): Nền trắng/mặc định và văn bản hoàn toàn rỗng.
 * 6. Chống khóa nhầm khi xóa chữ trên ô hệ thống: Nếu văn bản rỗng nhưng màu nền vẫn rất sát cam giữ chỗ (`d <= 0.08`),
 *    xanh lá/xanh dương đã đặt (`d <= 0.08`) hoặc xám vô hiệu (`d <= 0.05`), phân loại về trạng thái hệ thống tương ứng
 *    thay vì nhận nhầm là lệnh khóa mới của chủ nhà.
 * 7. Khóa lịch chủ nhà (`host_blocked` - Fail-safe): Mọi ô còn lại có ghi chú văn bản bất kỳ (như `"K"`, tên khách lẻ,
 *    bảo trì) hoặc tô màu đỏ/màu tùy chỉnh đều được hiểu là chủ nhà đóng lịch.
 */
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

/**
 * Giải thuật đóng gói dữ liệu ghi ô lịch (`RawSheetCell`) và chuỗi mặt nạ trường `fields` cho lệnh `UpdateCells`:
 * - Tự động lọc chống chèn công thức qua `sanitizeSheetTextValue` cho cả nội dung ô và ghi chú `note`.
 * - Khi bật `forcePlainText`, ép kiểu định dạng số `TEXT` để bảo toàn chuỗi mã định danh không bị ép kiểu số/ngày.
 */
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
/**
 * Bộ giới hạn tần suất yêu cầu theo cửa sổ trượt thời gian thực (`Sliding-Window Log Rate Limiter`)
 * giữ lưu lượng gọi Google Sheets API an toàn dưới hạn mức dự án (60 yêu cầu/phút).
 */
class SlidingWindowRateLimiter {
    private timestamps: number[] = [];

    /**
     * Giải thuật cấp quyền thực thi yêu cầu trong cửa sổ trượt `60.000 ms`:
     * - Lọc bỏ các mốc thời gian cũ hơn `60s` (`now - t < 60_000`). Nếu tổng yêu cầu hiện hành nhỏ hơn
     *   `safeLimit = max(5, maxPerMinute)`, ghi nhận ngay mốc `now` và cho phép đi tiếp.
     * - Nếu chạm ngưỡng, tính thời gian ngủ `waitMs = min(2500, max(50, 60_000 - (now - oldest) + 25))` ms
     *   chờ phần tử cũ nhất rời khỏi cửa sổ trượt rồi kiểm tra lại.
     */
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

/**
 * Giải thuật nạp khóa tài khoản dịch vụ Google (`ServiceAccountCredentials`) theo chuỗi ưu tiên dự phòng:
 * 1. Cặp biến môi trường rời (`GOOGLE_SERVICE_ACCOUNT_EMAIL` + `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`).
 * 2. Chuỗi JSON cấu hình nội tuyến hoặc đường dẫn tệp JSON chuyên biệt cho Google Sheets, dự phòng sang Firebase,
 *    đồng thời chuẩn hóa chuỗi thoát `\\n` về ký tự xuống dòng thực tế cho khóa riêng RSA PEM.
 */
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

/**
 * Giải thuật khởi tạo và lưu đệm thực thể xác thực `GoogleAuth` với phạm vi quyền tối thiểu (`spreadsheets`):
 * - Dùng khóa riêng RSA của Service Account ký JWT chuẩn OAuth2 để trao đổi lấy Bearer Access Token ngắn hạn
 *   từ máy chủ định danh Google, tận dụng cơ chế lưu đệm token có khoảng đệm thời hạn làm mới sớm tự động
 *   của `google-auth-library` và tự động tái tạo nếu `client_email` cấu hình thay đổi.
 */
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

/**
 * Giải thuật tạm dừng giãn cách lũy thừa có nhiễu ngẫu nhiên giữa các lần thử lại HTTP:
 * `delayMs = min(4000, 350 * 2^attempt) + floor(random() * 200)` ms.
 */
const sleepWithJitter = async (attempt: number) => {
    const baseMs = Math.min(4_000, 350 * Math.pow(2, attempt));
    const jitterMs = Math.floor(Math.random() * 200);
    await new Promise((resolve) => setTimeout(resolve, baseMs + jitterMs));
};

/**
 * Giải thuật thực thi yêu cầu HTTP tới Google Sheets API v4 có tích hợp điều tiết hạn mức, trao đổi OAuth2 token,
 * kiểm soát thời gian chờ và thử lại chịu lỗi tự động:
 * 1. Xin cấp phát lượt gọi từ `rateLimiter.acquire` và lấy OAuth2 Access Token đã đệm thời hạn qua `GoogleAuth`.
 * 2. Đặt bộ ngắt thời gian chờ `AbortController` theo `googleSheetsRequestTimeoutMs` (luôn dọn `clearTimeout` ở `finally`).
 * 3. Chính sách thử lại & phân loại lỗi (tối đa `maxAttempts = 3`):
 *    - Tự động chờ `sleepWithJitter` và thử lại khi gặp lỗi kết nối mạng hoặc mã HTTP tạm thời `429 / 502 / 503`.
 *    - Dừng ngay không thử lại với `401 / 403` (`PERMISSION_DENIED`) và `404` (`SPREADSHEET_NOT_FOUND`).
 *    - Khi hết lượt thử trên mã `429`, ném `QUOTA_EXCEEDED`; các mã lỗi khác ném `UPSTREAM_UNAVAILABLE`.
 */
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

/**
 * Bộ vận chuyển HTTP mặc định triển khai giao tiếp REST với `spreadsheets.get` và `spreadsheets.batchUpdate`:
 * - Mọi đầu vào `spreadsheetId` đều được kiểm định chống SSRF qua `parseAndValidateSpreadsheetInput` và mã hóa URI.
 * - `getSpreadsheet`: Hỗ trợ tải đa vùng `ranges` và mặt nạ trường `fields` giúp tối thiểu hóa dung lượng JSON tải về.
 * - `batchUpdate`: Bỏ qua sớm không tốn hạn mức nếu danh sách `requests` rỗng, thực thi lô cập nhật nguyên tử qua `POST :batchUpdate`.
 */
const defaultHttpTransport: GoogleSheetsTransport = {
    /**
     * Trả về địa chỉ email của tài khoản dịch vụ Google đang cấu hình để hướng dẫn chủ nhà cấp quyền chia sẻ.
     */
    async getServiceAccountEmail() {
        const creds = loadServiceAccountCredentials();
        return creds?.client_email ?? null;
    },

    /**
     * Gọi điểm cuối `GET /v4/spreadsheets/{spreadsheetId}` kèm tùy chọn lọc vùng A1 và mặt nạ trường dữ liệu.
     */
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

    /**
     * Gọi điểm cuối `POST /v4/spreadsheets/{spreadsheetId}:batchUpdate` thực thi nguyên tử danh sách yêu cầu cập nhật.
     */
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

/**
 * Trả về bộ vận chuyển Google Sheets hiện hành (HTTP thực tế hoặc bản giả lập trong kiểm thử).
 */
export const getGoogleSheetsTransport = (): GoogleSheetsTransport => activeTransport;

/**
 * Thay thế bộ vận chuyển Google Sheets phục vụ kiểm thử đơn vị và tích hợp không cần kết nối mạng ngoài.
 */
export const setGoogleSheetsTransportForTesting = (transport: GoogleSheetsTransport): void => {
    activeTransport = transport;
};

/**
 * Khôi phục bộ vận chuyển Google Sheets về triển khai HTTP mặc định sau khi kết thúc kiểm thử.
 */
export const resetGoogleSheetsTransportForTesting = (): void => {
    activeTransport = defaultHttpTransport;
};

/**
 * Truy xuất email tài khoản dịch vụ Google hiện đang được cấu hình thông qua bộ vận chuyển hiện hành.
 */
export const getConfiguredServiceAccountEmail = async (): Promise<string | null> => {
    return activeTransport.getServiceAccountEmail();
};

/**
 * Giải thuật xác minh kép quyền Đọc và quyền Ghi thực sự (`Editor`) trên Google Spreadsheet
 * bằng thao tác ghi thử siêu dữ liệu ẩn không phá hủy nội dung bảng tính (`DeveloperMetadata Ping`):
 * 1. Gọi `getSpreadsheet` để kiểm tra quyền đọc, lấy tiêu đề bảng tính và dò thẻ `agy_agency_ping`.
 * 2. Gửi lệnh `batchUpdate` cập nhật (nếu đã có `metadataId`) hoặc tạo mới thẻ `agy_agency_ping` với dấu thời gian
 *    ISO hiện tại; nếu chủ nhà mới chỉ cấp quyền Xem (`Viewer`), Google API sẽ trả `403` và bị chặn ngay lập tức.
 *
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
