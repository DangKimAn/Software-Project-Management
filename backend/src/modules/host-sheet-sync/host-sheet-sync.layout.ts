import {
    buildCalendarCellWriteData,
    extractCellRawText,
    RawDeveloperMetadata,
    RawSheetCell,
    RawSheetTab,
    sanitizeSheetTextValue,
    SHEET_COLORS,
    SHEET_FONT_FAMILY,
    SheetRgbColor,
} from "../../services/google-sheets-client.service";

export const DIRECTORY_TAB_TITLE = "DANH MỤC CĂN";

export const SHEET_METADATA_KEYS = {
    DIRECTORY_TAB: "agy_directory_tab",
    MONTH_TAB: "agy_month_tab",
    LISTING_ROW: "agy_listing_id",
} as const;

// Guide rows: 0..8 (Row 0 header, Rows 1..8 examples: 4 rules x 2 rows each = 8 rows, plus Row 0 header = 9 rows)
export const SHEET_GUIDE_ROW_COUNT = 9;
// Calendar table headers: Row 9 (Mã căn), Row 10 (Tên căn & Ngày/Tháng/Năm)
export const SHEET_CALENDAR_HEADER_ROW_COUNT = 2;
export const SHEET_HEADER_ROW_COUNT = SHEET_GUIDE_ROW_COUNT + SHEET_CALENDAR_HEADER_ROW_COUNT; // 11
export const SHEET_CALENDAR_START_ROW_INDEX = 11; // Day 1 starts at Row 11 (0-indexed, Sheet Row 12)
export const SHEET_DAY_ROW_OFFSET = 11;
export const SHEET_DATE_COLUMN_INDEX = 0; // Col A = 0 (Date: DD/MM/YYYY)
export const SHEET_DAY_COLUMN_OFFSET = 1; // Col B.. = Listings (1, 2, ...)
export const SHEET_TOTAL_COLUMNS = 35;

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

