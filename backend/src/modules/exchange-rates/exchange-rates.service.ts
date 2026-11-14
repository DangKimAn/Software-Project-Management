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

/**
 * Dịch vụ quản lý và quy đổi tỷ giá ngoại tệ hiển thị (cơ sở `1 VND` -> `USD`, `KRW`) vận hành theo:
 * - Kiến trúc bộ nhớ đệm đa tầng (Multi-tier Cache): Bộ nhớ RAM (`cachedSnapshot`) -> Tệp JSON bền vững
 *   trên đĩa (`ensureDiskHydrated` / `persistSnapshotToDisk`) -> Nguồn thượng nguồn chính & dự phòng
 *   kèm suy giảm an toàn về tiền tệ gốc `VND`.
 * - Cơ chế gộp yêu cầu đồng thời `Single-Flight` (`inFlightRefresh`) chống sập bộ nhớ đệm (Cache Stampede).
 * - Cơ chế giãn cách thử lại lũy thừa có nhiễu ngẫu nhiên (`Exponential Backoff with Jitter`) khi nhà cung cấp lỗi.
 */
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

    /**
     * Khởi tạo dịch vụ tỷ giá với thông số vòng đời bộ nhớ đệm (`cacheTtlMs`, `freshMaxAgeMs`, `maxStaleAgeMs`),
     * đường dẫn tệp snapshot trên đĩa và cặp nhà cung cấp chính/dự phòng (`Frankfurter` / `OpenErApi`).
     */
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

    /**
     * Giải thuật lấy bảng tỷ giá ngoại tệ theo kiến trúc đệm đa tầng kết hợp `Stale-While-Revalidate`:
     * 1. Nếu tính năng tỷ giá bị tắt cấu hình, ném `ExchangeRatesUnavailableError` để hệ thống hiển thị giá gốc `VND`.
     * 2. Nạp lười dữ liệu từ tầng đĩa lên tầng RAM lần đầu tiên qua `ensureDiskHydrated()`.
     * 3. Kiểm tra bản chụp khả dụng trong RAM (`getUsableCachedSnapshot`):
     *    - Nếu có bản chụp hợp lệ và tuổi lần tải `fetchAgeMs = max(0, nowMs - fetchedAt) >= cacheTtlMs`,
     *      phục vụ tức thời bản chụp đã xác thực cho người dùng đồng thời kích hoạt làm mới ngầm
     *      không chặn luồng qua `triggerSingleFlightRefresh()`.
     *    - Nếu `fetchAgeMs < cacheTtlMs`, trả về trực tiếp từ RAM với độ trễ `O(1)`.
     * 4. Nếu cả RAM và đĩa đều chưa có bản chụp còn hạn, ủy quyền cho `triggerSingleFlightRefresh()`
     *    để gộp mọi truy vấn đồng thời vào một tiến trình tải thượng nguồn duy nhất.
     */
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

    /**
     * Giải thuật đánh giá tính khả dụng và phân loại độ tươi của bản chụp tỷ giá trong RAM:
     * - Tính tuổi dữ liệu gốc `sourceAgeMs = nowMs - Date.parse(sourceUpdatedAt)`.
     * - Trả về `null` nếu dữ liệu không hữu hạn hoặc đã quá ngưỡng chịu lỗi tối đa `maxStaleAgeMs` (mặc định 7 ngày).
     * - Gắn cờ `isStale = true` khi `sourceAgeMs > freshMaxAgeMs`, cho phép tiếp tục phục vụ quy đổi hiển thị
     *   suy giảm an toàn trong trường hợp các API tỷ giá bên ngoài bị gián đoạn tạm thời.
     */
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

    /**
     * Giải thuật nạp bản chụp tỷ giá bền vững từ đĩa vào RAM (`loadSnapshotFromDisk` / Disk Hydration):
     * - Sử dụng chốt boolean `diskHydrated` để đảm bảo thao tác đọc I/O chỉ thực thi đúng một lần khi khởi động.
     * - Đọc tệp `snapshotFilePath` và kiểm định lại toàn bộ cấu trúc, biên tỷ giá qua `parseStoredExchangeRateSnapshot`.
     * - Chịu lỗi êm ái: Bỏ qua mã lỗi `ENOENT` khi tệp chưa được khởi tạo lần đầu và ghi cảnh báo nếu tệp hỏng.
     */
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

    /**
     * Giải thuật lưu bền vững bản chụp tỷ giá xuống đĩa cứng theo cơ chế ghi nguyên tử (Atomic Write-and-Rename):
     * - Đảm bảo thư mục cha tồn tại, ghi trọn vẹn chuỗi JSON vào tệp tạm gắn định danh `<pid>.<timestamp>.tmp`,
     *   sau đó đổi tên nguyên tử (`fs.rename`) đè lên `snapshotFilePath` để ngăn chặn tình trạng đọc phải tệp
     *   ghi dở dang (corrupted/partial file) khi mất điện hoặc khởi động lại tiến trình.
     */
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

    /**
     * Giải thuật gộp yêu cầu đồng thời `Single-Flight` (Request Coalescing) chống sập bộ nhớ đệm (Cache Stampede):
     * - Nếu đang có tiến trình làm mới thượng nguồn (`inFlightRefresh !== null`), trả về ngay cùng một `Promise`
     *   đang chạy cho tất cả các truy vấn đến đồng thời, đảm bảo chỉ phát sinh đúng 1 yêu cầu mạng duy nhất.
     * - Tự động giải phóng chốt `inFlightRefresh = null` trong khối `finally` ngay khi `Promise` kết thúc.
     */
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

    /**
     * Giải thuật tính thời gian giãn cách thử lại theo cấp số nhân có nhiễu ngẫu nhiên (`Exponential Backoff with Jitter`):
     * - Sinh nhiễu ngẫu nhiên `jitterMs = floor(jitterFn() * 5000)` trong khoảng `[0, 4999]` ms để phân tán tải thử lại.
     * - Nếu lỗi là `UpstreamHttpError` có chỉ thị `retryAfterSeconds` (như HTTP 429), lấy `max(retryAfterSeconds * 1000, BASE_BACKOFF_MS) + jitterMs`
     *   và kẹp trần tối đa `60 phút`.
     * - Ngược lại, tính bậc mũ `expShift = min(max(failureCount - 1, 0), 5)` và áp dụng công thức:
     *   `min(BASE_BACKOFF_MS * 2^expShift, MAX_BACKOFF_MS) + jitterMs` (tăng dần từ `30s` lên trần `15 phút` cộng jitter).
     */
    private computeBackoffMs(error: unknown, failureCount: number): number {
        const jitterMs = Math.floor(this.jitterFn() * 5_000);
        if (error instanceof UpstreamHttpError && error.retryAfterSeconds !== undefined) {
            const retryMs = Math.max(error.retryAfterSeconds * 1000, BASE_BACKOFF_MS);
            return Math.min(retryMs + jitterMs, 60 * 60_000);
        }
        const expShift = Math.min(Math.max(failureCount - 1, 0), 5);
        return Math.min(BASE_BACKOFF_MS * (1 << expShift), MAX_BACKOFF_MS) + jitterMs;
    }

    /**
     * Giải thuật dựng gói dữ liệu tỷ giá quy đổi tiền tệ chuẩn (`ExchangeRatePayload`) từ báo giá thượng nguồn:
     * - Thiết lập tiền tệ gốc bất biến `baseCurrency = "VND"` (`rates.VND = "1"`) và ánh xạ hệ số quy đổi
     *   `1 VND -> USD`, `1 VND -> KRW` (phục vụ công thức quy đổi hiển thị `targetAmount = vndAmount * rate`),
     *   đồng thời đánh dấu `isStale` nếu tuổi dữ liệu gốc vượt ngưỡng `freshMaxAgeMs`.
     */
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

    /**
     * Giải thuật điều phối làm mới tỷ giá đa tầng có kiểm chứng chéo đột biến và suy giảm an toàn (Multi-tier Failover):
     * 1. Tầng 1 - Nhà cung cấp chính (`primaryProvider`): Truy vấn khi không bị cách ly cooldown. Nếu phát hiện
     *    tỷ giá nhảy vọt `> 25%` so với bản chụp trước (`hasSuspiciousRateJump`), tự động gọi chéo `fallbackProvider`:
     *    chỉ chấp nhận nếu hai nguồn nhất quán (`<= 10%` qua `areQuotesConsistent`), hoặc dùng báo giá ổn định của
     *    nguồn dự phòng; nếu không xác minh được thì bác bỏ dữ liệu dị thường và áp dụng `Exponential Backoff`.
     * 2. Tầng 2 - Nhà cung cấp dự phòng (`fallbackProvider`): Tự động chuyển mạch dự phòng khi nguồn chính lỗi/cooldown,
     *    kiểm tra chống nhảy vọt `> 25%`, cập nhật bộ nhớ RAM và ghi bền vững xuống đĩa (`persistSnapshotToDisk`).
     * 3. Tầng 3 - Suy giảm về bản chụp đệm (RAM/Đĩa): Khi cả hai nguồn thượng nguồn đều sự cố, phục vụ bản chụp
     *    đã xác thực còn trong hạn `maxStaleAgeMs` (<= 7 ngày) kèm cờ `isStale = true`.
     * 4. Tầng 4 - Dự phòng tĩnh an toàn về tiền tệ gốc `VND`: Từ chối cấp tỷ giá giả hoặc quá hạn > 7 ngày, ném
     *    `ExchangeRatesUnavailableError` kèm `retryAfterSeconds` và `fallbackCurrency: "VND"` để giao diện hiển thị giá VND.
     */
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

/**
 * Khởi tạo lười (Lazy Singleton) và trả về thực thể dịch vụ tỷ giá `ExchangeRatesService` dùng chung toàn tiến trình.
 */
export const getExchangeRatesService = (): ExchangeRatesService => {
    if (!defaultExchangeRatesService) {
        defaultExchangeRatesService = new ExchangeRatesService();
    }
    return defaultExchangeRatesService;
};

/**
 * Ghi đè hoặc đặt lại thực thể singleton `ExchangeRatesService` phục vụ cô lập trạng thái trong kiểm thử tự động.
 */
export const setExchangeRatesServiceForTesting = (service: ExchangeRatesService | null): void => {
    defaultExchangeRatesService = service;
};
