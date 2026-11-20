import dns from "node:dns";

const defaultDnsPromisesLookup = dns.promises.lookup;
import net from "node:net";

import { ApiError } from "./api-error";
import { getEnv } from "../config/env";

export type SafeExternalUrlOptions = {
    requireHttps?: boolean;
    allowLocalhostInDev?: boolean;
    enforceDnsInTest?: boolean;
    dnsLookupFn?: (hostname: string) => Promise<Array<{ address: string; family: number }>>;
};

/**
 * Giải thuật kiểm tra dải địa chỉ IPv4 nội bộ / đặc biệt (Chống SSRF):
 * Tách 4 octet thập phân chuẩn [a, b, c, d] và chặn toàn bộ các dải không định tuyến công cộng:
 * - 0.0.0.0/8 (This network), 10.0.0.0/8 (RFC1918), 100.64.0.0/10 (CGNAT)
 * - 127.0.0.0/8 (Loopback), 169.254.0.0/16 (Cloud Metadata / Link-Local)
 * - 172.16.0.0/12 (RFC1918), 192.0.0.0/24, 192.0.2.0/24 (TEST-NET-1), 192.168.0.0/16 (RFC1918)
 * - 198.18.0.0/15 (Benchmark), 198.51.100.0/24 (TEST-NET-2), 203.0.113.0/24 (TEST-NET-3), 224.0.0.0/4+ (Multicast/Reserved)
 */
export const isPrivateIpv4 = (ip: string): boolean => {
    const parts = ip.split(".");
    if (parts.length !== 4 || parts.some((part) => !/^\d{1,3}$/.test(part))) {
        return true;
    }

    const nums = parts.map((part) => Number(part));
    if (nums.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) {
        return true;
    }

    const [a, b, c] = nums;
    if (a === 0 || a === 10 || a === 127) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 0 && (c === 0 || c === 2)) return true;
    if (a === 192 && b === 168) return true;
    if (a === 198 && (b === 18 || b === 19)) return true;
    if (a === 198 && b === 51 && c === 100) return true;
    if (a === 203 && b === 0 && c === 113) return true;
    if (a >= 224) return true;

    return false;
};

/**
 * Giải thuật chuẩn hóa địa chỉ IPv6 về mảng 8 nhóm số nguyên 16-bit (uint16[8]):
 * 1. Cắt bỏ định danh vùng (%eth0), kiểm tra tính hợp lệ qua net.isIP(ip) === 6.
 * 2. Nếu phần cuối ở dạng dotted-quad IPv4 (ví dụ ::ffff:127.0.0.1), chuyển 4 octet cuối thành 2 nhóm hex 16-bit.
 * 3. Giải nén ký hiệu rút gọn "::" thành số lượng nhóm 0x0000 tương ứng để thu được đúng 8 từ 16-bit,
 *    giúp nhận diện chính xác cả dạng chuẩn hóa hex của URL parser (ví dụ ::ffff:7f00:1 hay ::ffff:a9fe:a9fe).
 */
export const expandIpv6ToGroups = (rawIp: string): number[] | null => {
    const withoutZone = rawIp.trim().replace(/^\[|\]$/g, "").split("%")[0].toLowerCase();
    if (net.isIP(withoutZone) !== 6) {
        return null;
    }

    let working = withoutZone;
    const lastColon = working.lastIndexOf(":");
    if (lastColon !== -1 && working.slice(lastColon + 1).includes(".")) {
        const ipv4Tail = working.slice(lastColon + 1);
        if (net.isIP(ipv4Tail) !== 4) {
            return null;
        }
        const [o0, o1, o2, o3] = ipv4Tail.split(".").map((part) => Number(part));
        const high = ((o0 << 8) | o1).toString(16);
        const low = ((o2 << 8) | o3).toString(16);
        working = `${working.slice(0, lastColon)}:${high}:${low}`;
    }

    const doubleColonParts = working.split("::");
    if (doubleColonParts.length > 2) {
        return null;
    }

    const parseSide = (side: string): number[] | null => {
        if (!side) return [];
        const tokens = side.split(":");
        const values: number[] = [];
        for (const token of tokens) {
            if (!/^[0-9a-f]{1,4}$/.test(token)) {
                return null;
            }
            values.push(parseInt(token, 16));
        }
        return values;
    };

    if (doubleColonParts.length === 2) {
        const left = parseSide(doubleColonParts[0]);
        const right = parseSide(doubleColonParts[1]);
        if (!left || !right || left.length + right.length >= 8) {
            return null;
        }
        const zeroFill = new Array<number>(8 - left.length - right.length).fill(0);
        return [...left, ...zeroFill, ...right];
    }

    const full = parseSide(working);
    return full && full.length === 8 ? full : null;
};

const groupsToIpv4String = (high16: number, low16: number): string =>
    `${(high16 >> 8) & 0xff}.${high16 & 0xff}.${(low16 >> 8) & 0xff}.${low16 & 0xff}`;

