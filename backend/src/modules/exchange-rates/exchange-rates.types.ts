export type SupportedQuoteCurrency = "USD" | "KRW";

export type ExchangeRatePayload = {
    schemaVersion: "1.0";
    baseCurrency: "VND";
    rates: {
        VND: "1";
        USD: string;
        KRW: string;
    };
    source: string;
    sourceUpdatedAt: string;
    fetchedAt: string;
    isStale: boolean;
    displayOnly: true;
};

export type UpstreamQuoteResult = {
    source: string;
    sourceUpdatedAt: string;
    rates: {
        USD: string;
        KRW: string;
    };
};

export interface ExchangeRateProviderAdapter {
    readonly name: string;
    fetchVndQuotes(signal?: AbortSignal): Promise<UpstreamQuoteResult>;
}

export class UpstreamHttpError extends Error {
    readonly statusCode?: number;
    readonly retryAfterSeconds?: number;
    readonly providerName: string;

    constructor(
        providerName: string,
        message: string,
        options?: {
            statusCode?: number;
            retryAfterSeconds?: number;
        },
    ) {
        super(message);
        this.name = "UpstreamHttpError";
        this.providerName = providerName;
        this.statusCode = options?.statusCode;
        this.retryAfterSeconds = options?.retryAfterSeconds;
    }
}

export class ExchangeRatesUnavailableError extends Error {
    readonly statusCode = 503;
    readonly code = "EXCHANGE_RATES_UNAVAILABLE";
    readonly retryAfterSeconds?: number;
    readonly details?: Record<string, unknown>;

    constructor(
        message = "Exchange rates are temporarily unavailable. Please display prices in VND.",
        options?: {
            retryAfterSeconds?: number;
            details?: Record<string, unknown>;
        },
    ) {
        super(message);
        this.name = "ExchangeRatesUnavailableError";
        this.retryAfterSeconds = options?.retryAfterSeconds;
        this.details = options?.details;
    }
}
