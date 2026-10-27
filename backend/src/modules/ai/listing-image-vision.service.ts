import { GetObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import OpenAI from "openai";
import { Op, type Transaction } from "sequelize";
import { z } from "zod";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import sequelize from "../../config/database";
import ImageAnalysisResult, { type ImageAnalysisResultDocument } from "../../models/image-analysis-result";
import ImageTag, { type ImageTagDocument, type ImageTagSource } from "../../models/image-tag";
import Listing, { type ListingDocument, type ListingImageRecord } from "../../models/listing";
import ListingImage, { type ListingImageDocument } from "../../models/listing-image";
import TagTaxonomy, { type TagTaxonomyDocument } from "../../models/tag-taxonomy";
import {
    checkListingOwner,
    deleteListingImage,
    type HostActor,
} from "../host-listings/host-listings.service";
import { scheduleSemanticReindex } from "../semantic-search/semantic-search.indexer";

const roomTypeValues = [
    "bedroom",
    "bathroom",
    "kitchen",
    "living_room",
    "pool",
    "garden",
    "balcony",
    "exterior",
    "dining_area",
    "karaoke_room",
    "bbq_area",
    "unknown",
] as const;

export type AiImageRoomType = (typeof roomTypeValues)[number];

export type ImageTagTaxonomy = {
    code: string;
    labelVi: string;
    group: string;
    aliases: string[];
    isSearchable: boolean;
};

export const imageTagTaxonomy: ImageTagTaxonomy[] = [
    { code: "bedroom", labelVi: "phòng ngủ", group: "room", aliases: ["bedroom", "phong ngu", "phòng ngủ", "giường ngủ"], isSearchable: true },
    { code: "double_bed", labelVi: "giường đôi", group: "object", aliases: ["double bed", "giuong doi", "giường đôi", "queen bed", "king bed"], isSearchable: true },
    { code: "pool", labelVi: "hồ bơi", group: "amenity", aliases: ["pool", "swimming pool", "ho boi", "hồ bơi", "bể bơi"], isSearchable: true },
    { code: "garden", labelVi: "sân vườn", group: "amenity", aliases: ["garden", "san vuon", "sân vườn", "vườn", "cây xanh"], isSearchable: true },
    { code: "bbq", labelVi: "BBQ", group: "amenity", aliases: ["bbq", "barbecue", "bếp nướng", "khu nướng", "lò nướng ngoài trời"], isSearchable: true },
    { code: "kitchen", labelVi: "bếp", group: "room", aliases: ["kitchen", "bep", "bếp", "nhà bếp", "khu bếp"], isSearchable: true },
    { code: "living_room", labelVi: "phòng khách", group: "room", aliases: ["living room", "phong khach", "phòng khách", "sảnh khách"], isSearchable: true },
    { code: "toilet", labelVi: "toilet", group: "room", aliases: ["toilet", "bathroom", "phòng tắm", "phòng vệ sinh", "nhà vệ sinh", "wc"], isSearchable: true },
    { code: "bathtub", labelVi: "bồn tắm", group: "object", aliases: ["bathtub", "bon tam", "bồn tắm", "tub"], isSearchable: true },
    { code: "balcony", labelVi: "ban công", group: "amenity", aliases: ["balcony", "ban cong", "ban công", "terrace"], isSearchable: true },
    { code: "sea_view", labelVi: "view biển", group: "view", aliases: ["sea view", "ocean view", "view bien", "view biển", "nhìn ra biển"], isSearchable: true },
    { code: "karaoke", labelVi: "karaoke", group: "amenity", aliases: ["karaoke", "phòng karaoke", "loa karaoke", "micro karaoke"], isSearchable: true },
    { code: "billiards", labelVi: "bàn bida", group: "amenity", aliases: ["billiards", "pool table", "ban bida", "bàn bida", "bida"], isSearchable: true },
    { code: "front_view", labelVi: "mặt tiền", group: "exterior", aliases: ["front view", "facade", "mat tien", "mặt tiền", "ngoại thất", "exterior"], isSearchable: true },
    { code: "garage", labelVi: "gara", group: "amenity", aliases: ["garage", "gara", "nhà xe", "chỗ đậu xe", "parking garage"], isSearchable: true },
    { code: "air_conditioner", labelVi: "máy lạnh", group: "amenity", aliases: ["air conditioner", "air conditioning", "may lanh", "máy lạnh", "điều hòa"], isSearchable: true },
    { code: "sofa", labelVi: "sofa", group: "object", aliases: ["sofa", "ghế sofa", "couch"], isSearchable: true },
    { code: "dining_table", labelVi: "bàn ăn", group: "object", aliases: ["dining table", "ban an", "bàn ăn", "khu ăn uống"], isSearchable: true },
    { code: "modern", labelVi: "hiện đại", group: "style", aliases: ["modern", "hien dai", "hiện đại", "contemporary"], isSearchable: true },
    { code: "luxury", labelVi: "sang trọng", group: "style", aliases: ["luxury", "sang trong", "sang trọng", "cao cấp"], isSearchable: true },
    { code: "family_friendly", labelVi: "phù hợp gia đình", group: "quality", aliases: ["family friendly", "phu hop gia dinh", "phù hợp gia đình", "gia đình"], isSearchable: true },
    { code: "large_group_friendly", labelVi: "phù hợp nhóm đông người", group: "quality", aliases: ["large group", "nhom dong nguoi", "nhóm đông người", "phù hợp nhóm đông người"], isSearchable: true },
];

const taxonomyByCode = new Map(imageTagTaxonomy.map((item) => [item.code, item]));

const displayTitleByRoomType: Record<AiImageRoomType, string> = {
    bedroom: "Phòng ngủ",
    bathroom: "Toilet",
    kitchen: "Bếp",
    living_room: "Phòng khách",
    pool: "Hồ bơi",
    garden: "Sân vườn",
    balcony: "Ban công",
    exterior: "Mặt tiền",
    dining_area: "Khu bàn ăn",
    karaoke_room: "Phòng karaoke",
    bbq_area: "Khu BBQ",
    unknown: "Ảnh chỗ nghỉ",
};

const roomTypeToTagCodes: Partial<Record<AiImageRoomType, string[]>> = {
    bedroom: ["bedroom"],
    bathroom: ["toilet"],
    kitchen: ["kitchen"],
    living_room: ["living_room"],
    pool: ["pool"],
    garden: ["garden"],
    balcony: ["balcony"],
    exterior: ["front_view"],
    dining_area: ["dining_table"],
    karaoke_room: ["karaoke"],
    bbq_area: ["bbq"],
};

const aiVisionResponseSchema = z.object({
    caption: z.string().trim().min(1).max(1000),
    roomType: z.enum(roomTypeValues),
    objects: z.array(z.string().trim().min(1).max(80)).max(24),
    amenities: z.array(z.string().trim().min(1).max(80)).max(24),
    styleTags: z.array(z.string().trim().min(1).max(80)).max(12),
    qualityTags: z.array(z.string().trim().min(1).max(80)).max(12),
    searchTags: z.array(z.string().trim().min(1).max(80)).max(24),
    confidence: z.number().min(0).max(1),
});

export type AiVisionResponse = z.infer<typeof aiVisionResponseSchema>;

type AnalyzeListingImagesOptions = {
    force?: boolean;
};

type OpenAiVisionResult = {
    result: AiVisionResponse;
    provider: string;
    model: string;
    rawResponse: Record<string, unknown>;
};

const imageAnalysisJsonSchema = {
    type: "object",
    additionalProperties: false,
    required: ["caption", "roomType", "objects", "amenities", "styleTags", "qualityTags", "searchTags", "confidence"],
    properties: {
        caption: { type: "string", minLength: 1, maxLength: 1000 },
        roomType: { type: "string", enum: roomTypeValues },
        objects: {
            type: "array",
            maxItems: 24,
            items: { type: "string", minLength: 1, maxLength: 80 },
        },
        amenities: {
            type: "array",
            maxItems: 24,
            items: { type: "string", minLength: 1, maxLength: 80 },
        },
        styleTags: {
            type: "array",
            maxItems: 12,
            items: { type: "string", minLength: 1, maxLength: 80 },
        },
        qualityTags: {
            type: "array",
            maxItems: 12,
            items: { type: "string", minLength: 1, maxLength: 80 },
        },
        searchTags: {
            type: "array",
            maxItems: 24,
            items: { type: "string", minLength: 1, maxLength: 80 },
        },
        confidence: { type: "number", minimum: 0, maximum: 1 },
    },
};

const truncate = (value: string, maxLength: number) =>
    value.length > maxLength ? `${value.slice(0, maxLength - 3)}...` : value;

const normalizeText = (value: string) =>
    value
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "d")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .trim();

