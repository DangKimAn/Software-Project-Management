/**
 * Shared date/time helpers for Vietnam timezone (UTC+7).
 *
 * Every date comparison in this project that needs "today" should use
 * {@link getTodayInVietnamDateString} so that the boundary is consistent
 * regardless of the server's local timezone.
 */

const VIETNAM_UTC_OFFSET_MS = 7 * 60 * 60 * 1000;

/**
 * Returns the current date as `YYYY-MM-DD` in Vietnam timezone (UTC+7).
 *
 * @param now – injectable clock for testing; defaults to `new Date()`.
 */
export const getTodayInVietnamDateString = (now = new Date()): string =>
    new Date(now.getTime() + VIETNAM_UTC_OFFSET_MS).toISOString().slice(0, 10);
