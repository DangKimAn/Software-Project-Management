import fs from "fs/promises";
import path from "path";

import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import { OpenErApiExchangeRateProvider } from "./exchange-rates.fallback";
import { FrankfurterExchangeRateProvider } from "./exchange-rates.provider";
import type {
    ExchangeRatePayload,
    ExchangeRateProviderAdapter,
    UpstreamQuoteResult,
} from "./exchange-rates.types";
import { ExchangeRatesUnavailableError, UpstreamHttpError } from "./exchange-rates.types";
import {
    areQuotesConsistent,
    hasSuspiciousRateJump,
    parseStoredExchangeRateSnapshot,
} from "./exchange-rates.validator";

export type ExchangeRatesServiceOptions = {
    enabled?: boolean;
    primaryProvider?: ExchangeRateProviderAdapter;
    fallbackProvider?: ExchangeRateProviderAdapter;
    snapshotFilePath?: string;
    cacheTtlMs?: number;
    freshMaxAgeMs?: number;
    maxStaleAgeMs?: number;
    nowFn?: () => number;
    jitterFn?: () => number;
};

const BASE_BACKOFF_MS = 30_000;
const MAX_BACKOFF_MS = 15 * 60_000;

export class ExchangeRatesService {
    private readonly enabled: boolean;
    private readonly primaryProvider: ExchangeRateProviderAdapter;
    private readonly fallbackProvider: ExchangeRateProviderAdapter;
    private readonly snapshotFilePath: string;
    private readonly cacheTtlMs: number;
    private readonly freshMaxAgeMs: number;
    private readonly maxStaleAgeMs: number;
    private readonly nowFn: () => number;
    private readonly jitterFn: () => number;

    private cachedSnapshot: ExchangeRatePayload | null = null;
    private diskHydrated = false;
    private inFlightRefresh: Promise<ExchangeRatePayload> | null = null;

    private primaryCooldownUntilMs = 0;
    private primaryFailureCount = 0;
    private fallbackCooldownUntilMs = 0;
    private fallbackFailureCount = 0;

    constructor(options?: ExchangeRatesServiceOptions) {
        const env = getEnv();
        this.nowFn = options?.nowFn ?? Date.now;
        this.jitterFn = options?.jitterFn ?? Math.random;
        this.enabled = options?.enabled ?? env.exchangeRateEnabled;
        this.cacheTtlMs = options?.cacheTtlMs ?? env.exchangeRateCacheTtlMs;
        this.freshMaxAgeMs = options?.freshMaxAgeMs ?? env.exchangeRateFreshMaxAgeMs;
        this.maxStaleAgeMs = options?.maxStaleAgeMs ?? env.exchangeRateMaxStaleAgeMs;
        this.snapshotFilePath = path.resolve(
            process.cwd(),
            options?.snapshotFilePath ?? env.exchangeRateSnapshotPath,
        );

        const defaultPrimary = new FrankfurterExchangeRateProvider({
            timeoutMs: env.exchangeRateTimeoutMs,
            nowFn: this.nowFn,
        });
        const defaultSecondary = new OpenErApiExchangeRateProvider({
            timeoutMs: env.exchangeRateTimeoutMs,
            nowFn: this.nowFn,
        });

        const preferSecondary = env.exchangeRateProvider.toLowerCase() === "open-er-api";
        this.primaryProvider = options?.primaryProvider ?? (preferSecondary ? defaultSecondary : defaultPrimary);
        this.fallbackProvider = options?.fallbackProvider ?? (preferSecondary ? defaultPrimary : defaultSecondary);
    }

    async getExchangeRates(): Promise<ExchangeRatePayload> {
        if (!this.enabled) {
            throw new ExchangeRatesUnavailableError(
                "Exchange rate display service is currently disabled. Displaying prices in VND.",
            );
        }

        await this.ensureDiskHydrated();
        const nowMs = this.nowFn();
        const usable = this.getUsableCachedSnapshot(nowMs);

        if (usable) {
            const fetchAgeMs = Math.max(0, nowMs - Date.parse(usable.fetchedAt));
            if (fetchAgeMs >= this.cacheTtlMs) {
                // Stale-while-revalidate: serve verified snapshot immediately while refreshing in background
                void this.triggerSingleFlightRefresh().catch((error: unknown) => {
                    logger.warn("Background FX revalidation failed; continuing with cached snapshot", {
                        error: error instanceof Error ? error.message : String(error),
                    });
                });
            }
            return usable;
        }

        return this.triggerSingleFlightRefresh();
    }

