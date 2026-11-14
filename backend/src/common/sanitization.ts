const controlCharactersPattern = /[\u0000-\u001F\u007F]/g;
const scriptPattern = /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi;
const htmlTagPattern = /<\/?[^>]+>/g;

/**
 * Giải thuật làm sạch văn bản đa dòng chống XSS và ký tự điều khiển:
 * - Loại bỏ toàn bộ khối `<script>...</script>` và các thẻ HTML mở/đóng.
 * - Thay thế ký tự điều khiển ASCII (0x00-0x1F, 0x7F) bằng khoảng trắng, gom khoảng trắng thừa trên từng dòng nhưng bảo toàn ngắt dòng `\n`.
 */
export const sanitizeText = (value: string) =>
    value
        .replace(scriptPattern, "")
        .replace(htmlTagPattern, "")
        .replace(controlCharactersPattern, " ")
        .replace(/[ \t]+/g, " ")
        .replace(/\s*\n\s*/g, "\n")
        .trim();

/**
 * Giải thuật làm sạch văn bản một dòng:
 * - Kế thừa bộ lọc HTML/script của `sanitizeText` và gom mọi ký tự trắng liên tiếp (kể cả xuống dòng) thành một dấu cách duy nhất.
 */
export const sanitizeSingleLineText = (value: string) =>
    sanitizeText(value).replace(/\s+/g, " ").trim();

/**
 * Giải thuật chuẩn hóa văn bản một dòng cho phép rỗng (`null`):
 * - Trả về `null` khi giá trị đầu vào là `null`/`undefined` hoặc trở thành chuỗi rỗng sau khi loại bỏ mã độc/khoảng trắng.
 */
export const sanitizeNullableSingleLineText = (value?: string | null) => {
    if (value === undefined || value === null) {
        return null;
    }

    const sanitized = sanitizeSingleLineText(value);
    return sanitized.length > 0 ? sanitized : null;
};
