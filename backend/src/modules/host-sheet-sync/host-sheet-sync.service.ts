import crypto from "node:crypto";
import { Op } from "sequelize";

import { ApiError } from "../../common/api-error";
import { buildActiveBookingStatusWhere } from "../../common/booking-availability";
import { getTodayInVietnamDateString } from "../../common/date-time";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import AvailabilityCalendar from "../../models/availability-calendar";
import Booking, { BookingDocument } from "../../models/booking";
import HostSheetCellSnapshot, { HostSheetLockSource } from "../../models/host-sheet-cell-snapshot";
import HostSheetChangeLog from "../../models/host-sheet-change-log";
import HostSheetIntegration, {
    HostSheetIntegrationDocument,
    HostSheetIntegrationStatus,
} from "../../models/host-sheet-integration";
import HostSheetSyncConflict, {
    HostSheetConflictSeverity,
    HostSheetConflictType,
} from "../../models/host-sheet-sync-conflict";
import HostSheetSyncJob, { HostSheetSyncJobType } from "../../models/host-sheet-sync-job";
import Listing, { ListingDocument } from "../../models/listing";
import { writeAuditLog } from "../../services/audit-log-service";
import { buildReservedDates } from "../../services/booking-date-lock.service";
import {
    buildCalendarCellWriteData,
    classifySheetCalendarCell,
    extractCellRawText,
    getConfiguredServiceAccountEmail,
    getGoogleSheetsTransport,
    GoogleSheetsClientError,
    parseAndValidateSpreadsheetInput,
    RawSheetCell,
    RawSheetTab,
    rgbToHex,
    sanitizeSheetTextValue,
    SHEET_COLORS,
    SheetRgbColor,
    verifySpreadsheetEditorAccess,
} from "../../services/google-sheets-client.service";
import {
    buildDirectoryTabRequests,
    buildMonthTabHeaderRequests,
    buildRollingMonthSpecs,
    DIRECTORY_TAB_TITLE,
    escapeSheetTitleForA1,
    extractMonthSheetStructure,
    formatIsoDate,
    monthTabKeyFromIsoDate,
    resolveDirectorySheetTab,
    resolveMonthSheetTab,
    RollingMonthSpec,
    SHEET_DAY_COLUMN_OFFSET,
    SHEET_METADATA_KEYS,
    SHEET_TOTAL_COLUMNS,
} from "./host-sheet-sync.layout";

const LEASE_DURATION_MS = 90_000;

export const isHostSheetSyncRuntimeActive = (): boolean => {
    if (process.env.NODE_ENV === "test") {
        return process.env.HOST_SHEET_SYNC_TEST_ENABLED === "true";
    }
    const rawFlag = process.env.GOOGLE_SHEETS_SYNC_ENABLED ?? process.env.HOST_SHEET_SYNC_ENABLED ?? "true";
    return rawFlag.trim().toLowerCase() !== "false";
};

export type ConnectHostSheetInput = {
    spreadsheetUrlOrId: string;
    hostEditorEmail?: string | null;
    autoSyncEnabled?: boolean;
    strictBookingPrecheck?: boolean;
    initializeImmediately?: boolean;
};

export type UpdateHostSheetSettingsInput = {
    hostEditorEmail?: string | null;
    autoSyncEnabled?: boolean;
    strictBookingPrecheck?: boolean;
};

export type ResolveConflictAction =
    | "keep_locked"
    | "unlock_if_safe"
    | "undo_bulk_change"
    | "repair_structure";

const getDefaultPriorityForJobType = (jobType: HostSheetSyncJobType): number => {
    switch (jobType) {
        case "init_standard_calendar":
        case "manual_sync":
        case "booking_changed":
            return 10;
        case "listing_created":
        case "listing_archived":
        case "listing_restored":
        case "listing_transferred":
        case "structure_repair":
            return 25;
        case "listing_updated":
        case "app_calendar_updated":
            return 35;
        case "periodic_poll":
        default:
            return 80;
    }
};

export const enqueueHostSheetSyncJob = async (params: {
    hostUserId: number;
    jobType: HostSheetSyncJobType;
    listingId?: number | null;
    bookingId?: number | null;
    priority?: number;
    payloadJson?: Record<string, unknown> | null;
    forceEvenIfPaused?: boolean;
}) => {
    const integration = await HostSheetIntegration.findOne({
        where: {
            hostUserId: params.hostUserId,
        },
    });

    if (!integration || integration.status === "disconnected") {
        return null;
    }

    if (!params.forceEvenIfPaused && !integration.autoSyncEnabled && params.jobType === "periodic_poll") {
        return null;
    }

    const dedupeKey = `host:${params.hostUserId}:${params.jobType}:${params.listingId ?? "all"}:${params.bookingId ?? "none"}`;
    const existingPending = await HostSheetSyncJob.findOne({
        where: {
            hostUserId: params.hostUserId,
            dedupeKey,
            status: "pending",
        },
    });

    const requestedPriority = params.priority ?? getDefaultPriorityForJobType(params.jobType);

    if (existingPending) {
        if (requestedPriority < existingPending.priority) {
            existingPending.priority = requestedPriority;
            existingPending.availableAt = new Date();
            await existingPending.save();
        }
        return existingPending;
    }

    return HostSheetSyncJob.create({
        hostUserId: params.hostUserId,
        integrationId: integration.integrationId,
        listingId: params.listingId ?? null,
        bookingId: params.bookingId ?? null,
        jobType: params.jobType,
        priority: requestedPriority,
        dedupeKey,
        payloadJson: params.payloadJson ?? null,
        status: "pending",
        availableAt: new Date(),
    });
};

export const enqueueHostSheetSyncJobSafe = (params: {
    hostUserId: number;
    jobType: HostSheetSyncJobType;
    listingId?: number | null;
    bookingId?: number | null;
    payloadJson?: Record<string, unknown> | null;
}): void => {
    if (!isHostSheetSyncRuntimeActive()) {
        return;
    }

    void enqueueHostSheetSyncJob(params).catch((error: unknown) => {
        logger.warn("Failed to enqueue host sheet sync job", {
            hostUserId: params.hostUserId,
            jobType: params.jobType,
            listingId: params.listingId ?? null,
            bookingId: params.bookingId ?? null,
            errorMessage: error instanceof Error ? error.message : String(error),
        });
    });
};

const acquireHostSyncLease = async (
    integration: HostSheetIntegrationDocument,
): Promise<string | null> => {
    const now = new Date();
    if (
        integration.syncLockToken &&
        integration.syncLockExpiresAt &&
        new Date(integration.syncLockExpiresAt).getTime() > now.getTime()
    ) {
        return null;
    }

    const token = crypto.randomBytes(16).toString("hex");
    const expiresAt = new Date(now.getTime() + LEASE_DURATION_MS);

    const [updatedCount] = await HostSheetIntegration.update(
        {
            syncLockToken: token,
            syncLockExpiresAt: expiresAt,
        },
        {
            where: {
                integrationId: integration.integrationId,
                [Op.or]: [
                    { syncLockExpiresAt: null },
                    { syncLockExpiresAt: { [Op.lt]: now } },
                ],
            },
        },
    );

    if (updatedCount === 0) {
        return null;
    }

    integration.syncLockToken = token;
    integration.syncLockExpiresAt = expiresAt;
    return token;
};

const releaseHostSyncLease = async (integrationId: number, token: string): Promise<void> => {
    await HostSheetIntegration.update(
        {
            syncLockToken: null,
            syncLockExpiresAt: null,
        },
        {
            where: {
                integrationId,
                syncLockToken: token,
            },
        },
    ).catch(() => undefined);
};

const recordConflictIfNotOpen = async (params: {
    hostUserId: number;
    integrationId: number;
    listingId?: number | null;
    bookingId?: number | null;
    conflictDate?: string | null;
    monthTab?: string | null;
    conflictType: HostSheetConflictType;
    severity?: HostSheetConflictSeverity;
    status?: "open" | "auto_repaired";
    description: string;
    detailsJson?: Record<string, unknown> | null;
}) => {
    const existing = await HostSheetSyncConflict.findOne({
        where: {
            hostUserId: params.hostUserId,
            integrationId: params.integrationId,
            listingId: params.listingId ?? null,
            conflictDate: params.conflictDate ?? null,
            monthTab: params.monthTab ?? null,
            conflictType: params.conflictType,
            status: "open",
        },
    });

    if (existing) {
        return existing;
    }

    return HostSheetSyncConflict.create({
        hostUserId: params.hostUserId,
        integrationId: params.integrationId,
        listingId: params.listingId ?? null,
        bookingId: params.bookingId ?? null,
        conflictDate: params.conflictDate ?? null,
        monthTab: params.monthTab ?? null,
        conflictType: params.conflictType,
        severity: params.severity ?? "high",
        status: params.status ?? "open",
        description: params.description.slice(0, 500),
        detailsJson: params.detailsJson ?? null,
    });
};

type AuthoritativeBookingStatus = "pending_hold" | "booked";

