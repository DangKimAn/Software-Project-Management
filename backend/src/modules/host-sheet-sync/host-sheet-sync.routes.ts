import express from "express";
import { body, param, query } from "express-validator";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireHostOnly } from "../../middlewares/require-role.middleware";
import {
    connectHostSpreadsheetHandler,
    disconnectHostSpreadsheetHandler,
    getHostSheetSyncStatusHandler,
    initializeHostStandardCalendarHandler,
    listHostSheetChangeLogsHandler,
    listHostSheetConflictsHandler,
    resolveHostSheetConflictHandler,
    syncHostSpreadsheetNowHandler,
    updateHostSheetSettingsHandler,
    verifyHostSpreadsheetPermissionsHandler,
} from "./host-sheet-sync.controller";

const router = express.Router();

// Every host sheet sync endpoint strictly requires authenticated Host role (401 unauthenticated, 403 non-host)
router.use(authenticate, requireHostOnly);

router.get("/status", getHostSheetSyncStatusHandler);

router.post(
    "/connect",
    [
        body("spreadsheetUrlOrId")
            .isString()
            .trim()
            .notEmpty()
            .withMessage("spreadsheetUrlOrId is required")
            .isLength({ max: 512 })
            .withMessage("spreadsheetUrlOrId is too long"),
        body("hostEditorEmail")
            .optional({ nullable: true })
            .custom((value) => {
                if (value === null || value === "") {
                    return true;
                }
                return typeof value === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
            })
            .withMessage("hostEditorEmail must be a valid email"),
        body("autoSyncEnabled")
            .optional()
            .isBoolean()
            .withMessage("autoSyncEnabled must be boolean")
            .toBoolean(),
        body("strictBookingPrecheck")
            .optional()
            .isBoolean()
            .withMessage("strictBookingPrecheck must be boolean")
            .toBoolean(),
        body("initializeImmediately")
            .optional()
            .isBoolean()
            .withMessage("initializeImmediately must be boolean")
            .toBoolean(),
    ],
    connectHostSpreadsheetHandler,
);

router.post("/verify-permissions", verifyHostSpreadsheetPermissionsHandler);

router.post("/init-calendar", initializeHostStandardCalendarHandler);

router.post("/sync-now", syncHostSpreadsheetNowHandler);

router.patch(
    "/settings",
    [
        body("hostEditorEmail")
            .optional({ nullable: true })
            .custom((value) => {
                if (value === null || value === "") {
                    return true;
                }
                return typeof value === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
            })
            .withMessage("hostEditorEmail must be a valid email"),
        body("autoSyncEnabled")
            .optional()
            .isBoolean()
            .withMessage("autoSyncEnabled must be boolean")
            .toBoolean(),
        body("strictBookingPrecheck")
            .optional()
            .isBoolean()
            .withMessage("strictBookingPrecheck must be boolean")
            .toBoolean(),
    ],
    updateHostSheetSettingsHandler,
);

router.delete("/disconnect", disconnectHostSpreadsheetHandler);

router.get(
    "/conflicts",
    [
        query("status")
            .optional()
            .isIn(["open", "auto_repaired", "resolved", "reverted"])
            .withMessage("status is invalid"),
        query("listingId").optional().isInt({ min: 1 }).toInt(),
        query("page").optional().isInt({ min: 1 }).toInt(),
        query("limit").optional().isInt({ min: 1, max: 50 }).toInt(),
    ],
    listHostSheetConflictsHandler,
);

router.post(
    "/conflicts/:conflictId/resolve",
    [
        param("conflictId").isInt({ min: 1 }).withMessage("conflictId must be positive integer").toInt(),
        body("action")
            .isIn(["keep_locked", "unlock_if_safe", "undo_bulk_change", "repair_structure"])
            .withMessage("action is invalid"),
    ],
    resolveHostSheetConflictHandler,
);

router.get(
    "/logs",
    [
        query("listingId").optional().isInt({ min: 1 }).toInt(),
        query("search").optional().isString().trim().isLength({ max: 120 }),
        query("page").optional().isInt({ min: 1 }).toInt(),
        query("limit").optional().isInt({ min: 1, max: 50 }).toInt(),
    ],
    listHostSheetChangeLogsHandler,
);

export default router;