export const formatDisplayDate = (year: number, month: number, day: number): string => {
    return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${String(year).padStart(4, "0")}`;
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

export const columnIndexToA1Letter = (colIndex: number): string => {
    let n = Math.max(0, Math.floor(colIndex)) + 1;
    let letters = "";
    while (n > 0) {
        const rem = (n - 1) % 26;
        letters = String.fromCharCode(65 + rem) + letters;
        n = Math.floor((n - 1) / 26);
    }
    return letters;
};

export const buildMonthTabA1Range = (tab: RawSheetTab, listingCountHint = 0): string => {
    const gridCols = tab.properties.gridProperties?.columnCount ?? SHEET_TOTAL_COLUMNS;
    const totalCols = Math.max(SHEET_TOTAL_COLUMNS, gridCols, listingCountHint + 10);
    const endColLetter = columnIndexToA1Letter(totalCols - 1);
    const maxRows = Math.max(60, SHEET_CALENDAR_START_ROW_INDEX + 35, listingCountHint + 20);
    return `${escapeSheetTitleForA1(tab.properties.title)}!A1:${endColLetter}${maxRows}`;
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
    rowIndex: number; // 0-based row/col index in sheet
    colIndex: number;
    listingId: number;
    colAText: string;
    colBTitle: string;
    metadataListingId: number | null;
    colMismatch: boolean;
    cellsByDay: Map<number, RawSheetCell | undefined>;
};

export type ExtractedMonthSheetStructure = {
    isVerticalLayout: boolean;
    columnsByListingId: Map<number, ExtractedSheetListingRow[]>;
    rowsByListingId: Map<number, ExtractedSheetListingRow[]>;
    duplicateListingIds: Set<number>;
    tamperedColumnIndices: Array<{ colIndex: number; headerIdText: string; metadataListingId: number | null }>;
    tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }>;
    columnMetadataEntriesByCol: Map<number, RawDeveloperMetadata[]>;
    nextAppendColIndex: number;
    nextAppendRowIndex: number;
    guideRowCount?: number;
};

export const parsePositiveListingId = (raw: string | undefined | null): number | null => {
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

const collectColumnListingMetadataEntries = (
    tab: RawSheetTab,
    colIndex: number,
    gridColMeta?: { developerMetadata?: RawDeveloperMetadata[] },
): RawDeveloperMetadata[] => {
    const entries: RawDeveloperMetadata[] = [];
    const seenIds = new Set<number>();

    for (const meta of gridColMeta?.developerMetadata ?? []) {
        if (meta.metadataKey !== SHEET_METADATA_KEYS.LISTING_ROW) {
            continue;
        }
        if (meta.metadataId !== undefined) {
            seenIds.add(meta.metadataId);
        }
        entries.push(meta);
    }

    for (const meta of tab.developerMetadata ?? []) {
        if (meta.metadataKey !== SHEET_METADATA_KEYS.LISTING_ROW) {
            continue;
        }
        if (meta.metadataId !== undefined && seenIds.has(meta.metadataId)) {
            continue;
        }
        const range = meta.location?.dimensionRange;
        if (
            range &&
            range.dimension === "COLUMNS" &&
            range.startIndex === colIndex &&
            range.endIndex === colIndex + 1
        ) {
            entries.push(meta);
        }
    }

    return entries;
};

const findColumnDeveloperMetadataListingId = (
    tab: RawSheetTab,
    colIndex: number,
    gridColMeta?: { developerMetadata?: RawDeveloperMetadata[] },
): number | null => {
    for (const meta of collectColumnListingMetadataEntries(tab, colIndex, gridColMeta)) {
        const parsed = parsePositiveListingId(meta.metadataValue);
        if (parsed) {
            return parsed;
        }
    }

    return null;
};

export const extractMonthSheetStructure = (tab: RawSheetTab): ExtractedMonthSheetStructure => {
    const grid = tab.data?.[0];
    const rowData = grid?.rowData ?? [];
    const rowMetadata = grid?.rowMetadata ?? [];
    const columnMetadata = grid?.columnMetadata ?? [];

    const rowsByListingId = new Map<number, ExtractedSheetListingRow[]>();
    const duplicateListingIds = new Set<number>();
    const tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }> = [];
    const columnMetadataEntriesByCol = new Map<number, RawDeveloperMetadata[]>();

    // Dynamically detect guide row offset: Look for "Mã căn" in Col A around rows 6..14
    let guideRowCount = SHEET_GUIDE_ROW_COUNT;
    for (let r = 6; r <= 14; r += 1) {
        const text = extractCellRawText(rowData[r]?.values?.[0]);
        if (text.startsWith("Mã căn")) {
            guideRowCount = r;
            break;
        }
    }
    const calendarStartRow = guideRowCount + SHEET_CALENDAR_HEADER_ROW_COUNT;

    const idRowValues = rowData[guideRowCount]?.values ?? [];
    const titleRowValues = rowData[guideRowCount + 1]?.values ?? [];

    const row1ColAText = extractCellRawText(rowData[1]?.values?.[0]);
    const hasHorizontalHeader = row1ColAText.startsWith("Mã căn");
    const hasRowDeveloperMetadata = rowMetadata.some((rm) =>
        (rm?.developerMetadata ?? []).some((m) => m.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW),
    );
    const idColAText = extractCellRawText(rowData[guideRowCount]?.values?.[0]);
    const titleColAText = extractCellRawText(rowData[guideRowCount + 1]?.values?.[0]);
    const dateColAText = extractCellRawText(rowData[calendarStartRow]?.values?.[0]);
    const hasColumnDeveloperMetadata =
        columnMetadata.some((cm) =>
            (cm?.developerMetadata ?? []).some((m) => m.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW),
        ) ||
        (tab.developerMetadata ?? []).some(
            (m) =>
                m.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW &&
                m.location?.dimensionRange?.dimension === "COLUMNS",
        );
    const hasVerticalIdInRow = idRowValues
        .slice(SHEET_DAY_COLUMN_OFFSET)
        .some((cell) => parsePositiveListingId(extractCellRawText(cell)) !== null);

    const isVerticalLayout =
        !hasHorizontalHeader &&
        !hasRowDeveloperMetadata &&
        (rowData.length === 0 ||
            idColAText.startsWith("Mã căn") ||
            titleColAText.startsWith("Ngày") ||
            /^\d{2}\/\d{2}\/\d{4}$/.test(dateColAText) ||
            hasColumnDeveloperMetadata ||
            hasVerticalIdInRow);

    if (isVerticalLayout) {
        let maxUsedColIndex = 0;
        let maxMetaColPlusOne = 0;
        for (const meta of tab.developerMetadata ?? []) {
            if (
                meta.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW &&
                meta.location?.dimensionRange?.dimension === "COLUMNS" &&
                typeof meta.location.dimensionRange.endIndex === "number"
            ) {
                maxMetaColPlusOne = Math.max(maxMetaColPlusOne, meta.location.dimensionRange.endIndex);
            }
        }
        const maxCols = Math.max(
            idRowValues.length,
            titleRowValues.length,
            columnMetadata.length,
            maxMetaColPlusOne,
        );

        for (let colIndex = SHEET_DAY_COLUMN_OFFSET; colIndex < maxCols; colIndex += 1) {
            const colMetaEntries = collectColumnListingMetadataEntries(
                tab,
                colIndex,
                columnMetadata[colIndex],
            );
            if (colMetaEntries.length > 0) {
                columnMetadataEntriesByCol.set(colIndex, colMetaEntries);
            }

            const headerIdText = extractCellRawText(idRowValues[colIndex]);
            const headerTitleText = extractCellRawText(titleRowValues[colIndex]);
            const headerListingId = parsePositiveListingId(headerIdText);
            const metadataListingId = findColumnDeveloperMetadataListingId(
                tab,
                colIndex,
                columnMetadata[colIndex],
            );

            const hasAnyContent = headerIdText !== "" || headerTitleText !== "" || metadataListingId !== null;
            if (hasAnyContent) {
                maxUsedColIndex = Math.max(maxUsedColIndex, colIndex);
            }

            if (metadataListingId === null && headerListingId === null) {
                if (headerIdText !== "") {
                    tamperedRowIndices.push({ rowIndex: colIndex, colAText: headerIdText, metadataListingId: null });
                }
                continue;
            }

            const colMismatch =
                metadataListingId !== null && headerListingId !== null && metadataListingId !== headerListingId;
            if (colMismatch) {
                tamperedRowIndices.push({ rowIndex: colIndex, colAText: headerIdText, metadataListingId });
            }

            const resolvedListingId = metadataListingId ?? headerListingId!;
            const cellsByDay = new Map<number, RawSheetCell | undefined>();
            for (let day = 1; day <= 31; day += 1) {
                const rowIdx = calendarStartRow + (day - 1);
                cellsByDay.set(day, rowData[rowIdx]?.values?.[colIndex]);
            }

            const extractedEntry: ExtractedSheetListingRow = {
                rowIndex: colIndex,
                colIndex,
                listingId: resolvedListingId,
                colAText: headerIdText,
                colBTitle: headerTitleText,
                metadataListingId,
                colMismatch,
                cellsByDay,
            };

            const existing = rowsByListingId.get(resolvedListingId) ?? [];
            existing.push(extractedEntry);
            rowsByListingId.set(resolvedListingId, existing);

            if (existing.length > 1) {
                duplicateListingIds.add(resolvedListingId);
            }
        }

        return {
            isVerticalLayout: true,
            columnsByListingId: rowsByListingId,
            rowsByListingId,
            duplicateListingIds,
            tamperedColumnIndices: tamperedRowIndices.map((t) => ({
                colIndex: t.rowIndex,
                headerIdText: t.colAText,
                metadataListingId: t.metadataListingId,
            })),
            tamperedRowIndices,
            columnMetadataEntriesByCol,
            nextAppendColIndex: maxUsedColIndex === 0 ? SHEET_DAY_COLUMN_OFFSET : maxUsedColIndex + 1,
            nextAppendRowIndex: maxUsedColIndex === 0 ? SHEET_DAY_COLUMN_OFFSET : maxUsedColIndex + 1,
            guideRowCount,
        };
    }

    // Fallback: horizontal layout (Row = Listing, Col = Day)
    let maxUsedRowIndex = 1;

    for (let offset = 0; offset < rowData.length; offset += 1) {
        const rowIndex = offset;
        if (rowIndex < 2) continue;

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

        const resolvedListingId = metadataListingId ?? colAListingId!;
        const cellsByDay = new Map<number, RawSheetCell | undefined>();
        for (let day = 1; day <= 31; day += 1) {
            cellsByDay.set(day, values[2 + (day - 1)]);
        }

        const extractedRow: ExtractedSheetListingRow = {
            rowIndex,
            colIndex: rowIndex,
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
        isVerticalLayout: false,
        columnsByListingId: rowsByListingId,
        rowsByListingId,
        duplicateListingIds,
        tamperedColumnIndices: tamperedRowIndices.map((t) => ({
            colIndex: t.rowIndex,
            headerIdText: t.colAText,
            metadataListingId: t.metadataListingId,
        })),
        tamperedRowIndices,
        columnMetadataEntriesByCol,
        nextAppendColIndex: Math.max(SHEET_DAY_COLUMN_OFFSET, maxUsedRowIndex + 1),
        nextAppendRowIndex: Math.max(SHEET_DAY_COLUMN_OFFSET, maxUsedRowIndex + 1),
    };
};

const makeStyledHeaderCell = (
    text: string,
    bgColor: SheetRgbColor,
    options: {
        bold?: boolean;
        align?: "LEFT" | "CENTER";
        valign?: "TOP" | "MIDDLE" | "BOTTOM";
        wrap?: boolean;
        fontFamily?: string;
    } = {},
): RawSheetCell => ({
    userEnteredValue: { stringValue: text },
    userEnteredFormat: {
        backgroundColorStyle: { rgbColor: bgColor },
        horizontalAlignment: options.align ?? "CENTER",
        verticalAlignment: options.valign ?? "MIDDLE",
        wrapStrategy: options.wrap ? "WRAP" : "OVERFLOW_CELL",
        textFormat: {
            bold: options.bold ?? true,
            fontFamily: options.fontFamily ?? SHEET_FONT_FAMILY,
        },
    },
});

export const buildMonthTabHeaderRequests = (
    tab: RawSheetTab,
    monthSpec: RollingMonthSpec,
    options: { listingCount?: number } = {},
): Array<Record<string, unknown>> => {
    const requests: Array<Record<string, unknown>> = [];
    const sheetId = tab.properties.sheetId;

    const currentFrozenRows = tab.properties.gridProperties?.frozenRowCount ?? 0;
    const currentFrozenCols = tab.properties.gridProperties?.frozenColumnCount ?? 0;
    const currentCols = tab.properties.gridProperties?.columnCount ?? 26;
    const currentRows = tab.properties.gridProperties?.rowCount ?? 100;

    const neededCols = Math.max(currentCols, (options.listingCount ?? 10) + 5, 20);
    const neededRows = Math.max(currentRows, SHEET_HEADER_ROW_COUNT + monthSpec.daysInMonth + 10, 60);

    if (
        currentFrozenRows !== SHEET_HEADER_ROW_COUNT ||
        currentFrozenCols !== 1 ||
        currentCols < neededCols ||
        currentRows < neededRows
    ) {
        requests.push({
            updateSheetProperties: {
                properties: {
                    sheetId,
                    gridProperties: {
                        frozenRowCount: SHEET_HEADER_ROW_COUNT,
                        frozenColumnCount: 1,
                        columnCount: neededCols,
                        rowCount: neededRows,
                    },
                },
                fields: "gridProperties(frozenRowCount,frozenColumnCount,columnCount,rowCount)",
            },
        });
    }

    // Apply Times New Roman font to the entire tab across all columns and rows
    requests.push({
        repeatCell: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: neededRows,
                startColumnIndex: 0,
                endColumnIndex: neededCols,
            },
            cell: {
                userEnteredFormat: {
                    textFormat: {
                        fontFamily: SHEET_FONT_FAMILY,
                    },
                },
            },
            fields: "userEnteredFormat.textFormat.fontFamily",
        },
    });

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

    // Set column widths: Col A (Date) = 135px, Col B.. (Listings) = 220px
    requests.push(
        {
            updateDimensionProperties: {
                range: { sheetId, dimension: "COLUMNS", startIndex: 0, endIndex: 1 },
                properties: { pixelSize: 135 },
                fields: "pixelSize",
            },
        },
        {
            updateDimensionProperties: {
                range: { sheetId, dimension: "COLUMNS", startIndex: 1, endIndex: neededCols },
                properties: { pixelSize: 220 },
                fields: "pixelSize",
            },
        },
    );

    // 1. Unmerge any existing merges across guide rows (0..7) to guarantee clean, idempotent state
    requests.push({
        unmergeCells: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: SHEET_GUIDE_ROW_COUNT,
                startColumnIndex: 0,
                endColumnIndex: neededCols,
            },
        },
    });

    // 2. Set row heights for Guide rows (0..7) to 26px for balanced breathing room
    requests.push({
        updateDimensionProperties: {
            range: { sheetId, dimension: "ROWS", startIndex: 0, endIndex: SHEET_GUIDE_ROW_COUNT },
            properties: { pixelSize: 26 },
            fields: "pixelSize",
        },
    });

    // Build Rows 0 to 8: HƯỚNG DẪN, CHECKBOX XÁC NHẬN & NOTE GHI CHÚ MÀU SẮC
    const rows: Array<{ values: RawSheetCell[] }> = [
        // Row 0: Checkbox xác nhận (Col A: [ ]) & Tiêu đề banner hướng dẫn (Col B..end)
        {
            values: [
                {
                    userEnteredValue: { boolValue: false },
                    userEnteredFormat: {
                        backgroundColorStyle: { rgbColor: SHEET_COLORS.SUBHEADER_BG },
                        horizontalAlignment: "CENTER",
                        verticalAlignment: "MIDDLE",
                        wrapStrategy: "OVERFLOW_CELL",
                        textFormat: {
                            bold: true,
                            fontFamily: SHEET_FONT_FAMILY,
                        },
                    },
                },
                makeStyledHeaderCell(
                    `👉 TÍCH VÀO Ô BÊN TRÁI ĐỂ XÁC NHẬN LƯU THAY ĐỔI VÀO APP (Đổi giá, Đóng/Mở lịch) — THÁNG ${monthSpec.tabKey} (Tự động bỏ tích khi hoàn tất)`,
                    SHEET_COLORS.HEADER_BG,
                    { bold: true, align: "LEFT", valign: "MIDDLE" },
                ),
            ],
        },
        // Row 1: Ví dụ 1 - TRẮNG: Trống / Giá phòng (Gộp dòng với Row 2)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.WHITE, { valign: "MIDDLE" }),
                makeStyledHeaderCell(
                    "Màu trắng: Phòng trống — Tự động hiển thị giá phòng theo ngày. Khách có thể xem và đặt phòng trên App.",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT", valign: "MIDDLE", wrap: true },
                ),
            ],
        },
        // Row 2: (Hàng đệm gộp dòng với Row 1)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.WHITE, { valign: "MIDDLE" }),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE, { valign: "MIDDLE" }),
            ],
        },
        // Row 3: Ví dụ 2 - CAM: Giữ chỗ (Gộp dòng với Row 4)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.PENDING_HOLD_ORANGE, { valign: "MIDDLE" }),
                makeStyledHeaderCell(
                    "Màu cam: Đang giữ chỗ (Hold) — Tự động đổi màu cam và giữ nguyên giá phòng. Đơn tạm giữ 10 phút khi khách đang thanh toán.",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT", valign: "MIDDLE", wrap: true },
                ),
            ],
        },
        // Row 4: (Hàng đệm gộp dòng với Row 3)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.PENDING_HOLD_ORANGE, { valign: "MIDDLE" }),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE, { valign: "MIDDLE" }),
            ],
        },
        // Row 5: Ví dụ 3 - XANH LÁ: Đã đặt (Gộp dòng với Row 6)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.BOOKED_GREEN, { valign: "MIDDLE" }),
                makeStyledHeaderCell(
                    "Màu xanh lá: Đã đặt phòng (Booked) — Tự động đổi màu xanh lá và giữ nguyên giá phòng. Đơn đặt thành công (vui lòng không tự ý mở trống).",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT", valign: "MIDDLE", wrap: true },
                ),
            ],
        },
        // Row 6: (Hàng đệm gộp dòng với Row 5)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.BOOKED_GREEN, { valign: "MIDDLE" }),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE, { valign: "MIDDLE" }),
            ],
        },
        // Row 7: Ví dụ 4 - ĐỎ: Host khóa (Gộp dòng với Row 8)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.HOST_BLOCKED_RED, { valign: "MIDDLE" }),
                makeStyledHeaderCell(
                    "Màu đỏ: Host khóa phòng — Chủ nhà chủ động đóng lịch (Tô màu đỏ tại ô ngày tương ứng, nội dung giá phòng vẫn được giữ nguyên).",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT", valign: "MIDDLE", wrap: true },
                ),
            ],
        },
        // Row 8: (Hàng đệm gộp dòng với Row 7)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.HOST_BLOCKED_RED, { valign: "MIDDLE" }),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE, { valign: "MIDDLE" }),
            ],
        },
    ];

    const colATableRows: Array<{ values: RawSheetCell[] }> = [
        // Row 9: Table Header 1 - Mã căn
        {
            values: [
                makeStyledHeaderCell("Mã căn (ID)", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "CENTER" }),
            ],
        },
        // Row 10: Table Header 2 - Ngày \ Tên căn
        {
            values: [
                makeStyledHeaderCell("Ngày \\ Tên căn", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "CENTER" }),
            ],
        },
    ];

    // Rows 10 to 9 + daysInMonth (0-indexed): Ngày tháng năm ở Cột A
    for (let day = 1; day <= monthSpec.daysInMonth; day += 1) {
        colATableRows.push({
            values: [
                makeStyledHeaderCell(
                    formatDisplayDate(monthSpec.year, monthSpec.month, day),
                    SHEET_COLORS.SUBHEADER_BG,
                    { bold: true, align: "CENTER" },
                ),
            ],
        });
    }

    // Write Guide rows (Rows 0..7) across Col A..B
    requests.push({
        updateCells: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: SHEET_GUIDE_ROW_COUNT,
                startColumnIndex: 0,
                endColumnIndex: 2,
            },
            rows,
            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,verticalAlignment,wrapStrategy,textFormat.bold,textFormat.fontFamily)",
        },
    });

    // 3. Gộp dòng & Gộp cột chuyên nghiệp cho phần Hướng dẫn
    requests.push(
        // Header banner: Gộp cột B..end across row 0
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 0,
                    endRowIndex: 1,
                    startColumnIndex: 1,
                    endColumnIndex: neededCols,
                },
                mergeType: "MERGE_ALL",
            },
        },
        // Quy tắc 1 (Trống): Gộp dòng Cột A (A2:A3) & Gộp dòng + gộp cột Cột B..end (B2:end3)
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 1,
                    endRowIndex: 3,
                    startColumnIndex: 0,
                    endColumnIndex: 1,
                },
                mergeType: "MERGE_ALL",
            },
        },
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 1,
                    endRowIndex: 3,
                    startColumnIndex: 1,
                    endColumnIndex: neededCols,
                },
                mergeType: "MERGE_ALL",
            },
        },
        // Quy tắc 2 (Giữ chỗ): Gộp dòng Cột A (A4:A5) & Gộp dòng + gộp cột Cột B..end (B4:end5)
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 3,
                    endRowIndex: 5,
                    startColumnIndex: 0,
                    endColumnIndex: 1,
                },
                mergeType: "MERGE_ALL",
            },
        },
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 3,
                    endRowIndex: 5,
                    startColumnIndex: 1,
                    endColumnIndex: neededCols,
                },
                mergeType: "MERGE_ALL",
            },
        },
        // Quy tắc 3 (Đã đặt): Gộp dòng Cột A (A6:A7) & Gộp dòng + gộp cột Cột B..end (B6:end7)
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 5,
                    endRowIndex: 7,
                    startColumnIndex: 0,
                    endColumnIndex: 1,
                },
                mergeType: "MERGE_ALL",
            },
        },
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 5,
                    endRowIndex: 7,
                    startColumnIndex: 1,
                    endColumnIndex: neededCols,
                },
                mergeType: "MERGE_ALL",
            },
        },
        // Quy tắc 4 (Host khóa): Gộp dòng Cột A (A8:A9) & Gộp dòng + gộp cột Cột B..end (B8:end9)
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 7,
                    endRowIndex: 9,
                    startColumnIndex: 0,
                    endColumnIndex: 1,
                },
                mergeType: "MERGE_ALL",
            },
        },
        {
            mergeCells: {
                range: {
                    sheetId,
                    startRowIndex: 7,
                    endRowIndex: 9,
                    startColumnIndex: 1,
                    endColumnIndex: neededCols,
                },
                mergeType: "MERGE_ALL",
            },
        },
        // Borders viền chuyên nghiệp, sắc nét cho toàn bộ bảng Hướng dẫn (Rows 0..7)
        {
            updateBorders: {
                range: {
                    sheetId,
                    startRowIndex: 0,
                    endRowIndex: SHEET_GUIDE_ROW_COUNT,
                    startColumnIndex: 0,
                    endColumnIndex: neededCols,
                },
                top: { style: "SOLID", width: 1, colorStyle: { rgbColor: { red: 0.8, green: 0.83, blue: 0.86 } } },
                bottom: { style: "SOLID", width: 1, colorStyle: { rgbColor: { red: 0.8, green: 0.83, blue: 0.86 } } },
                left: { style: "SOLID", width: 1, colorStyle: { rgbColor: { red: 0.8, green: 0.83, blue: 0.86 } } },
                right: { style: "SOLID", width: 1, colorStyle: { rgbColor: { red: 0.8, green: 0.83, blue: 0.86 } } },
                innerHorizontal: { style: "SOLID", width: 1, colorStyle: { rgbColor: { red: 0.88, green: 0.9, blue: 0.92 } } },
                innerVertical: { style: "SOLID", width: 1, colorStyle: { rgbColor: { red: 0.88, green: 0.9, blue: 0.92 } } },
            },
        },
    );

    // Write Table Headers & Date labels (Rows 8..10+daysInMonth) strictly in Col A ONLY
    // so Listing #1 in Col B (B9:B41) is NEVER wiped out by UpdateCellsRequest range clearing!
    requests.push({
        updateCells: {
            range: {
                sheetId,
                startRowIndex: SHEET_GUIDE_ROW_COUNT,
                endRowIndex: SHEET_GUIDE_ROW_COUNT + colATableRows.length,
                startColumnIndex: 0,
                endColumnIndex: 1,
            },
            rows: colATableRows,
            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold,textFormat.fontFamily)",
        },
    });

    // Native Checkbox validation for Cell A1 (Xác nhận lưu thay đổi vào App)
    requests.push({
        setDataValidation: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: 1,
                startColumnIndex: 0,
                endColumnIndex: 1,
            },
            rule: {
                condition: {
                    type: "BOOLEAN",
                },
                showCustomUi: true,
                strict: true,
            },
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

    const hasHeaderProtection = (tab.protectedRanges ?? []).some(
        (range) => range.description === `agy_protect_header_rows_${monthSpec.tabKey}`,
    );
    if (!hasHeaderProtection) {
        requests.push({
            addProtectedRange: {
                protectedRange: {
                    range: {
                        sheetId,
                        startRowIndex: 0,
                        endRowIndex: SHEET_HEADER_ROW_COUNT,
                    },
                    description: `agy_protect_header_rows_${monthSpec.tabKey}`,
                    warningOnly: true,
                },
            },
        });
    }

    return requests;
};

export const isMonthTabCheckboxConfirmed = (tab: RawSheetTab): boolean => {
    const row0 = tab.data?.[0]?.rowData?.[0];
    const cellA1 = row0?.values?.[0];
    if (!cellA1) {
        return false;
    }
    if (cellA1.userEnteredValue?.boolValue !== undefined) {
        return cellA1.userEnteredValue.boolValue === true;
    }
    const raw = String(cellA1.userEnteredValue?.stringValue ?? "").trim().toUpperCase();
    return raw === "TRUE" || raw === "1";
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

    const currentCols = Math.max(tab.properties.gridProperties?.columnCount ?? 8, 8);
    const currentRows = Math.max(tab.properties.gridProperties?.rowCount ?? 200, listings.length + 25);

    requests.push({
        updateSheetProperties: {
            properties: {
                sheetId,
                gridProperties: {
                    frozenRowCount: 2,
                    frozenColumnCount: 1,
                    columnCount: currentCols,
                    rowCount: currentRows,
                },
            },
            fields: "gridProperties(frozenRowCount,frozenColumnCount,columnCount,rowCount)",
        },
    });

    // Apply Times New Roman font to the entire directory tab across all cells
    requests.push({
        repeatCell: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: currentRows,
                startColumnIndex: 0,
                endColumnIndex: currentCols,
            },
            cell: {
                userEnteredFormat: {
                    textFormat: {
                        fontFamily: SHEET_FONT_FAMILY,
                    },
                },
            },
            fields: "userEnteredFormat.textFormat.fontFamily",
        },
    });

    const makeDirectoryDataCell = (
        text: string,
        bgColor: SheetRgbColor,
        options: {
            bold?: boolean;
            align?: "LEFT" | "CENTER";
            fontFamily?: string;
        } = {},
    ): RawSheetCell => ({
        userEnteredValue: { stringValue: text },
        userEnteredFormat: {
            backgroundColorStyle: { rgbColor: bgColor },
            horizontalAlignment: options.align ?? "LEFT",
            textFormat: {
                bold: options.bold ?? false,
                fontFamily: options.fontFamily ?? SHEET_FONT_FAMILY,
            },
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
                    fontFamily: SHEET_FONT_FAMILY,
                }).cell,
                makeDirectoryDataCell(sanitizeSheetTextValue(item.title), SHEET_COLORS.WHITE, { align: "LEFT" }),
                makeDirectoryDataCell(
                    sanitizeSheetTextValue(`${item.district}, ${item.city}`),
                    SHEET_COLORS.WHITE,
                    { align: "LEFT" },
                ),
                makeDirectoryDataCell(
                    `${Math.round(Number(item.basePrice || 0)).toLocaleString("en-US")} đ`,
                    SHEET_COLORS.WHITE,
                    { align: "CENTER" },
                ),
                makeDirectoryDataCell(
                    statusLabel(item.status, item.deletedAt),
                    item.status === "active" || item.status === "published" || item.status === "approved"
                        ? SHEET_COLORS.BOOKED_GREEN
                        : SHEET_COLORS.SUBHEADER_BG,
                    { align: "CENTER" },
                ),
                makeDirectoryDataCell(
                    item.status === "inactive"
                        ? "Căn đang tạm ẩn trên App — khách không thể đặt mới"
                        : "Đồng bộ 2 chiều tự động",
                    SHEET_COLORS.WHITE,
                    { align: "LEFT" },
                ),
            ],
        });
    }

    // Blank separator + Archived section ("CĂN ĐÃ NGỪNG")
    rows.push({
        values: Array.from({ length: 6 }, () =>
            makeDirectoryDataCell("", SHEET_COLORS.WHITE),
        ),
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
                    fontFamily: SHEET_FONT_FAMILY,
                }).cell,
                makeDirectoryDataCell(sanitizeSheetTextValue(item.title), SHEET_COLORS.ARCHIVED_BG, { align: "LEFT" }),
                makeDirectoryDataCell(
                    sanitizeSheetTextValue(`${item.district}, ${item.city}`),
                    SHEET_COLORS.ARCHIVED_BG,
                    { align: "LEFT" },
                ),
                makeDirectoryDataCell(
                    `${Math.round(Number(item.basePrice || 0)).toLocaleString("en-US")} đ`,
                    SHEET_COLORS.ARCHIVED_BG,
                    { align: "CENTER" },
                ),
                makeDirectoryDataCell("Đã ngừng (Lưu trữ)", SHEET_COLORS.ARCHIVED_BG, { align: "CENTER" }),
                makeDirectoryDataCell(
                    "Có thể khôi phục lại trên App với nguyên mã căn cũ",
                    SHEET_COLORS.ARCHIVED_BG,
                    { align: "LEFT" },
                ),
            ],
        });
    }

    // Pad 5 blank rows below to clean up any previously archived/removed trailing rows
    for (let pad = 0; pad < 5; pad += 1) {
        rows.push({
            values: Array.from({ length: 6 }, () =>
                makeDirectoryDataCell("", SHEET_COLORS.WHITE),
            ),
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
            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold,textFormat.fontFamily,numberFormat)",
        },
    });

    return requests;
};

