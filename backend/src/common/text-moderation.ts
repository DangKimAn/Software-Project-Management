// CONFLICT-RESOLVED: Chuyển hàm thuần làm sạch và kiểm duyệt văn bản từ `src/services/trust-safety-service.ts` về `src/common/text-moderation.ts`.
import { ApiError } from "./api-error";
import { sanitizeSingleLineText, sanitizeText } from "./sanitization";

type TextMode = "singleLine" | "multiLine";

type SanitizeAndModerateOptions = {
    field: string;
    mode?: TextMode;
    allowEmpty?: boolean;
};

const defaultBlockedTerms = [
    "fuck",
    "shit",
    "địt",
    "dit",
    "lồn",
    "lon",
    "cặc",
    "cac",
];

const entityMap: Record<string, string> = {
    amp: "&",
    lt: "<",
    gt: ">",
    quot: "\"",
    "#34": "\"",
    "#39": "'",
    apos: "'",
};

/**
 * Kiểm tra mã điểm số nguyên có thuộc không gian Unicode Scalar hợp lệ (`0..0x10FFFF`, loại trừ dải surrogate
 * `0xD800..0xDFFF`) trước khi chuyển thành ký tự qua `String.fromCodePoint`.
 */
const isValidUnicodeScalar = (codePoint: number) =>
    Number.isInteger(codePoint) &&
    codePoint >= 0 &&
    codePoint <= 0x10ffff &&
    (codePoint < 0xd800 || codePoint > 0xdfff);

/**
 * Giải thuật giải mã một lượt các thực thể HTML (mã hex `&#x...;`, mã thập phân `&#...;` và thực thể đặt tên)
 * về ký tự Unicode thực tế để bóc tách lớp ngụy trang văn bản.
 */
const decodeHtmlEntitiesOnce = (value: string) =>
    value.replace(/&(#\d+|#x[a-f0-9]+|amp|lt|gt|quot|apos|#34|#39);/gi, (match, rawEntity: string) => {
        const entity = rawEntity.toLowerCase();

        if (entity.startsWith("#x")) {
            const codePoint = Number.parseInt(entity.slice(2), 16);
            return isValidUnicodeScalar(codePoint) ? String.fromCodePoint(codePoint) : match;
        }

        if (entity.startsWith("#")) {
            const codePoint = Number.parseInt(entity.slice(1), 10);
            return isValidUnicodeScalar(codePoint) ? String.fromCodePoint(codePoint) : match;
        }

        return entityMap[entity] ?? match;
    });

/**
 * Giải thuật giải mã lặp hội tụ thực thể HTML (tối đa 3 vòng, dừng sớm khi đạt điểm bất động):
 * - Ngăn chặn kỹ thuật mã hóa HTML lồng nhiều lớp (double/triple encoding) nhằm qua mặt bộ kiểm duyệt nội dung.
 */
const decodeHtmlEntities = (value: string) => {
    let decoded = value;

    for (let index = 0; index < 3; index += 1) {
        const nextValue = decodeHtmlEntitiesOnce(decoded);

        if (nextValue === decoded) {
            break;
        }

        decoded = nextValue;
    }

    return decoded;
};

/**
 * Giải thuật chuẩn hóa văn bản phục vụ đối sánh kiểm duyệt Trust & Safety:
 * - Phân rã tổ hợp Unicode NFD để tước bỏ dấu tiếng Việt (`\p{Diacritic}`), chuyển về chữ thường
 *   và thay mọi chuỗi ký tự phi chữ-số bằng khoảng trắng đơn nhằm phát hiện từ vi phạm bị chèn ký hiệu che giấu.
 */
const normalizeForModeration = (value: string) =>
    value
        .replace(/[đĐ]/g, "d")
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .trim();

/**
 * Tổng hợp và khử trùng lặp danh sách từ/cụm từ bị chặn từ tập mặc định (`defaultBlockedTerms`)
 * kết hợp cấu hình động `TRUST_SAFETY_BLOCKED_TERMS` (chặn ngôn từ thô tục, lạm dụng hoặc từ khóa lách nền tảng/rò rỉ liên hệ).
 */
const getBlockedTerms = () => {
    const configuredTerms = (process.env.TRUST_SAFETY_BLOCKED_TERMS ?? "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);

    return Array.from(new Set([...defaultBlockedTerms, ...configuredTerms]));
};

/**
 * Giải thuật làm sạch văn bản do người dùng nhập (tin nhắn, đánh giá, hồ sơ):
 * - Giải mã thực thể HTML ẩn trước khi chuẩn hóa ký tự điều khiển và khoảng trắng theo chế độ một dòng hoặc nhiều dòng.
 */
export const sanitizeUserText = (value: string, mode: TextMode = "multiLine") => {
    const decodedValue = decodeHtmlEntities(value);
    return mode === "singleLine" ? sanitizeSingleLineText(decodedValue) : sanitizeText(decodedValue);
};

/**
 * Giải thuật kiểm duyệt chính sách nội dung (Content Policy & Anti-Circumvention Moderation):
 * - Chuẩn hóa không dấu chuỗi văn bản và từng cụm từ cấm trong `getBlockedTerms()`, sau đó đối sánh theo
 *   biểu thức chính quy ranh giới từ `(^|\s)<term>(\s|$)` để tránh bắt nhầm từ ghép hợp lệ (false positive).
 * - Từ chối bằng lỗi `422` khi phát hiện nội dung vi phạm tiêu chuẩn cộng đồng hoặc chính sách an toàn giao dịch.
 */
export const assertTextAllowed = (value: string, field: string) => {
    const normalizedValue = normalizeForModeration(value);

    if (!normalizedValue) {
        return;
    }

    const matchedTerm = getBlockedTerms().find((term) => {
        const normalizedTerm = normalizeForModeration(term);

        if (!normalizedTerm) {
            return false;
        }

        return new RegExp(`(^|\\s)${normalizedTerm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(\\s|$)`).test(
            normalizedValue,
        );
    });

    if (matchedTerm) {
        throw new ApiError(
            422,
            "Nội dung chứa từ ngữ không phù hợp với tiêu chuẩn cộng đồng.",
            [
                {
                    path: field,
                    msg: "content violates content policy",
                },
            ],
        );
    }
};

/**
 * Quy trình khép kín làm sạch văn bản (`sanitizeUserText`), kiểm tra bắt buộc nhập (`!allowEmpty`)
 * và kiểm duyệt nội dung (`assertTextAllowed`) cho tin nhắn trao đổi, đánh giá và thông tin mô tả của người dùng.
 */
export const sanitizeAndModerateText = (
    value: string | null | undefined,
    options: SanitizeAndModerateOptions,
) => {
    const sanitized = sanitizeUserText(value ?? "", options.mode ?? "multiLine");

    if (!options.allowEmpty && sanitized.length === 0) {
        throw new ApiError(422, "Validation error", [
            {
                path: options.field,
                msg: `${options.field} is required`,
            },
        ]);
    }

    assertTextAllowed(sanitized, options.field);
    return sanitized;
};