const cleanStringList = (values: string[], maxItems: number) => {
    const result = new Map<string, string>();

    for (const value of values) {
        const trimmed = value.trim();
        const key = normalizeText(trimmed);

        if (trimmed && key && !result.has(key)) {
            result.set(key, truncate(trimmed, 80));
        }
    }

    return Array.from(result.values()).slice(0, maxItems);
};

const safeJsonArray = (value: unknown): string[] => {
    if (Array.isArray(value)) {
        return value.map(String).filter(Boolean);
    }

    if (typeof value === "string") {
        try {
            const parsed = JSON.parse(value) as unknown;
            return Array.isArray(parsed) ? parsed.map(String).filter(Boolean) : [];
        } catch {
            return [];
        }
    }

    return [];
};

const parseJsonObjectFromText = (text: string) => {
    try {
        return JSON.parse(text) as unknown;
    } catch {
        const match = text.match(/\{[\s\S]*\}/);
        if (!match) {
            throw new Error("AI response is not valid JSON");
        }

        return JSON.parse(match[0]) as unknown;
    }
};

const normalizeAiResult = (result: AiVisionResponse): AiVisionResponse => ({
    caption: truncate(result.caption.trim(), 1000) || "Ảnh chỗ nghỉ",
    roomType: result.roomType,
    objects: cleanStringList(result.objects, 24),
    amenities: cleanStringList(result.amenities, 24),
    styleTags: cleanStringList(result.styleTags, 12),
    qualityTags: cleanStringList(result.qualityTags, 12),
    searchTags: cleanStringList(result.searchTags, 24),
    confidence: Number(result.confidence.toFixed(4)),
});