const findAuthoritativeBookingForDate = (
    bookings: BookingDocument[],
    isoDate: string,
    todayVN: string,
    now: Date,
): { booking: BookingDocument; category: AuthoritativeBookingStatus } | null => {
    const matching = bookings.filter(
        (b) => b.checkInDate <= isoDate && isoDate < b.checkOutDate,
    );

    if (matching.length === 0) {
        return null;
    }

    // Paid / confirmed / checked_in always take top precedence
    const paidOrConfirmed = matching.find((b) =>
        ["paid", "confirmed", "checked_in"].includes(b.status),
    );
    if (paidOrConfirmed) {
        return { booking: paidOrConfirmed, category: "booked" };
    }

    // Historical or ongoing checked_out / completed stays keep history on Sheet and block active stay dates
    const completedOrCheckedOut = matching.find(
        (b) =>
            b.status === "completed" ||
            (b.status === "checked_out" && (isoDate < todayVN || b.checkOutDate > todayVN)),
    );
    if (completedOrCheckedOut) {
        return { booking: completedOrCheckedOut, category: "booked" };
    }

    // Active unexpired pending_payment hold
    const activeHold = matching.find(
        (b) =>
            b.status === "pending_payment" &&
            b.lockedUntil !== null &&
            new Date(b.lockedUntil).getTime() > now.getTime(),
    );
    if (activeHold) {
        return { booking: activeHold, category: "pending_hold" };
    }

    return null;
};

const isCellDisplayEqual = (
    existingCell: RawSheetCell | undefined,
    desiredText: string,
    desiredColor: SheetRgbColor,
): boolean => {
    const currentText = extractCellRawText(existingCell);
    if (currentText !== desiredText) {
        return false;
    }

    const desiredHex = rgbToHex(desiredColor);
    const currentStyleRgb =
        existingCell?.userEnteredFormat?.backgroundColorStyle?.rgbColor ??
        existingCell?.userEnteredFormat?.backgroundColor;
    const currentHex = currentStyleRgb ? rgbToHex(currentStyleRgb) : "#FFFFFF";

    return currentHex === desiredHex;
};

const mapSheetsErrorToIntegrationStatus = (
    error: unknown,
): { status: HostSheetIntegrationStatus; code: string; message: string } => {
    if (error instanceof GoogleSheetsClientError) {
        switch (error.code) {
            case "PERMISSION_DENIED":
                return {
                    status: "permission_error",
                    code: error.code,
                    message: error.message,
                };
            case "SPREADSHEET_NOT_FOUND":
                return {
                    status: "structure_error",
                    code: error.code,
                    message: error.message,
                };
            case "QUOTA_EXCEEDED":
                return {
                    status: "quota_limited",
                    code: error.code,
                    message: error.message,
                };
            default:
                return {
                    status: "sync_error",
                    code: error.code,
                    message: error.message,
                };
        }
    }

    return {
        status: "sync_error",
        code: "SYNC_RUNTIME_ERROR",
        message: error instanceof Error ? error.message : "Lỗi đồng bộ Google Sheets",
    };
};

export type SyncCycleResult = {
    skippedBecauseLocked?: boolean;
    importedBlocksCount: number;
    importedUnblocksCount: number;
    exportedCellsCount: number;
    appendedListingRowsCount: number;
    conflictsDetectedCount: number;
    syncedAt: string;
};

