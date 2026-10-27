import {
    detectLocationGroupsFromQuery,
    getLocationGroupAreaKey,
    getLocationGroupNameFromAreaKey,
    getLocationGroupNamesFromAreaKeys,
    normalizeVietnameseText,
    type LocationGroupName,
} from "../../common/vung-tau-location-groups";

export { normalizeVietnameseText };

export const normalizeKey = (value: string) => normalizeVietnameseText(value).replace(/\s+/g, "_");

export const uniqueNumbers = (values: number[]) =>
    Array.from(new Set(values.filter((value) => Number.isFinite(value))));

export const uniqueStrings = (values: string[]) =>
    Array.from(new Set(values.map((item) => item.trim()).filter(Boolean)));

export const toNumber = (value: unknown, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

export const listNights = (checkIn: string, checkOut: string) => {
    const dates: string[] = [];
    const cursor = new Date(`${checkIn}T00:00:00.000Z`);
    const end = new Date(`${checkOut}T00:00:00.000Z`);

    while (cursor < end) {
        dates.push(cursor.toISOString().slice(0, 10));
        cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    return dates;
};

export const getSemanticDefaultCity = () => process.env.SEMANTIC_DEFAULT_CITY || "Vũng Tàu";

export const shouldForceVungTauOnly = () =>
    (process.env.SEMANTIC_FORCE_VUNG_TAU_ONLY ?? "true").toLowerCase() !== "false";

export const inferVungTauAreaKeys = (text: string) =>
    uniqueStrings(detectLocationGroupsFromQuery(text).map(getLocationGroupAreaKey));

export const getVungTauAreaDisplayName = (key: string) =>
    getLocationGroupNameFromAreaKey(key) ?? key;

export const getVungTauAreaDisplayNames = (keys: string[]) =>
    getLocationGroupNamesFromAreaKeys(keys);

export const getVungTauAreaKeysForLocationGroups = (groupNames: LocationGroupName[]) =>
    uniqueStrings(groupNames.map(getLocationGroupAreaKey));

export const isVungTauRelatedText = (text: string) => {
    const normalized = normalizeVietnameseText(text);

    if (
        normalized.includes("vung tau") ||
        normalized.includes("ba ria vung tau") ||
        normalized.includes("br vt")
    ) {
        return true;
    }

    return inferVungTauAreaKeys(text).length > 0;
};

export const buildLocationKeys = (input: {
    city: string;
    district: string;
    ward: string;
    addressLine: string;
    title?: string;
    description?: string;
}) => {
    const text = [
        input.city,
        input.district,
        input.ward,
        input.addressLine,
        input.title ?? "",
        input.description ?? "",
    ].join(" ");

    const keys = [
        normalizeKey(input.city),
        normalizeKey(input.district),
        normalizeKey(input.ward),
        ...inferVungTauAreaKeys(text),
    ];

    if (isVungTauRelatedText(text)) {
        keys.push("vung_tau");
    }

    return uniqueStrings(keys);
};