const taxonomyAliasEntries = imageTagTaxonomy.flatMap((taxonomy) =>
    [taxonomy.code, taxonomy.labelVi, ...taxonomy.aliases].map((alias) => [normalizeText(alias), taxonomy.code] as const),
);
const taxonomyCodeByAlias = new Map(taxonomyAliasEntries);

const resolveTaxonomyCode = (value: string) => {
    const normalizedValue = normalizeText(value);

    if (!normalizedValue) {
        return null;
    }

    const exactMatch = taxonomyCodeByAlias.get(normalizedValue);
    if (exactMatch) {
        return exactMatch;
    }

    for (const [alias, code] of taxonomyCodeByAlias) {
        if (alias.length >= 4 && normalizedValue.length >= 4 && (normalizedValue.includes(alias) || alias.includes(normalizedValue))) {
            return code;
        }
    }

    return null;
};

const getTagLabel = (code: string) => taxonomyByCode.get(code)?.labelVi ?? code;
const getTagGroup = (code: string) => taxonomyByCode.get(code)?.group ?? "custom";

const buildVisionPrompt = () => `
Bạn là AI phân tích ảnh listing villa/homestay cho website booking.
Hãy nhìn ảnh và trả về duy nhất một JSON object hợp lệ, không markdown, không giải thích thêm.

Quy tắc bắt buộc:
- Caption viết tiếng Việt, ngắn, tự nhiên.
- Chỉ gắn tag thấy rõ trong ảnh.
- Không bịa tiện ích, không suy đoán tiện ích bị che khuất hoặc không xuất hiện.
- Nếu không chắc, để confidence thấp và không đưa tag đó vào các mảng.
- objects là vật thể nhìn thấy rõ.
- amenities là tiện ích nhìn thấy rõ.
- styleTags chỉ dùng khi phong cách nhìn rõ.
- qualityTags chỉ dùng khi ảnh cho thấy rõ phù hợp gia đình hoặc nhóm đông người.
- searchTags chỉ dùng đúng các tag phù hợp từ danh sách taxonomy.

Danh sách tag được phép dùng trong searchTags/styleTags/qualityTags/amenities/objects khi phù hợp:
${imageTagTaxonomy.map((item) => `- ${item.labelVi}`).join("\n")}

roomType chỉ được là một trong: ${roomTypeValues.join(" | ")}

JSON output bắt buộc, không thêm field khác:
{
  "caption": "Mô tả ngắn bằng tiếng Việt",
  "roomType": "bedroom | bathroom | kitchen | living_room | pool | garden | balcony | exterior | dining_area | karaoke_room | bbq_area | unknown",
  "objects": [],
  "amenities": [],
  "styleTags": [],
  "qualityTags": [],
  "searchTags": [],
  "confidence": 0.0
}
`;

