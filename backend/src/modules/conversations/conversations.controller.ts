/**
 * Bộ điều phối HTTP cho phân hệ hội thoại và nhắn tin trực tiếp giữa khách với chủ nhà (`conversations`):
 * - Xử lý liệt kê cuộc trò chuyện, khởi tạo hội thoại theo chỗ ở, phân trang lịch sử tin nhắn, gửi tin nhắn mới và đánh dấu đã đọc.
 */

import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    createConversation,
    CreateConversationInput,
    ConversationMessagesQuery,
    ConversationQuery,
    getConversationMessages,
    getConversations,
    markConversationRead,
    sendConversationMessage,
    SendMessageInput,
} from "./conversations.service";

/**
 * Liệt kê danh sách các cuộc hội thoại mà người dùng hiện tại đang tham gia.
 */
export const listConversations: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<ConversationQuery>(req);
    const result = await getConversations(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Khởi tạo hoặc mở lại cuộc hội thoại giữa khách với chủ nhà gắn theo chỗ ở.
 */
export const createNewConversation: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreateConversationInput>(req);
    const result = await createConversation(req.user!, payload);

    return sendSuccess(res, {
        statusCode: result.created ? 201 : 200,
        message: "Conversation ready",
        data: result,
    });
});

/**
 * Truy vấn phân trang lịch sử tin nhắn trong một cuộc hội thoại.
 */
export const listConversationMessages: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ conversationId: number }>(req);
    const queryParams = getValidatedQuery<ConversationMessagesQuery>(req);
    const result = await getConversationMessages(params.conversationId, req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Gửi tin nhắn mới vào cuộc hội thoại sau khi làm sạch và kiểm duyệt nội dung.
 */
export const sendMessage: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ conversationId: number }>(req);
    const payload = getValidatedBody<SendMessageInput>(req);
    const result = await sendConversationMessage(params.conversationId, req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Message sent",
        data: result,
    });
});

/**
 * Đánh dấu đã đọc các tin nhắn mới trong cuộc hội thoại đối với người dùng hiện tại.
 */
export const markRead: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ conversationId: number }>(req);
    const result = await markConversationRead(params.conversationId, req.user!);

    return sendSuccess(res, {
        data: result,
    });
});
