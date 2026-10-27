import { logger } from "../../config/logger";
import { getEmbeddingModel, getEmbeddingProvider, generateEmbedding } from "./embedding.service";
import {
    deleteListingVector,
    ensureListingVectorCollection,
    upsertListingVectors,
} from "./qdrant-vector.service";
import {
    buildListingSearchDocument,
    buildListingVectorPayload,
    getListingIndexRecord,
    ListingIndexRecord,
    upsertListingEmbeddingRecord,
} from "./semantic-search.repository";
import { shouldForceVungTauOnly } from "./semantic-search.utils";

export const getSemanticIndexVersion = () => process.env.SEMANTIC_INDEX_VERSION ?? "v1";

export const reindexListingRecord = async (record: ListingIndexRecord) => {
    const searchableText = buildListingSearchDocument(record);
    const embeddingVector = await generateEmbedding(searchableText);
    const payload = buildListingVectorPayload(record);

    await ensureListingVectorCollection();
    await upsertListingVectors([
        {
            id: record.listing.listingId,
            vector: embeddingVector,
            payload,
        },
    ]);

    await record.listing.update({
        searchText: searchableText,
        searchEmbeddingJson: embeddingVector,
        searchEmbeddingUpdatedAt: new Date(),
    });

    await upsertListingEmbeddingRecord({
        listingId: record.listing.listingId,
        embeddingProvider: getEmbeddingProvider(),
        embeddingModel: getEmbeddingModel(),
        embeddingVector,
        qdrantPointId: String(record.listing.listingId),
        searchableText,
        version: getSemanticIndexVersion(),
    });

    return {
        listingId: record.listing.listingId,
        searchableText,
        embeddingDimensions: embeddingVector.length,
    };
};

export const reindexListingById = async (listingId: number) => {
    const record = await getListingIndexRecord(listingId, shouldForceVungTauOnly());

    if (!record) {
        await deleteListingVector(listingId).catch(() => undefined);
        return {
            listingId,
            indexed: false,
        };
    }

    const result = await reindexListingRecord(record);

    return {
        ...result,
        indexed: true,
    };
};

export const scheduleSemanticReindex = (listingId: number, reason: string) => {
    if (process.env.NODE_ENV === "test" && process.env.SEMANTIC_AUTO_REINDEX_TEST !== "true") {
        return;
    }

    if ((process.env.SEMANTIC_AUTO_REINDEX ?? "true").toLowerCase() === "false") {
        return;
    }

    setTimeout(() => {
        void reindexListingById(listingId).catch((error) => {
            logger.warn("Semantic reindex trigger failed", {
                listingId,
                reason,
                errorMessage: error instanceof Error ? error.message : String(error),
            });
        });
    }, 0);
};