const buildR2Client = () => {
    const env = getEnv();

    if (!env.r2AccountId || !env.r2AccessKeyId || !env.r2SecretAccessKey || !env.r2Bucket) {
        return null;
    }

    return {
        bucket: env.r2Bucket,
        client: new S3Client({
            region: "auto",
            endpoint: `https://${env.r2AccountId}.r2.cloudflarestorage.com`,
            credentials: {
                accessKeyId: env.r2AccessKeyId,
                secretAccessKey: env.r2SecretAccessKey,
            },
        }),
    };
};

const getSignedR2ReadUrl = async (objectKey?: string | null) => {
    if (!objectKey) {
        return null;
    }

    const r2 = buildR2Client();
    if (!r2) {
        return null;
    }

    try {
        return await getSignedUrl(
            r2.client,
            new GetObjectCommand({
                Bucket: r2.bucket,
                Key: objectKey,
            }),
            { expiresIn: 300 },
        );
    } catch {
        return null;
    }
};

const getImageUrlForVision = async (image: ListingImageDocument) => {
    const signedUrl = await getSignedR2ReadUrl(image.objectKey);
    return signedUrl ?? image.url;
};

const callOpenAiVision = async (image: ListingImageDocument): Promise<OpenAiVisionResult> => {
    const env = getEnv();

    if (!env.openaiApiKey) {
        throw new ApiError(503, "OPENAI_API_KEY is not configured");
    }

    const imageUrl = await getImageUrlForVision(image);
    const client = new OpenAI({ apiKey: env.openaiApiKey });
    const response = await client.responses.create({
        model: env.openaiVisionModel,
        temperature: 0.1,
        max_output_tokens: 900,
        store: false,
        instructions: "Bạn chỉ trả về JSON object hợp lệ theo schema đã cung cấp. Không markdown.",
        text: {
            format: {
                type: "json_schema",
                name: "listing_image_analysis",
                strict: true,
                schema: imageAnalysisJsonSchema,
            },
        },
        input: [
            {
                role: "user",
                content: [
                    {
                        type: "input_text",
                        text: buildVisionPrompt(),
                    },
                    {
                        type: "input_image",
                        image_url: imageUrl,
                        detail: "low",
                    },
                ],
            },
        ],
    });

    const responseRecord = response as unknown as Record<string, unknown>;
    const content = typeof response.output_text === "string" ? response.output_text.trim() : "";
    if (!content) {
        throw new Error("OpenAI Vision response did not contain output text");
    }

    const parsed = aiVisionResponseSchema.parse(parseJsonObjectFromText(content));

    return {
        result: normalizeAiResult(parsed),
        provider: "openai",
        model: env.openaiVisionModel,
        rawResponse: {
            id: responseRecord.id ?? null,
            model: responseRecord.model ?? env.openaiVisionModel,
            outputText: content,
            usage: responseRecord.usage ?? null,
        },
    };
};

const getListingForActor = async (listingId: number, actor: HostActor) => {
    const listing = await Listing.findOne({
        where: {
            listingId,
            deletedAt: null,
        },
    });

    if (!listing) {
        throw new ApiError(404, "Listing not found");
    }

    checkListingOwner(listing, actor);
    return listing;
};

const getImageForListing = async (listingId: number, imageId: number) => {
    const image = await ListingImage.findOne({
        where: {
            id: imageId,
            listingId,
        },
    });

    if (!image) {
        throw new ApiError(404, "Image not found");
    }

    return image;
};

const getImageById = async (imageId: number) => {
    const image = await ListingImage.findOne({
        where: {
            id: imageId,
        },
    });

    if (!image) {
        throw new ApiError(404, "Image not found");
    }

    return image;
};

const getImageForActor = async (imageId: number, actor: HostActor) => {
    const image = await getImageById(imageId);
    await getListingForActor(image.listingId, actor);
    return image;
};

const toListingImageRecord = (row: ListingImageDocument): ListingImageRecord => ({
    imageId: Number(row.id),
    url: row.url,
    objectKey: row.objectKey,
    key: row.objectKey,
    originalFilename: row.originalFilename,
    displayTitle: row.displayTitle,
    altText: row.altText,
    caption: row.caption,
    aiImageType: row.aiImageType,
    aiSceneTags: row.aiSceneTags,
    aiAmenityTags: row.aiAmenityTags,
    aiDescription: row.aiDescription,
    aiConfidence: row.aiConfidence,
    aiQualityWarnings: row.aiQualityWarnings,
    aiAnalysisStatus: row.aiAnalysisStatus,
    aiErrorMessage: row.aiErrorMessage,
    aiAnalyzedAt: row.aiAnalyzedAt,
    sortOrder: row.sortOrder,
    isCover: row.isCover,
});

