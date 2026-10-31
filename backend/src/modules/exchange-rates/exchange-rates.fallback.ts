import type { ExchangeRateProviderAdapter, UpstreamQuoteResult } from "./exchange-rates.types";
import { UpstreamHttpError } from "./exchange-rates.types";
import type { FetchLike } from "./exchange-rates.provider";
import { parseRetryAfterHeader } from "./exchange-rates.provider";
import { validateUpstreamQuotes } from "./exchange-rates.validator";

/**
 * Secondary fallback FX adapter using ExchangeRate-API Open Access v6:
 * `GET https://open.er-api.com/v6/latest/VND`
 */
export class OpenErApiExchangeRateProvider implements ExchangeRateProviderAdapter {
    readonly name = "open-er-api";
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
        this.endpointUrl = options?.endpointUrl ?? "https://open.er-api.com/v6/latest/VND";
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
                `ExchangeRate-API request failed: ${error instanceof Error ? error.message : String(error)}`,
            );
        }

        const nowMs = this.nowFn();
        if (!response.ok) {
            const retryAfterSeconds = parseRetryAfterHeader(response.headers.get("retry-after"), nowMs);
            throw new UpstreamHttpError(this.name, `ExchangeRate-API returned HTTP ${response.status}`, {
                statusCode: response.status,
                retryAfterSeconds,
            });
        }

        const body: unknown = await response.json();
        if (!body || typeof body !== "object" || Array.isArray(body)) {
            throw new UpstreamHttpError(this.name, "ExchangeRate-API returned invalid JSON payload");
        }

        const record = body as Record<string, unknown>;
        if (record.result !== undefined && record.result !== "success") {
            throw new UpstreamHttpError(this.name, `ExchangeRate-API reported failure result: ${String(record.result)}`);
        }

        const baseCode = String(record.base_code ?? record.base ?? "").toUpperCase();
        if (baseCode !== "VND") {
            throw new UpstreamHttpError(this.name, `ExchangeRate-API base_code is "${baseCode}", expected "VND"`);
        }

        const rates = record.rates;
        if (!rates || typeof rates !== "object" || Array.isArray(rates)) {
            throw new UpstreamHttpError(this.name, "ExchangeRate-API payload missing rates object");
        }
        const ratesRec = rates as Record<string, unknown>;

        const rawUpdatedAt = record.time_last_update_unix ?? record.time_last_update_utc;

        return validateUpstreamQuotes(
            {
                source: this.name,
                sourceUpdatedAt: rawUpdatedAt,
                usdRate: ratesRec.USD,
                krwRate: ratesRec.KRW,
            },
            nowMs,
        );
    }
}
