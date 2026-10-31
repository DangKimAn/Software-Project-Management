import {
    buildCalendarCellWriteData,
    extractCellRawText,
    RawDeveloperMetadata,
    RawSheetCell,
    RawSheetTab,
    sanitizeSheetTextValue,
    SHEET_COLORS,
    SheetRgbColor,
} from "../../services/google-sheets-client.service";

export const DIRECTORY_TAB_TITLE = "DANH MỤC CĂN";

export const SHEET_METADATA_KEYS = {
    DIRECTORY_TAB: "agy_directory_tab",
    MONTH_TAB: "agy_month_tab",
    LISTING_ROW: "agy_listing_id",
} as const;

export const SHEET_HEADER_ROW_COUNT = 2;
export const SHEET_DAY_COLUMN_OFFSET = 2; // Col A = 0 (listing_id), Col B = 1 (title), Col C..AG = 2..32 (day 01..31)
export const SHEET_TOTAL_COLUMNS = 33; // 2 + 31

export type RollingMonthSpec = {
    tabKey: string; // MM-YYYY e.g. "10-2026"
    year: number;
    month: number; // 1..12
    daysInMonth: number;
    firstDate: string; // YYYY-MM-DD
    lastDate: string; // YYYY-MM-DD
};

export const getDaysInCalendarMonth = (year: number, month: number): number => {
    return new Date(Date.UTC(year, month, 0)).getUTCDate();
};

export const formatIsoDate = (year: number, month: number, day: number): string => {
    return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
};

export const formatMonthTabKey = (year: number, month: number): string => {
    return `${String(month).padStart(2, "0")}-${String(year).padStart(4, "0")}`;
};

export const parseMonthTabKey = (tabKey: string): RollingMonthSpec | null => {
    const match = /^(0[1-9]|1[0-2])-(\d{4})$/.exec(tabKey.trim());
    if (!match) {
        return null;
    }
    const month = Number(match[1]);
    const year = Number(match[2]);
    const daysInMonth = getDaysInCalendarMonth(year, month);
    return {
        tabKey: formatMonthTabKey(year, month),
        year,
        month,
        daysInMonth,
        firstDate: formatIsoDate(year, month, 1),
        lastDate: formatIsoDate(year, month, daysInMonth),
    };
};

export const monthTabKeyFromIsoDate = (isoDate: string): string | null => {
    const match = /^(\d{4})-(0[1-9]|1[0-2])-(\d{2})$/.exec(isoDate.trim());
    if (!match) {
        return null;
    }
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const maxDay = getDaysInCalendarMonth(year, month);
    if (day < 1 || day > maxDay) {
        return null;
    }
    return formatMonthTabKey(year, month);
};

export const buildRollingMonthSpecs = (baseIsoDate: string, monthCount = 6): RollingMonthSpec[] => {
    const match = /^(\d{4})-(0[1-9]|1[0-2])-(\d{2})$/.exec(baseIsoDate.trim());
    const baseYear = match ? Number(match[1]) : new Date().getUTCFullYear();
    const baseMonth = match ? Number(match[2]) : new Date().getUTCMonth() + 1;

    const specs: RollingMonthSpec[] = [];
    for (let offset = 0; offset < monthCount; offset += 1) {
        const totalMonths = baseYear * 12 + (baseMonth - 1) + offset;
        const year = Math.floor(totalMonths / 12);
        const month = (totalMonths % 12) + 1;
        const daysInMonth = getDaysInCalendarMonth(year, month);
        specs.push({
            tabKey: formatMonthTabKey(year, month),
            year,
            month,
            daysInMonth,
            firstDate: formatIsoDate(year, month, 1),
            lastDate: formatIsoDate(year, month, daysInMonth),
        });
    }
    return specs;
};

export const escapeSheetTitleForA1 = (title: string): string => {
    return `'${title.replace(/'/g, "''")}'`;
};

