import {
    buildCalendarCellWriteData,
    extractCellRawText,
    RawDeveloperMetadata,
    RawSheetCell,
    RawSheetTab,
    sanitizeSheetTextValue,
    SHEET_COLORS,
    SheetRgbColor,
} from "./google-sheets.client";

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

/**
 * Giải thuật tính số ngày thực tế (`28..31`, tự động xử lý năm nhuận) của tháng dương lịch `(year, month)`
 * bằng cách lấy ngày UTC thứ `0` của tháng kế tiếp (`Date.UTC(year, month, 0)`), tương ứng ngày cuối cùng của tháng `month`.
 */
export const getDaysInCalendarMonth = (year: number, month: number): number => {
    return new Date(Date.UTC(year, month, 0)).getUTCDate();
};

/**
 * Định dạng bộ ba `(year, month, day)` thành chuỗi ngày chuẩn ISO-8601 `YYYY-MM-DD` có đệm chữ số `0`.
 */
export const formatIsoDate = (year: number, month: number, day: number): string => {
    return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
};

/**
 * Định dạng bộ ba `(year, month, day)` thành chuỗi ngày hiển thị `DD/MM/YYYY` cho cột tiêu đề ngày trên trang tính.
 */
export const formatDisplayDate = (year: number, month: number, day: number): string => {
    return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${String(year).padStart(4, "0")}`;
};

/**
 * Định dạng năm và tháng thành khóa định danh tab lịch tháng chuẩn `MM-YYYY` (ví dụ `"10-2026"`).
 */
export const formatMonthTabKey = (year: number, month: number): string => {
    return `${String(month).padStart(2, "0")}-${String(year).padStart(4, "0")}`;
};

/**
 * Giải thuật phân tích và xác thực khóa tên tab `MM-YYYY` sang cấu trúc đặc tả tháng `RollingMonthSpec`
 * gồm tổng số ngày trong tháng cùng ngày đầu/cuối tháng chuẩn ISO; trả về `null` nếu sai định dạng.
 */
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

/**
 * Giải thuật kiểm chứng ngày dương lịch hợp lệ (`1 <= day <= maxDay`) từ chuỗi `YYYY-MM-DD`
 * và trích xuất khóa tab tháng `MM-YYYY` tương ứng.
 */
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

/**
 * Giải thuật sinh danh sách đặc tả cửa sổ cuốn chiếu `monthCount` tháng liên tiếp kể từ tháng của `baseIsoDate`:
 * - Ánh xạ `(baseYear, baseMonth)` sang trục số nguyên tháng tuyến tính `totalMonths = baseYear * 12 + (baseMonth - 1) + offset`,
 *   sau đó giải ngược `year = floor(totalMonths / 12)` và `month = (totalMonths mod 12) + 1` để cộng tháng qua ranh giới năm
 *   chính xác tuyệt đối mà không phụ thuộc múi giờ máy chủ.
 */
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

/**
 * Thoát ký tự đặc biệt cho tiêu đề tab khi ghép biểu thức vùng A1 bằng cách nhân đôi dấu nháy đơn (`'` -> `''`)
 * và bao đóng toàn bộ tên tab trong cặp dấu nháy đơn.
 */
export const escapeSheetTitleForA1 = (title: string): string => {
    return `'${title.replace(/'/g, "''")}'`;
};

/**
 * Giải thuật chuyển đổi chỉ số cột 0-based (`0, 1, ..., 25, 26, ...`) sang ký hiệu cột chữ cái A1 (`A..Z, AA..ZZ, ...`)
 * theo hệ đếm song ánh cơ số 26 không có chữ số 0 (Bijective Base-26 Numeration):
 * 1. Dịch chỉ số 0-based sang số thứ tự cột nguyên dương 1-based: `n = max(0, floor(colIndex)) + 1`.
 * 2. Lặp khi `n > 0`:
 *    - Lấy phần dư dịch chuẩn `rem = (n - 1) mod 26` thuộc `{0..25}` và ánh xạ sang chữ cái mã ASCII `65 + rem` (`A..Z`).
 *    - Ghép chữ cái vào đầu chuỗi kết quả và giảm bậc thương số `n = floor((n - 1) / 26)`.
 *    Phép trừ `1` trước mỗi bước chia loại bỏ hoàn toàn sự thiếu vắng chữ số `0`, đảm bảo song ánh chuẩn (`25 -> Z`, `26 -> AA`).
 */
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

/**
 * Giải thuật tính biểu thức vùng địa chỉ A1 tối ưu cần tải cho một tab lịch tháng dựa trên kích thước lưới thực tế
 * và số lượng căn gợi ý (`listingCountHint`), bao phủ trọn vẹn vùng hướng dẫn, tiêu đề cột và tối đa 31 ngày.
 */
export const buildMonthTabA1Range = (tab: RawSheetTab, listingCountHint = 0): string => {
    const gridCols = tab.properties.gridProperties?.columnCount ?? SHEET_TOTAL_COLUMNS;
    const totalCols = Math.max(SHEET_TOTAL_COLUMNS, gridCols, listingCountHint + 10);
    const endColLetter = columnIndexToA1Letter(totalCols - 1);
    const maxRows = Math.max(60, SHEET_CALENDAR_START_ROW_INDEX + 35, listingCountHint + 20);
    return `${escapeSheetTitleForA1(tab.properties.title)}!A1:${endColLetter}${maxRows}`;
};

/**
 * Giải thuật định vị tab `DANH MỤC CĂN` trong bảng tính: ưu tiên đối sánh thẻ `DeveloperMetadata` bất biến
 * (`agy_directory_tab === "true"`) để chịu lỗi khi chủ nhà đổi tên hiển thị, sau đó dự phòng khớp tên tiêu đề.
 */
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

/**
 * Giải thuật định vị tab lịch tháng theo khóa `MM-YYYY`: ưu tiên tìm theo `DeveloperMetadata` (`agy_month_tab`)
 * trước khi dự phòng đối sánh trực tiếp tiêu đề tab.
 */
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
};