export const runHostSheetSyncCycle = async (
    hostUserId: number,
    options: { mode?: "initialize" | "bidirectional" } = {},
): Promise<SyncCycleResult> => {
    const env = getEnv();
    const integration = await HostSheetIntegration.findOne({
        where: { hostUserId },
    });

    if (!integration || integration.status === "disconnected") {
        throw new ApiError(404, "Chủ nhà chưa kết nối Google Sheets");
    }

    const leaseToken = await acquireHostSyncLease(integration);
    if (!leaseToken) {
        return {
            skippedBecauseLocked: true,
            importedBlocksCount: 0,
            importedUnblocksCount: 0,
            exportedCellsCount: 0,
            appendedListingRowsCount: 0,
            conflictsDetectedCount: 0,
            syncedAt: (integration.lastSyncedAt ?? new Date()).toISOString(),
        };
    }

    try {
        const transport = getGoogleSheetsTransport();
        const now = new Date();
        const todayVN = getTodayInVietnamDateString(now);
        const rollingMonths = buildRollingMonthSpecs(todayVN, 6);
        const firstRollingDate = rollingMonths[0].firstDate;
        const lastRollingDate = rollingMonths[rollingMonths.length - 1].lastDate;

        // 1. Read authoritative DB state for this Host
        const hostListings = await Listing.findAll({
            where: {
                hostId: hostUserId,
            },
            order: [["listingId", "ASC"]],
        });

        const activeOrManagedListings = hostListings.filter((item) => !item.deletedAt);
        const allListingIds = hostListings.map((item) => item.listingId);

        const [bookings, calendarRows, snapshotRows] =
            allListingIds.length === 0
                ? [[], [], []]
                : await Promise.all([
                      Booking.findAll({
                          where: {
                              listingId: { [Op.in]: allListingIds },
                              checkInDate: { [Op.lte]: lastRollingDate },
                              checkOutDate: { [Op.gt]: firstRollingDate },
                              status: {
                                  [Op.in]: [
                                      "pending_payment",
                                      "paid",
                                      "confirmed",
                                      "checked_in",
                                      "checked_out",
                                      "completed",
                                  ],
                              },
                          },
                          order: [["bookingId", "DESC"]],
                      }),
                      AvailabilityCalendar.findAll({
                          where: {
                              listingId: { [Op.in]: allListingIds },
                              date: { [Op.between]: [firstRollingDate, lastRollingDate] },
                          },
                      }),
                      HostSheetCellSnapshot.findAll({
                          where: {
                              listingId: { [Op.in]: allListingIds },
                              date: { [Op.between]: [firstRollingDate, lastRollingDate] },
                          },
                      }),
                  ]);

        const bookingsByListing = new Map<number, BookingDocument[]>();
        for (const b of bookings) {
            const list = bookingsByListing.get(b.listingId) ?? [];
            list.push(b);
            bookingsByListing.set(b.listingId, list);
        }

        const calendarMap = new Map<string, AvailabilityCalendar>();
        for (const row of calendarRows) {
            calendarMap.set(`${row.listingId}:${row.date}`, row);
        }

        const snapshotMap = new Map<string, HostSheetCellSnapshot>();
        for (const snap of snapshotRows) {
            snapshotMap.set(`${snap.listingId}:${snap.date}`, snap);
        }

        // 2. Read Spreadsheet tabs & create any missing tabs (idempotently!)
        let metaSpreadsheet = await transport.getSpreadsheet({
            spreadsheetId: integration.spreadsheetId,
            includeGridData: false,
            fields: "spreadsheetId,properties.title,sheets(properties(sheetId,title,index,gridProperties),developerMetadata,protectedRanges)",
        });

        let sheetsList = metaSpreadsheet.sheets ?? [];
        const createTabRequests: Array<Record<string, unknown>> = [];
        let conflictsDetectedCount = 0;

        if (!resolveDirectorySheetTab(sheetsList)) {
            createTabRequests.push({
                addSheet: {
                    properties: {
                        title: DIRECTORY_TAB_TITLE,
                        index: 0,
                        gridProperties: {
                            rowCount: Math.max(200, hostListings.length + 30),
                            columnCount: 8,
                            frozenRowCount: 2,
                            frozenColumnCount: 1,
                        },
                    },
                },
            });
        }

        for (const monthSpec of rollingMonths) {
            if (!resolveMonthSheetTab(sheetsList, monthSpec.tabKey)) {
                if (integration.lastSyncedAt && options.mode !== "initialize" && monthSpec.tabKey === rollingMonths[0].tabKey) {
                    conflictsDetectedCount += 1;
                    await recordConflictIfNotOpen({
                        hostUserId,
                        integrationId: integration.integrationId,
                        monthTab: monthSpec.tabKey,
                        conflictType: "missing_month_tab",
                        severity: "medium",
                        status: "auto_repaired",
                        description: `Phát hiện thiếu tab tháng ${monthSpec.tabKey} trên Google Sheets — hệ thống đã tự động khôi phục từ dữ liệu gốc.`,
                    });
                }

                createTabRequests.push({
                    addSheet: {
                        properties: {
                            title: monthSpec.tabKey,
                            gridProperties: {
                                rowCount: Math.max(200, activeOrManagedListings.length + 30),
                                columnCount: SHEET_TOTAL_COLUMNS,
                                frozenRowCount: 2,
                                frozenColumnCount: 2,
                            },
                        },
                    },
                });
            }
        }

        if (createTabRequests.length > 0) {
            await transport.batchUpdate({
                spreadsheetId: integration.spreadsheetId,
                requests: createTabRequests,
            });

            metaSpreadsheet = await transport.getSpreadsheet({
                spreadsheetId: integration.spreadsheetId,
                includeGridData: false,
                fields: "spreadsheetId,properties.title,sheets(properties(sheetId,title,index,gridProperties),developerMetadata,protectedRanges)",
            });
            sheetsList = metaSpreadsheet.sheets ?? [];
        }

        const resolvedMonthTabs = new Map<string, RawSheetTab>();
        const gridRanges: string[] = [];

        for (const monthSpec of rollingMonths) {
            const tab = resolveMonthSheetTab(sheetsList, monthSpec.tabKey);
            if (tab) {
                resolvedMonthTabs.set(monthSpec.tabKey, tab);
                const maxRowsToRead = Math.max(150, hostListings.length + 50);
                gridRanges.push(`${escapeSheetTitleForA1(tab.properties.title)}!A1:AG${maxRowsToRead}`);
            }
        }

        // Single multi-range GET request with narrow fields mask (NEVER requesting effectiveFormat!)
        const gridResponse = await transport.getSpreadsheet({
            spreadsheetId: integration.spreadsheetId,
            ranges: gridRanges,
            includeGridData: true,
            fields: "spreadsheetId,properties.title,sheets(properties(sheetId,title,gridProperties),developerMetadata,protectedRanges,data(startRow,startColumn,rowMetadata.developerMetadata,rowData.values(userEnteredValue,userEnteredFormat(backgroundColorStyle,backgroundColor),note)))",
        });

        const gridSheets = gridResponse.sheets ?? [];
        for (const monthSpec of rollingMonths) {
            const tab = resolveMonthSheetTab(gridSheets, monthSpec.tabKey);
            if (tab) {
                resolvedMonthTabs.set(monthSpec.tabKey, tab);
            }
        }

        const directoryTab = resolveDirectorySheetTab(sheetsList);

        let importedBlocksCount = 0;
        let importedUnblocksCount = 0;
        const customHostTextMap = new Map<string, string>();

        // 3. PHASE A: Safe Sheet -> App Import (with strict BOLA, structural checks & 3-way diff)
        const monthStructures = new Map<string, ReturnType<typeof extractMonthSheetStructure>>();

        for (const monthSpec of rollingMonths) {
            const tab = resolvedMonthTabs.get(monthSpec.tabKey);
            if (!tab) {
                continue;
            }

            const structure = extractMonthSheetStructure(tab);
            monthStructures.set(monthSpec.tabKey, structure);

            // Detect duplicate listing_id rows
            for (const dupListingId of structure.duplicateListingIds) {
                if (!allListingIds.includes(dupListingId)) {
                    continue;
                }
                conflictsDetectedCount += 1;
                await recordConflictIfNotOpen({
                    hostUserId,
                    integrationId: integration.integrationId,
                    listingId: dupListingId,
                    monthTab: monthSpec.tabKey,
                    conflictType: "duplicate_listing_row",
                    severity: "high",
                    status: "open",
                    description: `Căn #${dupListingId} đang bị nhân bản thành nhiều dòng trong tab ${monthSpec.tabKey}. Đã tạm dừng nhận thay đổi từ các dòng trùng để bảo vệ lịch.`,
                });
            }

            // Detect missing active listing rows when Sheet was previously synced
            if (integration.lastSyncedAt) {
                for (const listing of activeOrManagedListings) {
                    const listingCreatedBeforeLastSync =
                        listing.createdAt &&
                        new Date(listing.createdAt).getTime() + 1_000 <
                            new Date(integration.lastSyncedAt).getTime();

                    if (
                        listingCreatedBeforeLastSync &&
                        !structure.rowsByListingId.has(listing.listingId)
                    ) {
                        conflictsDetectedCount += 1;
                        await recordConflictIfNotOpen({
                            hostUserId,
                            integrationId: integration.integrationId,
                            listingId: listing.listingId,
                            monthTab: monthSpec.tabKey,
                            conflictType: "missing_listing_row",
                            severity: "high",
                            status: "auto_repaired",
                            description: `Dòng lịch của căn #${listing.listingId} (${listing.title}) bị xóa khỏi tab ${monthSpec.tabKey}. Hệ thống KHÔNG mở trống ngày và đã khôi phục lại dòng từ DB.`,
                        });
                        await HostSheetChangeLog.create({
                            hostUserId,
                            integrationId: integration.integrationId,
                            listingId: listing.listingId,
                            direction: "structure_repair",
                            action: "restore_missing_listing_row",
                            previousValue: "missing_row",
                            newValue: `restored_in_${monthSpec.tabKey}`,
                        });
                    }
                }
            }

            // Inspect each non-deleted Host listing row
            for (const listing of activeOrManagedListings) {
                if (structure.duplicateListingIds.has(listing.listingId)) {
                    continue;
                }

                const extractedRows = structure.rowsByListingId.get(listing.listingId);
                if (!extractedRows || extractedRows.length !== 1) {
                    continue;
                }

                const sheetRow = extractedRows[0];
                const listingBookings = bookingsByListing.get(listing.listingId) ?? [];
                const newlyBlockedInMonth: Array<{
                    date: string;
                    prevBlocked: boolean;
                    prevIsAvailable: boolean;
                    prevLockSource: string | null;
                    prevNotes: string | null;
                }> = [];

                for (let day = 1; day <= monthSpec.daysInMonth; day += 1) {
                    const isoDate = formatIsoDate(monthSpec.year, monthSpec.month, day);
                    if (isoDate < todayVN) {
                        continue; // Never import availability mutations for past dates
                    }

                    const cell = sheetRow.cellsByDay.get(day);
                    const classified = classifySheetCalendarCell(cell);
                    const cellKey = `${listing.listingId}:${isoDate}`;
                    const authBooking = findAuthoritativeBookingForDate(
                        listingBookings,
                        isoDate,
                        todayVN,
                        now,
                    );

                    // Active DB booking ALWAYS wins
                    if (authBooking) {
                        if (classified.state === "host_blocked") {
                            conflictsDetectedCount += 1;
                            await recordConflictIfNotOpen({
                                hostUserId,
                                integrationId: integration.integrationId,
                                listingId: listing.listingId,
                                bookingId: authBooking.booking.bookingId,
                                conflictDate: isoDate,
                                monthTab: monthSpec.tabKey,
                                conflictType: "booking_vs_sheet_edit",
                                severity: "critical",
                                status: "open",
                                description: `Ngày ${isoDate} của căn #${listing.listingId} đang có đơn #${authBooking.booking.bookingId} trên hệ thống nhưng bị sửa thủ công trên Google Sheets. Hệ thống giữ nguyên đơn đặt.`,
                                detailsJson: {
                                    sheetRawValue: classified.rawValue,
                                    sheetBgHex: classified.bgHex,
                                    bookingId: authBooking.booking.bookingId,
                                    bookingStatus: authBooking.booking.status,
                                },
                            });
                        }
                        continue;
                    }

                    const cal = calendarMap.get(cellKey);
                    const snap = snapshotMap.get(cellKey);
                    const isBlockedByAdmin = Boolean(cal?.isBlockedByAdmin);
                    const isMaintenanceLock = cal?.lockSource === "maintenance";

                    if (isBlockedByAdmin || isMaintenanceLock) {
                        continue;
                    }

                    const appBlocked = Boolean(cal?.isBlockedByHost);
                    const calRev = Number(cal?.syncRevision ?? 0);
                    const snapRev = Number(snap?.syncRevision ?? 0);
                    const snapAppBlocked = Boolean(snap?.lastAppBlockedByHost);

                    const appChanged = snap
                        ? calRev > snapRev || appBlocked !== snapAppBlocked
                        : appBlocked || calRev > 0;

                    // Ignore stale booking markers left on Sheet from an expired/cancelled booking
                    if (classified.state === "pending_hold" || classified.state === "booked") {
                        continue;
                    }

                    const sheetWantsBlock = classified.state === "host_blocked";
                    const prevSheetManualBlock = snap ? snap.lastSheetState === "host_blocked" : false;
                    const sheetChanged = snap ? sheetWantsBlock !== prevSheetManualBlock : sheetWantsBlock;

                    if (classified.state === "host_blocked" && classified.rawValue) {
                        customHostTextMap.set(
                            cellKey,
                            sanitizeSheetTextValue(classified.rawValue, 24) || "K",
                        );
                    }

                    if (!sheetChanged) {
                        continue;
                    }

                    if (appChanged && appBlocked !== sheetWantsBlock) {
                        // Concurrent conflict between App and Sheet -> fail-safe to BLOCKED!
                        conflictsDetectedCount += 1;
                        const nextRev = Math.max(calRev, snapRev) + 1;
                        if (cal) {
                            cal.isBlockedByHost = true;
                            cal.isAvailable = false;
                            cal.lockSource = "app_manual";
                            cal.syncRevision = nextRev;
                            cal.lastSheetSyncedAt = now;
                            await cal.save();
                        } else {
                            const created = await AvailabilityCalendar.create({
                                listingId: listing.listingId,
                                date: isoDate,
                                isAvailable: false,
                                isBlockedByHost: true,
                                isBlockedByAdmin: false,
                                lockSource: "app_manual",
                                priceOverride: null,
                                minNightsOverride: null,
                                notes: "Khóa an toàn do xung đột đồng thời App & Google Sheets",
                                syncRevision: nextRev,
                                lastSheetSyncedAt: now,
                            });
                            calendarMap.set(cellKey, created);
                        }

                        await recordConflictIfNotOpen({
                            hostUserId,
                            integrationId: integration.integrationId,
                            listingId: listing.listingId,
                            conflictDate: isoDate,
                            monthTab: monthSpec.tabKey,
                            conflictType: "app_vs_sheet_concurrent",
                            severity: "high",
                            status: "open",
                            description: `Xung đột chỉnh sửa đồng thời ngày ${isoDate} (căn #${listing.listingId}) giữa App và Google Sheets — đã ưu tiên khóa ngày để tránh trùng lịch.`,
                        });
                        continue;
                    }

                    if (sheetWantsBlock) {
                        if (!appBlocked) {
                            newlyBlockedInMonth.push({
                                date: isoDate,
                                prevBlocked: appBlocked,
                                prevIsAvailable: cal ? Boolean(cal.isAvailable) : true,
                                prevLockSource: cal?.lockSource ?? null,
                                prevNotes: cal?.notes ?? null,
                            });
                        }

                        const nextRev = Math.max(calRev, snapRev) + 1;
                        const customNote =
                            classified.rawValue && classified.rawValue.toUpperCase() !== "K"
                                ? sanitizeSheetTextValue(classified.rawValue, 180)
                                : cal?.notes ?? "Khóa lịch từ Google Sheets";

                        if (cal) {
                            cal.isBlockedByHost = true;
                            cal.isAvailable = false;
                            cal.lockSource = "sheet_manual";
                            cal.notes = customNote;
                            cal.syncRevision = nextRev;
                            cal.lastSheetSyncedAt = now;
                            await cal.save();
                        } else {
                            const created = await AvailabilityCalendar.create({
                                listingId: listing.listingId,
                                date: isoDate,
                                isAvailable: false,
                                isBlockedByHost: true,
                                isBlockedByAdmin: false,
                                lockSource: "sheet_manual",
                                priceOverride: null,
                                minNightsOverride: null,
                                notes: customNote,
                                syncRevision: nextRev,
                                lastSheetSyncedAt: now,
                            });
                            calendarMap.set(cellKey, created);
                        }

                        importedBlocksCount += 1;
                        await HostSheetChangeLog.create({
                            hostUserId,
                            integrationId: integration.integrationId,
                            listingId: listing.listingId,
                            targetDate: isoDate,
                            direction: "sheet_to_app",
                            action: "host_block_added",
                            previousValue: "available",
                            newValue: classified.rawValue || "K",
                            metadataJson: { bgHex: classified.bgHex, monthTab: monthSpec.tabKey },
                        });
                    } else if (cal && cal.isBlockedByHost) {
                        // Sheet intentionally cleared a previously synced host_blocked cell -> safe unblock
                        const nextRev = Math.max(calRev, snapRev) + 1;
                        cal.isBlockedByHost = false;
                        cal.lockSource = null;
                        cal.isAvailable = !cal.isBlockedByAdmin;
                        if (
                            cal.notes === "Khóa lịch từ Google Sheets" ||
                            cal.lockSource === null
                        ) {
                            cal.notes = null;
                        }
                        cal.syncRevision = nextRev;
                        cal.lastSheetSyncedAt = now;

                        if (
                            cal.isAvailable &&
                            !cal.isBlockedByAdmin &&
                            cal.priceOverride === null &&
                            cal.minNightsOverride === null &&
                            cal.notes === null
                        ) {
                            await cal.destroy();
                            calendarMap.delete(cellKey);
                        } else {
                            await cal.save();
                        }

                        importedUnblocksCount += 1;
                        await HostSheetChangeLog.create({
                            hostUserId,
                            integrationId: integration.integrationId,
                            listingId: listing.listingId,
                            targetDate: isoDate,
                            direction: "sheet_to_app",
                            action: "host_block_removed",
                            previousValue: "host_blocked",
                            newValue: "available",
                            metadataJson: { monthTab: monthSpec.tabKey },
                        });
                    }
                }

                // Bulk row block guard (accidental whole-row color fill warning + 1-click Undo!)
                if (newlyBlockedInMonth.length >= env.googleSheetsBulkChangeWarnThreshold) {
                    conflictsDetectedCount += 1;
                    await recordConflictIfNotOpen({
                        hostUserId,
                        integrationId: integration.integrationId,
                        listingId: listing.listingId,
                        monthTab: monthSpec.tabKey,
                        conflictType: "bulk_row_block_warning",
                        severity: "medium",
                        status: "open",
                        description: `Cảnh báo khóa hàng loạt: Căn #${listing.listingId} (${listing.title}) vừa bị khóa cùng lúc ${newlyBlockedInMonth.length} ngày trong tháng ${monthSpec.tabKey}. Bạn có thể bấm Hoàn tác nếu tô nhầm dòng.`,
                        detailsJson: {
                            count: newlyBlockedInMonth.length,
                            monthTab: monthSpec.tabKey,
                            previousStates: newlyBlockedInMonth,
                        },
                    });
                }
            }
        }

        // 4. PHASE B: Authoritative Render & Diff Export (App -> Sheet)
        const batchRequests: Array<Record<string, unknown>> = [];
        let exportedCellsCount = 0;
        let appendedListingRowsCount = 0;
        const snapshotUpserts: Array<{
            hostUserId: number;
            listingId: number;
            date: string;
            lastSheetState: "empty" | "host_blocked" | "pending_hold" | "booked";
            lastSheetRawValue: string | null;
            lastSheetBgHex: string | null;
            lastAppBlockedByHost: boolean;
            lastActiveBookingId: number | null;
            lockSource: HostSheetLockSource;
            syncRevision: number;
            syncedAt: Date;
        }> = [];

        if (directoryTab) {
            batchRequests.push(
                ...buildDirectoryTabRequests(
                    directoryTab,
                    hostListings.map((l) => ({
                        listingId: l.listingId,
                        title: l.title,
                        district: l.district,
                        city: l.city,
                        basePrice: Number(l.basePrice ?? 0),
                        status: l.status,
                        deletedAt: l.deletedAt ?? null,
                    })),
                ),
            );
        }

        for (const monthSpec of rollingMonths) {
            const tab = resolvedMonthTabs.get(monthSpec.tabKey);
            if (!tab) {
                continue;
            }

            const sheetId = tab.properties.sheetId;
            const structure = monthStructures.get(monthSpec.tabKey) ?? extractMonthSheetStructure(tab);

            if (options.mode === "initialize" || (tab.data?.[0]?.rowData?.length ?? 0) < 2) {
                batchRequests.push(...buildMonthTabHeaderRequests(tab, monthSpec));
            }

            let nextAppendRowIndex = structure.nextAppendRowIndex;
            const currentGridRowCount = tab.properties.gridProperties?.rowCount ?? 200;
            const requiredRowCount = nextAppendRowIndex + activeOrManagedListings.length + 10;
            if (requiredRowCount > currentGridRowCount) {
                batchRequests.push({
                    appendDimension: {
                        sheetId,
                        dimension: "ROWS",
                        length: requiredRowCount - currentGridRowCount,
                    },
                });
            }

            // Mark soft-deleted listings' existing rows clearly if present without shifting other rows' IDs
            for (const archivedListing of hostListings.filter((l) => Boolean(l.deletedAt))) {
                const existingArchivedRows = structure.rowsByListingId.get(archivedListing.listingId) ?? [];
                for (const row of existingArchivedRows) {
                    const archivedTitle = sanitizeSheetTextValue(`[ĐÃ NGỪNG] ${archivedListing.title}`);
                    if (row.colBTitle !== archivedTitle) {
                        batchRequests.push({
                            updateCells: {
                                range: {
                                    sheetId,
                                    startRowIndex: row.rowIndex,
                                    endRowIndex: row.rowIndex + 1,
                                    startColumnIndex: 1,
                                    endColumnIndex: 2,
                                },
                                rows: [
                                    {
                                        values: [
                                            {
                                                userEnteredValue: { stringValue: archivedTitle },
                                                userEnteredFormat: {
                                                    backgroundColorStyle: { rgbColor: SHEET_COLORS.ARCHIVED_BG },
                                                    horizontalAlignment: "LEFT",
                                                },
                                            },
                                        ],
                                    },
                                ],
                                fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment)",
                            },
                        });
                    }
                }
            }

            for (const listing of activeOrManagedListings) {
                const existingRows = structure.rowsByListingId.get(listing.listingId) ?? [];
                const targetRow = existingRows.length >= 1 ? existingRows[0] : null;
                const rowIndex = targetRow ? targetRow.rowIndex : nextAppendRowIndex++;
                const isNewRow = !targetRow;

                if (isNewRow) {
                    appendedListingRowsCount += 1;
                }

                const listingBookings = bookingsByListing.get(listing.listingId) ?? [];
                const safeTitle =
                    listing.status === "inactive"
                        ? sanitizeSheetTextValue(`[TẠM ẨN] ${listing.title}`)
                        : sanitizeSheetTextValue(listing.title);

                // Ensure Col A (immutable plain-text listing_id), Col B (title), and Row DeveloperMetadata
                if (
                    isNewRow ||
                    targetRow.colAText !== String(listing.listingId) ||
                    targetRow.colBTitle !== safeTitle ||
                    targetRow.colMismatch
                ) {
                    const colACell = buildCalendarCellWriteData({
                        text: String(listing.listingId),
                        bgColor: SHEET_COLORS.SUBHEADER_BG,
                        bold: true,
                        forcePlainText: true,
                    }).cell;

                    const colBCell: RawSheetCell = {
                        userEnteredValue: { stringValue: safeTitle },
                        userEnteredFormat: {
                            backgroundColorStyle: { rgbColor: SHEET_COLORS.WHITE },
                            horizontalAlignment: "LEFT",
                            textFormat: { bold: false },
                        },
                    };

                    batchRequests.push({
                        updateCells: {
                            range: {
                                sheetId,
                                startRowIndex: rowIndex,
                                endRowIndex: rowIndex + 1,
                                startColumnIndex: 0,
                                endColumnIndex: 2,
                            },
                            rows: [{ values: [colACell, colBCell] }],
                            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold,numberFormat)",
                        },
                    });
                }

                if (isNewRow || targetRow.metadataListingId !== listing.listingId) {
                    batchRequests.push({
                        createDeveloperMetadata: {
                            developerMetadata: {
                                metadataKey: SHEET_METADATA_KEYS.LISTING_ROW,
                                metadataValue: String(listing.listingId),
                                location: {
                                    dimensionRange: {
                                        sheetId,
                                        dimension: "ROWS",
                                        startIndex: rowIndex,
                                        endIndex: rowIndex + 1,
                                    },
                                },
                                visibility: "DOCUMENT",
                            },
                        },
                    });
                }

                // Build day cells 01..31
                const fullRowCells: RawSheetCell[] = [];
                let anyDayChangedInRow = isNewRow;

                for (let day = 1; day <= 31; day += 1) {
                    const existingCell = targetRow?.cellsByDay.get(day);

                    if (day > monthSpec.daysInMonth) {
                        const invalidCell = buildCalendarCellWriteData({
                            text: "✕",
                            bgColor: SHEET_COLORS.INVALID_DAY_GRAY,
                            bold: false,
                            note: "Ngày không tồn tại trong tháng",
                        }).cell;
                        fullRowCells.push(invalidCell);
                        if (!isCellDisplayEqual(existingCell, "✕", SHEET_COLORS.INVALID_DAY_GRAY)) {
                            anyDayChangedInRow = true;
                        }
                        continue;
                    }

                    const isoDate = formatIsoDate(monthSpec.year, monthSpec.month, day);
                    const cellKey = `${listing.listingId}:${isoDate}`;
                    const authBooking = findAuthoritativeBookingForDate(
                        listingBookings,
                        isoDate,
                        todayVN,
                        now,
                    );
                    const cal = calendarMap.get(cellKey);

                    let desiredText = "";
                    let desiredColor: SheetRgbColor = SHEET_COLORS.WHITE;
                    let desiredBold = false;
                    let desiredNote = "";
                    let snapState: "empty" | "host_blocked" | "pending_hold" | "booked" = "empty";
                    let snapLockSource: HostSheetLockSource = "none";
                    let activeBookingId: number | null = null;

                    if (authBooking) {
                        activeBookingId = authBooking.booking.bookingId;
                        if (authBooking.category === "pending_hold") {
                            desiredText = `G #${activeBookingId}`;
                            desiredColor = SHEET_COLORS.PENDING_HOLD_ORANGE;
                            desiredBold = true;
                            desiredNote = `Giữ chỗ chờ thanh toán #${activeBookingId} (${authBooking.booking.checkInDate} → ${authBooking.booking.checkOutDate})`;
                            snapState = "pending_hold";
                            snapLockSource = "booking_hold";
                        } else {
                            desiredText = `Đ #${activeBookingId}`;
                            desiredColor = SHEET_COLORS.BOOKED_GREEN;
                            desiredBold = true;
                            desiredNote = `Đã đặt #${activeBookingId} (${authBooking.booking.checkInDate} → ${authBooking.booking.checkOutDate})`;
                            snapState = "booked";
                            snapLockSource = "booking_paid";
                        }
                    } else if (cal?.isBlockedByAdmin) {
                        desiredText = "K";
                        desiredColor = SHEET_COLORS.HOST_BLOCKED_RED;
                        desiredBold = true;
                        desiredNote = "Khóa bởi Quản trị viên";
                        snapState = "host_blocked";
                        snapLockSource = "admin_lock";
                    } else if (cal?.isBlockedByHost || cal?.isAvailable === false) {
                        const existingClassified = classifySheetCalendarCell(existingCell);
                        const preservedCustomText =
                            customHostTextMap.get(cellKey) ??
                            (cal?.lockSource === "sheet_manual" &&
                            existingClassified.state === "host_blocked" &&
                            existingClassified.rawValue
                                ? sanitizeSheetTextValue(existingClassified.rawValue, 24)
                                : "K");
                        desiredText = preservedCustomText || "K";
                        desiredColor = SHEET_COLORS.HOST_BLOCKED_RED;
                        desiredBold = true;
                        desiredNote = cal?.notes ? sanitizeSheetTextValue(cal.notes, 200) : "Host khóa lịch";
                        snapState = "host_blocked";
                        snapLockSource =
                            cal?.lockSource === "sheet_manual" ? "sheet_manual" : "app_manual";
                    }

                    const built = buildCalendarCellWriteData({
                        text: desiredText,
                        bgColor: desiredColor,
                        bold: desiredBold,
                        note: desiredNote,
                    });
                    fullRowCells.push(built.cell);

                    if (!isCellDisplayEqual(existingCell, desiredText, desiredColor)) {
                        anyDayChangedInRow = true;
                        exportedCellsCount += 1;
                    }

                    snapshotUpserts.push({
                        hostUserId,
                        listingId: listing.listingId,
                        date: isoDate,
                        lastSheetState: snapState,
                        lastSheetRawValue: desiredText || null,
                        lastSheetBgHex: rgbToHex(desiredColor),
                        lastAppBlockedByHost: Boolean(cal?.isBlockedByHost),
                        lastActiveBookingId: activeBookingId,
                        lockSource: snapLockSource,
                        syncRevision: Number(cal?.syncRevision ?? 0),
                        syncedAt: now,
                    });
                }

                if (anyDayChangedInRow) {
                    batchRequests.push({
                        updateCells: {
                            range: {
                                sheetId,
                                startRowIndex: rowIndex,
                                endRowIndex: rowIndex + 1,
                                startColumnIndex: SHEET_DAY_COLUMN_OFFSET,
                                endColumnIndex: SHEET_TOTAL_COLUMNS,
                            },
                            rows: [{ values: fullRowCells }],
                            fields: "userEnteredValue,userEnteredFormat(backgroundColorStyle,horizontalAlignment,textFormat.bold),note",
                        },
                    });
                }
            }
        }

        if (batchRequests.length > 0) {
            await transport.batchUpdate({
                spreadsheetId: integration.spreadsheetId,
                requests: batchRequests,
            });
        }

        if (snapshotUpserts.length > 0) {
            await HostSheetCellSnapshot.bulkCreate(snapshotUpserts, {
                updateOnDuplicate: [
                    "hostUserId",
                    "lastSheetState",
                    "lastSheetRawValue",
                    "lastSheetBgHex",
                    "lastAppBlockedByHost",
                    "lastActiveBookingId",
                    "lockSource",
                    "syncRevision",
                    "syncedAt",
                ],
            });
        }

        const nextPollAt = new Date(now.getTime() + env.googleSheetsSyncIntervalSeconds * 1000);
        integration.status = "connected";
        integration.spreadsheetTitle =
            metaSpreadsheet.properties?.title?.trim() || integration.spreadsheetTitle;
        integration.canWriteVerified = true;
        integration.lastSyncedAt = now;
        integration.lastPolledAt = now;
        integration.nextPollAt = nextPollAt;
        integration.lastErrorCode = null;
        integration.lastErrorMessage = null;
        integration.consecutiveFailures = 0;
        integration.syncRevision = Number(integration.syncRevision ?? 0) + 1;
        await integration.save();

        return {
            importedBlocksCount,
            importedUnblocksCount,
            exportedCellsCount,
            appendedListingRowsCount,
            conflictsDetectedCount,
            syncedAt: now.toISOString(),
        };
    } catch (error) {
        const mapped = mapSheetsErrorToIntegrationStatus(error);
        integration.status = mapped.status;
        integration.lastErrorCode = mapped.code;
        integration.lastErrorMessage = mapped.message;
        integration.consecutiveFailures = Number(integration.consecutiveFailures ?? 0) + 1;
        if (mapped.code === "PERMISSION_DENIED") {
            integration.canWriteVerified = false;
            await recordConflictIfNotOpen({
                hostUserId,
                integrationId: integration.integrationId,
                conflictType: "permission_revoked",
                severity: "critical",
                status: "open",
                description: mapped.message,
            }).catch(() => undefined);
        }
        await integration.save().catch(() => undefined);

        if (error instanceof GoogleSheetsClientError) {
            throw new ApiError(error.httpStatus, error.message);
        }
        throw error;
    } finally {
        await releaseHostSyncLease(integration.integrationId, leaseToken);
    }
};

