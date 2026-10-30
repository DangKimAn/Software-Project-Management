import OpenAI from "openai";
import { z } from "zod";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";

export const identityDocTypes = ["cccd", "cmnd", "passport", "driver_license", "unknown"] as const;
export type IdentityDocType = (typeof identityDocTypes)[number];

export const identitySides = ["front", "back", "unknown"] as const;
export type IdentitySide = (typeof identitySides)[number];

export const identityVisionResponseSchema = z.object({
    documentType: z.enum(identityDocTypes),
    side: z.enum(identitySides),
    idNumber: z.string().nullable(),
    fullName: z.string().nullable(),
    dateOfBirth: z.string().nullable(),
    gender: z.string().nullable(),
    nationality: z.string().nullable(),
    placeOfOrigin: z.string().nullable(),
    placeOfResidence: z.string().nullable(),
    expiryDate: z.string().nullable(),
    issueDate: z.string().nullable(),
    issuePlace: z.string().nullable(),
    mrz: z.string().nullable(),
    isClear: z.boolean(),
    isDocumentValid: z.boolean(),
    confidence: z.number().min(0).max(1),
    warnings: z.array(z.string()),
    summaryVi: z.string(),
});

export type IdentityVisionResult = z.infer<typeof identityVisionResponseSchema>;

const identityVisionJsonSchema = {
    type: "object",
    additionalProperties: false,
    required: [
        "documentType",
        "side",
        "idNumber",
        "fullName",
        "dateOfBirth",
        "gender",
        "nationality",
        "placeOfOrigin",
        "placeOfResidence",
        "expiryDate",
        "issueDate",
        "issuePlace",
        "mrz",
        "isClear",
        "isDocumentValid",
        "confidence",
        "warnings",
        "summaryVi",
    ],
    properties: {
        documentType: {
            type: "string",
            enum: identityDocTypes,
            description: "Loại giấy tờ: cccd (Căn cước công dân gắn chip hoặc mã vạch), cmnd (Chứng minh nhân dân 9 hoặc 12 số cũ), passport (Hộ chiếu), driver_license (Bằng lái xe GPLX), hoặc unknown.",
        },
        side: {
            type: "string",
            enum: identitySides,
            description: "Mặt của giấy tờ: front (mặt trước), back (mặt sau), hoặc unknown.",
        },
        idNumber: {
            type: ["string", "null"],
            description: "Số thẻ định danh: Số CCCD (12 chữ số) hoặc CMND (9 chữ số) hoặc số hộ chiếu.",
        },
        fullName: {
            type: ["string", "null"],
            description: "Họ và tên chủ giấy tờ, viết IN HOA tiếng Việt đầy đủ dấu (ví dụ: NGUYỄN VĂN AN).",
        },
        dateOfBirth: {
            type: ["string", "null"],
            description: "Ngày tháng năm sinh theo định dạng DD/MM/YYYY (ví dụ: 15/08/1992).",
        },
        gender: {
            type: ["string", "null"],
            description: "Giới tính: Nam hoặc Nữ.",
        },
        nationality: {
            type: ["string", "null"],
            description: "Quốc tịch, ví dụ: Việt Nam.",
        },
        placeOfOrigin: {
            type: ["string", "null"],
            description: "Quê quán ghi trên giấy tờ.",
        },
        placeOfResidence: {
            type: ["string", "null"],
            description: "Nơi thường trú / Địa chỉ cư trú ghi trên giấy tờ.",
        },
        expiryDate: {
            type: ["string", "null"],
            description: "Có giá trị đến ngày (DD/MM/YYYY) hoặc Không thời hạn.",
        },
        issueDate: {
            type: ["string", "null"],
            description: "Ngày cấp giấy tờ (thường ở mặt sau CCCD hoặc bên dưới thông tin cá nhân).",
        },
        issuePlace: {
            type: ["string", "null"],
            description: "Nơi cấp giấy tờ (ví dụ: CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI).",
        },
        mrz: {
            type: ["string", "null"],
            description: "Dãy ký tự MRZ ở mặt sau CCCD gắn chip hoặc hộ chiếu (nếu có).",
        },
        isClear: {
            type: "boolean",
            description: "true nếu hình ảnh đủ sắc nét, không bị mờ nhòe hay che khuất thông tin quan trọng.",
        },
        isDocumentValid: {
            type: "boolean",
            description: "true nếu hình ảnh đúng là giấy tờ tùy thân hợp lệ, không phải ảnh chụp màn hình giả lập hay giấy tờ không liên quan.",
        },
        confidence: {
            type: "number",
            minimum: 0,
            maximum: 1,
            description: "Độ tin cậy tổng thể của trích xuất AI từ 0.0 đến 1.0.",
        },
        warnings: {
            type: "array",
            items: { type: "string" },
            description: "Danh sách các cảnh báo bằng tiếng Việt nếu có (ví dụ: 'Ảnh bị lóa sáng', 'Bị che mất góc', 'Mặt sau không có thông tin họ tên').",
        },
        summaryVi: {
            type: "string",
            description: "Tóm tắt ngắn gọn 1 dòng bằng tiếng Việt về giấy tờ (ví dụ: 'CCCD mặt trước - NGUYỄN VĂN AN - Số: 079090123456').",
        },
    },
};

