import type { ExchangeRateProviderAdapter, UpstreamQuoteResult } from "./exchange-rates.types";
import { UpstreamHttpError } from "./exchange-rates.types";
import { normalizeIsoUtcTimestamp, validateUpstreamQuotes } from "./exchange-rates.validator";

export const parseRetryAfterHeader = (headerValue: string | null, nowMs = Date.now()): number | undefined => {
    if (!headerValue) {
        return undefined;
    }
    const trimmed = headerValue.trim();
    if (!trimmed) {
        return undefined;
    }
    const seconds = Number.parseInt(trimmed, 10);
    if (Number.isFinite(seconds) && seconds >= 0 && /^\d+$/.test(trimmed)) {
        return seconds;
    }
    const dateMs = Date.parse(trimmed);
    if (Number.isFinite(dateMs) && dateMs > nowMs) {
        return Math.ceil((dateMs - nowMs) / 1000);
    }
    return undefined;
};

export type FetchLike = typeof fetch;

/**
 * Primary upstream FX adapter using ECB-backed Frankfurter API v2:
 * `GET https://api.frankfurter.dev/v2/rates?base=VND&quotes=USD,KRW`
 */
export class FrankfurterExchangeRateProvider implements ExchangeRateProviderAdapter {
    readonly name = "frankfurter";
    private readonly endpointUrl: string;
    private readonly timeoutMs: number;
    private readonly fetchImpl: FetchLike;
    private readonly nowFn: () => number;

    constructor(options?: {
        endpointUrl?: string;
        timeoutMs?: number;
        fetchImpl?: FetchLike;
        nowFn?: () => number;
    }) {
        this.endpointUrl = options?.endpointUrl ?? "https://api.frankfurter.dev/v2/rates?base=VND&quotes=USD,KRW";
        this.timeoutMs = options?.timeoutMs ?? 5000;
        this.fetchImpl = options?.fetchImpl ?? fetch;
        this.nowFn = options?.nowFn ?? Date.now;
    }

    async fetchVndQuotes(externalSignal?: AbortSignal): Promise<UpstreamQuoteResult> {
        const timeoutSignal = AbortSignal.timeout(this.timeoutMs);
        const signal = externalSignal ? AbortSignal.any([externalSignal, timeoutSignal]) : timeoutSignal;

        let response: Response;
        try {
            response = await this.fetchImpl(this.endpointUrl, {
                method: "GET",
                headers: {
                    Accept: "application/json",
                },
                signal,
            });
        } catch (error) {
            throw new UpstreamHttpError(
                this.name,
                `Frankfurter request failed: ${error instanceof Error ? error.message : String(error)}`,
            );
        }

        const nowMs = this.nowFn();
        if (!response.ok) {
            const retryAfterSeconds = parseRetryAfterHeader(response.headers.get("retry-after"), nowMs);
            throw new UpstreamHttpError(this.name, `Frankfurter returned HTTP ${response.status}`, {
                statusCode: response.status,
                retryAfterSeconds,
            });
        }

        const body: unknown = await response.json();

        // Frankfurter v2 returns a JSON array:
        // [{"date":"2026-10-31","base":"VND","quote":"KRW","rate":0.051872},{"date":"2026-10-30","base":"VND","quote":"USD","rate":0.000038813}]
        if (Array.isArray(body)) {
            let usdRate: unknown;
            let krwRate: unknown;
            let oldestSourceMs: number | null = null;

            for (const entry of body) {
                if (!entry || typeof entry !== "object") {
                    continue;
                }
                const item = entry as Record<string, unknown>;
                const base = String(item.base ?? "").toUpperCase();
                const quote = String(item.quote ?? "").toUpperCase();
                if (base !== "VND") {
                    continue;
                }
                if (quote === "USD" || quote === "KRW") {
                    const normalizedIso = normalizeIsoUtcTimestamp(item.date, nowMs);
                    if (!normalizedIso) {
                        throw new UpstreamHttpError(this.name, `Frankfurter entry for ${quote} has invalid date`);
                    }
                    const ts = Date.parse(normalizedIso);
                    if (oldestSourceMs === null || ts < oldestSourceMs) {
                        oldestSourceMs = ts;
                    }
                    if (quote === "USD") {
                        usdRate = item.rate;
                    } else {
                        krwRate = item.rate;
                    }
                }
            }

            if (oldestSourceMs === null) {
                throw new UpstreamHttpError(this.name, "Frankfurter array contained no valid VND quotes");
            }

            return validateUpstreamQuotes(
                {
                    source: this.name,
                    sourceUpdatedAt: new Date(oldestSourceMs).toISOString(),
                    usdRate,
                    krwRate,
                },
                nowMs,
            );
        }

        // Support object shape (`{ base: "VND", date: "...", rates: { USD, KRW } }`) if returned
        if (body && typeof body === "object") {
            const record = body as Record<string, unknown>;
            if (String(record.base ?? "").toUpperCase() !== "VND") {
                throw new UpstreamHttpError(this.name, "Frankfurter response base currency is not VND");
            }
            const rates = record.rates as Record<string, unknown> | undefined;
            return validateUpstreamQuotes(
                {
                    source: this.name,
                    sourceUpdatedAt: record.date,
                    usdRate: rates?.USD,
                    krwRate: rates?.KRW,
                },
                nowMs,
            );
        }

        throw new UpstreamHttpError(this.name, "Frankfurter returned unexpected JSON shape");
    }
}
