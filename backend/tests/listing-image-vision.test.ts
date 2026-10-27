const assert = require("node:assert/strict");
const { afterEach, describe, it } = require("node:test");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";

type PatchEntry = [Record<string, unknown>, string, unknown];

const patches: PatchEntry[] = [];

const patch = (target: Record<string, unknown>, key: string, value: unknown) => {
    patches.push([target, key, target[key]]);
    target[key] = value;
};

afterEach(() => {
    while (patches.length > 0) {
        const [target, key, value] = patches.pop()!;
        target[key] = value;
    }
});

type VisionResult = {
    caption: string;
    roomType: string;
    objects: string[];
    amenities: string[];
    styleTags: string[];
    qualityTags: string[];
    searchTags: string[];
    confidence: number;
};

describe("listing image vision multi-label taxonomy", () => {
    it("declares timestamp defaults for AI image analysis tables", () => {
        const ImageAnalysisResult = require("../dist/models/image-analysis-result").default;
        const ImageTag = require("../dist/models/image-tag").default;
        const ListingImage = require("../dist/models/listing-image").default;

        assert.equal(ImageAnalysisResult.rawAttributes.createdAt.field, "created_at");
        assert.equal(ImageAnalysisResult.rawAttributes.createdAt.allowNull, false);
        assert.ok(ImageAnalysisResult.rawAttributes.createdAt.defaultValue);
        assert.equal(ImageAnalysisResult.rawAttributes.updatedAt.field, "updated_at");
        assert.equal(ImageAnalysisResult.rawAttributes.updatedAt.allowNull, false);
        assert.ok(ImageAnalysisResult.rawAttributes.updatedAt.defaultValue);

        assert.equal(ImageTag.rawAttributes.createdAt.field, "created_at");
        assert.equal(ImageTag.rawAttributes.createdAt.allowNull, false);
        assert.ok(ImageTag.rawAttributes.createdAt.defaultValue);

        assert.equal(ListingImage.rawAttributes.createdAt.field, "created_at");
        assert.equal(ListingImage.rawAttributes.updatedAt.field, "updated_at");
        assert.ok(ListingImage.rawAttributes.createdAt.defaultValue);
        assert.ok(ListingImage.rawAttributes.updatedAt.defaultValue);
    });

    it("maps bedroom, pool, BBQ, toilet, and sea-view uploads to canonical image tags", () => {
        const { mapVisionResultToTaxonomyTags } = require("../dist/modules/ai/listing-image-vision.service");
        const cases: Array<{ name: string; result: VisionResult; expectedTags: string[] }> = [
            {
                name: "bedroom upload",
                result: {
                    caption: "Phòng ngủ sáng, có giường đôi và máy lạnh.",
                    roomType: "bedroom",
                    objects: ["giường đôi", "máy lạnh"],
                    amenities: ["máy lạnh"],
                    styleTags: ["hiện đại"],
                    qualityTags: [],
                    searchTags: ["phòng ngủ", "giường đôi", "máy lạnh", "hiện đại"],
                    confidence: 0.93,
                },
                expectedTags: ["bedroom", "double_bed", "air_conditioner", "modern"],
            },
            {
                name: "pool upload",
                result: {
                    caption: "Hồ bơi ngoài trời cạnh sân vườn.",
                    roomType: "pool",
                    objects: [],
                    amenities: ["hồ bơi", "sân vườn"],
                    styleTags: [],
                    qualityTags: ["phù hợp gia đình"],
                    searchTags: ["hồ bơi", "sân vườn", "phù hợp gia đình"],
                    confidence: 0.91,
                },
                expectedTags: ["pool", "garden", "family_friendly"],
            },
            {
                name: "BBQ upload",
                result: {
                    caption: "Khu BBQ ngoài trời có bàn ăn dài.",
                    roomType: "bbq_area",
                    objects: ["bàn ăn"],
                    amenities: ["BBQ"],
                    styleTags: [],
                    qualityTags: ["phù hợp nhóm đông người"],
                    searchTags: ["BBQ", "bàn ăn", "phù hợp nhóm đông người"],
                    confidence: 0.88,
                },
                expectedTags: ["bbq", "dining_table", "large_group_friendly"],
            },
            {
                name: "toilet upload",
                result: {
                    caption: "Toilet sạch có bồn tắm.",
                    roomType: "bathroom",
                    objects: ["bồn tắm"],
                    amenities: ["toilet"],
                    styleTags: [],
                    qualityTags: [],
                    searchTags: ["toilet", "bồn tắm"],
                    confidence: 0.9,
                },
                expectedTags: ["toilet", "bathtub"],
            },
            {
                name: "sea view upload",
                result: {
                    caption: "Ban công nhìn ra biển.",
                    roomType: "balcony",
                    objects: [],
                    amenities: ["ban công"],
                    styleTags: ["sang trọng"],
                    qualityTags: [],
                    searchTags: ["ban công", "view biển", "sang trọng"],
                    confidence: 0.89,
                },
                expectedTags: ["balcony", "sea_view", "luxury"],
            },
        ];

        for (const item of cases) {
            const tags = mapVisionResultToTaxonomyTags(item.result).map((tag: { code: string }) => tag.code);

            for (const expectedTag of item.expectedTags) {
                assert.equal(tags.includes(expectedTag), true, `${item.name} should include ${expectedTag}`);
            }
        }
    });

    it("marks an uploaded listing image as failed when OpenAI Vision is unavailable", async () => {
        const service = require("../dist/modules/ai/listing-image-vision.service");
        const Listing = require("../dist/models/listing").default;
        const ListingImage = require("../dist/models/listing-image").default;
        const ImageAnalysisResult = require("../dist/models/image-analysis-result").default;
        const ImageTag = require("../dist/models/image-tag").default;
        const previousApiKey = process.env.OPENAI_API_KEY;

        delete process.env.OPENAI_API_KEY;

        const image: Record<string, unknown> = {
            id: 501,
            listingId: 701,
            url: "https://example.com/listing.jpg",
            objectKey: null,
            originalFilename: "listing.jpg",
            displayTitle: null,
            altText: null,
            caption: null,
            aiImageType: null,
            aiSceneTags: null,
            aiAmenityTags: null,
            aiDescription: null,
            aiConfidence: null,
            aiQualityWarnings: null,
            aiAnalysisStatus: "pending",
            aiErrorMessage: null,
            aiAnalyzedAt: null,
            sortOrder: 0,
            isCover: false,
            update: async (values: Record<string, unknown>) => {
                Object.assign(image, values);
                return image;
            },
        };
        const analysis: Record<string, unknown> = {
            id: 601,
            imageId: 501,
            provider: "openai",
            model: "gpt-4.1-mini",
            status: "pending",
            caption: null,
            roomType: null,
            detectedObjects: null,
            amenities: null,
            styleTags: null,
            qualityTags: null,
            rawResponse: null,
            confidence: null,
            errorMessage: null,
            analyzedAt: null,
            createdAt: new Date("2026-06-10T00:00:00.000Z"),
            updatedAt: new Date("2026-06-10T00:00:00.000Z"),
            update: async (values: Record<string, unknown>) => {
                Object.assign(analysis, values);
                return analysis;
            },
        };

        try {
            patch(Listing, "findOne", async () => ({ listingId: 701, hostId: 101, deletedAt: null }));
            patch(ListingImage, "findOne", async () => image);
            patch(ImageAnalysisResult, "create", async (payload: Record<string, unknown>) => {
                assert.equal(payload.imageId, 501);
                assert.equal(payload.status, "pending");
                assert.equal(Object.prototype.hasOwnProperty.call(payload, "created_at"), false);
                return analysis;
            });
            patch(ImageAnalysisResult, "findAll", async () => [analysis]);
            patch(ImageTag, "findAll", async () => []);

            const result = await service.analyzeListingImage(701, 501, {
                userId: "101",
                isAdmin: false,
            });

            assert.equal(result.aiAnalysisStatus, "failed");
            assert.match(result.aiErrorMessage, /OPENAI_API_KEY is not configured/);
            assert.equal(analysis.status, "failed");
            assert.match(String(analysis.errorMessage), /OPENAI_API_KEY is not configured/);
        } finally {
            if (previousApiKey === undefined) {
                delete process.env.OPENAI_API_KEY;
            } else {
                process.env.OPENAI_API_KEY = previousApiKey;
            }
        }
    });
});

export {};
