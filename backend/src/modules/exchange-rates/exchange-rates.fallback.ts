import type { ExchangeRateProviderAdapter, UpstreamQuoteResult } from "./exchange-rates.types";
import { UpstreamHttpError } from "./exchange-rates.types";
import type { FetchLike } from "./exchange-rates.provider";
import { parseRetryAfterHeader } from "./exchange-rates.provider";
import { validateUpstreamQuotes } from "./exchange-rates.validator";

/**
 * Bộ chuyển đổi (adapter) nhà cung cấp tỷ giá dự phòng (Fallback Provider) kết nối tới
 * ExchangeRate-API Open Access v6 để lấy bảng tỷ giá tham chiếu cơ sở VND.
 *
 * Secondary fallback FX adapter using ExchangeRate-API Open Access v6:
 * `GET https://open.er-api.com/v6/latest/VND`
 */
export class OpenErApiExchangeRateProvider implements ExchangeRateProviderAdapter {
    readonly name = "open-er-api";
    private readonly endpointUrl: string;
    private readonly timeoutMs: number;
    private readonly fetchImpl: FetchLike;
    private readonly nowFn: () => number;

    /**
     * Khởi tạo bộ cung cấp tỷ giá dự phòng với cấu hình điểm cuối HTTP, ngưỡng cắt thời gian chờ
     * (`timeoutMs`, mặc định 5000ms), hàm thực thi `fetch` và nguồn đồng hồ hệ thống phục vụ kiểm thử.
     */
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

    /**
     * Giải thuật truy xuất và kiểm định báo giá tỷ giá cơ sở VND sang USD/KRW từ ExchangeRate-API:
     * 1. Kiểm soát thời gian chờ (Timeout Composition): Tạo tín hiệu `AbortSignal.timeout(timeoutMs)`
     *    và hợp nhất với `externalSignal` (nếu có) qua `AbortSignal.any` để hủy sớm kết nối treo quá hạn.
     * 2. Chịu lỗi tầng giao vận & HTTP: Mọi lỗi mạng hoặc mã trạng thái ngoài dải `2xx` đều được
     *    đóng gói thành `UpstreamHttpError` kèm số giây chờ trích xuất từ header `Retry-After`
     *    nhằm phục vụ tính toán giãn cách lũy thừa (Exponential Backoff) ở tầng dịch vụ.
     * 3. Xác thực cấu trúc & miền giá trị dương hữu hạn: Kiểm tra phản hồi là đối tượng JSON hợp lệ,
     *    trạng thái `result === "success"`, tiền tệ gốc `base_code === "VND"`, trích xuất mốc cập nhật
     *    (`time_last_update_unix` hoặc `time_last_update_utc`) và ủy quyền cho `validateUpstreamQuotes`
     *    kiểm tra tính dương hữu hạn cùng biên độ an toàn trước khi trả kết quả.
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
