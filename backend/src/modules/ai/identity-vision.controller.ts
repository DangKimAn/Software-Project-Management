import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { analyzeIdentityDocument } from "./identity-vision.service";

export const analyzeIdentityDocumentController: RequestHandler = asyncHandler(async (req, res) => {
    let fileBuffer: Buffer | undefined;
    let mimeType: string | undefined;

    if (req.file) {
        fileBuffer = req.file.buffer;
        mimeType = req.file.mimetype;
    }

    const imageUrl = typeof req.body?.imageUrl === "string" ? req.body.imageUrl.trim() : undefined;
    const base64Data = typeof req.body?.base64Data === "string" ? req.body.base64Data.trim() : undefined;

    if (!fileBuffer && !imageUrl && !base64Data) {
        throw new ApiError(400, "Vui lòng đính kèm tệp ảnh (field: 'image' hoặc 'file') hoặc truyền 'imageUrl' / 'base64Data'.");
    }

    const result = await analyzeIdentityDocument({
        fileBuffer,
        mimeType,
        imageUrl,
        base64Data,
    });

    return sendSuccess(res, {
        message: result.summaryVi || "Phân tích căn cước công dân thành công",
        data: result,
    });
});