    private getUsableCachedSnapshot(nowMs: number): ExchangeRatePayload | null {
        if (!this.cachedSnapshot) {
            return null;
        }
        const sourceAgeMs = nowMs - Date.parse(this.cachedSnapshot.sourceUpdatedAt);
        if (!Number.isFinite(sourceAgeMs) || sourceAgeMs > this.maxStaleAgeMs) {
            return null;
        }
        const isStale = this.cachedSnapshot.isStale || sourceAgeMs > this.freshMaxAgeMs;
        return {
            ...this.cachedSnapshot,
            isStale,
        };
    }

    private async ensureDiskHydrated(): Promise<void> {
        if (this.diskHydrated) {
            return;
        }
        this.diskHydrated = true;

        try {
            const content = await fs.readFile(this.snapshotFilePath, "utf8");
            const parsed = parseStoredExchangeRateSnapshot(content, this.nowFn());
            if (parsed) {
                this.cachedSnapshot = parsed;
            } else {
                logger.warn("Ignored malformed FX snapshot file on disk", {
                    snapshotFilePath: this.snapshotFilePath,
                });
            }
        } catch (error) {
            const code = (error as NodeJS.ErrnoException | undefined)?.code;
            if (code !== "ENOENT") {
                logger.warn("Could not read FX snapshot file from disk", {
                    snapshotFilePath: this.snapshotFilePath,
                    error: error instanceof Error ? error.message : String(error),
                });
            }
        }
    }

    private async persistSnapshotToDisk(snapshot: ExchangeRatePayload): Promise<void> {
        try {
            const dir = path.dirname(this.snapshotFilePath);
            await fs.mkdir(dir, { recursive: true });
            const tempPath = `${this.snapshotFilePath}.${process.pid}.${this.nowFn()}.tmp`;
            await fs.writeFile(tempPath, JSON.stringify(snapshot, null, 2), "utf8");
            await fs.rename(tempPath, this.snapshotFilePath);
        } catch (error) {
            logger.warn("Failed to persist FX snapshot to disk", {
                snapshotFilePath: this.snapshotFilePath,
                error: error instanceof Error ? error.message : String(error),
            });
        }
    }

    private triggerSingleFlightRefresh(): Promise<ExchangeRatePayload> {
        if (this.inFlightRefresh) {
            return this.inFlightRefresh;
        }

        const promise = this.performRefresh().finally(() => {
            if (this.inFlightRefresh === promise) {
                this.inFlightRefresh = null;
            }
        });
        this.inFlightRefresh = promise;
        return promise;
    }

    private computeBackoffMs(error: unknown, failureCount: number): number {
        const jitterMs = Math.floor(this.jitterFn() * 5_000);
        if (error instanceof UpstreamHttpError && error.retryAfterSeconds !== undefined) {
            const retryMs = Math.max(error.retryAfterSeconds * 1000, BASE_BACKOFF_MS);
            return Math.min(retryMs + jitterMs, 60 * 60_000);
        }
        const expShift = Math.min(Math.max(failureCount - 1, 0), 5);
        return Math.min(BASE_BACKOFF_MS * (1 << expShift), MAX_BACKOFF_MS) + jitterMs;
    }

    private buildPayloadFromQuotes(quotes: UpstreamQuoteResult, nowMs: number): ExchangeRatePayload {
        const sourceAgeMs = Math.max(0, nowMs - Date.parse(quotes.sourceUpdatedAt));
        return {
            schemaVersion: "1.0",
            baseCurrency: "VND",
            rates: {
                VND: "1",
                USD: quotes.rates.USD,
                KRW: quotes.rates.KRW,
            },
            source: quotes.source,
            sourceUpdatedAt: quotes.sourceUpdatedAt,
            fetchedAt: new Date(nowMs).toISOString(),
            isStale: sourceAgeMs > this.freshMaxAgeMs,
            displayOnly: true,
        };
    }

