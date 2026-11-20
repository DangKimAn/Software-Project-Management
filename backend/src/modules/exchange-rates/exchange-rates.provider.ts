import type { ExchangeRateProviderAdapter, UpstreamQuoteResult } from "./exchange-rates.types";
import { UpstreamHttpError } from "./exchange-rates.types";
import { normalizeIsoUtcTimestamp, validateUpstreamQuotes } from "./exchange-rates.validator";

/**
 * Giải thuật phân tích giá trị header HTTP `Retry-After` (theo chuẩn RFC 9110) sang số giây cần chờ:
 * - Nếu chuỗi biểu diễn số nguyên không âm hợp lệ (`/^\d+$/` và hữu hạn), trả về trực tiếp số giây đó.
 * - Nếu chuỗi là ngày giờ chuẩn HTTP-date nằm trong tương lai (`dateMs > nowMs`), quy đổi khoảng chờ
 *   sang giây theo công thức làm tròn lên: `ceil((dateMs - nowMs) / 1000)`.
 * - Cơ chế chịu lỗi: Trả về `undefined` khi header rỗng, sai cú pháp hoặc chỉ mốc thời gian quá khứ.
 */
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
 * Bộ chuyển đổi (adapter) nhà cung cấp tỷ giá chính (Primary Provider) sử dụng dữ liệu tham chiếu
 * Ngân hàng Trung ương Châu Âu (ECB) qua Frankfurter API v2.
 *
 * Primary upstream FX adapter using ECB-backed Frankfurter API v2:
 * `GET https://api.frankfurter.dev/v2/rates?base=VND&quotes=USD,KRW`
 */
export class FrankfurterExchangeRateProvider implements ExchangeRateProviderAdapter {
    readonly name = "frankfurter";
    private readonly endpointUrl: string;
    private readonly timeoutMs: number;
    private readonly fetchImpl: FetchLike;
    private readonly nowFn: () => number;

    /**
     * Khởi tạo bộ cung cấp tỷ giá chính với cấu hình URL điểm cuối, giới hạn thời gian chờ HTTP
     * (`timeoutMs`, mặc định 5000ms), hàm gọi `fetch` và đồng hồ thời gian chuẩn.
     */
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

    /**
     * Giải thuật truy xuất và chuẩn hóa tỷ giá VND sang USD/KRW từ Frankfurter API v2:
     * 1. Giới hạn thời gian chờ (Timeout Guard): Hợp nhất `AbortSignal.timeout(timeoutMs)` với
     *    `externalSignal` qua `AbortSignal.any` để chủ động hủy yêu cầu mạng vượt quá thời gian cho phép.
     * 2. Kiểm soát lỗi & hạn mức thượng nguồn: Chuyển hóa sự cố kết nối và mã phản hồi HTTP lỗi
     *    thành `UpstreamHttpError`, đồng thời đọc chỉ thị `Retry-After` phục vụ chiến lược giãn cách thử lại.
     * 3. Phân tích đa định dạng phản hồi:
     *    - Định dạng mảng v2 (`Array`): Lọc các bản ghi có `base === "VND"` và `quote` thuộc `{USD, KRW}`,
     *      chuẩn hóa ngày hiệu lực qua `normalizeIsoUtcTimestamp` và lấy mốc cũ nhất `oldestSourceMs = min(ts_i)`
     *      làm `sourceUpdatedAt` bảo thủ nhằm tránh đánh giá quá mức độ mới của gói tỷ giá.
     *    - Định dạng đối tượng kế thừa (`Object`): Trích xuất trực tiếp `base`, `date` và `rates.{USD, KRW}`.
     * 4. Kiểm định tính dương hữu hạn: Gọi `validateUpstreamQuotes` để đảm bảo tỷ giá dương hữu hạn
     *    và nằm trong biên độ kinh tế hợp lý của VND trước khi trả về.
     */
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