/**
 * Giải thuật phát hiện địa chỉ IPv6 nội bộ & cơ chế ánh xạ IPv4-in-IPv6 (Chống vượt tường lửa SSRF):
 * Chuyển IPv6 sang 8 nhóm 16-bit [g0..g7], sau đó kiểm tra toàn diện:
 * - Unspecified (::), Loopback (::1), Unique Local (fc00::/7), Link-Local (fe80::/10), Site-Local (fec0::/10), Multicast (ff00::/8)
 * - Discard-Only (100::/64), Documentation (2001:db8::/32), Teredo (2001:0000::/32)
 * - IPv4-mapped (::ffff:0:0/96, kể cả dạng hex ::ffff:7f00:1), IPv4-compatible (::/96), SIIT (::ffff:0:0:0/96),
 *   NAT64 (64:ff9b::/96 và 64:ff9b:1::/48) và 6to4 (2002::/16) -> trích xuất IPv4 nhúng bên trong và kiểm tra qua isPrivateIpv4.
 */
export const isPrivateIpv6 = (ip: string): boolean => {
    const groups = expandIpv6ToGroups(ip);
    if (!groups) {
        return true;
    }

    const [g0, g1, g2, g3, g4, g5, g6, g7] = groups;
    const allZeroPrefix6 = g0 === 0 && g1 === 0 && g2 === 0 && g3 === 0 && g4 === 0 && g5 === 0;

    // :: (unspecified) hoặc ::1 (loopback) hoặc IPv4-compatible ::w.x.y.z
    if (allZeroPrefix6) {
        if (g6 === 0 && (g7 === 0 || g7 === 1)) {
            return true;
        }
        return isPrivateIpv4(groupsToIpv4String(g6, g7));
    }

    // IPv4-mapped IPv6 ::ffff:w.x.y.z (bao gồm ::ffff:7f00:1, ::ffff:a9fe:a9fe)
    if (g0 === 0 && g1 === 0 && g2 === 0 && g3 === 0 && g4 === 0 && g5 === 0xffff) {
        return isPrivateIpv4(groupsToIpv4String(g6, g7));
    }

    // IPv4-translated SIIT ::ffff:0:w.x.y.z
    if (g0 === 0 && g1 === 0 && g2 === 0 && g3 === 0 && g4 === 0xffff && g5 === 0) {
        return isPrivateIpv4(groupsToIpv4String(g6, g7));
    }

    // NAT64 64:ff9b::/96 hoặc 64:ff9b:1::/48
    if (g0 === 0x0064 && g1 === 0xff9b) {
        return isPrivateIpv4(groupsToIpv4String(g6, g7));
    }

    // 6to4 2002::/16 (IPv4 nhúng tại g1, g2)
    if (g0 === 0x2002) {
        return isPrivateIpv4(groupsToIpv4String(g1, g2));
    }

    // Teredo 2001:0000::/32 & Documentation 2001:db8::/32
    if (g0 === 0x2001 && (g1 === 0x0000 || g1 === 0x0db8)) {
        return true;
    }

    // Discard-Only RFC 6666 (100::/64)
    if (g0 === 0x0100 && g1 === 0 && g2 === 0 && g3 === 0) {
        return true;
    }

    // Unique Local fc00::/7, Link-Local fe80::/10, Site-Local fec0::/10, Multicast ff00::/8
    if (
        (g0 & 0xfe00) === 0xfc00 ||
        (g0 & 0xffc0) === 0xfe80 ||
        (g0 & 0xffc0) === 0xfec0 ||
        (g0 & 0xff00) === 0xff00
    ) {
        return true;
    }

    return false;
};

export const isPrivateIpAddress = (ip: string): boolean => {
    const normalized = ip.trim().replace(/^\[|\]$/g, "").split("%")[0];
    const version = net.isIP(normalized);
    if (version === 4) return isPrivateIpv4(normalized);
    if (version === 6) return isPrivateIpv6(normalized);
    return true;
};

/**
 * Giải thuật kiểm tra đồng bộ URL HTTP(S) bên ngoài an toàn:
 * Xác thực giao thức (ép buộc HTTPS trên production), từ chối thông tin xác thực nhúng trong URL,
 * chặn tên miền nội bộ (.local, .internal, localhost) và kiểm tra chặt chẽ IPv4/IPv6 nội bộ.
 */