/**
 * Giải thuật phân tích chuỗi văn bản ô tiêu đề (bỏ các dấu nháy đơn dẫn đầu `'+`) thành số nguyên dương
 * định danh chỗ nghỉ an toàn (`Number.isSafeInteger(num) && num > 0`); trả về `null` nếu không hợp lệ.
 */
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

/**
 * Giải thuật tìm mã `listingId` từ `DeveloperMetadata` gắn ở cấp dòng (`dimension === "ROWS"`),
 * tra cứu cả siêu dữ liệu dòng trong vùng lưới (`gridRowMeta`) lẫn danh sách siêu dữ liệu cấp tab.
 */
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

/**
 * Giải thuật thu thập và khử trùng lặp (theo `metadataId`) mọi bản ghi `DeveloperMetadata` khóa `agy_listing_id`
 * được gắn trên cột chỉ số `colIndex` (`dimension === "COLUMNS"`).
 */
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

/**
 * Trích xuất mã `listingId` nguyên dương hợp lệ đầu tiên từ tập `DeveloperMetadata` của cột `colIndex`.
 */
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

/**
 * Giải thuật tự động nhận diện hướng bố cục bảng tính lịch tháng, ánh xạ từng cột/hàng căn hộ/villa
 * theo siêu dữ liệu hoặc mã listing và trích xuất ma trận ô lịch theo ngày `1..31`:
 * 1. Nhận diện bố cục tự động (Vertical vs Horizontal Layout Detection):
 *    - Kiểm tra nhãn tiêu đề (`Mã căn`, `Ngày \ Tên căn`), định dạng ngày `DD/MM/YYYY` tại cột A dòng 11
 *      và sự tồn tại của `DeveloperMetadata` cấp cột/dòng để phân biệt bố cục dọc chuẩn (`isVerticalLayout = true`:
 *      Cột A chứa các ngày `1..31` từ chỉ số dòng `10`, các cột từ B trở đi ứng với từng căn hộ/villa có ID ở dòng `8`
 *      và tên căn ở dòng `9`) hay bố cục ngang kế thừa (`isVerticalLayout = false`: mỗi dòng từ chỉ số `2` là một căn,
 *      các cột từ C trở đi là các ngày `1..31`).
 * 2. Ánh xạ căn hộ & kiểm tra toàn vẹn cấu trúc:
 *    - Đối chiếu mã `metadataListingId` bất biến với mã văn bản hiển thị trên ô tiêu đề; ưu tiên `metadataListingId`
 *      làm khóa định danh chuẩn, đánh dấu `colMismatch` / `tamperedRowIndices` khi phát hiện sửa tay lệch mã,
 *      và đưa vào `duplicateListingIds` nếu một căn hộ bị nhân bản thành nhiều cột/hàng.
 * 3. Trích xuất ma trận ô lịch `1..31`:
 *    - Với mỗi căn hợp lệ, ánh xạ từng ngày `day` thuộc `[1, 31]` tới ô dữ liệu tương ứng lưu vào `cellsByDay`,
 *      đồng thời xác định chỉ số cột/hàng trống tiếp theo (`nextAppendColIndex` / `nextAppendRowIndex`) để chèn căn mới.
 */