const syncListingImageSnapshot = async (listing: ListingDocument, transaction?: Transaction) => {
    const rows = await ListingImage.findAll({
        where: {
            listingId: listing.listingId,
        },
        order: [
            ["isCover", "DESC"],
            ["sortOrder", "ASC"],
            ["id", "ASC"],
        ],
        transaction,
    });

    listing.images = rows.map(toListingImageRecord);
};

export const mapVisionResultToTaxonomyTags = (result: AiVisionResponse) => {
    const normalizedResult = normalizeAiResult(result);

    if (normalizedResult.confidence < 0.35) {
        return [];
    }

    const codes = new Set<string>(roomTypeToTagCodes[normalizedResult.roomType] ?? []);
    const rawTagValues = [
        ...normalizedResult.objects,
        ...normalizedResult.amenities,
        ...normalizedResult.styleTags,
        ...normalizedResult.qualityTags,
        ...normalizedResult.searchTags,
    ];

    for (const rawValue of rawTagValues) {
        const code = resolveTaxonomyCode(rawValue);
        if (code) {
            codes.add(code);
        }
    }

    return Array.from(codes)
        .map((code) => taxonomyByCode.get(code))
        .filter((taxonomy): taxonomy is ImageTagTaxonomy => Boolean(taxonomy));
};

const serializeTag = (tag: ImageTagDocument) => ({
    id: Number(tag.id),
    imageId: Number(tag.imageId),
    listingId: Number(tag.listingId),
    tag: tag.tag,
    code: tag.tag,
    labelVi: getTagLabel(tag.tag),
    tagGroup: tag.tagGroup,
    confidence: tag.confidence === null ? null : Number(tag.confidence),
    source: tag.source,
    createdAt: tag.createdAt,
});

const serializeAnalysis = (analysis: ImageAnalysisResultDocument | null) =>
    analysis
        ? {
              id: Number(analysis.id),
              imageId: Number(analysis.imageId),
              provider: analysis.provider,
              model: analysis.model,
              status: analysis.status,
              caption: analysis.caption,
              roomType: analysis.roomType,
              detectedObjects: safeJsonArray(analysis.detectedObjects),
              amenities: safeJsonArray(analysis.amenities),
              styleTags: safeJsonArray(analysis.styleTags),
              qualityTags: safeJsonArray(analysis.qualityTags),
              confidence: analysis.confidence === null ? null : Number(analysis.confidence),
              errorMessage: analysis.errorMessage,
              analyzedAt: analysis.analyzedAt,
              createdAt: analysis.createdAt,
              updatedAt: analysis.updatedAt,
          }
        : null;

const serializeTaxonomy = (taxonomy: ImageTagTaxonomy) => ({
    code: taxonomy.code,
    labelVi: taxonomy.labelVi,
    group: taxonomy.group,
    aliases: taxonomy.aliases,
    isSearchable: taxonomy.isSearchable,
});

export const getTagTaxonomies = async () => {
    const rows = await TagTaxonomy.findAll({
        order: [
            ["group", "ASC"],
            ["labelVi", "ASC"],
        ],
    }).catch(() => [] as TagTaxonomyDocument[]);

    if (rows.length === 0) {
        return imageTagTaxonomy.map(serializeTaxonomy);
    }

    return rows.map((row) => ({
        code: row.code,
        labelVi: row.labelVi,
        group: row.group,
        aliases: safeJsonArray(row.aliases),
        isSearchable: row.isSearchable,
    }));
};

const getLatestAnalysisByImageId = async (imageIds: number[]) => {
    if (imageIds.length === 0) {
        return new Map<number, ImageAnalysisResultDocument>();
    }

    const rows = await ImageAnalysisResult.findAll({
        where: {
            imageId: {
                [Op.in]: imageIds,
            },
        },
        order: [
            ["imageId", "ASC"],
            ["createdAt", "DESC"],
            ["id", "DESC"],
        ],
    });
    const latest = new Map<number, ImageAnalysisResultDocument>();

    for (const row of rows) {
        const imageId = Number(row.imageId);
        if (!latest.has(imageId)) {
            latest.set(imageId, row);
        }
    }

    return latest;
};

