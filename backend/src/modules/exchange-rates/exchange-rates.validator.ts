import type { ExchangeRatePayload, UpstreamQuoteResult } from "./exchange-rates.types";

// Sanity bounds for 1 VND -> target currency:
// USD: 1 USD between 5,000 VND (0.0002) and 100,000 VND (0.00001)
const MIN_USD_PER_VND = 0.00001;
const MAX_USD_PER_VND = 0.0002;
// KRW: 1 KRW between 4 VND (0.25) and 100 VND (0.01)
const MIN_KRW_PER_VND = 0.01;
const MAX_KRW_PER_VND = 0.25;

// Sudden swing threshold vs previous verified snapshot triggering cross-provider verification (FX-26)
const MAX_UNVERIFIED_RELATIVE_JUMP = 0.25;
const CROSS_PROVIDER_MAX_DIVERGENCE = 0.10;

const MAX_FUTURE_DRIFT_MS = 48 * 60 * 60 * 1000;
const MIN_VALID_TIMESTAMP_MS = Date.UTC(2020, 0, 1);

/**
 * Converts a finite positive number or numeric string (including scientific notation like `3.9e-5`)
 * into a canonical plain decimal string without scientific notation (`"0.000039"`).
 */
export const normalizePositiveRateDecimal = (raw: unknown): string | null => {
    if (raw === null || raw === undefined || typeof raw === "boolean" || typeof raw === "object") {
        return null;
    }

    const str = typeof raw === "number" ? (Number.isFinite(raw) ? raw.toString() : "") : String(raw).trim();
    if (!str) {
        return null;
    }

    const match = /^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(str);
    if (!match) {
        return null;
    }

    const sign = match[1];
    if (sign === "-") {
        return null;
    }

    const wholeDigits = match[2] ?? "0";
    const fracDigits = match[3] ?? "";
    const exp = match[4] !== undefined ? Number.parseInt(match[4], 10) : 0;
    if (!Number.isInteger(exp) || Math.abs(exp) > 100) {
        return null;
    }

    const combined = `${wholeDigits}${fracDigits}`.replace(/^0+/, "");
    if (!combined) {
        // Zero value
        return null;
    }

    const scale = fracDigits.length - exp;
    if (scale <= 0) {
        return `${combined}${"0".repeat(-scale)}`;
    }

    if (combined.length <= scale) {
        const padded = combined.padStart(scale, "0").replace(/0+$/, "");
        return padded ? `0.${padded}` : null;
    }

    const splitAt = combined.length - scale;
    const intPart = combined.slice(0, splitAt);
    const decPart = combined.slice(splitAt).replace(/0+$/, "");
    return decPart ? `${intPart}.${decPart}` : intPart;
};

export const normalizeIsoUtcTimestamp = (raw: unknown, nowMs = Date.now()): string | null => {
    if (typeof raw !== "string" && typeof raw !== "number") {
        return null;
    }

    let parsedMs: number;
    if (typeof raw === "number") {
        if (!Number.isFinite(raw)) {
            return null;
        }
        // Distinguish seconds vs milliseconds
        parsedMs = raw < 1e12 ? Math.round(raw * 1000) : Math.round(raw);
    } else {
        const trimmed = raw.trim();
        if (!trimmed) {
            return null;
        }
        // Date-only `YYYY-MM-DD` -> treat as UTC midnight
        if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
            parsedMs = Date.parse(`${trimmed}T00:00:00.000Z`);
        } else {
            parsedMs = Date.parse(trimmed);
        }
    }

    if (!Number.isFinite(parsedMs)) {
        return null;
    }

    if (parsedMs < MIN_VALID_TIMESTAMP_MS || parsedMs > nowMs + MAX_FUTURE_DRIFT_MS) {
        return null;
    }

    return new Date(parsedMs).toISOString();
};

