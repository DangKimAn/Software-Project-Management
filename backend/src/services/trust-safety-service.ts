import { ApiError } from "../common/api-error";
import { sanitizeSingleLineText, sanitizeText } from "../common/sanitization";

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

const decodeHtmlEntitiesOnce = (value: string) =>
    value.replace(/&(#\d+|#x[a-f0-9]+|amp|lt|gt|quot|apos|#34|#39);/gi, (match, rawEntity: string) => {
        const entity = rawEntity.toLowerCase();

        if (entity.startsWith("#x")) {
            const codePoint = Number.parseInt(entity.slice(2), 16);
            return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : match;
        }

        if (entity.startsWith("#")) {
            const codePoint = Number.parseInt(entity.slice(1), 10);
            return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : match;
        }

        return entityMap[entity] ?? match;
    });

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

const normalizeForModeration = (value: string) =>
    value
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .trim();

const getBlockedTerms = () => {
    const configuredTerms = (process.env.TRUST_SAFETY_BLOCKED_TERMS ?? "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);

    return Array.from(new Set([...defaultBlockedTerms, ...configuredTerms]));
};

export const sanitizeUserText = (value: string, mode: TextMode = "multiLine") => {
    const decodedValue = decodeHtmlEntities(value);
    return mode === "singleLine" ? sanitizeSingleLineText(decodedValue) : sanitizeText(decodedValue);
};

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
        throw new ApiError(422, "Validation error", [
            {
                path: field,
                msg: "content violates content policy",
            },
        ]);
    }
};

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