const buildIdentityVisionPrompt = (): string => {
    return [
        "Bạn là hệ thống AI OCR chuyên sâu hàng đầu về phân tích và trích xuất giấy tờ tùy thân Việt Nam (Căn cước công dân - CCCD gắn chip/mã vạch, CMND, Hộ chiếu, Giấy phép lái xe).",
        "Nhiệm vụ của bạn:",
        "1. Xác định chính xác loại giấy tờ (cccd, cmnd, passport, driver_license) và mặt hiển thị (front - mặt trước, back - mặt sau).",
        "   * Lưu ý đặc biệt về CĂN CƯỚC CÔNG DÂN (CCCD) gắn chip Việt Nam:",
        "     - Mặt trước (front): Có Quốc huy, ảnh chân dung chủ thẻ bên trái, dòng chữ 'CĂN CƯỚC CÔNG DÂN', số CCCD (12 số), Họ và tên, Ngày sinh, Giới tính, Quê quán, Nơi thường trú, Có giá trị đến.",
        "     - Mặt sau (back): Có CHIP điện tử màu vàng ở bên trái, 2 ô vân tay (ngón trỏ trái/phải), đặc điểm nhân dạng, ngày tháng năm cấp (ví dụ: 01/07/2024), con dấu đỏ và chữ ký của CỤC TRƯỞNG CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI (ví dụ: 'Phạm Công Nguyên'), và 3 dòng mã MRZ (Machine Readable Zone) ở dưới cùng. Đây CHÍNH LÀ MẶT SAU CỦA CCCD (documentType: 'cccd', side: 'back'), TUYỆT ĐỐI KHÔNG ĐƯỢC NHẬN NHẦM THÀNH HỘ CHIẾU HAY MẶT TRƯỚC!",
        "     - Trên mặt sau CCCD: Tên của Cục trưởng (như 'Phạm Công Nguyên') là người ký cấp, KHÔNG PHẢI là fullName của chủ thẻ (fullName ở mặt sau nên để null hoặc đọc từ dòng MRZ). Số CCCD chính là 12 số nằm sau chữ 'IDVNM' trên dòng MRZ đầu tiên (ví dụ 'IDVNM012345678901' -> số CCCD là '012345678901').",
        "2. Trích xuất chính xác 100% các trường thông tin có dấu tiếng Việt chuẩn:",
        "   - Số CCCD / CMND / Hộ chiếu (idNumber): Chỉ gồm các chữ số hoặc ký tự chuẩn, không có dấu cách hay ký tự lạ.",
        "   - Họ và tên (fullName): Viết IN HOA có dấu (ví dụ: NGUYỄN VĂN A).",
        "   - Ngày sinh (dateOfBirth): Chuẩn định dạng DD/MM/YYYY.",
        "   - Giới tính (gender): Nam hoặc Nữ.",
        "   - Quê quán (placeOfOrigin) & Nơi thường trú (placeOfResidence): Đầy đủ số nhà, đường, phường/xã, quận/huyện, tỉnh/thành phố.",
        "   - Ngày cấp (issueDate) & Nơi cấp (issuePlace) nếu đây là mặt sau hoặc hộ chiếu.",
        "   - Mã MRZ (mrz): Toàn bộ các dòng ký tự MRZ.",
        "3. Kiểm tra tính toàn vẹn và chất lượng hình ảnh:",
        "   - isClear: Ảnh có rõ nét, dễ đọc không?",
        "   - isDocumentValid: Có phải giấy tờ tùy thân hợp lệ không? Nếu là hóa đơn tiền điện/nước/internet, chứng từ hoặc vật phẩm khác không phải giấy tờ tùy thân, hãy để documentType: 'unknown', side: 'unknown', isDocumentValid: false và cảnh báo trong warnings.",
        "   - warnings: Liệt kê các cảnh báo bằng tiếng Việt nếu có:",
        "     + Nếu là bản chụp photocopy / đen trắng: ghi rõ 'Bản photocopy đen trắng, khuyến nghị tải lên ảnh chụp bản gốc màu'.",
        "     + Nếu giấy tờ đã quá ngày hết hạn (expiryDate): ghi rõ 'Giấy tờ đã hết hạn sử dụng'.",
        "     + Nếu ảnh bị lóa sáng, mờ nhòe, che góc bởi ngón tay hoặc vật thể khác.",
        "   - Trường hợp công dân cao tuổi có ghi 'Không thời hạn' ở mục Có giá trị đến thì expiryDate giữ nguyên là 'Không thời hạn'.",
        "4. Nếu trường nào không có trên mặt giấy tờ đang xét, hãy để giá trị null cho trường đó.",
        "5. Trả về đúng JSON theo schema được yêu cầu. Không thêm bất kỳ giải thích nào ngoài JSON.",
    ].join("\n");
};