const getTagsByImageId = async (imageIds: number[]) => {
    if (imageIds.length === 0) {
        return new Map<number, ImageTagDocument[]>();
    }

    const rows = await ImageTag.findAll({
        where: {
            imageId: {
                [Op.in]: imageIds,
            },
        },
        order: [
            ["imageId", "ASC"],
            ["tagGroup", "ASC"],
            ["tag", "ASC"],
        ],
    });
    const map = new Map<number, ImageTagDocument[]>();

    for (const row of rows) {
        const imageId = Number(row.imageId);
        const current = map.get(imageId) ?? [];
        current.push(row);
        map.set(imageId, current);
    }

    return map;
};

const serializeAnalyzedImage = (
    image: ListingImageDocument,
    tags: ImageTagDocument[] = [],
    analysis: ImageAnalysisResultDocument | null = null,
) => ({
    imageId: Number(image.id),
    id: Number(image.id),
    listingId: image.listingId,
    url: image.url,
    displayTitle: image.displayTitle ?? null,
    altText: image.altText ?? null,
    caption: image.caption ?? null,
    aiImageType: image.aiImageType ?? null,
    aiSceneTags: safeJsonArray(image.aiSceneTags),
    aiAmenityTags: safeJsonArray(image.aiAmenityTags),
    aiDescription: image.aiDescription ?? null,
    aiConfidence: image.aiConfidence === null ? null : Number(image.aiConfidence),
    aiQualityWarnings: safeJsonArray(image.aiQualityWarnings),
    aiAnalysisStatus: image.aiAnalysisStatus,
    aiErrorMessage: image.aiErrorMessage ?? null,
    aiAnalyzedAt: image.aiAnalyzedAt ?? null,
    sortOrder: image.sortOrder,
    isCover: image.isCover,
    tags: tags.map(serializeTag),
    aiTags: tags.map(serializeTag),
    analysis: serializeAnalysis(analysis),
});

const serializeImageWithRelations = async (image: ListingImageDocument) => {
    const imageId = Number(image.id);
    const tagsByImageId = await getTagsByImageId([imageId]);
    const latestAnalysisByImageId = await getLatestAnalysisByImageId([imageId]);

    return serializeAnalyzedImage(
        image,
        tagsByImageId.get(imageId) ?? [],
        latestAnalysisByImageId.get(imageId) ?? null,
    );
};

const markImageFailed = async (
    image: ListingImageDocument,
    error: unknown,
    analysis: ImageAnalysisResultDocument | null,
) => {
    const message = error instanceof Error ? error.message : "Unknown AI image analysis error";
    const analyzedAt = new Date();

    await image.update({
        aiAnalysisStatus: "failed",
        aiErrorMessage: truncate(message, 5000),
        aiAnalyzedAt: analyzedAt,
    });

    if (analysis) {
        await analysis.update({
            status: "failed",
            errorMessage: truncate(message, 5000),
            analyzedAt,
        });
    }

    return serializeImageWithRelations(image);
};

const saveAnalysisTags = async (
    image: ListingImageDocument,
    vision: OpenAiVisionResult,
    analysis: ImageAnalysisResultDocument,
) => {
    const { result } = vision;
    const taxonomies = mapVisionResultToTaxonomyTags(result);
    const tagLabels = taxonomies.map((tag) => tag.labelVi);
    const confidence = result.confidence;
    const analyzedAt = new Date();
    const title = displayTitleByRoomType[result.roomType] ?? "Ảnh chỗ nghỉ";
    const sceneTags = cleanStringList(
        [
            title,
            ...result.objects,
            ...tagLabels.filter((label) => ["phòng ngủ", "phòng khách", "bếp", "toilet", "ban công", "view biển", "mặt tiền"].includes(label)),
        ],
        24,
    );
    const amenityTags = cleanStringList(
        [
            ...result.amenities,
            ...tagLabels.filter((label) => !sceneTags.includes(label)),
        ],
        24,
    );

    await sequelize.transaction(async (transaction) => {
        await analysis.update(
            {
                provider: vision.provider,
                model: vision.model,
                status: "analyzed",
                caption: result.caption,
                roomType: result.roomType,
                detectedObjects: result.objects,
                amenities: result.amenities,
                styleTags: result.styleTags,
                qualityTags: result.qualityTags,
                rawResponse: vision.rawResponse,
                confidence,
                errorMessage: null,
                analyzedAt,
            },
            { transaction },
        );

        await ImageTag.destroy({
            where: {
                imageId: Number(image.id),
            },
            transaction,
        });

        if (taxonomies.length > 0) {
            await ImageTag.bulkCreate(
                taxonomies.map((taxonomy) => ({
                    imageId: Number(image.id),
                    listingId: image.listingId,
                    tag: taxonomy.code,
                    tagGroup: taxonomy.group,
                    confidence,
                    source: "ai" as ImageTagSource,
                })),
                { transaction },
            );
        }

        await image.update(
            {
                displayTitle: title,
                altText: truncate(result.caption, 500),
                caption: result.caption,
                aiImageType: result.roomType === "unknown" ? "other" : result.roomType,
                aiSceneTags: sceneTags,
                aiAmenityTags: amenityTags,
                aiDescription: result.caption,
                aiConfidence: confidence,
                aiQualityWarnings: result.qualityTags,
                aiAnalysisStatus: "analyzed",
                aiErrorMessage: null,
                aiAnalyzedAt: analyzedAt,
            },
            { transaction },
        );
    });
};