export const validateUpstreamQuotes = (
    candidate: {
        source: unknown;
        sourceUpdatedAt: unknown;
        usdRate: unknown;
        krwRate: unknown;
    },
    nowMs = Date.now(),
): UpstreamQuoteResult => {
    const source = typeof candidate.source === "string" ? candidate.source.trim() : "";
    if (!source) {
        throw new Error("FX validation failed: missing provider source");
    }

    const sourceUpdatedAt = normalizeIsoUtcTimestamp(candidate.sourceUpdatedAt, nowMs);
    if (!sourceUpdatedAt) {
        throw new Error(`FX validation failed: invalid sourceUpdatedAt from ${source}`);
    }

    const usdDecimal = normalizePositiveRateDecimal(candidate.usdRate);
    const krwDecimal = normalizePositiveRateDecimal(candidate.krwRate);
    if (!usdDecimal || !krwDecimal) {
        throw new Error(`FX validation failed: missing or non-positive USD/KRW rate from ${source}`);
    }

    const usdNumeric = Number(usdDecimal);
    const krwNumeric = Number(krwDecimal);

    if (!Number.isFinite(usdNumeric) || usdNumeric < MIN_USD_PER_VND || usdNumeric > MAX_USD_PER_VND) {
        throw new Error(`FX validation failed: USD rate ${usdDecimal} outside sane VND bounds`);
    }

    if (!Number.isFinite(krwNumeric) || krwNumeric < MIN_KRW_PER_VND || krwNumeric > MAX_KRW_PER_VND) {
        throw new Error(`FX validation failed: KRW rate ${krwDecimal} outside sane VND bounds`);
    }

    return {
        source,
        sourceUpdatedAt,
        rates: {
            USD: usdDecimal,
            KRW: krwDecimal,
        },
    };
};

export const hasSuspiciousRateJump = (
    previous: Pick<ExchangeRatePayload, "rates">,
    next: Pick<UpstreamQuoteResult, "rates">,
    threshold = MAX_UNVERIFIED_RELATIVE_JUMP,
): boolean => {
    const prevUsd = Number(previous.rates.USD);
    const nextUsd = Number(next.rates.USD);
    const prevKrw = Number(previous.rates.KRW);
    const nextKrw = Number(next.rates.KRW);

    if (!Number.isFinite(prevUsd) || !Number.isFinite(prevKrw) || prevUsd <= 0 || prevKrw <= 0) {
        return false;
    }

    const usdRelDiff = Math.abs(nextUsd - prevUsd) / prevUsd;
    const krwRelDiff = Math.abs(nextKrw - prevKrw) / prevKrw;
    return usdRelDiff > threshold || krwRelDiff > threshold;
};

export const areQuotesConsistent = (
    primary: Pick<UpstreamQuoteResult, "rates">,
    secondary: Pick<UpstreamQuoteResult, "rates">,
    maxDivergence = CROSS_PROVIDER_MAX_DIVERGENCE,
): boolean => {
    const pUsd = Number(primary.rates.USD);
    const sUsd = Number(secondary.rates.USD);
    const pKrw = Number(primary.rates.KRW);
    const sKrw = Number(secondary.rates.KRW);

    if (sUsd <= 0 || sKrw <= 0) {
        return false;
    }

    const usdDiff = Math.abs(pUsd - sUsd) / sUsd;
    const krwDiff = Math.abs(pKrw - sKrw) / sKrw;
    return usdDiff <= maxDivergence && krwDiff <= maxDivergence;
};

export const parseStoredExchangeRateSnapshot = (
    raw: unknown,
    nowMs = Date.now(),
): ExchangeRatePayload | null => {
    try {
        const obj = typeof raw === "string" ? (JSON.parse(raw) as unknown) : raw;
        if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
            return null;
        }
        const record = obj as Record<string, unknown>;
        if (record.baseCurrency !== "VND" || record.displayOnly !== true) {
            return null;
        }
        const rates = record.rates;
        if (!rates || typeof rates !== "object" || Array.isArray(rates)) {
            return null;
        }
        const ratesRec = rates as Record<string, unknown>;
        if (String(ratesRec.VND ?? "1") !== "1") {
            return null;
        }

        const fetchedAt = normalizeIsoUtcTimestamp(record.fetchedAt, nowMs);
        if (!fetchedAt) {
            return null;
        }

        const validatedQuotes = validateUpstreamQuotes(
            {
                source: record.source,
                sourceUpdatedAt: record.sourceUpdatedAt,
                usdRate: ratesRec.USD,
                krwRate: ratesRec.KRW,
            },
            nowMs,
        );

        return {
            schemaVersion: "1.0",
            baseCurrency: "VND",
            rates: {
                VND: "1",
                USD: validatedQuotes.rates.USD,
                KRW: validatedQuotes.rates.KRW,
            },
            source: validatedQuotes.source,
            sourceUpdatedAt: validatedQuotes.sourceUpdatedAt,
            fetchedAt,
            isStale: Boolean(record.isStale),
            displayOnly: true,
        };
    } catch {
        return null;
    }
};
