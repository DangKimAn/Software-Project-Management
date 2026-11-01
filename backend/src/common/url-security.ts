import net from "node:net";

import { ApiError } from "./api-error";
import { getEnv } from "../config/env";

const isPrivateIpv4 = (ip: string): boolean => {
    const parts = ip.split(".").map((part) => Number(part));
    if (parts.length !== 4 || parts.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) {
        return true;
    }

    const [a, b] = parts;
    if (a === 0 || a === 10 || a === 127) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a >= 224) return true;

    return false;
};

const isPrivateIpv6 = (ip: string): boolean => {
    const normalized = ip.toLowerCase().split("%")[0];
    if (
        normalized === "::" ||
        normalized === "::1" ||
        normalized.startsWith("fc") ||
        normalized.startsWith("fd") ||
        normalized.startsWith("fe8") ||
        normalized.startsWith("fe9") ||
        normalized.startsWith("fea") ||
        normalized.startsWith("feb")
    ) {
        return true;
    }

    if (normalized.startsWith("::ffff:")) {
        const mappedV4 = normalized.slice("::ffff:".length);
        if (net.isIP(mappedV4) === 4) {
            return isPrivateIpv4(mappedV4);
        }
    }

    return false;
};

export const isSafeExternalHttpUrl = (
    rawUrl: string,
    options: { requireHttps?: boolean; allowLocalhostInDev?: boolean } = {},
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
        hostname === "metadata.google.internal"
    ) {
        return allowLocal && (hostname === "localhost" || hostname.endsWith(".localhost"));
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

    return hostname.includes(".");
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