export const connectHostSpreadsheet = async (
    hostUserId: number,
    input: ConnectHostSheetInput,
) => {
    const env = getEnv();
    const { spreadsheetId, canonicalUrl } = parseAndValidateSpreadsheetInput(
        input.spreadsheetUrlOrId,
    );

    const existingForSpreadsheet = await HostSheetIntegration.findOne({
        where: { spreadsheetId },
    });

    if (
        existingForSpreadsheet &&
        Number(existingForSpreadsheet.hostUserId) !== Number(hostUserId)
    ) {
        throw new ApiError(
            409,
            "Google Sheets này đã được liên kết với một tài khoản Chủ nhà khác. Mỗi Chủ nhà sử dụng 1 trang tính riêng.",
        );
    }

    let verifiedAccess: Awaited<ReturnType<typeof verifySpreadsheetEditorAccess>>;
    try {
        verifiedAccess = await verifySpreadsheetEditorAccess(spreadsheetId);
    } catch (error) {
        if (error instanceof GoogleSheetsClientError) {
            const serviceAccountEmail = await getConfiguredServiceAccountEmail().catch(() => null);
            throw new ApiError(error.httpStatus, error.message, [
                {
                    path: "spreadsheetUrlOrId",
                    msg: error.message,
                    ...(serviceAccountEmail ? { serviceAccountEmail } : {}),
                },
            ]);
        }
        throw error;
    }

    const hostEditorEmail =
        input.hostEditorEmail !== undefined
            ? input.hostEditorEmail?.trim() || null
            : env.googleSheetsDefaultHostEditorEmail;

    let integration = await HostSheetIntegration.findOne({
        where: { hostUserId },
    });

    const now = new Date();
    const nextPollAt = new Date(now.getTime() + env.googleSheetsSyncIntervalSeconds * 1000);

    if (!integration) {
        integration = await HostSheetIntegration.create({
            hostUserId,
            spreadsheetId,
            spreadsheetUrl: canonicalUrl,
            spreadsheetTitle: verifiedAccess.title,
            hostEditorEmail,
            serviceAccountEmail: verifiedAccess.serviceAccountEmail,
            status: "connected",
            autoSyncEnabled: input.autoSyncEnabled ?? true,
            strictBookingPrecheck: input.strictBookingPrecheck ?? true,
            permissionVerifiedAt: now,
            canWriteVerified: true,
            nextPollAt,
            lastErrorCode: null,
            lastErrorMessage: null,
            consecutiveFailures: 0,
        });
    } else {
        integration.spreadsheetId = spreadsheetId;
        integration.spreadsheetUrl = canonicalUrl;
        integration.spreadsheetTitle = verifiedAccess.title;
        integration.hostEditorEmail = hostEditorEmail;
        integration.serviceAccountEmail = verifiedAccess.serviceAccountEmail;
        integration.status = "connected";
        if (input.autoSyncEnabled !== undefined) {
            integration.autoSyncEnabled = input.autoSyncEnabled;
        }
        if (input.strictBookingPrecheck !== undefined) {
            integration.strictBookingPrecheck = input.strictBookingPrecheck;
        }
        integration.permissionVerifiedAt = now;
        integration.canWriteVerified = true;
        integration.nextPollAt = nextPollAt;
        integration.lastErrorCode = null;
        integration.lastErrorMessage = null;
        integration.consecutiveFailures = 0;
        await integration.save();
    }

    await writeAuditLog({
        actorId: hostUserId,
        action: "host_sheet.connect",
        targetType: "host_sheet_integration",
        targetId: integration.integrationId,
        metadata: {
            spreadsheetId,
            spreadsheetTitle: verifiedAccess.title,
        },
    });

    const initJob = await enqueueHostSheetSyncJob({
        hostUserId,
        jobType: "init_standard_calendar",
        forceEvenIfPaused: true,
    });

    if (input.initializeImmediately !== false) {
        try {
            const cycleResult = await runHostSheetSyncCycle(hostUserId, { mode: "initialize" });
            if (initJob && !cycleResult.skippedBecauseLocked) {
                initJob.status = "succeeded";
                initJob.completedAt = new Date();
                await initJob.save();
            }
        } catch (error) {
            logger.warn("Immediate calendar initialization deferred to durable worker queue", {
                hostUserId,
                errorMessage: error instanceof Error ? error.message : String(error),
            });
        }
    }

    return getHostSheetSyncStatus(hostUserId);
};

