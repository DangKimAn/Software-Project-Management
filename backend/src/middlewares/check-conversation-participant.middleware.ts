import { RequestHandler } from "express";

import { ApiError } from "../common/api-error";
import { asyncHandler } from "../common/async-handler";
import { assertConversationParticipant } from "../modules/conversations/conversations.service";

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