export const resolveDirectorySheetTab = (sheets: RawSheetTab[]): RawSheetTab | undefined => {
    const byMetadata = sheets.find((sheet) =>
        (sheet.developerMetadata ?? []).some(
            (meta) => meta.metadataKey === SHEET_METADATA_KEYS.DIRECTORY_TAB && meta.metadataValue === "true",
        ),
    );
    if (byMetadata) {
        return byMetadata;
    }

    return sheets.find(
        (sheet) => sheet.properties.title.trim().toUpperCase() === DIRECTORY_TAB_TITLE,
    );
};

export const resolveMonthSheetTab = (sheets: RawSheetTab[], monthTabKey: string): RawSheetTab | undefined => {
    const byMetadata = sheets.find((sheet) =>
        (sheet.developerMetadata ?? []).some(
            (meta) => meta.metadataKey === SHEET_METADATA_KEYS.MONTH_TAB && meta.metadataValue === monthTabKey,
        ),
    );
    if (byMetadata) {
        return byMetadata;
    }

    return sheets.find((sheet) => sheet.properties.title.trim() === monthTabKey);
};

export type ExtractedSheetListingRow = {
    rowIndex: number; // 0-based row index in sheet
    listingId: number;
    colAText: string;
    colBTitle: string;
    metadataListingId: number | null;
    colMismatch: boolean;
    cellsByDay: Map<number, RawSheetCell | undefined>;
};

export type ExtractedMonthSheetStructure = {
    rowsByListingId: Map<number, ExtractedSheetListingRow[]>;
    duplicateListingIds: Set<number>;
    tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }>;
    nextAppendRowIndex: number;
};

const parsePositiveListingId = (raw: string | undefined | null): number | null => {
    if (!raw) {
        return null;
    }
    const cleaned = String(raw).replace(/^'+/, "").trim();
    if (!/^\d+$/.test(cleaned)) {
        return null;
    }
    const num = Number.parseInt(cleaned, 10);
    return Number.isSafeInteger(num) && num > 0 ? num : null;
};

const findRowDeveloperMetadataListingId = (
    tab: RawSheetTab,
    rowIndex: number,
    gridRowMeta?: { developerMetadata?: RawDeveloperMetadata[] },
): number | null => {
    for (const meta of gridRowMeta?.developerMetadata ?? []) {
        if (meta.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW) {
            const parsed = parsePositiveListingId(meta.metadataValue);
            if (parsed) {
                return parsed;
            }
        }
    }

    for (const meta of tab.developerMetadata ?? []) {
        if (meta.metadataKey !== SHEET_METADATA_KEYS.LISTING_ROW) {
            continue;
        }
        const range = meta.location?.dimensionRange;
        if (
            range &&
            range.dimension === "ROWS" &&
            range.startIndex === rowIndex &&
            range.endIndex === rowIndex + 1
        ) {
            const parsed = parsePositiveListingId(meta.metadataValue);
            if (parsed) {
                return parsed;
            }
        }
    }

    return null;
};

export const extractMonthSheetStructure = (tab: RawSheetTab): ExtractedMonthSheetStructure => {
    const grid = tab.data?.[0];
    const startRow = grid?.startRow ?? 0;
    const rowData = grid?.rowData ?? [];
    const rowMetadata = grid?.rowMetadata ?? [];

    const rowsByListingId = new Map<number, ExtractedSheetListingRow[]>();
    const duplicateListingIds = new Set<number>();
    const tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }> = [];

    let maxUsedRowIndex = SHEET_HEADER_ROW_COUNT - 1;

    for (let offset = 0; offset < rowData.length; offset += 1) {
        const rowIndex = startRow + offset;
        if (rowIndex < SHEET_HEADER_ROW_COUNT) {
            continue;
        }

        const values = rowData[offset]?.values ?? [];
        const colAText = extractCellRawText(values[0]);
        const colBTitle = extractCellRawText(values[1]);
        const colAListingId = parsePositiveListingId(colAText);
        const metadataListingId = findRowDeveloperMetadataListingId(tab, rowIndex, rowMetadata[offset]);

        const hasAnyContent =
            colAText !== "" ||
            colBTitle !== "" ||
            metadataListingId !== null ||
            values.slice(2).some((cell) => extractCellRawText(cell) !== "");

        if (hasAnyContent) {
            maxUsedRowIndex = Math.max(maxUsedRowIndex, rowIndex);
        }

        if (metadataListingId === null && colAListingId === null) {
            if (colAText !== "") {
                tamperedRowIndices.push({ rowIndex, colAText, metadataListingId: null });
            }
            continue;
        }

        const colMismatch =
            metadataListingId !== null && colAListingId !== null && metadataListingId !== colAListingId;
        if (colMismatch) {
            tamperedRowIndices.push({ rowIndex, colAText, metadataListingId });
        }

        // Authoritative row identity prefers immutable Row DeveloperMetadata when present
        const resolvedListingId = metadataListingId ?? colAListingId!;
        const cellsByDay = new Map<number, RawSheetCell | undefined>();
        for (let day = 1; day <= 31; day += 1) {
            cellsByDay.set(day, values[SHEET_DAY_COLUMN_OFFSET + (day - 1)]);
        }

        const extractedRow: ExtractedSheetListingRow = {
            rowIndex,
            listingId: resolvedListingId,
            colAText,
            colBTitle,
            metadataListingId,
            colMismatch,
            cellsByDay,
        };

        const existingRows = rowsByListingId.get(resolvedListingId) ?? [];
        existingRows.push(extractedRow);
        rowsByListingId.set(resolvedListingId, existingRows);

        if (existingRows.length > 1) {
            duplicateListingIds.add(resolvedListingId);
        }
    }

    return {
        rowsByListingId,
        duplicateListingIds,
        tamperedRowIndices,
        nextAppendRowIndex: Math.max(SHEET_HEADER_ROW_COUNT, maxUsedRowIndex + 1),
    };
};

