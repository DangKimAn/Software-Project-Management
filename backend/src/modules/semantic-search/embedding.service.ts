import { ApiError } from "../../common/api-error";

const openAiEmbeddingUrl = "https://api.openai.com/v1/embeddings";
const defaultEmbeddingModel = "text-embedding-3-small";
const defaultTimeoutMs = 20_000;
const defaultMaxRetries = 2;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const readJson = async (response: Response): Promise<unknown> => {
    const text = await response.text();

    if (!text) {
        return null;
    }

    try {
        return JSON.parse(text) as unknown;
    } catch {
        return text;
    }
};

const isEmbeddingResponse = (value: unknown): value is { data: Array<{ embedding: number[] }> } => {
    if (!value || typeof value !== "object") return false;

    const data = (value as { data?: unknown }).data;

    return Array.isArray(data) && Array.isArray((data[0] as { embedding?: unknown } | undefined)?.embedding);
};

export const getEmbeddingDimension = () => Number(process.env.EMBEDDING_DIMENSIONS ?? 1536);
export const getEmbeddingProvider = () => process.env.EMBEDDING_PROVIDER ?? "openai";
export const getEmbeddingModel = () => process.env.EMBEDDING_MODEL ?? defaultEmbeddingModel;

export const generateEmbedding = async (text: string): Promise<number[]> => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
        throw new ApiError(503, "OPENAI_API_KEY is not configured");
    }

    const model = getEmbeddingModel();
    const dimensions = getEmbeddingDimension();
    const timeoutMs = Number(process.env.EMBEDDING_TIMEOUT_MS ?? defaultTimeoutMs);
    const maxRetries = Number(process.env.EMBEDDING_MAX_RETRIES ?? defaultMaxRetries);

    let lastError: unknown;

    for (let attempt = 0; attempt <= maxRetries; attempt += 1) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), timeoutMs);

        try {
            const response = await fetch(openAiEmbeddingUrl, {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${apiKey}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    model,
                    input: text,
                    dimensions,
                }),
                signal: controller.signal,
            });

            const payload = await readJson(response);

            if (!response.ok) {
                throw new Error(`Embedding provider returned ${response.status}: ${JSON.stringify(payload)}`);
            }

            if (!isEmbeddingResponse(payload)) {
                throw new Error("Embedding provider returned an invalid response");
            }

            const embedding = payload.data[0]?.embedding;

            if (!embedding || embedding.length !== dimensions || embedding.some((value) => !Number.isFinite(value))) {
                throw new Error(`Embedding vector must contain ${dimensions} finite numbers`);
            }

            return embedding;
        } catch (error) {
            lastError = error;

            if (attempt < maxRetries) {
                await sleep(300 * (attempt + 1));
            }
        } finally {
            clearTimeout(timeout);
        }
    }

    const message = lastError instanceof Error ? lastError.message : "Cannot generate embedding";
    throw new ApiError(503, `Cannot generate embedding: ${message}`);
};
