// Quick parser verification — run with: node -r ts-node/register scratch/test-parser.ts

import { parseSearchQuery } from "../src/modules/semantic-search/semantic-search.parser";

const now = new Date("2026-06-07T06:00:00.000Z");

const tests = [
    // ── PRICE ───────────────────────────────────────────
    { q: "villa dưới 4tr", expect: "maxPrice=4000000" },
    { q: "villa dưới 4000000", expect: "maxPrice=4000000" },
    { q: "villa dưới 4m", expect: "maxPrice=4000000" },
    { q: "villa trên 4tr", expect: "minPrice=4000000" },
    { q: "villa từ 3tr đến 5tr", expect: "min=3M max=5M" },
    { q: "villa 3-5tr", expect: "min=3M max=5M" },
    { q: "villa tầm 4tr", expect: "min~3.4M max~4.6M" },
    { q: "villa 4tr", expect: "approximate ~4M" },
    { q: "villa 3.5tr", expect: "~3.5M" },
    { q: "villa 3tr5", expect: "~3.5M" },
    { q: "villa 3 triệu rưỡi", expect: "~3.5M" },
    { q: "villa 4 củ", expect: "~4M" },
    { q: "villa 4.000.000", expect: "~4M" },

    // ── GUESTS ──────────────────────────────────────────
    { q: "villa cho 20 khách", expect: "guests=20" },
    { q: "villa 10-30 khách", expect: "guests=30" },
    { q: "villa cặp đôi", expect: "guests=2" },
    { q: "villa gia đình nhỏ", expect: "guests=5" },
    { q: "villa nhóm đông", expect: "guests=15" },
    { q: "villa 20 pax", expect: "guests=20" },

    // ── ROOMS ───────────────────────────────────────────
    { q: "villa 8 phòng ngủ", expect: "bedrooms=8" },
    { q: "villa 8pn", expect: "bedrooms=8" },
    { q: "villa 4 phòng", expect: "bedrooms=4" },
    { q: "villa 10 giường", expect: "beds=10" },
    { q: "villa 9 wc", expect: "bathrooms=9" },

    // ── AMENITIES ───────────────────────────────────────
    { q: "villa hồ bơi karaoke dưới 6tr", expect: "pool+karaoke+maxPrice=6M" },
    { q: "villa bida BBQ", expect: "billiards+bbq" },
    { q: "villa gần biển", expect: "near_beach" },
    { q: "villa thang máy", expect: "elevator" },

    // ── DATES ───────────────────────────────────────────
    { q: "villa ngày mai dưới 5tr", expect: "tomorrow+maxPrice=5M" },
    { q: "villa cuối tuần này", expect: "this_weekend" },
    { q: "villa tháng 7/2026", expect: "month_7_2026" },
    { q: "villa 7/2025", expect: "past date" },

    // ── COMBINED ────────────────────────────────────────
    { q: "villa Vũng Tàu Bãi Sau hồ bơi dưới 5tr cho 20 khách", expect: "VT+BaiSau+pool+max5M+20guests" },
    { q: "villa gần biển có BBQ 3-5tr cho nhóm đông", expect: "near_beach+bbq+3-5M+15guests" },
    { q: "Hello", expect: "no filters" },
];

for (const t of tests) {
    const result = parseSearchQuery(t.q, [], now);
    const parts: string[] = [];

    if (result.minPrice) parts.push(`min=${(result.minPrice / 1000000).toFixed(2)}M`);
    if (result.maxPrice) parts.push(`max=${(result.maxPrice / 1000000).toFixed(2)}M`);
    if (result.guests) parts.push(`guests=${result.guests}`);
    if (result.bedrooms) parts.push(`bedrooms=${result.bedrooms}`);
    if (result.beds) parts.push(`beds=${result.beds}`);
    if (result.bathrooms) parts.push(`bathrooms=${result.bathrooms}`);
    if (result.amenityCodes.length) parts.push(`amenities=[${result.amenityCodes.join(",")}]`);
    if (result.proximity.length) parts.push(`proximity=[${result.proximity.join(",")}]`);
    if (result.city) parts.push(`city=${result.city}`);
    if (result.dateIntent) parts.push(`date=${result.dateIntent.label}(${result.dateIntent.checkIn}→${result.dateIntent.checkOut})`);
    if (result.propertyType) parts.push(`type=${result.propertyType}`);
    if (result.locationIntent) parts.push(`areas=[${result.locationIntent.areaKeys.join(",")}]`);

    const summary = parts.length > 0 ? parts.join(" | ") : "(empty)";
    console.log(`\n[${t.q}]`);
    console.log(`  Expected: ${t.expect}`);
    console.log(`  Parsed:   ${summary}`);
}