const makeStyledHeaderCell = (
    text: string,
    bgColor: SheetRgbColor,
    options: { bold?: boolean; align?: "LEFT" | "CENTER" } = {},
): RawSheetCell => ({
    userEnteredValue: { stringValue: text },
    userEnteredFormat: {
        backgroundColorStyle: { rgbColor: bgColor },
        horizontalAlignment: options.align ?? "CENTER",
        textFormat: { bold: options.bold ?? true },
    },
});

export const buildMonthTabHeaderRequests = (
    tab: RawSheetTab,
    monthSpec: RollingMonthSpec,
): Array<Record<string, unknown>> => {
    const requests: Array<Record<string, unknown>> = [];
    const sheetId = tab.properties.sheetId;

    const currentFrozenRows = tab.properties.gridProperties?.frozenRowCount ?? 0;
    const currentFrozenCols = tab.properties.gridProperties?.frozenColumnCount ?? 0;
    const currentCols = tab.properties.gridProperties?.columnCount ?? 26;

    if (
        currentFrozenRows !== SHEET_HEADER_ROW_COUNT ||
        currentFrozenCols !== SHEET_DAY_COLUMN_OFFSET ||
        currentCols < SHEET_TOTAL_COLUMNS
    ) {
        requests.push({
            updateSheetProperties: {
                properties: {
                    sheetId,
                    gridProperties: {
                        frozenRowCount: SHEET_HEADER_ROW_COUNT,
                        frozenColumnCount: SHEET_DAY_COLUMN_OFFSET,
                        columnCount: Math.max(currentCols, SHEET_TOTAL_COLUMNS),
                        rowCount: Math.max(tab.properties.gridProperties?.rowCount ?? 200, 200),
                    },
                },
                fields: "gridProperties(frozenRowCount,frozenColumnCount,columnCount,rowCount)",
            },
        });
    }

    const hasMonthMetadata = (tab.developerMetadata ?? []).some(
        (m) => m.metadataKey === SHEET_METADATA_KEYS.MONTH_TAB && m.metadataValue === monthSpec.tabKey,
    );
    if (!hasMonthMetadata) {
        requests.push({
            createDeveloperMetadata: {
                developerMetadata: {
                    metadataKey: SHEET_METADATA_KEYS.MONTH_TAB,
                    metadataValue: monthSpec.tabKey,
                    location: { sheetId },
                    visibility: "DOCUMENT",
                },
            },
        });
    }

    // Column widths for clean UX
    requests.push(
        {
            updateDimensionProperties: {
                range: { sheetId, dimension: "COLUMNS", startIndex: 0, endIndex: 1 },
                properties: { pixelSize: 90 },
                fields: "pixelSize",
            },
        },
        {
            updateDimensionProperties: {
                range: { sheetId, dimension: "COLUMNS", startIndex: 1, endIndex: 2 },
                properties: { pixelSize: 240 },
                fields: "pixelSize",
            },
        },
        {
            updateDimensionProperties: {
                range: { sheetId, dimension: "COLUMNS", startIndex: 2, endIndex: SHEET_TOTAL_COLUMNS },
                properties: { pixelSize: 46 },
                fields: "pixelSize",
            },
        },
    );

    const row0Cells: RawSheetCell[] = [
        makeStyledHeaderCell("HƯỚNG DẪN", SHEET_COLORS.HEADER_BG, { bold: true, align: "CENTER" }),
        makeStyledHeaderCell(
            `THÁNG ${monthSpec.tabKey} — Trắng: Trống | Cam (G): Giữ chỗ | Xanh (Đ): Đã đặt | Đỏ (K): Host khóa (Không tô màu trang trí cả dòng)`,
            SHEET_COLORS.HEADER_BG,
            { bold: true, align: "LEFT" },
        ),
    ];
    for (let day = 1; day <= 31; day += 1) {
        row0Cells.push(
            makeStyledHeaderCell(
                day <= monthSpec.daysInMonth ? "" : "—",
                day <= monthSpec.daysInMonth ? SHEET_COLORS.HEADER_BG : SHEET_COLORS.INVALID_DAY_GRAY,
                { bold: false },
            ),
        );
    }

    const row1Cells: RawSheetCell[] = [
        makeStyledHeaderCell("Mã căn (Khóa)", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "CENTER" }),
        makeStyledHeaderCell("Tên căn hộ / Villa", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "LEFT" }),
    ];
    for (let day = 1; day <= 31; day += 1) {
        const isValid = day <= monthSpec.daysInMonth;
        row1Cells.push(
            makeStyledHeaderCell(
                isValid ? String(day).padStart(2, "0") : "✕",
                isValid ? SHEET_COLORS.SUBHEADER_BG : SHEET_COLORS.INVALID_DAY_GRAY,
                { bold: isValid, align: "CENTER" },
            ),
        );
    }

    requests.push({
        updateCells: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: SHEET_HEADER_ROW_COUNT,
                startColumnIndex: 0,
                endColumnIndex: SHEET_TOTAL_COLUMNS,
            },
            rows: [{ values: row0Cells }, { values: row1Cells }],
            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold)",
        },
    });

    const hasProtection = (tab.protectedRanges ?? []).some(
        (range) => range.description === `agy_protect_col_a_${monthSpec.tabKey}`,
    );
    if (!hasProtection) {
        requests.push({
            addProtectedRange: {
                protectedRange: {
                    range: {
                        sheetId,
                        startColumnIndex: 0,
                        endColumnIndex: 1,
                    },
                    description: `agy_protect_col_a_${monthSpec.tabKey}`,
                    warningOnly: true,
                },
            },
        });
    }

    return requests;
};