export const verifyHostSpreadsheetPermissions = async (hostUserId: number) => {
    const integration = await HostSheetIntegration.findOne({
        where: { hostUserId },
    });

    if (!integration || integration.status === "disconnected") {
        throw new ApiError(404, "Chủ nhà chưa kết nối Google Sheets");
    }

    try {
        const verified = await verifySpreadsheetEditorAccess(integration.spreadsheetId);
        integration.canWriteVerified = true;
        integration.permissionVerifiedAt = new Date();
        integration.spreadsheetTitle = verified.title;
        integration.serviceAccountEmail =
            verified.serviceAccountEmail ?? integration.serviceAccountEmail;
        integration.status = "connected";
        integration.lastErrorCode = null;
        integration.lastErrorMessage = null;
        integration.consecutiveFailures = 0;
        await integration.save();

        // Auto-resolve any open permission_revoked conflicts
        await HostSheetSyncConflict.update(
            {
                status: "resolved",
                resolvedByUserId: hostUserId,
                resolvedAt: new Date(),
            },
            {
                where: {
                    hostUserId,
                    integrationId: integration.integrationId,
                    conflictType: "permission_revoked",
                    status: "open",
                },
            },
        );
    } catch (error) {
        const mapped = mapSheetsErrorToIntegrationStatus(error);
        integration.status = mapped.status;
        integration.canWriteVerified = false;
        integration.lastErrorCode = mapped.code;
        integration.lastErrorMessage = mapped.message;
        await integration.save();
        throw new ApiError(
            error instanceof GoogleSheetsClientError ? error.httpStatus : 403,
            mapped.message,
        );
    }

    return getHostSheetSyncStatus(hostUserId);
};

