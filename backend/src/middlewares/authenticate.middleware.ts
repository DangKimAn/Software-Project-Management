import { RequestHandler } from "express";

import { ApiError } from "../common/api-error";
import { asyncHandler } from "../common/async-handler";
import User from "../models/user";
import {
    assertUserCanAuthenticate,
    extractAuthToken,
    toAuthenticatedUser,
    verifyAuthToken,
} from "../modules/auth/auth.service";

/**
 * Giải thuật xác thực yêu cầu HTTP bằng JWT Access Token:
 * - Bước 1: Trích xuất Bearer token từ header `Authorization` (từ chối `401` nếu thiếu).
 * - Bước 2: Giải mã và kiểm tra chữ ký/hạn dùng JWT, sau đó truy vấn lại bản ghi `User` thực tế từ CSDL để không tin tưởng mù quáng vào claim cũ.
 * - Bước 3: Kiểm tra trạng thái hoạt động của tài khoản (`assertUserCanAuthenticate`) và gắn ngữ cảnh quyền hạn mới nhất vào `req.user`.
 */
export const authenticate: RequestHandler = asyncHandler(async (req, _res, next) => {
    const token = extractAuthToken(req);

    if (!token) {
        throw new ApiError(401, "Unauthorized");
    }

    const payload = verifyAuthToken(token);
    const user = await User.findById(payload.userId);

    if (!user) {
        throw new ApiError(401, "Unauthorized");
    }

    assertUserCanAuthenticate(user);
    req.user = await toAuthenticatedUser(user);
    next();
});
