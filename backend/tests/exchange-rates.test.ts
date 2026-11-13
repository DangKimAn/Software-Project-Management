const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { after, afterEach, describe, it } = require("node:test");

const request = require("supertest");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = process.env.JWT_SECRET_KEY || "test-secret-fx-module-1234567890";
process.env.GLOBAL_RATE_LIMIT_MAX = "2000";

const app = require("../dist/app").default;
const sequelize = require("../dist/config/database").default;
const { OpenErApiExchangeRateProvider } = require("../dist/modules/exchange-rates/exchange-rates.fallback");
const { FrankfurterExchangeRateProvider } = require("../dist/modules/exchange-rates/exchange-rates.provider");
const {
    ExchangeRatesService,
    setExchangeRatesServiceForTesting,
} = require("../dist/modules/exchange-rates/exchange-rates.service");
const { UpstreamHttpError } = require("../dist/modules/exchange-rates/exchange-rates.types");
const { normalizePositiveRateDecimal } = require("../dist/modules/exchange-rates/exchange-rates.validator");

describe("Exchange Rates Module (/api/v1/exchange-rates)", () => {
    const fixedNowMs = Date.parse("2026-10-31T06:00:00.000Z");
    const tempDirs: string[] = [];

    const createTempSnapshotPath = async (): Promise<string> => {
        const dir = await fs.mkdtemp(path.join(os.tmpdir(), "fx-snapshot-test-"));
        tempDirs.push(dir);
        return path.join(dir, "exchange-rates.snapshot.json");
    };

    afterEach(() => {
        setExchangeRatesServiceForTesting(null);
    });

    after(async () => {
        setExchangeRatesServiceForTesting(null);
        for (const dir of tempDirs) {
            await fs.rm(dir, { recursive: true, force: true }).catch(() => undefined);
        }
        await sequelize.close().catch(() => undefined);
    });

    it("normalizes scientific notation and parses Frankfurter v2 & OpenErApi responses cleanly", async () => {
        assert.equal(normalizePositiveRateDecimal(3.9e-5), "0.000039");
        assert.equal(normalizePositiveRateDecimal("0.05187200"), "0.051872");
        assert.equal(normalizePositiveRateDecimal(0), null);
        assert.equal(normalizePositiveRateDecimal(-0.05), null);
        assert.equal(normalizePositiveRateDecimal("NaN"), null);

        const frankfurter = new FrankfurterExchangeRateProvider({
            nowFn: () => fixedNowMs,
            fetchImpl: async () =>
                new Response(
                    JSON.stringify([
                        { date: "2026-10-31", base: "VND", quote: "KRW", rate: 0.051872 },
                        { date: "2026-10-30", base: "VND", quote: "USD", rate: 0.000038813 },
                    ]),
                    { status: 200, headers: { "Content-Type": "application/json" } },
                ),
        });
        const primaryQuotes = await frankfurter.fetchVndQuotes();
        assert.equal(primaryQuotes.source, "frankfurter");
        assert.equal(primaryQuotes.rates.USD, "0.000038813");
        assert.equal(primaryQuotes.rates.KRW, "0.051872");
        // Uses conservative older quote date (2026-10-30)
        assert.equal(primaryQuotes.sourceUpdatedAt, "2026-10-30T00:00:00.000Z");

        const openEr = new OpenErApiExchangeRateProvider({
            nowFn: () => fixedNowMs,
            fetchImpl: async () =>
                new Response(
                    JSON.stringify({
                        result: "success",
                        base_code: "VND",
                        time_last_update_unix: Math.floor((fixedNowMs - 3600_000) / 1000),
                        rates: {
                            VND: 1,
                            USD: 3.9e-5,
                            KRW: 0.051796,
                        },
                    }),
                    { status: 200, headers: { "Content-Type": "application/json" } },
                ),
        });
        const fallbackQuotes = await openEr.fetchVndQuotes();
        assert.equal(fallbackQuotes.source, "open-er-api");
        assert.equal(fallbackQuotes.rates.USD, "0.000039");
        assert.equal(fallbackQuotes.rates.KRW, "0.051796");
    });

    it("serves canonical contract, caches hits, and coalesces concurrent single-flight requests", async () => {
        const snapshotPath = await createTempSnapshotPath();
        let primaryCalls = 0;

        const service = new ExchangeRatesService({
            snapshotFilePath: snapshotPath,
            nowFn: () => fixedNowMs,
            jitterFn: () => 0,
            primaryProvider: {
                name: "frankfurter",
                fetchVndQuotes: async () => {
                    primaryCalls += 1;
                    await new Promise((resolve) => setTimeout(resolve, 25));
                    return {
                        source: "frankfurter",
                        sourceUpdatedAt: "2026-10-31T04:00:00.000Z",
                        rates: {
                            USD: "0.000038813",
                            KRW: "0.051872",
                        },
                    };
                },
            },
            fallbackProvider: {
                name: "open-er-api",
                fetchVndQuotes: async () => {
                    throw new Error("Should not call fallback when primary succeeds");
                },
            },
        });
        setExchangeRatesServiceForTesting(service);

        // Fire 15 concurrent HTTP requests on a cold cache -> must execute only 1 upstream call
        const responses = await Promise.all(
            Array.from({ length: 15 }, (_, idx) =>
                request(app).get(idx % 2 === 0 ? "/api/v1/exchange-rates" : "/api/exchange-rates"),
            ),
        );

        assert.equal(primaryCalls, 1);
        for (const res of responses) {
            assert.equal(res.status, 200);
            assert.equal(res.body.success, true);
            assert.equal(res.body.data.schemaVersion, "1.0");
            assert.equal(res.body.data.baseCurrency, "VND");
            assert.equal(res.body.data.rates.VND, "1");
            assert.equal(res.body.data.rates.USD, "0.000038813");
            assert.equal(res.body.data.rates.KRW, "0.051872");
            assert.equal(res.body.data.isStale, false);
            assert.equal(res.body.data.displayOnly, true);
        }

        // Subsequent request within 3h TTL hits memory cache with 0 extra upstream calls
        const cachedRes = await request(app).get("/api/v1/exchange-rates");
        assert.equal(cachedRes.status, 200);
        assert.equal(primaryCalls, 1);

        // Verify disk snapshot was persisted atomically
        const persistedRaw = await fs.readFile(snapshotPath, "utf8");
        const persisted = JSON.parse(persistedRaw);
        assert.equal(persisted.rates.USD, "0.000038813");
    });

    it("falls back to secondary provider on timeout/429 and enforces Retry-After cooldown (FX-25)", async () => {
        const snapshotPath = await createTempSnapshotPath();
        let currentNowMs = fixedNowMs;
        let primaryCalls = 0;
        let fallbackCalls = 0;

        const service = new ExchangeRatesService({
            snapshotFilePath: snapshotPath,
            cacheTtlMs: 1_000, // short TTL to force revalidation checks
            nowFn: () => currentNowMs,
            jitterFn: () => 0,
            primaryProvider: {
                name: "frankfurter",
                fetchVndQuotes: async () => {
                    primaryCalls += 1;
                    throw new UpstreamHttpError("frankfurter", "Too Many Requests", {
                        statusCode: 429,
                        retryAfterSeconds: 180,
                    });
                },
            },
            fallbackProvider: {
                name: "open-er-api",
                fetchVndQuotes: async () => {
                    fallbackCalls += 1;
                    return {
                        source: "open-er-api",
                        sourceUpdatedAt: new Date(currentNowMs - 1800_000).toISOString(),
                        rates: {
                            USD: "0.000039",
                            KRW: "0.0518",
                        },
                    };
                },
            },
        });
        setExchangeRatesServiceForTesting(service);

        const first = await request(app).get("/api/v1/exchange-rates");
        assert.equal(first.status, 200);
        assert.equal(first.body.data.source, "open-er-api");
        assert.equal(primaryCalls, 1);
        assert.equal(fallbackCalls, 1);

        // Advance 30 seconds (past 1s cacheTtlMs, still inside 180s primary 429 cooldown)
        currentNowMs += 30_000;
        await service.getExchangeRates();
        await new Promise((resolve) => setTimeout(resolve, 20));
        // Primary MUST NOT be called again while inside its 180s Retry-After window!
        assert.equal(primaryCalls, 1);
        assert.equal(fallbackCalls, 2);
    });

    it("rejects unverified >25% FX rate anomaly from primary when fallback disagrees (FX-26)", async () => {
        const snapshotPath = await createTempSnapshotPath();
        let currentNowMs = fixedNowMs;
        let injectSpike = false;

        const service = new ExchangeRatesService({
            snapshotFilePath: snapshotPath,
            cacheTtlMs: 1_000,
            nowFn: () => currentNowMs,
            jitterFn: () => 0,
            primaryProvider: {
                name: "frankfurter",
                fetchVndQuotes: async () => ({
                    source: "frankfurter",
                    sourceUpdatedAt: new Date(currentNowMs - 600_000).toISOString(),
                    rates: injectSpike
                        ? { USD: "0.000095", KRW: "0.051872" } // >140% spike on USD!
                        : { USD: "0.000038813", KRW: "0.051872" },
                }),
            },
            fallbackProvider: {
                name: "open-er-api",
                fetchVndQuotes: async () => ({
                    source: "open-er-api",
                    sourceUpdatedAt: new Date(currentNowMs - 600_000).toISOString(),
                    rates: { USD: "0.000039", KRW: "0.0518" },
                }),
            },
        });

        const initial = await service.getExchangeRates();
        assert.equal(initial.rates.USD, "0.000038813");

        // Trigger revalidation with anomalous primary spike; fallback stays normal -> must reject primary spike!
        injectSpike = true;
        currentNowMs += 5_000;
        await service.getExchangeRates();
        await new Promise((resolve) => setTimeout(resolve, 20));

        const afterSpike = await service.getExchangeRates();
        assert.equal(afterSpike.rates.USD, "0.000039");
        assert.equal(afterSpike.source, "open-er-api");
    });

    it("hydrates stale disk snapshot (48h..7d) offline, and returns 503 when expired (>7d) or disabled (FX-10, FX-30)", async () => {
        const staleSnapshotPath = await createTempSnapshotPath();
        const sixtyHoursAgoIso = new Date(fixedNowMs - 60 * 3600_000).toISOString();
        await fs.writeFile(
            staleSnapshotPath,
            JSON.stringify({
                schemaVersion: "1.0",
                baseCurrency: "VND",
                rates: { VND: "1", USD: "0.0000388", KRW: "0.0518" },
                source: "frankfurter",
                sourceUpdatedAt: sixtyHoursAgoIso,
                fetchedAt: sixtyHoursAgoIso,
                isStale: false,
                displayOnly: true,
            }),
            "utf8",
        );

        const offlineStaleService = new ExchangeRatesService({
            snapshotFilePath: staleSnapshotPath,
            nowFn: () => fixedNowMs,
            jitterFn: () => 0,
            primaryProvider: {
                name: "frankfurter",
                fetchVndQuotes: async () => {
                    throw new Error("Offline");
                },
            },
            fallbackProvider: {
                name: "open-er-api",
                fetchVndQuotes: async () => {
                    throw new Error("Offline");
                },
            },
        });
        setExchangeRatesServiceForTesting(offlineStaleService);

        const staleRes = await request(app).get("/api/v1/exchange-rates");
        assert.equal(staleRes.status, 200);
        assert.equal(staleRes.body.data.isStale, true);
        assert.equal(staleRes.body.data.rates.USD, "0.0000388");

        // Now test >7 days expired snapshot when offline -> MUST return 503 EXCHANGE_RATES_UNAVAILABLE
        const expiredSnapshotPath = await createTempSnapshotPath();
        const eightDaysAgoIso = new Date(fixedNowMs - 8 * 86400_000).toISOString();
        await fs.writeFile(
            expiredSnapshotPath,
            JSON.stringify({
                schemaVersion: "1.0",
                baseCurrency: "VND",
                rates: { VND: "1", USD: "0.0000388", KRW: "0.0518" },
                source: "frankfurter",
                sourceUpdatedAt: eightDaysAgoIso,
                fetchedAt: eightDaysAgoIso,
                isStale: true,
                displayOnly: true,
            }),
            "utf8",
        );

        const expiredService = new ExchangeRatesService({
            snapshotFilePath: expiredSnapshotPath,
            nowFn: () => fixedNowMs,
            jitterFn: () => 0,
            primaryProvider: {
                name: "frankfurter",
                fetchVndQuotes: async () => {
                    throw new Error("Offline");
                },
            },
            fallbackProvider: {
                name: "open-er-api",
                fetchVndQuotes: async () => {
                    throw new Error("Offline");
                },
            },
        });
        setExchangeRatesServiceForTesting(expiredService);

        const expiredRes = await request(app).get("/api/v1/exchange-rates");
        assert.equal(expiredRes.status, 503);
        assert.equal(expiredRes.body.success, false);
        assert.equal(expiredRes.body.code, "EXCHANGE_RATES_UNAVAILABLE");

        // Feature flag disabled -> 503 EXCHANGE_RATES_UNAVAILABLE
        const disabledService = new ExchangeRatesService({
            enabled: false,
            snapshotFilePath: staleSnapshotPath,
            nowFn: () => fixedNowMs,
        });
        setExchangeRatesServiceForTesting(disabledService);

        const disabledRes = await request(app).get("/api/v1/exchange-rates");
        assert.equal(disabledRes.status, 503);
        assert.equal(disabledRes.body.code, "EXCHANGE_RATES_UNAVAILABLE");
    });
});

export {};