export const isSafeExternalHttpUrl = (
    rawUrl: string,
    options: SafeExternalUrlOptions = {},
): boolean => {
    let parsed: URL;
    try {
        parsed = new URL(rawUrl.trim());
    } catch {
        return false;
    }

    if (parsed.username || parsed.password) {
        return false;
    }

    const env = getEnv();
    const requireHttps = options.requireHttps ?? env.nodeEnv === "production";
    if (requireHttps) {
        if (parsed.protocol !== "https:") {
            return false;
        }
    } else if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
        return false;
    }

    const hostname = parsed.hostname.replace(/^\[|\]$/g, "").toLowerCase();
    if (!hostname) {
        return false;
    }

    const allowLocal = Boolean(options.allowLocalhostInDev && env.nodeEnv !== "production");
    if (
        hostname === "localhost" ||
        hostname.endsWith(".localhost") ||
        hostname.endsWith(".local") ||
        hostname.endsWith(".internal") ||
        hostname.endsWith(".home.arpa") ||
        hostname === "metadata.google.internal"
    ) {
        return allowLocal && (hostname === "localhost" || hostname.endsWith(".localhost"));
    }

    // Chặn biểu diễn IPv4 dạng số nguyên/bát phân/thập lục phân (ví dụ http://2130706433 hoặc http://0x7f000001)
    if (/^(0x[0-9a-f]+|\d+)$/i.test(hostname) || hostname.split(".").every((part) => /^(0x[0-9a-f]+|\d+)$/i.test(part))) {
        if (net.isIP(hostname) !== 4) {
            return false;
        }
    }

    const ipVersion = net.isIP(hostname);
    if (ipVersion === 4) {
        if (allowLocal && hostname === "127.0.0.1") {
            return true;
        }
        return !isPrivateIpv4(hostname);
    }
    if (ipVersion === 6) {
        if (allowLocal && hostname === "::1") {
            return true;
        }
        return !isPrivateIpv6(hostname);
    }

    return hostname.includes(".") && !hostname.endsWith(".");
};

export const assertSafeExternalImageUrl = (rawUrl: string, fieldName = "imageUrl"): string => {
    const trimmed = rawUrl.trim();
    if (!isSafeExternalHttpUrl(trimmed)) {
        throw new ApiError(422, "Validation error", [
            {
                path: fieldName,
                msg: `${fieldName} must be a valid public HTTPS URL`,
            },
        ]);
    }
    return trimmed;
};

/**
 * Giải thuật chống DNS Rebinding bất đồng bộ (assertSafeExternalUrlResolved):
 * 1. Thực thi kiểm tra cú pháp & IP trực tiếp qua isSafeExternalHttpUrl.
 * 2. Nếu hostname là tên miền, phân giải toàn bộ bản ghi A và AAAA qua dns.promises.lookup({ all: true })
 *    kèm giới hạn thời gian 3 giây.
 * 3. Đối chiếu từng IP phân giải được với isPrivateIpAddress; nếu không có bản ghi hoặc tồn tại bất kỳ IP nội bộ nào
 *    (ví dụ tên miền tấn công trỏ về 127.0.0.1, 169.254.169.254 hoặc ::ffff:127.0.0.1), từ chối ngay với mã 422.
 */
export const assertSafeExternalUrlResolved = async (
    rawUrl: string,
    fieldName = "url",
    options: SafeExternalUrlOptions = {},
): Promise<string> => {
    const trimmed = rawUrl.trim();
    if (!isSafeExternalHttpUrl(trimmed, options)) {
        throw new ApiError(422, "Validation error", [
            {
                path: fieldName,
                msg: `${fieldName} must be a valid public HTTPS URL`,
            },
        ]);
    }

    const parsed = new URL(trimmed);
    const hostname = parsed.hostname.replace(/^\[|\]$/g, "").toLowerCase();
    const env = getEnv();
    const allowLocal = Boolean(options.allowLocalhostInDev && env.nodeEnv !== "production");

    if (net.isIP(hostname) !== 0 || (allowLocal && (hostname === "localhost" || hostname.endsWith(".localhost")))) {
        return trimmed;
    }

    // CONFLICT-RESOLVED: Cho phép bỏ qua tra cứu mạng thực trong môi trường test mặc định, nhưng tự động kích hoạt kiểm tra DNS Rebinding khi bài kiểm thử chủ động ghi đè `dns.promises.lookup`.
    const isDnsLookupOverridden = dns.promises.lookup !== defaultDnsPromisesLookup;
    if (env.nodeEnv === "test" && !options.enforceDnsInTest && !options.dnsLookupFn && !isDnsLookupOverridden) {
        return trimmed;
    }

    const lookup =
        options.dnsLookupFn ??
        ((host: string) => dns.promises.lookup(host, { all: true, verbatim: true }));

    let records: Array<{ address: string; family: number }>;
    try {
        records = await Promise.race([
            lookup(hostname),
            new Promise<never>((_resolve, reject) =>
                setTimeout(() => reject(new Error("DNS lookup timeout")), 3000),
            ),
        ]);
    } catch {
        throw new ApiError(422, "Validation error", [
            {
                path: fieldName,
                msg: `${fieldName} hostname could not be safely resolved`,
            },
        ]);
    }

    if (!Array.isArray(records) || records.length === 0 || records.some((rec) => isPrivateIpAddress(rec.address))) {
        throw new ApiError(422, "Validation error", [
            {
                path: fieldName,
                msg: `${fieldName} resolves to a restricted or private network address`,
            },
        ]);
    }

    return trimmed;
};