const analyzeListingImageRecord = async (image: ListingImageDocument) => {
    const env = getEnv();
    let analysis: ImageAnalysisResultDocument | null = null;

    try {
        analysis = await ImageAnalysisResult.create({
            imageId: Number(image.id),
            provider: "openai",
            model: env.openaiVisionModel,
            status: "pending",
        });

        await image.update({
            aiAnalysisStatus: "pending",
            aiErrorMessage: null,
        });

        const vision = await callOpenAiVision(image);
        await saveAnalysisTags(image, vision, analysis);
        await summarizeListingImageTags(image.listingId);

        return serializeImageWithRelations(image);
    } catch (error) {
        return markImageFailed(image, error, analysis);
    }
};

export const analyzeListingImage = async (listingId: number, imageId: number, actor: HostActor) => {
    await getListingForActor(listingId, actor);
    const image = await getImageForListing(listingId, imageId);

    return analyzeListingImageRecord(image);
};

export const reanalyzeImageAsAdmin = async (imageId: number) => {
    const image = await getImageById(imageId);
    return analyzeListingImageRecord(image);
};

export const summarizeListingImageTags = async (listingId: number) => {
    const listing = await Listing.findOne({
        where: {
            listingId,
            deletedAt: null,
        },
    });

    if (!listing) {
        return null;
    }

    const images = await ListingImage.findAll({
        where: {
            listingId,
        },
        order: [
            ["isCover", "DESC"],
            ["sortOrder", "ASC"],
            ["id", "ASC"],
        ],
    });
    const tags = await ImageTag.findAll({
        where: {
            listingId,
        },
        order: [
            ["tagGroup", "ASC"],
            ["tag", "ASC"],
        ],
    });
    const titleSet = new Set<string>();
    const tagSet = new Set<string>();

    for (const image of images) {
        if (image.displayTitle) {
            titleSet.add(image.displayTitle);
        }

        for (const value of [...safeJsonArray(image.aiSceneTags), ...safeJsonArray(image.aiAmenityTags)]) {
            tagSet.add(value.toLowerCase());
        }
    }

    for (const tag of tags) {
        const taxonomy = taxonomyByCode.get(tag.tag);
        if (taxonomy?.isSearchable !== false) {
            tagSet.add((taxonomy?.labelVi ?? tag.tag).toLowerCase());
            tagSet.add(tag.tag.replace(/_/g, " ").toLowerCase());
        }
    }

    const titles = Array.from(titleSet);
    const aiImageTags = Array.from(tagSet).filter(Boolean).slice(0, 80);
    const summaryTags = tags
        .map((tag) => getTagLabel(tag.tag))
        .filter((value, index, values) => values.indexOf(value) === index)
        .slice(0, 12);
    const summary = summaryTags.length
        ? `AI nhận diện ảnh có: ${summaryTags.join(", ")}.`
        : titles.length
            ? `AI nhận diện listing có: ${titles.join(", ")}.`
            : null;

    await syncListingImageSnapshot(listing);
    listing.aiImageTags = aiImageTags;
    listing.aiImageSummary = summary;
    await listing.save();
    scheduleSemanticReindex(listing.listingId, "listing_image_tags_update");

    return {
        aiImageTags,
        aiImageSummary: summary,
    };
};

