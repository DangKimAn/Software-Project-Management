import { logger } from "../../config/logger";
import { getEmbeddingDimension } from "./embedding.service";
import {
    ListingVectorPayload,
    SemanticSearchFilters,
    VectorSearchHit,
    semanticPublicListingStatuses,
} from "./semantic-search.types";

// ─── Env helpers ──────────────────────────────────────────────────────────────

export const getQdrantUrl = (): string | undefined =>
    process.env.QDRANT_URL?.replace(/\/$/, "") || undefined;

export const getQdrantApiKey = (): string | undefined =>
    process.env.QDRANT_API_KEY || undefined;

/**
 * Collection name resolution with backward-compatible fallback.
 *
 * Priority:
 *   1. QDRANT_COLLECTION_LISTINGS  (new canonical name)
 *   2. QDRANT_COLLECTION           (legacy alias)
 *   3. "booking_listings"           (default)
 */
export const getQdrantCollectionName = (): string =>
    process.env.QDRANT_COLLECTION_LISTINGS ||
    process.env.QDRANT_COLLECTION ||
    "booking_listings";

export const isQdrantConfigured = (): boolean => Boolean(getQdrantUrl());

// ─── HTTP helpers ──────────────────────────────────────────────────────────────

const buildHeaders = (): Record<string, string> => {
    const headers: Record<string, string> = {
        "Content-Type": "application/json",
    };

    const apiKey = getQdrantApiKey();

    if (apiKey) {
        headers["api-key"] = apiKey;
    }

    return headers;
};

const parseJson = (text: string): unknown => {
    if (!text) return null;

    try {
        return JSON.parse(text) as unknown;
    } catch {
        return text;
    }
};

const requestQdrant = async <T>(path: string, init: RequestInit): Promise<T> => {
    const baseUrl = getQdrantUrl();

    if (!baseUrl) {
        throw new Error("QDRANT_URL is not configured");
    }

    const response = await fetch(`${baseUrl}${path}`, {
        ...init,
        headers: {
            ...buildHeaders(),
            ...(init.headers ?? {}),
        },
    });

    const text = await response.text();
    const payload = parseJson(text);

    if (!response.ok) {
        throw new Error(`Qdrant returned ${response.status}: ${JSON.stringify(payload)}`);
    }

    return payload as T;
};

// ─── Collection types ─────────────────────────────────────────────────────────

type QdrantCollectionResponse = {
    result?: {
        config?: {
            params?: {
                vectors?: {
                    size?: number;
                    distance?: string;
                };
            };
        };
    };
};

// ─── Collection management ────────────────────────────────────────────────────

const getExistingCollection = async (): Promise<QdrantCollectionResponse | null> => {
    const baseUrl = getQdrantUrl();

    if (!baseUrl) return null;

    const collectionName = getQdrantCollectionName();
    const response = await fetch(
        `${baseUrl}/collections/${encodeURIComponent(collectionName)}`,
        { method: "GET", headers: buildHeaders() },
    );

    if (response.status === 404) {
        return null;
    }

    const text = await response.text();
    const payload = parseJson(text) as QdrantCollectionResponse;

    if (!response.ok) {
        throw new Error(`Cannot read Qdrant collection: ${response.status} ${text}`);
    }

    return payload;
};

/**
 * Ensures the Qdrant collection exists with the correct vector configuration.
 *
 * - If collection already exists with correct size → no-op (logs info).
 * - If collection already exists with WRONG size → logs WARNING, does NOT
 *   delete or recreate (manual action required to avoid data loss).
 * - If collection does not exist → creates it with Cosine distance.
 * - If QDRANT_URL is not configured → returns early with a warning.
 */
export const ensureListingVectorCollection = async (): Promise<void> => {
    if (!isQdrantConfigured()) {
        logger.warn("Qdrant: QDRANT_URL is not set — semantic search is disabled");
        return;
    }

    const collectionName = getQdrantCollectionName();
    const dimensions = getEmbeddingDimension();

    let existingCollection: QdrantCollectionResponse | null;

    try {
        existingCollection = await getExistingCollection();
    } catch (error) {
        throw new Error(
            `Qdrant: Failed to check collection "${collectionName}": ${
                error instanceof Error ? error.message : String(error)
            }`,
        );
    }

    if (existingCollection) {
        const existingSize =
            existingCollection.result?.config?.params?.vectors?.size;

        if (existingSize !== undefined && existingSize !== dimensions) {
            logger.warn(
                `Qdrant: Collection "${collectionName}" exists but has vector size ${existingSize} ` +
                `while EMBEDDING_DIMENSIONS=${dimensions}. ` +
                `To fix: delete the collection manually on Qdrant Cloud and restart the server.`,
                { collectionName, existingSize, expectedSize: dimensions },
            );
            // Do NOT throw — allow server to start; search will fail gracefully per request.
            return;
        }

        logger.info("Qdrant: Collection exists and is ready", {
            collectionName,
            vectorSize: existingSize ?? dimensions,
            distance: "Cosine",
        });
        return;
    }

    // Collection does not exist — create it.
    logger.info("Qdrant: Collection not found — creating now", {
        collectionName,
        vectorSize: dimensions,
        distance: "Cosine",
    });

    await requestQdrant(`/collections/${encodeURIComponent(collectionName)}`, {
        method: "PUT",
        body: JSON.stringify({
            vectors: {
                size: dimensions,
                distance: "Cosine",
            },
        }),
    });

    logger.info("Qdrant: Collection created successfully", {
        collectionName,
        vectorSize: dimensions,
        distance: "Cosine",
    });
};

