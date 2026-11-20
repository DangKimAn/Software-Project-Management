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
 * Giải thuật chuẩn hóa số thực dương hữu hạn hoặc chuỗi số (kể cả ký pháp khoa học như `3.9e-5`)
 * sang chuỗi thập phân chính tắc không chứa số mũ (`"0.000039"`), loại bỏ sai số làm tròn dấu phẩy động:
 * 1. Tách cấu trúc bằng biểu thức chính quy thành dấu, phần nguyên (`wholeDigits`), phần lẻ (`fracDigits`)
 *    và bậc mũ cơ số 10 (`exp` thuộc đoạn `[-100, 100]`); bác bỏ số âm, số `0`, `NaN`, `Infinity`.
 * 2. Ghép dãy chữ số có nghĩa `combined` (bỏ các chữ số `0` ở đầu) và tính độ dịch dấu phẩy `scale = fracDigits.length - exp`.
 * 3. Tái tạo chuỗi thập phân theo 3 miền giá trị của `scale`:
 *    - Nếu `scale <= 0`: nối thêm `-scale` chữ số `0` vào bên phải `combined`.
 *    - Nếu `combined.length <= scale`: đệm `0` bên trái tạo dạng `0.<padded>` và cắt `0` vô nghĩa ở đuôi.
 *    - Nếu `combined.length > scale`: chèn dấu chấm tại vị trí `combined.length - scale` và khử `0` thừa ở cuối.
 *
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

/**
 * Giải thuật chuẩn hóa mốc thời gian đa định dạng (Unix timestamp giây/mili-giây, chuỗi ngày `YYYY-MM-DD`,
 * hoặc chuỗi ISO-8601) về chuỗi UTC ISO-8601 chính tắc:
 * - Tự động phân biệt đơn vị số học: nếu giá trị số hữu hạn `< 10^12` thì quy đổi từ giây sang mili-giây (`raw * 1000`),
 *   ngược lại giữ nguyên mili-giây; nếu là chuỗi ngày `YYYY-MM-DD` thì gắn mốc `T00:00:00.000Z`.
 * - Ràng buộc cửa sổ thời gian hợp lệ: Bác bỏ (`null`) mọi mốc trước `2020-01-01T00:00:00.000Z` hoặc lệch về
 *   tương lai quá `48 giờ` so với `nowMs` (`nowMs + MAX_FUTURE_DRIFT_MS`) để chống dữ liệu lỗi/trôi đồng hồ.
 */
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

/**
 * Giải thuật kiểm định toàn diện gói báo giá tỷ giá thượng nguồn (cơ sở `1 VND` sang `USD` và `KRW`):
 * 1. Kiểm tra định danh nguồn `source` khác rỗng và chuẩn hóa thời gian cập nhật `sourceUpdatedAt`.
 * 2. Chuẩn hóa chuỗi số thập phân dương hữu hạn cho `USD` và `KRW` qua `normalizePositiveRateDecimal`.
 * 3. Kiểm tra miền biên kinh tế an toàn (Sanity Bounds) chống dữ liệu hỏng hoặc đảo nghịch cơ số:
 *    - `USD` phải thuộc `[0.00001, 0.0002]` (tương ứng `1 USD` nằm trong khoảng `5.000` đến `100.000` VND).
 *    - `KRW` phải thuộc `[0.01, 0.25]` (tương ứng `1 KRW` nằm trong khoảng `4` đến `100` VND).
 * 4. Ném ngoại lệ tức thời nếu vi phạm bất kỳ điều kiện nào để bảo vệ bộ nhớ đệm khỏi tỷ giá độc hại.
 */
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

/**
 * Giải thuật phát hiện biến động tỷ giá đột biến bất thường (Rate Spike Detection) so với bản chụp gần nhất:
 * - Tính độ lệch tương đối cho từng ngoại tệ theo công thức: `relDiff = |nextRate - prevRate| / prevRate`.
 * - Trả về `true` nếu biến động của USD hoặc KRW vượt quá ngưỡng `threshold` (mặc định `0.25` = `25%`),
 *   kích hoạt cơ chế kiểm chứng chéo bắt buộc với nhà cung cấp dự phòng trước khi lưu bộ nhớ đệm.
 */
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

/**
 * Giải thuật đối chiếu chéo độ nhất quán (Cross-Provider Consistency Check) giữa hai nguồn tỷ giá độc lập:
 * - Tính sai số tương đối giữa nguồn chính (`primary`) và nguồn dự phòng (`secondary`) theo công thức:
 *   `diff = |primaryRate - secondaryRate| / secondaryRate`.
 * - Trả về `true` khi cả tỷ giá USD và KRW của nguồn dự phòng đều dương và độ lệch tương đối không vượt quá
 *   ngưỡng `maxDivergence` (mặc định `0.10` = `10%`).
 */
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

/**
 * Giải thuật phân tích và tái xác thực bản chụp tỷ giá lưu bền vững từ đĩa cứng (`ExchangeRatePayload`):
 * - Giải mã chuỗi JSON an toàn trong khối `try/catch`, kiểm tra các bất biến lược đồ (`baseCurrency === "VND"`,
 *   `displayOnly === true`, `rates.VND === "1"`) và mốc thời gian `fetchedAt`.
 * - Thực thi lại toàn bộ quy trình kiểm định `validateUpstreamQuotes` trên cặp tỷ giá `USD`/`KRW`;
 *   trả về `null` an toàn (không ném lỗi) nếu tệp snapshot bị hỏng cấu trúc hoặc vi phạm miền giá trị.
 */
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