const parseJsonObjectFromText = (text: string): unknown => {
    try {
        return JSON.parse(text);
    } catch {
        const match = text.match(/\{[\s\S]*\}/);
        if (!match) {
            throw new Error("AI response is not valid JSON");
        }
        return JSON.parse(match[0]);
    }
};

export type AnalyzeIdentityInput = {
    fileBuffer?: Buffer;
    mimeType?: string;
    imageUrl?: string;
    base64Data?: string;
};

export const analyzeIdentityDocument = async (input: AnalyzeIdentityInput): Promise<IdentityVisionResult> => {
    const env = getEnv();

    if (!env.openaiApiKey) {
        throw new ApiError(503, "OPENAI_API_KEY is not configured on the server");
    }

    let resolvedImageUrl: string;

    if (input.fileBuffer) {
        const mime = input.mimeType || "image/jpeg";
        const base64 = input.fileBuffer.toString("base64");
        resolvedImageUrl = `data:${mime};base64,${base64}`;
    } else if (input.base64Data) {
        resolvedImageUrl = input.base64Data.startsWith("data:")
            ? input.base64Data
            : `data:image/jpeg;base64,${input.base64Data}`;
    } else if (input.imageUrl) {
        resolvedImageUrl = input.imageUrl;
    } else {
        throw new ApiError(400, "Vui lòng cung cấp tệp ảnh hoặc URL ảnh giấy tờ căn cước.");
    }

    const client = new OpenAI({ apiKey: env.openaiApiKey });

    try {
        const response = await client.responses.create({
            model: env.openaiVisionModel,
            temperature: 0.1,
            max_output_tokens: 1000,
            store: false,
            instructions: "Bạn chỉ trả về JSON object hợp lệ theo schema đã cung cấp. Không kèm markdown hay văn bản nào khác.",
            text: {
                format: {
                    type: "json_schema",
                    name: "vietnamese_identity_ocr",
                    strict: true,
                    schema: identityVisionJsonSchema,
                },
            },
            input: [
                {
                    role: "user",
                    content: [
                        {
                            type: "input_text",
                            text: buildIdentityVisionPrompt(),
                        },
                        {
                            type: "input_image",
                            image_url: resolvedImageUrl,
                            detail: "high",
                        },
                    ],
                },
            ],
        });

        const content = typeof response.output_text === "string" ? response.output_text.trim() : "";
        if (!content) {
            throw new Error("OpenAI Vision response did not contain output text");
        }

        const rawJson = parseJsonObjectFromText(content);
        const parsed = identityVisionResponseSchema.parse(rawJson);

        if (!parsed.idNumber && parsed.mrz) {
            const mrzMatch = parsed.mrz.match(/IDVNM(\d{9,12})/i);
            if (mrzMatch) {
                parsed.idNumber = mrzMatch[1];
            }
        }

        logger.info("Identity OCR analyzed successfully", {
            documentType: parsed.documentType,
            side: parsed.side,
            idNumberMasked: parsed.idNumber ? `${parsed.idNumber.slice(0, 3)}***${parsed.idNumber.slice(-3)}` : null,
            confidence: parsed.confidence,
        });

        return parsed;
    } catch (err) {
        logger.error("Failed to analyze identity document with AI", err);
        if (err instanceof ApiError) throw err;
        throw new ApiError(500, "Không thể phân tích ảnh căn cước bằng AI. Vui lòng thử lại với ảnh rõ nét hơn.");
    }
};
