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

// Guide rows: 0..7 (Row 0 header, Rows 1, 3, 5, 7 examples, Rows 2, 4, 6 blank spacing rows)
export const SHEET_GUIDE_ROW_COUNT = 8;
// Calendar table headers: Row 8 (Mã căn), Row 9 (Tên căn & Ngày/Tháng/Năm)
export const SHEET_CALENDAR_HEADER_ROW_COUNT = 2;
export const SHEET_HEADER_ROW_COUNT = SHEET_GUIDE_ROW_COUNT + SHEET_CALENDAR_HEADER_ROW_COUNT; // 10
export const SHEET_CALENDAR_START_ROW_INDEX = 10; // Day 1 starts at Row 10 (0-indexed)
export const SHEET_DAY_ROW_OFFSET = 10;
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
    columnsByListingId: Map<number, ExtractedSheetListingRow[]>;
    rowsByListingId: Map<number, ExtractedSheetListingRow[]>;
    duplicateListingIds: Set<number>;
    tamperedColumnIndices: Array<{ colIndex: number; headerIdText: string; metadataListingId: number | null }>;
    tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }>;
    nextAppendColIndex: number;
    nextAppendRowIndex: number;
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

const findColumnDeveloperMetadataListingId = (
    tab: RawSheetTab,
    colIndex: number,
): number | null => {
    for (const meta of tab.developerMetadata ?? []) {
        if (meta.metadataKey !== SHEET_METADATA_KEYS.LISTING_ROW) {
            continue;
        }
        const range = meta.location?.dimensionRange;
        if (
            range &&
            range.dimension === "COLUMNS" &&
            range.startIndex === colIndex &&
            range.endIndex === colIndex + 1
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
    const rowData = grid?.rowData ?? [];

    const rowsByListingId = new Map<number, ExtractedSheetListingRow[]>();
    const duplicateListingIds = new Set<number>();
    const tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }> = [];

    // Header row 9 has listing ID, Header row 10 has listing Title
    const idRowValues = rowData[SHEET_GUIDE_ROW_COUNT]?.values ?? [];
    const titleRowValues = rowData[SHEET_GUIDE_ROW_COUNT + 1]?.values ?? [];
    const isVerticalLayout =
        idRowValues.length > 0 ||
        rowData[0]?.values?.[0]?.userEnteredValue?.stringValue === "HƯỚNG DẪN" ||
        rowData[SHEET_CALENDAR_START_ROW_INDEX]?.values?.[0]?.userEnteredValue?.stringValue?.includes("/");

    if (isVerticalLayout) {
        let maxUsedColIndex = 0;
        const maxCols = Math.max(idRowValues.length, titleRowValues.length);

        for (let colIndex = SHEET_DAY_COLUMN_OFFSET; colIndex < maxCols; colIndex += 1) {
            const headerIdText = extractCellRawText(idRowValues[colIndex]);
            const headerTitleText = extractCellRawText(titleRowValues[colIndex]);
            const headerListingId = parsePositiveListingId(headerIdText);
            const metadataListingId = findColumnDeveloperMetadataListingId(tab, colIndex);

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
                const rowIdx = SHEET_CALENDAR_START_ROW_INDEX + (day - 1);
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
            columnsByListingId: rowsByListingId,
            rowsByListingId,
            duplicateListingIds,
            tamperedColumnIndices: tamperedRowIndices.map((t) => ({
                colIndex: t.rowIndex,
                headerIdText: t.colAText,
                metadataListingId: t.metadataListingId,
            })),
            tamperedRowIndices,
            nextAppendColIndex: maxUsedColIndex === 0 ? SHEET_DAY_COLUMN_OFFSET : maxUsedColIndex + 1,
            nextAppendRowIndex: maxUsedColIndex === 0 ? SHEET_DAY_COLUMN_OFFSET : maxUsedColIndex + 1,
        };
    }

    // Fallback: horizontal layout (Row = Listing, Col = Day)
    const rowMetadata = grid?.rowMetadata ?? [];
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
        columnsByListingId: rowsByListingId,
        rowsByListingId,
        duplicateListingIds,
        tamperedColumnIndices: tamperedRowIndices.map((t) => ({
            colIndex: t.rowIndex,
            headerIdText: t.colAText,
            metadataListingId: t.metadataListingId,
        })),
        tamperedRowIndices,
        nextAppendColIndex: Math.max(SHEET_DAY_COLUMN_OFFSET, maxUsedRowIndex + 1),
        nextAppendRowIndex: Math.max(SHEET_DAY_COLUMN_OFFSET, maxUsedRowIndex + 1),
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

    // Build Rows 0 to 8: HƯỚNG DẪN & NOTE GHI CHÚ MÀU SẮC
    // Mỗi ví dụ màu là 1 hàng, cách nhau 1 hàng trống
    const rows: Array<{ values: RawSheetCell[] }> = [
        // Row 0: Header Hướng dẫn
        {
            values: [
                makeStyledHeaderCell("HƯỚNG DẪN", SHEET_COLORS.HEADER_BG, { bold: true, align: "CENTER" }),
                makeStyledHeaderCell(
                    `QUY TẮC MÀU SẮC & ĐỒNG BỘ LỊCH TỰ ĐỘNG (THÁNG ${monthSpec.tabKey})`,
                    SHEET_COLORS.HEADER_BG,
                    { bold: true, align: "LEFT" },
                ),
            ],
        },
        // Row 1: Ví dụ 1 - TRẮNG: Trống
        {
            values: [
                makeStyledHeaderCell("Trống", SHEET_COLORS.WHITE, { bold: false, align: "CENTER" }),
                makeStyledHeaderCell(
                    "Trắng: Phòng trống — Khách có thể xem và đặt phòng trên App (Điền 'K' hoặc đổi màu đỏ để đóng lịch)",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT" },
                ),
            ],
        },
        // Row 2: (Hàng trống cách nhau)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.WHITE),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE),
            ],
        },
        // Row 3: Ví dụ 2 - CAM (G): Giữ chỗ
        {
            values: [
                makeStyledHeaderCell("G", SHEET_COLORS.PENDING_HOLD_ORANGE, { bold: true, align: "CENTER" }),
                makeStyledHeaderCell(
                    "Cam (G): Đang giữ chỗ — Đơn đang chờ khách thanh toán (Tạm giữ 10 phút, hệ thống tự xử lý)",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT" },
                ),
            ],
        },
        // Row 4: (Hàng trống cách nhau)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.WHITE),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE),
            ],
        },
        // Row 5: Ví dụ 3 - XANH LÁ (Đ): Đã đặt
        {
            values: [
                makeStyledHeaderCell("Đ", SHEET_COLORS.BOOKED_GREEN, { bold: true, align: "CENTER" }),
                makeStyledHeaderCell(
                    "Xanh lá (Đ): Đã đặt phòng — Đơn đặt phòng thành công trên hệ thống (Không tự ý mở trống)",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT" },
                ),
            ],
        },
        // Row 6: (Hàng trống cách nhau)
        {
            values: [
                makeStyledHeaderCell("", SHEET_COLORS.WHITE),
                makeStyledHeaderCell("", SHEET_COLORS.WHITE),
            ],
        },
        // Row 7: Ví dụ 4 - ĐỎ (K): Host khóa
        {
            values: [
                makeStyledHeaderCell("K", SHEET_COLORS.HOST_BLOCKED_RED, { bold: true, align: "CENTER" }),
                makeStyledHeaderCell(
                    "Đỏ (K): Host khóa phòng — Chủ nhà đóng lịch (Điền chữ K hoặc tô màu đỏ tại ô ngày tương ứng)",
                    SHEET_COLORS.WHITE,
                    { bold: false, align: "LEFT" },
                ),
            ],
        },
        // Row 8: Table Header 1 - Mã căn
        {
            values: [
                makeStyledHeaderCell("Mã căn (ID)", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "CENTER" }),
            ],
        },
        // Row 9: Table Header 2 - Ngày/Tháng/Năm
        {
            values: [
                makeStyledHeaderCell("Ngày / Tháng / Năm", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "CENTER" }),
            ],
        },
    ];

    // Rows 11 to 10 + daysInMonth: Ngày tháng năm ở Cột A
    for (let day = 1; day <= monthSpec.daysInMonth; day += 1) {
        rows.push({
            values: [
                makeStyledHeaderCell(
                    formatDisplayDate(monthSpec.year, monthSpec.month, day),
                    SHEET_COLORS.SUBHEADER_BG,
                    { bold: true, align: "CENTER" },
                ),
            ],
        });
    }

    requests.push({
        updateCells: {
            range: {
                sheetId,
                startRowIndex: 0,
                endRowIndex: rows.length,
                startColumnIndex: 0,
                endColumnIndex: 2,
            },
            rows,
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

