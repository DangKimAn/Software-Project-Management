/**
 * Định nghĩa kiểu dữ liệu miền, giao diện bộ thích ứng nhà cung cấp tỷ giá (`ExchangeRateProviderAdapter`)
 * và các lớp ngoại lệ chuyên biệt (`UpstreamHttpError`, `ExchangeRatesUnavailableError`) của phân hệ tỷ giá ngoại tệ.
 */

/**
 * Kiểu liên hợp các mã tiền tệ đích được hỗ trợ quy đổi hiển thị từ đồng cơ sở VND.
 */
export type SupportedQuoteCurrency = "USD" | "KRW";

/**
 * Cấu trúc dữ liệu phản hồi chuẩn chứa tỷ giá quy đổi từ VND, thời điểm cập nhật và trạng thái dùng lại bộ nhớ đệm (`stale`).
 */
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

/**
 * Cấu trúc kết quả thô chuẩn hóa trả về từ một bộ thích ứng nhà cung cấp tỷ giá bên ngoài.
 */
export type UpstreamQuoteResult = {
    source: string;
    sourceUpdatedAt: string;
    rates: {
        USD: string;
        KRW: string;
    };
};

/**
 * Giao diện chuẩn cho các bộ thích ứng thu thập tỷ giá hối đoái từ nguồn cung cấp bên thứ ba.
 */
export interface ExchangeRateProviderAdapter {
    readonly name: string;
    fetchVndQuotes(signal?: AbortSignal): Promise<UpstreamQuoteResult>;
}

/**
 * Lớp ngoại lệ biểu diễn lỗi giao tiếp HTTP hoặc giới hạn tần suất (`Retry-After`) từ nhà cung cấp tỷ giá thượng nguồn.
 */
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

/**
 * Lớp ngoại lệ miền (`503 Service Unavailable`) khi mọi nguồn tỷ giá trực tuyến và bản lưu dự phòng đều không khả dụng.
 */
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