export type DirectoryListingEntry = {
    listingId: number;
    title: string;
    district: string;
    city: string;
    basePrice: number;
    status: string;
    deletedAt: Date | null;
};

export const buildDirectoryTabRequests = (
    tab: RawSheetTab,
    listings: DirectoryListingEntry[],
): Array<Record<string, unknown>> => {
    const sheetId = tab.properties.sheetId;
    const requests: Array<Record<string, unknown>> = [];

    const hasDirMetadata = (tab.developerMetadata ?? []).some(
        (m) => m.metadataKey === SHEET_METADATA_KEYS.DIRECTORY_TAB && m.metadataValue === "true",
    );
    if (!hasDirMetadata) {
        requests.push({
            createDeveloperMetadata: {
                developerMetadata: {
                    metadataKey: SHEET_METADATA_KEYS.DIRECTORY_TAB,
                    metadataValue: "true",
                    location: { sheetId },
                    visibility: "DOCUMENT",
                },
            },
        });
    }

    requests.push({
        updateSheetProperties: {
            properties: {
                sheetId,
                gridProperties: {
                    frozenRowCount: 2,
                    frozenColumnCount: 1,
                    columnCount: Math.max(tab.properties.gridProperties?.columnCount ?? 8, 8),
                    rowCount: Math.max(tab.properties.gridProperties?.rowCount ?? 200, listings.length + 25),
                },
            },
            fields: "gridProperties(frozenRowCount,frozenColumnCount,columnCount,rowCount)",
        },
    });

    const activeListings = listings.filter((item) => !item.deletedAt);
    const archivedListings = listings.filter((item) => Boolean(item.deletedAt));

    const rows: Array<{ values: RawSheetCell[] }> = [
        {
            values: [
                makeStyledHeaderCell("Mã căn", SHEET_COLORS.HEADER_BG),
                makeStyledHeaderCell("DANH MỤC CĂN ĐANG QUẢN LÝ (Tự động đồng bộ từ App)", SHEET_COLORS.HEADER_BG, {
                    align: "LEFT",
                }),
                makeStyledHeaderCell("Khu vực", SHEET_COLORS.HEADER_BG),
                makeStyledHeaderCell("Giá cơ bản (VNĐ)", SHEET_COLORS.HEADER_BG),
                makeStyledHeaderCell("Trạng thái App", SHEET_COLORS.HEADER_BG),
                makeStyledHeaderCell("Quy tắc lịch", SHEET_COLORS.HEADER_BG, { align: "LEFT" }),
            ],
        },
        {
            values: [
                makeStyledHeaderCell("ID bất biến", SHEET_COLORS.SUBHEADER_BG),
                makeStyledHeaderCell("Tên hiển thị", SHEET_COLORS.SUBHEADER_BG, { align: "LEFT" }),
                makeStyledHeaderCell("Quận/Thành phố", SHEET_COLORS.SUBHEADER_BG),
                makeStyledHeaderCell("Chỉ đọc từ App", SHEET_COLORS.SUBHEADER_BG),
                makeStyledHeaderCell("Trạng thái", SHEET_COLORS.SUBHEADER_BG),
                makeStyledHeaderCell("Ghi chú", SHEET_COLORS.SUBHEADER_BG, { align: "LEFT" }),
            ],
        },
    ];

    const statusLabel = (status: string, deletedAt: Date | null): string => {
        if (deletedAt) return "Đã ngừng (Lưu trữ)";
        switch (status) {
            case "active":
            case "approved":
            case "published":
                return "Đang mở đặt";
            case "inactive":
                return "Đang tạm ẩn";
            case "pending_approval":
                return "Chờ duyệt";
            case "draft":
                return "Bản nháp";
            case "rejected":
                return "Từ chối duyệt";
            case "suspended":
                return "Tạm khóa Admin";
            default:
                return status;
        }
    };

    for (const item of activeListings) {
        rows.push({
            values: [
                buildCalendarCellWriteData({
                    text: String(item.listingId),
                    bgColor: SHEET_COLORS.WHITE,
                    bold: true,
                    forcePlainText: true,
                }).cell,
                {
                    userEnteredValue: { stringValue: sanitizeSheetTextValue(item.title) },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE },
                        horizontalAlignment: "LEFT",
                    },
                },
                {
                    userEnteredValue: {
                        stringValue: sanitizeSheetTextValue(`${item.district}, ${item.city}`),
                    },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE },
                        horizontalAlignment: "LEFT",
                    },
                },
                {
                    userEnteredValue: {
                        stringValue: `${Math.round(Number(item.basePrice || 0)).toLocaleString("en-US")} đ`,
                    },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE },
                        horizontalAlignment: "CENTER",
                    },
                },
                {
                    userEnteredValue: { stringValue: statusLabel(item.status, item.deletedAt) },
                    userEnteredFormat: {
                        backgroundColorStyle: {
                            rgbColor:
                                item.status === "active" || item.status === "published" || item.status === "approved"
                                    ? SHEET_COLORS.BOOKED_GREEN
                                    : SHEET_COLORS.SUBHEADER_BG,
                        },
                        horizontalAlignment: "CENTER",
                    },
                },
                {
                    userEnteredValue: {
                        stringValue:
                            item.status === "inactive"
                                ? "Căn đang tạm ẩn trên App — khách không thể đặt mới"
                                : "Đồng bộ 2 chiều tự động",
                    },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE },
                        horizontalAlignment: "LEFT",
                    },
                },
            ],
        });
    }

    // Blank separator + Archived section ("CĂN ĐÃ NGỪNG")
    rows.push({
        values: Array.from({ length: 6 }, () => ({
            userEnteredValue: { stringValue: "" },
            userEnteredFormat: { backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE } },
        })),
    });
    rows.push({
        values: [
            makeStyledHeaderCell("Mã căn", SHEET_COLORS.ARCHIVED_BG),
            makeStyledHeaderCell("CĂN ĐÃ NGỪNG (LƯU TRỮ LỊCH SỬ — KHÔNG TÁI SỬ DỤNG ID CHO CĂN KHÁC)", SHEET_COLORS.ARCHIVED_BG, {
                align: "LEFT",
            }),
            makeStyledHeaderCell("Khu vực", SHEET_COLORS.ARCHIVED_BG),
            makeStyledHeaderCell("Giá cũ", SHEET_COLORS.ARCHIVED_BG),
            makeStyledHeaderCell("Trạng thái", SHEET_COLORS.ARCHIVED_BG),
            makeStyledHeaderCell("Ghi chú", SHEET_COLORS.ARCHIVED_BG, { align: "LEFT" }),
        ],
    });

    for (const item of archivedListings) {
        rows.push({
            values: [
                buildCalendarCellWriteData({
                    text: String(item.listingId),
                    bgColor: SHEET_COLORS.ARCHIVED_BG,
                    bold: false,
                    forcePlainText: true,
                }).cell,
                {
                    userEnteredValue: { stringValue: sanitizeSheetTextValue(item.title) },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.ARCHIVED_BG },
                        horizontalAlignment: "LEFT",
                    },
                },
                {
                    userEnteredValue: {
                        stringValue: sanitizeSheetTextValue(`${item.district}, ${item.city}`),
                    },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.ARCHIVED_BG },
                        horizontalAlignment: "LEFT",
                    },
                },
                {
                    userEnteredValue: {
                        stringValue: `${Math.round(Number(item.basePrice || 0)).toLocaleString("en-US")} đ`,
                    },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.ARCHIVED_BG },
                        horizontalAlignment: "CENTER",
                    },
                },
                {
                    userEnteredValue: { stringValue: "Đã ngừng (Lưu trữ)" },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.ARCHIVED_BG },
                        horizontalAlignment: "CENTER",
                    },
                },
                {
                    userEnteredValue: {
                        stringValue: "Có thể khôi phục lại trên App với nguyên mã căn cũ",
                    },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.ARCHIVED_BG },
                        horizontalAlignment: "LEFT",
                    },
                },
            ],
        });
    }

    // Pad 5 blank rows below to clean up any previously archived/removed trailing rows
    for (let pad = 0; pad < 5; pad += 1) {
        rows.push({
            values: Array.from({ length: 6 }, () => ({
                userEnteredValue: { stringValue: "" },
                userEnteredFormat: { backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE } },
            })),
        });
    }

    requests.push({
        updateCells: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: rows.length,
                startColumnIndex: 0,
                endColumnIndex: 6,
            },
            rows,
            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold,numberFormat)",
        },
    });

    return requests;
};