export const extractMonthSheetStructure = (tab: RawSheetTab): ExtractedMonthSheetStructure => {
    const grid = tab.data?.[0];
    const rowData = grid?.rowData ?? [];
    const rowMetadata = grid?.rowMetadata ?? [];
    const columnMetadata = grid?.columnMetadata ?? [];

    const rowsByListingId = new Map<number, ExtractedSheetListingRow[]>();
    const duplicateListingIds = new Set<number>();
    const tamperedRowIndices: Array<{ rowIndex: number; colAText: string; metadataListingId: number | null }> = [];
    const columnMetadataEntriesByCol = new Map<number, RawDeveloperMetadata[]>();

    // Header row 9 (0-based 8) has listing ID, Header row 10 (0-based 9) has listing Title
    const idRowValues = rowData[SHEET_GUIDE_ROW_COUNT]?.values ?? [];
    const titleRowValues = rowData[SHEET_GUIDE_ROW_COUNT + 1]?.values ?? [];

    const row1ColAText = extractCellRawText(rowData[1]?.values?.[0]);
    const hasHorizontalHeader = row1ColAText.startsWith("Mã căn");
    const hasRowDeveloperMetadata = rowMetadata.some((rm) =>
        (rm?.developerMetadata ?? []).some((m) => m.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW),
    );
    const row8ColAText = extractCellRawText(rowData[SHEET_GUIDE_ROW_COUNT]?.values?.[0]);
    const row9ColAText = extractCellRawText(rowData[SHEET_GUIDE_ROW_COUNT + 1]?.values?.[0]);
    const row10ColAText = extractCellRawText(rowData[SHEET_CALENDAR_START_ROW_INDEX]?.values?.[0]);
    const hasColumnDeveloperMetadata =
        columnMetadata.some((cm) =>
            (cm?.developerMetadata ?? []).some((m) => m.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW),
        ) ||
        (tab.developerMetadata ?? []).some(
            (m) =>
                m.metadataKey === SHEET_METADATA_KEYS.LISTING_ROW &&
                m.location?.dimensionRange?.dimension === "COLUMNS",
        );
    const hasVerticalIdInRow8 = idRowValues
        .slice(SHEET_DAY_COLUMN_OFFSET)
        .some((cell) => parsePositiveListingId(extractCellRawText(cell)) !== null);

    const isVerticalLayout =
        !hasHorizontalHeader &&
        !hasRowDeveloperMetadata &&
        (rowData.length === 0 ||
            row8ColAText.startsWith("Mã căn") ||
            row9ColAText.startsWith("Ngày") ||
            /^\d{2}\/\d{2}\/\d{4}$/.test(row10ColAText) ||
            hasColumnDeveloperMetadata ||
            hasVerticalIdInRow8);

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

/**
 * Khởi tạo cấu trúc ô tiêu đề đã định dạng sẵn màu nền RGB, căn lề ngang và kiểu chữ in đậm.
 */
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

/**
 * Giải thuật dựng lô yêu cầu `batchUpdate` khởi tạo và chuẩn hóa mẫu bảng tính lịch tháng:
 * 1. Cấu hình vùng đóng băng (`10` dòng đầu, `1` cột ngày), mở rộng số dòng/cột lưới đủ chứa danh sách căn,
 *    gắn `DeveloperMetadata` khóa `agy_month_tab` và thiết lập độ rộng hiển thị chuẩn cho cột Ngày (`135px`) và cột Căn (`220px`).
 * 2. Dựng bảng chú giải quy tắc màu sắc trực quan ở dòng `0..7` (Trắng: trống, Cam `G`: giữ chỗ, Xanh lá `Đ`: đã đặt, Đỏ `K`: khóa).
 * 3. Ghi tiêu đề cột A (`Mã căn (ID)`, `Ngày \ Tên căn`) và danh sách nhãn ngày `DD/MM/YYYY` (`1..daysInMonth`)
 *    tách biệt hoàn toàn trong phạm vi cột A (`startColumnIndex = 0, endColumnIndex = 1`) để không xóa nhầm dữ liệu căn ở cột B.
 * 4. Thiết lập vùng bảo vệ cảnh báo (`warningOnly` Protected Range) cho cột A và 10 dòng đầu chống sửa nhầm cấu trúc.
 */
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
    ];

    const colATableRows: Array<{ values: RawSheetCell[] }> = [
        // Row 8: Table Header 1 - Mã căn
        {
            values: [
                makeStyledHeaderCell("Mã căn (ID)", SHEET_COLORS.SUBHEADER_BG, { bold: true, align: "CENTER" }),
            ],
        },
        // Row 9: Table Header 2 - Ngày \ Tên căn
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

    // Write Guide rows (Rows 0..7) across Col A..B ONLY
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
            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold)",
        },
    });

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

export type DirectoryListingEntry = {
    listingId: number;
    title: string;
    district: string;
    city: string;
    basePrice: number;
    status: string;
    deletedAt: Date | null;
};

/**
 * Giải thuật sinh lô yêu cầu `batchUpdate` dựng trang tổng hợp `DANH MỤC CĂN`:
 * 1. Đánh dấu `DeveloperMetadata` khóa `agy_directory_tab = "true"`, đóng băng 2 dòng tiêu đề và cột Mã căn.
 * 2. Tách danh sách chỗ nghỉ thành hai phân vùng: căn đang quản lý hoạt động (`!deletedAt`) và căn đã ngừng
 *    kinh doanh lưu trữ lịch sử (`deletedAt !== null`, giữ nguyên ID bất biến để không tái sử dụng nhầm).
 * 3. Đệm thêm 5 dòng trống nền trắng phía cuối bảng nhằm dọn sạch tàn dư hiển thị khi số căn giảm xuống.
 */
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

    /**
     * Ánh xạ mã trạng thái chỗ nghỉ nội bộ và cờ xóa mềm sang nhãn hiển thị tiếng Việt trên trang danh mục.
     */
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