    private async performRefresh(): Promise<ExchangeRatePayload> {
        const nowMs = this.nowFn();
        const previousSnapshot = this.cachedSnapshot;
        let lastErrorMessage = "All upstream FX providers failed";

        // 1. Try Primary Provider unless currently cooling down (e.g. HTTP 429)
        if (nowMs >= this.primaryCooldownUntilMs) {
            try {
                const primaryQuotes = await this.primaryProvider.fetchVndQuotes();

                if (previousSnapshot && hasSuspiciousRateJump(previousSnapshot, primaryQuotes)) {
                    logger.warn("Detected >25% FX jump from primary provider; cross-verifying with fallback", {
                        primarySource: primaryQuotes.source,
                        previousRates: previousSnapshot.rates,
                        candidateRates: primaryQuotes.rates,
                    });

                    let verifiedQuotes: UpstreamQuoteResult | null = null;
                    try {
                        const secondaryQuotes = await this.fallbackProvider.fetchVndQuotes();
                        this.fallbackFailureCount = 0;
                        this.fallbackCooldownUntilMs = 0;

                        if (areQuotesConsistent(primaryQuotes, secondaryQuotes)) {
                            verifiedQuotes = primaryQuotes;
                        } else if (!hasSuspiciousRateJump(previousSnapshot, secondaryQuotes)) {
                            logger.warn("Primary FX jump rejected; fallback provider remained stable", {
                                fallbackSource: secondaryQuotes.source,
                            });
                            verifiedQuotes = secondaryQuotes;
                        }
                    } catch (crossCheckError) {
                        logger.warn("Fallback FX cross-check failed during primary spike verification", {
                            error:
                                crossCheckError instanceof Error ? crossCheckError.message : String(crossCheckError),
                        });
                    }

                    if (!verifiedQuotes) {
                        throw new Error("Rejected unverified >25% FX rate anomaly from primary provider");
                    }

                    this.primaryFailureCount = 0;
                    this.primaryCooldownUntilMs = 0;
                    const payload = this.buildPayloadFromQuotes(verifiedQuotes, this.nowFn());
                    this.cachedSnapshot = payload;
                    await this.persistSnapshotToDisk(payload);
                    return this.getUsableCachedSnapshot(this.nowFn()) ?? payload;
                }

                this.primaryFailureCount = 0;
                this.primaryCooldownUntilMs = 0;
                const payload = this.buildPayloadFromQuotes(primaryQuotes, this.nowFn());
                this.cachedSnapshot = payload;
                await this.persistSnapshotToDisk(payload);
                return this.getUsableCachedSnapshot(this.nowFn()) ?? payload;
            } catch (primaryError) {
                this.primaryFailureCount += 1;
                const backoffMs = this.computeBackoffMs(primaryError, this.primaryFailureCount);
                this.primaryCooldownUntilMs = this.nowFn() + backoffMs;
                lastErrorMessage = primaryError instanceof Error ? primaryError.message : String(primaryError);
                logger.warn("Primary FX provider failed; attempting fallback or cached snapshot", {
                    provider: this.primaryProvider.name,
                    backoffMs,
                    error: lastErrorMessage,
                });
            }
        }

        // 2. Try Fallback Provider unless currently cooling down
        const afterPrimaryMs = this.nowFn();
        if (afterPrimaryMs >= this.fallbackCooldownUntilMs) {
            try {
                const fallbackQuotes = await this.fallbackProvider.fetchVndQuotes();

                if (previousSnapshot && hasSuspiciousRateJump(previousSnapshot, fallbackQuotes)) {
                    throw new Error("Rejected unverified >25% FX rate anomaly from fallback provider");
                }

                this.fallbackFailureCount = 0;
                this.fallbackCooldownUntilMs = 0;
                const payload = this.buildPayloadFromQuotes(fallbackQuotes, this.nowFn());
                this.cachedSnapshot = payload;
                await this.persistSnapshotToDisk(payload);
                return this.getUsableCachedSnapshot(this.nowFn()) ?? payload;
            } catch (fallbackError) {
                this.fallbackFailureCount += 1;
                const backoffMs = this.computeBackoffMs(fallbackError, this.fallbackFailureCount);
                this.fallbackCooldownUntilMs = this.nowFn() + backoffMs;
                lastErrorMessage = fallbackError instanceof Error ? fallbackError.message : String(fallbackError);
                logger.warn("Fallback FX provider failed", {
                    provider: this.fallbackProvider.name,
                    backoffMs,
                    error: lastErrorMessage,
                });
            }
        }

        // 3. Degrade gracefully to usable cached snapshot (<= 7d old) if available
        const finalNowMs = this.nowFn();
        const usableFallback = this.getUsableCachedSnapshot(finalNowMs);
        if (usableFallback) {
            return {
                ...usableFallback,
                isStale: true,
            };
        }

        // 4. Snapshot missing or > 7 days expired -> refuse to serve outdated/fake rates
        const earliestCooldownMs = Math.min(
            this.primaryCooldownUntilMs || finalNowMs + BASE_BACKOFF_MS,
            this.fallbackCooldownUntilMs || finalNowMs + BASE_BACKOFF_MS,
        );
        const retryAfterSeconds = Math.max(Math.ceil((earliestCooldownMs - finalNowMs) / 1000), 30);

        throw new ExchangeRatesUnavailableError(
            "Unable to retrieve verified exchange rates at this time. Please view prices in VND.",
            {
                retryAfterSeconds,
                details: {
                    fallbackCurrency: "VND",
                },
            },
        );
    }
}

let defaultExchangeRatesService: ExchangeRatesService | null = null;

export const getExchangeRatesService = (): ExchangeRatesService => {
    if (!defaultExchangeRatesService) {
        defaultExchangeRatesService = new ExchangeRatesService();
    }
    return defaultExchangeRatesService;
};

export const setExchangeRatesServiceForTesting = (service: ExchangeRatesService | null): void => {
    defaultExchangeRatesService = service;
};
