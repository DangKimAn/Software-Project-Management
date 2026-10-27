import { normalizeVietnameseText } from "./src/modules/semantic-search/semantic-search.utils";

const ACCOMMODATION_KEYWORDS = [
    "villa", "biet thu", "homestay", "home stay", "can ho", "chung cu",
    "phong", "resort", "nha nghi", "cho o", "khach san", "hotel",
    "nha", "apartment", "studio", "nha rieng", "nguyen can",
];

const normalized = normalizeVietnameseText("hello/abc/test");
console.log("normalized:", normalized);

const hasAccommodation = ACCOMMODATION_KEYWORDS.some((kw) => {
    const match = normalized.includes(kw);
    if (match) console.log("MATCHED ACCOMMODATION:", kw);
    return match;
});

const LOCATION_KEYWORDS = [
    "vung tau", "bai sau", "bai truoc", "long cung", "chi linh",
    "thuy tien", "trung tam", "gan trung tam", "tran phu", "thuy van",
    "vt", "vtau", "br vt", "brvt",
];

const hasLocation = LOCATION_KEYWORDS.some((kw) => {
    const match = normalized.includes(kw);
    if (match) console.log("MATCHED LOCATION:", kw);
    return match;
});

console.log({ hasAccommodation, hasLocation });