export const analyzeListingImages = async (
    listingId: number,
    actor: HostActor,
    options: AnalyzeListingImagesOptions = {},
) => {
    await getListingForActor(listingId, actor);

    const images = await ListingImage.findAll({
        where: {
            listingId,
        },
        order: [
            ["isCover", "DESC"],
            ["sortOrder", "ASC"],
            ["id", "ASC"],
        ],
    });

    const targetImages = options.force
        ? images
        : images.filter((image) => image.aiAnalysisStatus !== "analyzed");
    const results = [];

    for (const image of targetImages) {
        results.push(await analyzeListingImageRecord(image));
    }

    const summary = await summarizeListingImageTags(listingId);

    return {
        listingId,
        totalImages: images.length,
        requestedImages: targetImages.length,
        analyzedCount: results.filter((item) => item.aiAnalysisStatus === "analyzed").length,
        failedCount: results.filter((item) => item.aiAnalysisStatus === "failed").length,
        results,
        summary,
    };
};

export const getListingImageAnalysis = async (listingId: number, actor: HostActor) => {
    const listing = await getListingForActor(listingId, actor);

    const images = await ListingImage.findAll({
        where: {
            listingId,
        },
        order: [
            ["isCover", "DESC"],
            ["sortOrder", "ASC"],
            ["id", "ASC"],
        ],
    });
    const imageIds = images.map((image) => Number(image.id));
    const tagsByImageId = await getTagsByImageId(imageIds);
    const latestAnalysisByImageId = await getLatestAnalysisByImageId(imageIds);

    return {
        listingId,
        images: images.map((image) =>
            serializeAnalyzedImage(
                image,
                tagsByImageId.get(Number(image.id)) ?? [],
                latestAnalysisByImageId.get(Number(image.id)) ?? null,
            ),
        ),
        tagTaxonomies: await getTagTaxonomies(),
        summary: {
            aiImageTags: Array.isArray(listing.aiImageTags) ? listing.aiImageTags : safeJsonArray(listing.aiImageTags),
            aiImageSummary: listing.aiImageSummary ?? null,
        },
    };
};

const resolvePatchTagCodes = (values: string[]) => {
    const codes = new Set<string>();
    const unknownValues: string[] = [];

    for (const value of values) {
        const code = resolveTaxonomyCode(value);
        if (code) {
            codes.add(code);
        } else {
            unknownValues.push(value);
        }
    }

    if (unknownValues.length > 0) {
        throw new ApiError(422, "Unknown image tag", [
            {
                path: "tags",
                msg: `Unknown tags: ${unknownValues.join(", ")}`,
            },
        ]);
    }

    return Array.from(codes);
};

export const updateImageTags = async (imageId: number, actor: HostActor, tags: string[]) => {
    const image = await getImageForActor(imageId, actor);
    const tagCodes = resolvePatchTagCodes(tags);
    const analyzedAt = new Date();

    await sequelize.transaction(async (transaction) => {
        await ImageTag.destroy({
            where: {
                imageId,
            },
            transaction,
        });

        if (tagCodes.length > 0) {
            await ImageTag.bulkCreate(
                tagCodes.map((code) => ({
                    imageId,
                    listingId: image.listingId,
                    tag: code,
                    tagGroup: getTagGroup(code),
                    confidence: 1,
                    source: actor.isAdmin ? "admin" : "host",
                })),
                { transaction },
            );
        }

        await image.update(
            {
                aiSceneTags: tagCodes.map(getTagLabel),
                aiAmenityTags: tagCodes.map(getTagLabel),
                aiAnalysisStatus: tagCodes.length > 0 ? "analyzed" : image.aiAnalysisStatus,
                aiErrorMessage: null,
                aiAnalyzedAt: tagCodes.length > 0 ? analyzedAt : image.aiAnalyzedAt,
            },
            { transaction },
        );
    });

    await summarizeListingImageTags(image.listingId);
    return serializeImageWithRelations(image);
};

export const deleteImageByIdForHost = async (imageId: number, actor: HostActor) => {
    const image = await getImageForActor(imageId, actor);
    const listingId = image.listingId;

    await deleteListingImage(listingId, imageId, actor);
    await ImageTag.destroy({ where: { imageId } });
    await ImageAnalysisResult.destroy({ where: { imageId } });
    await summarizeListingImageTags(listingId);

    return {
        imageId,
        listingId,
    };
};
