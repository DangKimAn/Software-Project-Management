import express from "express";
import { body, param, query } from "express-validator";

import {
    createNewConversation,
    listConversationMessages,
    listConversations,
    markRead,
    sendMessage,
} from "./conversations.controller";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { checkConversationParticipant } from "../../middlewares/check-conversation-participant.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { getMessageWriteRateLimiter } from "../../middlewares/rate-limit.middleware";
import { messageTypeValues } from "../../models/message";

const router = express.Router();

const conversationIdParamValidator = param("conversationId")
    .isInt({ min: 1 })
    .withMessage("conversationId must be a positive integer")
    .toInt();

router.use(authenticate, requireActiveUser);

router.get(
    "/",
    [
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("limit must be between 1 and 100").toInt(),
        query("unreadOnly").optional().isBoolean().withMessage("unreadOnly must be boolean").toBoolean(),
        query("scope").optional().isIn(["guest", "host"]).withMessage("scope must be guest or host"),
    ],
    listConversations,
);

router.post(
    "/",
    getMessageWriteRateLimiter(),
    [
        body("listingId").optional().isInt({ min: 1 }).withMessage("listingId must be a positive integer").toInt(),
        body("bookingId").optional().isInt({ min: 1 }).withMessage("bookingId must be a positive integer").toInt(),
        body("participantId")
            .optional()
            .isInt({ min: 1 })
            .withMessage("participantId must be a positive integer")
            .toInt(),
        body("hostUserId")
            .optional()
            .isInt({ min: 1 })
            .withMessage("hostUserId must be a positive integer")
            .toInt(),
        body("firstMessage")
            .optional()
            .isString()
            .trim()
            .isLength({ max: 2000 })
            .withMessage("firstMessage must be at most 2000 characters"),
    ],
    createNewConversation,
);

router.get(
    "/:conversationId/messages",
    [
        conversationIdParamValidator,
        query("page").optional().isInt({ min: 1 }).withMessage("page must be at least 1").toInt(),
        query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("limit must be between 1 and 100").toInt(),
    ],
    checkConversationParticipant,
    listConversationMessages,
);

router.post(
    "/:conversationId/messages",
    getMessageWriteRateLimiter(),
    [
        conversationIdParamValidator,
        body("content")
            .optional()
            .isString()
            .trim()
            .isLength({ max: 2000 })
            .withMessage("content must be at most 2000 characters"),
        body("messageType").optional().isIn(messageTypeValues).withMessage("messageType is invalid"),
        body("attachments").optional().isArray({ max: 10 }).withMessage("attachments must be an array"),
        body("attachments.*.url")
            .optional()
            .isURL({ protocols: ["http", "https"], require_protocol: true })
            .withMessage("attachments.url must be a valid URL"),
        body("attachments.*.type").optional({ nullable: true }).isString().trim().isLength({ max: 100 }),
        body("attachments.*.name").optional({ nullable: true }).isString().trim().isLength({ max: 255 }),
    ],
    checkConversationParticipant,
    sendMessage,
);

router.patch(
    "/:conversationId/read",
    [conversationIdParamValidator],
    checkConversationParticipant,
    markRead,
);

export default router;