/**
 * Initializes Qdrant collections at server startup.
 *
 * Wraps ensureListingVectorCollection with full logging and graceful error
 * handling: a Qdrant error will NOT crash the server but is logged as error.
 */
export const initQdrantCollections = async (): Promise<{
    status: "ok" | "not_configured" | "error";
    detail?: string;
}> => {
    if (!isQdrantConfigured()) {
        logger.warn("Qdrant: Skipping collection init — QDRANT_URL not set");
        return { status: "not_configured", detail: "QDRANT_URL not set" };
    }

    try {
        await ensureListingVectorCollection();
        return { status: "ok" };
    } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);
        logger.error("Qdrant: Collection init failed", error, { detail });
        return { status: "error", detail };
    }
};

/**
 * Quick connectivity check — resolves with status string, never throws.
 */
export const checkQdrantHealth = async (): Promise<"connected" | "not_configured" | "error"> => {
    if (!isQdrantConfigured()) return "not_configured";

    try {
        await requestQdrant<unknown>("/collections", { method: "GET" });
        return "connected";
    } catch {
        return "error";
    }
};

// ─── Vector CRUD ──────────────────────────────────────────────────────────────

export const upsertListingVectors = async (
    points: Array<{
        id: number;
        vector: number[];
        payload: ListingVectorPayload;
    }>,
): Promise<void> => {
    if (points.length === 0) return;

    const collectionName = getQdrantCollectionName();

    await requestQdrant(
        `/collections/${encodeURIComponent(collectionName)}/points?wait=true`,
        {
            method: "PUT",
            body: JSON.stringify({ points }),
        },
    );
};

export const deleteListingVector = async (listingId: number): Promise<void> => {
    const collectionName = getQdrantCollectionName();

    await requestQdrant(
        `/collections/${encodeURIComponent(collectionName)}/points/delete?wait=true`,
        {
            method: "POST",
            body: JSON.stringify({ points: [listingId] }),
        },
    );
};

// ─── Search ───────────────────────────────────────────────────────────────────

const buildQdrantFilter = (filters: SemanticSearchFilters) => {
    const must: unknown[] = [
        {
            key: "status",
            match: { any: semanticPublicListingStatuses },
        },
    ];

    if (filters.forceVungTauOnly) {
        must.push({ key: "location_keys", match: { value: "vung_tau" } });
    } else if (filters.cityKey) {
        must.push({ key: "city_key", match: { value: filters.cityKey } });
    }

    if (filters.locationAreaFilterMode === "hard" && filters.vungTauAreaKeys.length > 0) {
        must.push({ key: "vung_tau_area_keys", match: { any: filters.vungTauAreaKeys } });
    }

    if (filters.districtKey) {
        must.push({ key: "district_key", match: { value: filters.districtKey } });
    }

    if (filters.guests) {
        must.push({ key: "max_guests", range: { gte: filters.guests } });
    }

    if (filters.minPrice !== undefined || filters.maxPrice !== undefined) {
        must.push({
            key: "base_price",
            range: {
                ...(filters.minPrice !== undefined ? { gte: filters.minPrice } : {}),
                ...(filters.maxPrice !== undefined ? { lte: filters.maxPrice } : {}),
            },
        });
    }

    if (filters.propertyType) {
        must.push({ key: "property_type", match: { value: filters.propertyType } });
    }

    if (filters.roomType) {
        must.push({ key: "room_type", match: { value: filters.roomType } });
    }

    return { must };
};

type QdrantSearchResponse = {
    result: Array<{
        id: string | number;
        score: number;
        payload: ListingVectorPayload;
    }>;
};

export const searchListingVectors = async (
    vector: number[],
    filters: SemanticSearchFilters,
    limit = 250,
): Promise<VectorSearchHit[]> => {
    const collectionName = getQdrantCollectionName();

    const response = await requestQdrant<QdrantSearchResponse>(
        `/collections/${encodeURIComponent(collectionName)}/points/search`,
        {
            method: "POST",
            body: JSON.stringify({
                vector,
                limit,
                with_payload: true,
                with_vector: false,
                filter: buildQdrantFilter(filters),
            }),
        },
    );

    return response.result.map((hit) => ({
        id: hit.id,
        score: Number(hit.score),
        payload: hit.payload,
    }));
};