export const initializeHostStandardCalendar = async (hostUserId: number) => {
    const syncResult = await runHostSheetSyncCycle(hostUserId, { mode: "initialize" });
    const status = await getHostSheetSyncStatus(hostUserId);
    return {
        ...status,
        lastCycle: syncResult,
    };
};

export const syncHostSpreadsheetNow = async (hostUserId: number) => {
    const syncResult = await runHostSheetSyncCycle(hostUserId, { mode: "bidirectional" });
    const status = await getHostSheetSyncStatus(hostUserId);
    return {
        ...status,
        lastCycle: syncResult,
    };
};

export const updateHostSheetSettings = async (
    hostUserId: number,
    input: UpdateHostSheetSettingsInput,
) => {
    const integration = await HostSheetIntegration.findOne({
        where: { hostUserId },
    });

    if (!integration || integration.status === "disconnected") {
        throw new ApiError(404, "Chủ nhà chưa kết nối Google Sheets");
    }

    if (input.autoSyncEnabled !== undefined) {
        integration.autoSyncEnabled = input.autoSyncEnabled;
    }
    if (input.strictBookingPrecheck !== undefined) {
        integration.strictBookingPrecheck = input.strictBookingPrecheck;
    }
    if (input.hostEditorEmail !== undefined) {
        integration.hostEditorEmail = input.hostEditorEmail?.trim() || null;
    }

    await integration.save();
    return getHostSheetSyncStatus(hostUserId);
};

export const disconnectHostSpreadsheet = async (hostUserId: number) => {
    const integration = await HostSheetIntegration.findOne({
        where: { hostUserId },
    });

    if (!integration) {
        return getHostSheetSyncStatus(hostUserId);
    }

    integration.status = "disconnected";
    integration.autoSyncEnabled = false;
    integration.canWriteVerified = false;
    integration.syncLockToken = null;
    integration.syncLockExpiresAt = null;
    await integration.save();

    await HostSheetSyncJob.update(
        { status: "cancelled" },
        {
            where: {
                hostUserId,
                status: "pending",
            },
        },
    );

    await writeAuditLog({
        actorId: hostUserId,
        action: "host_sheet.disconnect",
        targetType: "host_sheet_integration",
        targetId: integration.integrationId,
    });

    return getHostSheetSyncStatus(hostUserId);
};

/**
 * Live pre-check executed BEFORE finalizing a Guest booking when the Host has an active Google Sheet.
 * Prevents double-booking if Host painted a date Red seconds before Guest clicked "Đặt phòng".
 */
export const verifySheetAvailabilityBeforeBooking = async (params: {
    listingId: number;
    hostUserId: number;
    checkInDate: string;
    checkOutDate: string;
}): Promise<{ verified: boolean; skipped?: boolean }> => {
    if (!isHostSheetSyncRuntimeActive()) {
        return { verified: false, skipped: true };
    }

    const integration = await HostSheetIntegration.findOne({
        where: { hostUserId: params.hostUserId },
    });

    if (!integration || integration.status === "disconnected") {
        return { verified: false, skipped: true };
    }

    const reservedDates = buildReservedDates(params.checkInDate, params.checkOutDate);
    if (reservedDates.length === 0) {
        return { verified: true };
    }

    const datesByMonthTab = new Map<string, string[]>();
    for (const date of reservedDates) {
        const tabKey = monthTabKeyFromIsoDate(date);
        if (!tabKey) {
            continue;
        }
        const list = datesByMonthTab.get(tabKey) ?? [];
        list.push(date);
        datesByMonthTab.set(tabKey, list);
    }

    try {
        const transport = getGoogleSheetsTransport();
        const meta = await transport.getSpreadsheet({
            spreadsheetId: integration.spreadsheetId,
            includeGridData: false,
            fields: "spreadsheetId,sheets(properties(sheetId,title,gridProperties),developerMetadata)",
        });

        const sheetsList = meta.sheets ?? [];
        const targetTabs = new Map<string, RawSheetTab>();
        const ranges: string[] = [];

        for (const tabKey of datesByMonthTab.keys()) {
            const tab = resolveMonthSheetTab(sheetsList, tabKey);
            if (tab) {
                targetTabs.set(tabKey, tab);
                ranges.push(`${escapeSheetTitleForA1(tab.properties.title)}!A1:AG300`);
            }
        }

        if (ranges.length === 0) {
            return { verified: true };
        }

        const gridData = await transport.getSpreadsheet({
            spreadsheetId: integration.spreadsheetId,
            ranges,
            includeGridData: true,
            fields: "spreadsheetId,sheets(properties(sheetId,title),developerMetadata,data(startRow,startColumn,rowMetadata.developerMetadata,rowData.values(userEnteredValue,userEnteredFormat(backgroundColorStyle,backgroundColor))))",
        });

        const gridSheets = gridData.sheets ?? [];
        const blockedDatesDetected: string[] = [];

        for (const [tabKey, datesInTab] of datesByMonthTab.entries()) {
            const tab = resolveMonthSheetTab(gridSheets, tabKey);
            if (!tab) {
                continue;
            }

            const structure = extractMonthSheetStructure(tab);
            if (structure.duplicateListingIds.has(params.listingId)) {
                if (integration.strictBookingPrecheck) {
                    throw new ApiError(
                        409,
                        "Lịch trực tuyến của chỗ nghỉ đang có xung đột cấu trúc tạm thời, vui lòng thử lại sau ít phút",
                    );
                }
                continue;
            }

            const rows = structure.rowsByListingId.get(params.listingId);
            if (!rows || rows.length !== 1) {
                continue;
            }

            const row = rows[0];
            for (const isoDate of datesInTab) {
                const day = Number(isoDate.slice(8, 10));
                const classified = classifySheetCalendarCell(row.cellsByDay.get(day));
                if (classified.state === "host_blocked") {
                    blockedDatesDetected.push(isoDate);

                    // Immediately persist newly discovered Sheet manual block into DB AvailabilityCalendar
                    const existingCal = await AvailabilityCalendar.findOne({
                        where: {
                            listingId: params.listingId,
                            date: isoDate,
                        },
                    });

                    if (existingCal) {
                        existingCal.isBlockedByHost = true;
                        existingCal.isAvailable = false;
                        existingCal.lockSource = existingCal.lockSource ?? "sheet_manual";
                        existingCal.lastSheetSyncedAt = new Date();
                        await existingCal.save();
                    } else {
                        await AvailabilityCalendar.create({
                            listingId: params.listingId,
                            date: isoDate,
                            isAvailable: false,
                            isBlockedByHost: true,
                            isBlockedByAdmin: false,
                            lockSource: "sheet_manual",
                            priceOverride: null,
                            minNightsOverride: null,
                            notes: classified.rawValue
                                ? sanitizeSheetTextValue(classified.rawValue, 180)
                                : "Khóa lịch từ Google Sheets",
                            syncRevision: 1,
                            lastSheetSyncedAt: new Date(),
                        });
                    }
                }
            }
        }

        if (blockedDatesDetected.length > 0) {
            await HostSheetChangeLog.create({
                hostUserId: params.hostUserId,
                integrationId: integration.integrationId,
                listingId: params.listingId,
                targetDate: blockedDatesDetected[0],
                direction: "sheet_to_app",
                action: "prebooking_live_block_detected",
                previousValue: "available",
                newValue: blockedDatesDetected.join(","),
            }).catch(() => undefined);

            throw new ApiError(
                409,
                "Selected dates include unavailable calendar days",
            );
        }

        return { verified: true };
    } catch (error) {
        if (error instanceof ApiError) {
            throw error;
        }

        const mapped = mapSheetsErrorToIntegrationStatus(error);
        integration.status = mapped.status;
        integration.lastErrorCode = mapped.code;
        integration.lastErrorMessage = mapped.message;
        await integration.save().catch(() => undefined);

        if (integration.strictBookingPrecheck) {
            throw new ApiError(
                503,
                "Tạm thời chưa xác minh được lịch trực tuyến của Chủ nhà, vui lòng thử lại sau ít phút",
            );
        }

        return { verified: false };
    }
};

