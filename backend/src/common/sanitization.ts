const controlCharactersPattern = /[\u0000-\u001F\u007F]/g;
const scriptPattern = /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi;
const htmlTagPattern = /<\/?[^>]+>/g;

export const sanitizeText = (value: string) =>
    value
        .replace(scriptPattern, "")
        .replace(htmlTagPattern, "")
        .replace(controlCharactersPattern, " ")
        .replace(/[ \t]+/g, " ")
        .replace(/\s*\n\s*/g, "\n")
        .trim();

export const sanitizeSingleLineText = (value: string) =>
    sanitizeText(value).replace(/\s+/g, " ").trim();

export const sanitizeNullableSingleLineText = (value?: string | null) => {
    if (value === undefined || value === null) {
        return null;
    }

    const sanitized = sanitizeSingleLineText(value);
    return sanitized.length > 0 ? sanitized : null;
};
