/**
 * Manual Qdrant health-check and collection bootstrap script.
 *
 * Usage:
 *   npm run qdrant:check
 *
 * What it does:
 *   1. Reads QDRANT_URL and QDRANT_API_KEY from environment.
 *   2. Connects to Qdrant and lists collections.
 *   3. Checks whether the target collection exists.
 *   4. Creates the collection if it does not exist.
 *   5. Prints a clear summary with all relevant env values.
 *
 * Exit code: 0 = success / 1 = error
 */

import "dotenv/config";

const getEnv = (key: string, fallback?: string): string | undefined =>
    process.env[key]?.trim() || fallback;

const qdrantUrl = (getEnv("QDRANT_URL") ?? "").replace(/\/$/, "");
const qdrantApiKey = getEnv("QDRANT_API_KEY");
const collectionName =
    getEnv("QDRANT_COLLECTION_LISTINGS") ||
    getEnv("QDRANT_COLLECTION") ||
    "booking_listings";
const embeddingDimensions = Number(getEnv("EMBEDDING_DIMENSIONS") ?? 1536);
const embeddingModel = getEnv("EMBEDDING_MODEL") ?? "text-embedding-3-small";

const buildHeaders = (): Record<string, string> => {
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (qdrantApiKey) headers["api-key"] = qdrantApiKey;
    return headers;
};

const printSeparator = () => console.log("─".repeat(60));

const main = async () => {
    printSeparator();
    console.log("🔍  Qdrant Collection Check");
    printSeparator();
    console.log(`  QDRANT_URL            : ${qdrantUrl || "(not set)"}`);
    console.log(`  QDRANT_API_KEY        : ${qdrantApiKey ? "[set]" : "(not set)"}`);
    console.log(`  Collection name       : ${collectionName}`);
    console.log(`  Embedding model       : ${embeddingModel}`);
    console.log(`  Embedding dimensions  : ${embeddingDimensions}`);
    console.log(`  Distance metric       : Cosine`);
    printSeparator();

    if (!qdrantUrl) {
        console.error("❌  QDRANT_URL is not set. Please add it to your .env file.");
        process.exit(1);
    }

    // ── Step 1: List collections ───────────────────────────────────────────────
    console.log("\n[1/3] Connecting to Qdrant…");

    const listRes = await fetch(`${qdrantUrl}/collections`, {
        method: "GET",
        headers: buildHeaders(),
    });

    if (!listRes.ok) {
        const body = await listRes.text();
        console.error(`❌  Qdrant returned ${listRes.status}: ${body}`);
        process.exit(1);
    }

    const listData = (await listRes.json()) as {
        result?: { collections?: Array<{ name: string }> };
    };
    const existingNames = (listData.result?.collections ?? []).map((c) => c.name);

    console.log(`✅  Connected. Existing collections: [${existingNames.join(", ") || "none"}]`);

    // ── Step 2: Check target collection ───────────────────────────────────────
    console.log(`\n[2/3] Checking collection "${collectionName}"…`);

    const infoRes = await fetch(
        `${qdrantUrl}/collections/${encodeURIComponent(collectionName)}`,
        { method: "GET", headers: buildHeaders() },
    );

    if (infoRes.status === 404) {
        // ── Step 3: Create collection ──────────────────────────────────────────
        console.log(`⚠️   Collection "${collectionName}" not found.`);
        console.log(`\n[3/3] Creating collection "${collectionName}"…`);

        const createRes = await fetch(
            `${qdrantUrl}/collections/${encodeURIComponent(collectionName)}`,
            {
                method: "PUT",
                headers: buildHeaders(),
                body: JSON.stringify({
                    vectors: {
                        size: embeddingDimensions,
                        distance: "Cosine",
                    },
                }),
            },
        );

        if (!createRes.ok) {
            const body = await createRes.text();
            console.error(`❌  Failed to create collection: ${createRes.status} — ${body}`);
            process.exit(1);
        }

        console.log(`✅  Collection "${collectionName}" created!`);
        console.log(`    vector size : ${embeddingDimensions}`);
        console.log(`    distance    : Cosine`);
    } else if (infoRes.ok) {
        const infoData = (await infoRes.json()) as {
            result?: { config?: { params?: { vectors?: { size?: number; distance?: string } } } };
        };
        const existingSize = infoData.result?.config?.params?.vectors?.size;
        const existingDistance = infoData.result?.config?.params?.vectors?.distance;

        console.log(`✅  Collection "${collectionName}" already exists.`);
        console.log(`    vector size : ${existingSize ?? "unknown"}`);
        console.log(`    distance    : ${existingDistance ?? "unknown"}`);

        if (existingSize !== undefined && existingSize !== embeddingDimensions) {
            console.warn(
                `\n⚠️  WARNING: Vector size mismatch!` +
                `\n   Collection has size ${existingSize} but EMBEDDING_DIMENSIONS=${embeddingDimensions}.` +
                `\n   Fix: Delete the collection manually on Qdrant Cloud, then re-run this script.`,
            );
        }

        console.log("\n[3/3] No action needed.");
    } else {
        const body = await infoRes.text();
        console.error(`❌  Qdrant error ${infoRes.status}: ${body}`);
        process.exit(1);
    }

    printSeparator();
    console.log("🎉  Done. Collection is ready.");
    printSeparator();
};

main().catch((error: unknown) => {
    console.error("\n❌  Unexpected error:", error instanceof Error ? error.message : error);
    process.exit(1);
});