export const getHostSheetSyncStatus = async (hostUserId: number) => {
    const env = getEnv();
    const [integration, serviceAccountEmail, hostListings] = await Promise.all([
        HostSheetIntegration.findOne({ where: { hostUserId } }),
        getConfiguredServiceAccountEmail().catch(() => null),
        Listing.findAll({
            where: { hostId: hostUserId },
            attributes: ["listingId", "title", "status", "deletedAt"],
            order: [["listingId", "ASC"]],
        }),
    ]);

    const activeListings = hostListings.filter((l) => !l.deletedAt);
    const archivedListings = hostListings.filter((l) => Boolean(l.deletedAt));
    const activeListingIds = activeListings.map((l) => l.listingId);
    const listingTitleMap = new Map<number, string>(
        hostListings.map((l) => [l.listingId, l.title]),
    );

    const now = new Date();
    const pendingHoldsCount =
        activeListingIds.length === 0
            ? 0
            : await Booking.count({
                  where: {
                      listingId: { [Op.in]: activeListingIds },
                      status: "pending_payment",
                      lockedUntil: { [Op.gt]: now },
                  },
              });

    const isConnected = Boolean(integration && integration.status !== "disconnected");

    if (!integration || !isConnected) {
        return {
            connected: false,
            serviceAccountEmail,
            defaultHostEditorEmail: env.googleSheetsDefaultHostEditorEmail,
            integration: null,
            stats: {
                totalListings: activeListings.length,
                archivedListings: archivedListings.length,
                pendingHoldsCount,
                openConflictsCount: 0,
                syncErrorsCount: 0,
                pendingJobsCount: 0,
            },
            listingsSummary: activeListings.map((l) => ({
                listingId: l.listingId,
                title: l.title,
                status: l.status,
            })),
            openWarnings: [],
            recentLogs: [],
        };
    }

    const [openConflictsCount, failedJobsCount, pendingJobsCount, openWarnings, recentLogs] =
        await Promise.all([
            HostSheetSyncConflict.count({
                where: {
                    hostUserId,
                    integrationId: integration.integrationId,
                    status: "open",
                },
            }),
            HostSheetSyncJob.count({
                where: {
                    hostUserId,
                    status: "failed",
                },
            }),
            HostSheetSyncJob.count({
                where: {
                    hostUserId,
                    status: "pending",
                },
            }),
            HostSheetSyncConflict.findAll({
                where: {
                    hostUserId,
                    integrationId: integration.integrationId,
                    status: "open",
                },
                order: [["createdAt", "DESC"]],
                limit: 10,
            }),
            HostSheetChangeLog.findAll({
                where: {
                    hostUserId,
                    integrationId: integration.integrationId,
                },
                order: [["detectedAt", "DESC"]],
                limit: 20,
            }),
        ]);

    const integrationHasError = integration.status !== "connected" ? 1 : 0;

    return {
        connected: true,
        serviceAccountEmail: integration.serviceAccountEmail ?? serviceAccountEmail,
        defaultHostEditorEmail: env.googleSheetsDefaultHostEditorEmail,
        integration: {
            integrationId: integration.integrationId,
            spreadsheetId: integration.spreadsheetId,
            spreadsheetUrl: integration.spreadsheetUrl,
            spreadsheetTitle: integration.spreadsheetTitle ?? "Lịch quản lý chỗ nghỉ",
            hostEditorEmail: integration.hostEditorEmail ?? env.googleSheetsDefaultHostEditorEmail,
            status: integration.status,
            autoSyncEnabled: Boolean(integration.autoSyncEnabled),
            strictBookingPrecheck: Boolean(integration.strictBookingPrecheck),
            canWriteVerified: Boolean(integration.canWriteVerified),
            permissionVerifiedAt: integration.permissionVerifiedAt,
            lastSyncedAt: integration.lastSyncedAt,
            lastPolledAt: integration.lastPolledAt,
            nextPollAt: integration.nextPollAt,
            lastErrorCode: integration.lastErrorCode,
            lastErrorMessage: integration.lastErrorMessage,
            consecutiveFailures: Number(integration.consecutiveFailures ?? 0),
        },
        stats: {
            totalListings: activeListings.length,
            archivedListings: archivedListings.length,
            pendingHoldsCount,
            openConflictsCount,
            syncErrorsCount: openConflictsCount + failedJobsCount + integrationHasError,
            pendingJobsCount,
        },
        listingsSummary: activeListings.map((l) => ({
            listingId: l.listingId,
            title: l.title,
            status: l.status,
        })),
        openWarnings: openWarnings.map((item) => ({
            conflictId: item.conflictId,
            listingId: item.listingId,
            listingTitle: item.listingId ? listingTitleMap.get(item.listingId) ?? `Căn #${item.listingId}` : null,
            bookingId: item.bookingId,
            conflictDate: item.conflictDate,
            monthTab: item.monthTab,
            conflictType: item.conflictType,
            severity: item.severity,
            status: item.status,
            description: item.description,
            canUndoBulkChange: item.conflictType === "bulk_row_block_warning",
            createdAt: item.createdAt,
        })),
        recentLogs: recentLogs.map((log) => ({
            logId: log.logId,
            listingId: log.listingId,
            listingTitle: log.listingId ? listingTitleMap.get(log.listingId) ?? `Căn #${log.listingId}` : null,
            targetDate: log.targetDate,
            direction: log.direction,
            action: log.action,
            previousValue: log.previousValue,
            newValue: log.newValue,
            detectedAt: log.detectedAt,
        })),
    };
};

export const listHostSheetConflicts = async (
    hostUserId: number,
    query: { status?: string; listingId?: number; page?: number; limit?: number },
) => {
    const page = Math.max(1, Number(query.page ?? 1));
    const limit = Math.min(50, Math.max(1, Number(query.limit ?? 20)));
    const where: Record<string, unknown> = { hostUserId };

    if (query.status && ["open", "auto_repaired", "resolved", "reverted"].includes(query.status)) {
        where.status = query.status;
    }
    if (query.listingId) {
        where.listingId = query.listingId;
    }

    const { rows, count } = await HostSheetSyncConflict.findAndCountAll({
        where,
        order: [["createdAt", "DESC"]],
        offset: (page - 1) * limit,
        limit,
    });

    return {
        items: rows,
        pagination: {
            page,
            limit,
            totalItems: count,
            totalPages: Math.max(1, Math.ceil(count / limit)),
        },
    };
};

