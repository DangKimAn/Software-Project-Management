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

/**
 * Giải thuật xác thực tùy chọn (Optional Authentication):
 * - Nếu request có đính kèm JWT hợp lệ và tài khoản đang hoạt động thì gắn `req.user` để phục vụ kiểm tra hạn mức theo người dùng.
 * - Nếu không có token hoặc token hết hạn/không hợp lệ thì bỏ qua lặng lẽ để cho phép khách vãng lai truy cập các endpoint công khai (như kiểm tra mã giảm giá).
 */
export const optionalAuthenticate: RequestHandler = asyncHandler(async (req, _res, next) => {
    const token = extractAuthToken(req);

    if (!token) {
        return next();
    }

    try {
        const payload = verifyAuthToken(token);
        const user = await User.findById(payload.userId);

        if (user) {
            assertUserCanAuthenticate(user);
            req.user = await toAuthenticatedUser(user);
        }
    } catch {
        // Bỏ qua token không hợp lệ trên luồng công khai không bắt buộc đăng nhập
    }

    return next();
});
