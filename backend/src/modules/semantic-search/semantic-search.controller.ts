import { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { assertValidRequest, getValidatedBody } from "../../common/validation";
import { semanticSearchListings as searchService } from "./semantic-search.service";
import {
    AiListingSearchRequest,
    SemanticSearchRequest,
} from "./semantic-search.types";

/**
 * Endpoint xử lý tìm kiếm ngữ nghĩa cho listing.
 * Chấp nhận các tham số lọc từ body (POST request).
 */
export const semanticSearchListings: RequestHandler = asyncHandler(async (req, res) => {
    // 1. Kiểm tra validation từ express-validator (đã định nghĩa ở routes)
    assertValidRequest(req);

    // 2. Lấy dữ liệu đã được validate và sanitize
    const payload = getValidatedBody<SemanticSearchRequest>(req);

    // 3. Gọi service xử lý logic tìm kiếm
    const result = await searchService(payload, {
        userId: req.user?.id ? Number(req.user.id) : null,
    });

    // 4. Trả về kết quả thành công
    return sendSuccess(res, {
        data: result,
    });
});

export const aiListingSearch: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<AiListingSearchRequest>(req);
    const query = payload.query.trim();
    const result = await searchService({
        query,
        limit: payload.limit,
        city: payload.filters?.city,
        minPrice: payload.filters?.minPrice,
        maxPrice: payload.filters?.maxPrice,
        guests: payload.filters?.guests,
        checkIn: payload.filters?.checkIn,
        checkOut: payload.filters?.checkOut,
        locationGroup: payload.filters?.locationGroup,
        amenities: payload.filters?.amenities,
        propertyType: payload.filters?.propertyType,
        roomType: payload.filters?.roomType,
    }, {
        userId: req.user?.id ? Number(req.user.id) : null,
    });

    return sendSuccess(res, {
        data: {
            ...result,
            query: result.query ?? query,
            mode: result.mode ?? (result.fallback ? "keyword_fallback" : "semantic"),
        },
    });
});
