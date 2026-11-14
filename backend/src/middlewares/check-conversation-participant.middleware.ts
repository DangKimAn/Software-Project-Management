import { RequestHandler } from "express";

import { ApiError } from "../common/api-error";
import { asyncHandler } from "../common/async-handler";
import { assertConversationParticipant } from "../modules/conversations/conversations.service";

/**
 * Giải thuật kiểm soát quyền truy cập mức đối tượng (BOLA/IDOR) cho hội thoại:
 * - Kiểm tra người dùng đã đăng nhập, ép kiểu và xác thực `conversationId` là số nguyên dương.
 * - Gọi `assertConversationParticipant` để đảm bảo chỉ thành viên thuộc hội thoại mới được đọc hoặc gửi tin nhắn.
 */
export const checkConversationParticipant: RequestHandler = asyncHandler(async (req, _res, next) => {
    if (!req.user) {
        throw new ApiError(401, "Unauthorized");
    }

    const conversationId = Number(req.params.conversationId);

    if (!Number.isInteger(conversationId) || conversationId < 1) {
        throw new ApiError(422, "Validation error", [
            {
                path: "conversationId",
                msg: "conversationId must be a positive integer",
            },
        ]);
    }

    await assertConversationParticipant(conversationId, Number(req.user.id));
    next();
});