export const resolveHostSheetConflict = async (
    hostUserId: number,
    conflictId: number,
    action: ResolveConflictAction,
) => {
    const conflict = await HostSheetSyncConflict.findByPk(conflictId);
    if (!conflict) {
        throw new ApiError(404, "Không tìm thấy cảnh báo xung đột");
    }

    // Strict BOLA check: Host B accessing Host A's conflict -> 403 Forbidden
    if (Number(conflict.hostUserId) !== Number(hostUserId)) {
        throw new ApiError(403, "Forbidden");
    }

    const now = new Date();
    const todayVN = getTodayInVietnamDateString(now);

    if (action === "undo_bulk_change") {
        if (conflict.conflictType !== "bulk_row_block_warning" || !conflict.listingId) {
            throw new ApiError(422, "Chỉ hỗ trợ hoàn tác cho cảnh báo khóa hàng loạt trên dòng");
        }

        const details = (conflict.detailsJson ?? {}) as {
            previousStates?: Array<{
                date: string;
                prevBlocked: boolean;
                prevIsAvailable: boolean;
                prevLockSource: string | null;
                prevNotes: string | null;
            }>;
        };

        const prevStates = Array.isArray(details.previousStates) ? details.previousStates : [];
        const datesToCheck = prevStates.map((s) => s.date);

        const activeBookings =
            datesToCheck.length === 0
                ? []
                : await Booking.findAll({
                      where: {
                          listingId: conflict.listingId,
                          ...buildActiveBookingStatusWhere(now),
                      },
                  });

        for (const state of prevStates) {
            if (state.prevBlocked || state.date < todayVN) {
                continue;
            }
            const hasActiveBooking = activeBookings.some(
                (b) => b.checkInDate <= state.date && state.date < b.checkOutDate,
            );
            if (hasActiveBooking) {
                continue;
            }

            const cal = await AvailabilityCalendar.findOne({
                where: {
                    listingId: conflict.listingId,
                    date: state.date,
                },
            });

            if (cal && !cal.isBlockedByAdmin) {
                cal.isBlockedByHost = false;
                cal.lockSource = state.prevLockSource;
                cal.notes = state.prevNotes;
                cal.isAvailable = true;
                cal.syncRevision = Number(cal.syncRevision ?? 0) + 1;

                if (
                    cal.priceOverride === null &&
                    cal.minNightsOverride === null &&
                    cal.notes === null
                ) {
                    await cal.destroy();
                } else {
                    await cal.save();
                }
            }

            // Update snapshot so next sync knows Sheet should be reset to empty White!
            await HostSheetCellSnapshot.update(
                {
                    lastSheetState: "empty",
                    lastSheetRawValue: null,
                    lastSheetBgHex: "#FFFFFF",
                    lastAppBlockedByHost: false,
                    lockSource: "none",
                    syncedAt: now,
                },
                {
                    where: {
                        listingId: conflict.listingId,
                        date: state.date,
                    },
                },
            );
        }

        conflict.status = "reverted";
        conflict.resolvedByUserId = hostUserId;
        conflict.resolvedAt = now;
        await conflict.save();

        await HostSheetChangeLog.create({
            hostUserId,
            integrationId: conflict.integrationId,
            listingId: conflict.listingId,
            direction: "app_to_sheet",
            action: "bulk_block_reverted",
            previousValue: "bulk_blocked",
            newValue: "reverted",
        });

        // Push clean White cells back to Sheet immediately (without re-importing the red cells!)
        await updateSheetCellsAfterBulkUndo(hostUserId, conflict.listingId, prevStates.map((s) => s.date));
        return getHostSheetSyncStatus(hostUserId);
    }

    if (action === "unlock_if_safe" && conflict.listingId && conflict.conflictDate) {
        const activeBookings = await Booking.findAll({
            where: {
                listingId: conflict.listingId,
                ...buildActiveBookingStatusWhere(now),
            },
        });
        const booked = activeBookings.some(
            (b) => b.checkInDate <= conflict.conflictDate! && conflict.conflictDate! < b.checkOutDate,
        );
        if (booked) {
            throw new ApiError(
                409,
                "Không thể mở khóa ngày đang có đơn đặt phòng hoặc giữ chỗ hợp lệ",
            );
        }

        const cal = await AvailabilityCalendar.findOne({
            where: {
                listingId: conflict.listingId,
                date: conflict.conflictDate,
            },
        });
        if (cal) {
            if (cal.isBlockedByAdmin) {
                throw new ApiError(409, "Ngày này đang bị Quản trị viên khóa");
            }
            cal.isBlockedByHost = false;
            cal.isAvailable = true;
            cal.lockSource = null;
            cal.syncRevision = Number(cal.syncRevision ?? 0) + 1;
            await cal.save();

            await HostSheetCellSnapshot.update(
                {
                    lastSheetState: "empty",
                    lastSheetRawValue: null,
                    lastSheetBgHex: "#FFFFFF",
                    lastAppBlockedByHost: false,
                    lockSource: "none",
                    syncedAt: now,
                },
                {
                    where: {
                        listingId: conflict.listingId,
                        date: conflict.conflictDate,
                    },
                },
            );

            await updateSheetCellsAfterBulkUndo(hostUserId, conflict.listingId, [conflict.conflictDate]);
        }
    }

    conflict.status = "resolved";
    conflict.resolvedByUserId = hostUserId;
    conflict.resolvedAt = now;
    await conflict.save();

    if (action === "repair_structure") {
        await runHostSheetSyncCycle(hostUserId, { mode: "initialize" }).catch(() => undefined);
    } else {
        await enqueueHostSheetSyncJob({
            hostUserId,
            jobType: "manual_sync",
            listingId: conflict.listingId,
            forceEvenIfPaused: true,
        });
    }

    return getHostSheetSyncStatus(hostUserId);
};

const updateSheetCellsAfterBulkUndo = async (
    hostUserId: number,
    listingId: number,
    revertedDates: string[],
) => {
    const integration = await HostSheetIntegration.findOne({ where: { hostUserId } });
    if (!integration || integration.status === "disconnected" || revertedDates.length === 0) {
        return;
    }

    try {
        const transport = getGoogleSheetsTransport();
        const tabKey = monthTabKeyFromIsoDate(revertedDates[0]);
        if (!tabKey) {
            return;
        }

        const meta = await transport.getSpreadsheet({
            spreadsheetId: integration.spreadsheetId,
            includeGridData: false,
            fields: "spreadsheetId,sheets(properties(sheetId,title),developerMetadata)",
        });
        const tab = resolveMonthSheetTab(meta.sheets ?? [], tabKey);
        if (!tab) {
            return;
        }

        const grid = await transport.getSpreadsheet({
            spreadsheetId: integration.spreadsheetId,
            ranges: [`${escapeSheetTitleForA1(tab.properties.title)}!A1:AG300`],
            includeGridData: true,
            fields: "spreadsheetId,sheets(properties(sheetId,title),developerMetadata,data(startRow,startColumn,rowMetadata.developerMetadata,rowData.values(userEnteredValue)))",
        });

        const gridTab = resolveMonthSheetTab(grid.sheets ?? [], tabKey);
        if (!gridTab) {
            return;
        }

        const structure = extractMonthSheetStructure(gridTab);
        const rows = structure.rowsByListingId.get(listingId);
        if (!rows || rows.length !== 1) {
            return;
        }

        const rowIndex = rows[0].rowIndex;
        const requests: Array<Record<string, unknown>> = [];
        const whiteCell = buildCalendarCellWriteData({
            text: "",
            bgColor: SHEET_COLORS.WHITE,
            bold: false,
            note: "",
        });

        for (const isoDate of revertedDates) {
            const day = Number(isoDate.slice(8, 10));
            const colIndex = SHEET_DAY_COLUMN_OFFSET + (day - 1);
            requests.push({
                updateCells: {
                    range: {
                        sheetId: gridTab.properties.sheetId,
                        startRowIndex: rowIndex,
                        endRowIndex: rowIndex + 1,
                        startColumnIndex: colIndex,
                        endColumnIndex: colIndex + 1,
                    },
                    rows: [{ values: [whiteCell.cell] }],
                    fields: whiteCell.fields,
                },
            });
        }

        if (requests.length > 0) {
            await transport.batchUpdate({
                spreadsheetId: integration.spreadsheetId,
                requests,
            });
        }
    } catch (error) {
        logger.warn("Failed to immediately clear reverted bulk cells on Google Sheets", {
            hostUserId,
            listingId,
            errorMessage: error instanceof Error ? error.message : String(error),
        });
    }
};

export const listHostSheetChangeLogs = async (
    hostUserId: number,
    query: { listingId?: number; search?: string; page?: number; limit?: number },
) => {
    const page = Math.max(1, Number(query.page ?? 1));
    const limit = Math.min(50, Math.max(1, Number(query.limit ?? 20)));

    const hostListings = await Listing.findAll({
        where: { hostId: hostUserId },
        attributes: ["listingId", "title"],
    });
    const titleMap = new Map<number, string>(hostListings.map((l) => [l.listingId, l.title]));

    const where: Record<string, unknown> = { hostUserId };
    if (query.listingId) {
        where.listingId = query.listingId;
    } else if (query.search?.trim()) {
        const needle = query.search.trim().toLowerCase();
        const matchingIds = hostListings
            .filter(
                (l) =>
                    String(l.listingId).includes(needle) ||
                    l.title.toLowerCase().includes(needle),
            )
            .map((l) => l.listingId);
        where.listingId = matchingIds.length > 0 ? { [Op.in]: matchingIds } : -1;
    }

    const { rows, count } = await HostSheetChangeLog.findAndCountAll({
        where,
        order: [["detectedAt", "DESC"]],
        offset: (page - 1) * limit,
        limit,
    });

    return {
        items: rows.map((log) => ({
            logId: log.logId,
            listingId: log.listingId,
            listingTitle: log.listingId ? titleMap.get(log.listingId) ?? `Căn #${log.listingId}` : null,
            targetDate: log.targetDate,
            direction: log.direction,
            action: log.action,
            previousValue: log.previousValue,
            newValue: log.newValue,
            detectedAt: log.detectedAt,
        })),
        pagination: {
            page,
            limit,
            totalItems: count,
            totalPages: Math.max(1, Math.ceil(count / limit)),
        },
    };
};
