import "dotenv/config";

import sequelize from "../config/database";
import { logger } from "../config/logger";
import { ensureListingVectorCollection } from "../modules/semantic-search/qdrant-vector.service";
import { reindexListingRecord } from "../modules/semantic-search/semantic-search.indexer";
import {
    getActiveListingIndexRecords,
} from "../modules/semantic-search/semantic-search.repository";
import { shouldForceVungTauOnly } from "../modules/semantic-search/semantic-search.utils";

const batchSize = Number(process.env.SEMANTIC_REINDEX_BATCH_SIZE ?? 12);

const chunk = <T>(items: T[], size: number) => {
    const chunks: T[][] = [];

    for (let index = 0; index < items.length; index += size) {
        chunks.push(items.slice(index, index + size));
    }

    return chunks;
};

const main = async () => {
    await sequelize.authenticate();
    await ensureListingVectorCollection();

    const forceVungTauOnly = shouldForceVungTauOnly();
    const records = await getActiveListingIndexRecords(forceVungTauOnly);

    let successCount = 0;
    let failedCount = 0;

    logger.info("Starting Vung Tau semantic search reindex", {
        total: records.length,
        batchSize,
        forceVungTauOnly,
    });

    for (const batch of chunk(records, batchSize)) {
        for (const record of batch) {
            try {
                await reindexListingRecord(record);
                successCount += 1;
            } catch (error) {
                failedCount += 1;

                logger.error("Failed to build embedding for listing", error, {
                    listingId: record.listing.listingId,
                });
            }
        }

        logger.info("Vung Tau semantic search reindex batch processed", {
            batchSize: batch.length,
            successCount,
            failedCount,
        });
    }

    logger.info("Vung Tau semantic search reindex completed", {
        successCount,
        failedCount,
        total: records.length,
    });

    await sequelize.close();
};

main().catch(async (error) => {
    logger.error("Semantic search reindex crashed", error);
    await sequelize.close();
    process.exit(1);
});
