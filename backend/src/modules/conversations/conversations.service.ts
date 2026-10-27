import { Op, QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import Conversation from "../../models/conversation";
import ConversationParticipant from "../../models/conversation-participant";
import Message, { MessageAttachment, MessageDocument, MessageType } from "../../models/message";
import { emitMessageNew } from "../../socket/socket";
import { sanitizeAndModerateText, sanitizeUserText } from "../../services/trust-safety-service";
import { assertBasicUserExists } from "../../services/user-access-service";
import type { AuthenticatedUser } from "../auth/auth.service";

export type ConversationQuery = {
    page?: number;
    limit?: number;
    unreadOnly?: boolean;
    scope?: "guest" | "host";
};

export type CreateConversationInput = {
    listingId?: number;
    /**
     * Direct conversation fallback. Ignored when listingId is present because
     * listing conversations always resolve the recipient from listings.host_id.
     */
    hostUserId?: number;
    participantId?: number;
    bookingId?: number;
    firstMessage?: string;
};

export type ConversationMessagesQuery = {
    page?: number;
    limit?: number;
};

export type SendMessageInput = {
    content?: string;
    messageType?: MessageType;
    attachments?: MessageAttachment[];
};

export type SerializedMessage = {
    id: number;
    messageId: number;
    conversationId: number;
    senderUserId: number;
    senderId: number;
    content: string;
    body: string;
    messageType: MessageType;
    attachments: MessageAttachment[];
    createdAt: Date;
    updatedAt: Date | null;
};

type ConversationListRow = {
    id: number;
    conversationId: number;
    createdByUserId: number | null;
    listingId: number | null;
    guestUserId: number | null;
    hostUserId: number | null;
    bookingOrderId: number | null;
    lastMessage: string | null;
    lastMessageAt: Date | null;
    unreadCount: number;
    createdAt: Date;
    updatedAt: Date;
    listingTitle: string | null;
    listingCoverImageUrl: string | null;
    otherUserId: number | null;
    otherFullName: string | null;
    otherAvatarUrl: string | null;
};

type ConversationAccessRow = {
    bookingOrderId: number;
    listingId: number;
    guestUserId: number;
    hostUserId: number;
};

type ListingAccessRow = {
    listingId: number;
    hostId: number;
    title: string;
};

const attachmentTypePattern = /^[a-z0-9][a-z0-9.+-]*\/[a-z0-9][a-z0-9.+-]*$/i;
const maxMessageLength = 2000;
const defaultPageLimit = 30;

const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

const debugMessaging = (...args: unknown[]) => {
    if (process.env.NODE_ENV !== "production") {
        console.log(...args);
    }
};

const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(100, Math.max(1, limit ?? defaultPageLimit)),
});

const normalizeMessageContent = (value: string | undefined, allowEmpty = false) => {
    const content = sanitizeAndModerateText(value ?? "", {
        field: "content",
        allowEmpty,
    }).trim();

    if (content.length > maxMessageLength) {
        throw new ApiError(422, "Validation error", [
            {
                path: "content",
                msg: `content must be at most ${maxMessageLength} characters`,
            },
        ]);
    }

    return content;
};

const throwAttachmentValidationError = (path: string, msg: string): never => {
    throw new ApiError(422, "Validation error", [
        {
            path,
            msg,
        },
    ]);
};

const parseAttachmentUrl = (value: string, path: string): URL => {
    try {
        return new URL(value);
    } catch {
        return throwAttachmentValidationError(path, "attachments.url must be a valid URL");
    }
};

const normalizeAttachments = (attachments: MessageAttachment[], messageType: MessageType) =>
    attachments.map((attachment, index) => {
        const url = parseAttachmentUrl(attachment.url, `attachments.${index}.url`);

        if (!["http:", "https:"].includes(url.protocol)) {
            throwAttachmentValidationError(`attachments.${index}.url`, "attachments.url must use http or https");
        }

        const type = attachment.type ? sanitizeUserText(attachment.type, "singleLine").toLowerCase() : null;

        if (type && !attachmentTypePattern.test(type)) {
            throwAttachmentValidationError(`attachments.${index}.type`, "attachments.type must be a valid media type");
        }

        if (messageType === "image" && type && !type.startsWith("image/")) {
            throwAttachmentValidationError(`attachments.${index}.type`, "image messages require image attachments");
        }

        return {
            url: url.toString(),
            type,
            name: attachment.name ? sanitizeUserText(attachment.name, "singleLine") : null,
        };
    });

const getListingOrThrow = async (listingId: number, transaction?: Transaction) => {
    const rows = await sequelize.query<ListingAccessRow>(
        `
        SELECT
            listing_id AS listingId,
            host_id AS hostId,
            title
        FROM listings
        WHERE listing_id = ?
          AND deleted_at IS NULL
        LIMIT 1
        `,
        {
            replacements: [listingId],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    if (!rows[0]) {
        throw new ApiError(404, "Listing not found");
    }

    return rows[0];
};

const getBookingAccess = async (bookingId: number, transaction?: Transaction) => {
    const rows = await sequelize.query<ConversationAccessRow>(
        `
        SELECT
            b.booking_id AS bookingOrderId,
            b.listing_id AS listingId,
            b.guest_user_id AS guestUserId,
            b.host_user_id AS hostUserId
        FROM bookings b
        WHERE b.booking_id = ?
        LIMIT 1
        `,
        {
            replacements: [bookingId],
            type: QueryTypes.SELECT,
            transaction,
        },
    );

    if (!rows[0]) {
        throw new ApiError(404, "Booking not found");
    }

    return rows[0];
};

const buildPairDedupeKey = (leftUserId: number, rightUserId: number, listingId?: number) => {
    const [firstUserId, secondUserId] = [leftUserId, rightUserId].sort((left, right) => left - right);

    return listingId
        ? `listing:${listingId}:${firstUserId}:${secondUserId}`
        : `direct:${firstUserId}:${secondUserId}`;
};

const buildListingConversationDedupeKey = (listingId: number, guestUserId: number, hostUserId: number) =>
    `listing:${listingId}:guest:${guestUserId}:host:${hostUserId}`;

const ensureTwoPartyConversation = (guestUserId: number | null, hostUserId: number | null) => {
    const normalizedGuestUserId = Number(guestUserId);
    const normalizedHostUserId = Number(hostUserId);

    if (
        !Number.isInteger(normalizedGuestUserId) ||
        !Number.isInteger(normalizedHostUserId) ||
        normalizedGuestUserId < 1 ||
        normalizedHostUserId < 1 ||
        normalizedGuestUserId === normalizedHostUserId
    ) {
        throw new ApiError(409, "Conversation participants are invalid");
    }

    return {
        guestUserId: normalizedGuestUserId,
        hostUserId: normalizedHostUserId,
    };
};

const getConversationDirectRole = (
    conversation: { guestUserId: number | null; hostUserId: number | null },
    userId: number,
) => {
    if (Number(conversation.guestUserId) === userId) {
        return "guest" as const;
    }

    if (Number(conversation.hostUserId) === userId) {
        return "host" as const;
    }

    return null;
};

const ensureConversationParticipants = async (
    conversationId: number,
    guestUserId: number,
    hostUserId: number,
    transaction?: Transaction,
) => {
    const now = new Date();

    await ConversationParticipant.bulkCreate(
        [
            {
                conversationId,
                userId: guestUserId,
                role: "guest",
                joinedAt: now,
                lastReadAt: null,
            },
            {
                conversationId,
                userId: hostUserId,
                role: "host",
                joinedAt: now,
                lastReadAt: null,
            },
        ],
        {
            transaction,
            updateOnDuplicate: ["role"],
        },
    );
};

const serializeConversationRow = (row: ConversationListRow) => ({
    id: Number(row.conversationId),
    conversationId: Number(row.conversationId),
    createdByUserId: row.createdByUserId === null ? null : Number(row.createdByUserId),
    listingId: row.listingId === null ? null : Number(row.listingId),
    guestUserId: row.guestUserId === null ? null : Number(row.guestUserId),
    hostUserId: row.hostUserId === null ? null : Number(row.hostUserId),
    bookingId: row.bookingOrderId === null ? null : Number(row.bookingOrderId),
    lastMessage: row.lastMessage ?? null,
    lastMessageAt: row.lastMessageAt ?? null,
    unreadCount: Number(row.unreadCount ?? 0),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    listing: row.listingId
        ? {
              listingId: Number(row.listingId),
              title: row.listingTitle ?? "Chỗ nghỉ",
              coverImageUrl: row.listingCoverImageUrl ?? null,
          }
        : null,
    otherParticipant: row.otherUserId
        ? {
              userId: Number(row.otherUserId),
              fullName: row.otherFullName ?? "Người dùng",
              avatarUrl: row.otherAvatarUrl ?? null,
          }
        : null,
});

const serializeMessage = (message: MessageDocument): SerializedMessage => ({
    id: Number(message.messageId),
    messageId: Number(message.messageId),
    conversationId: Number(message.conversationId),
    senderUserId: Number(message.senderId),
    senderId: Number(message.senderId),
    content: message.content,
    body: message.content,
    messageType: message.messageType,
    attachments: message.attachments ?? [],
    createdAt: message.createdAt,
    updatedAt: message.updatedAt ?? null,
});

const getConversationRowsForUser = async (
    userId: number,
    query: ConversationQuery,
    conversationId?: number,
) => {
    const { page, limit } = toPagination(query.page, query.limit);
    const offset = (page - 1) * limit;
    const conversationClause = conversationId ? "AND c.conversation_id = :conversationId" : "";
    const scopeClause =
        query.scope === "host"
            ? "AND (c.host_user_id = :userId OR current_participant.role = 'host')"
            : query.scope === "guest"
              ? "AND (c.guest_user_id = :userId OR current_participant.role = 'guest')"
              : "";
    const unreadOnlyClause = query.unreadOnly === true ? "WHERE conversation_rows.unreadCount > 0" : "";

    const baseSql = `
        SELECT *
        FROM (
            SELECT
                c.conversation_id AS id,
                c.conversation_id AS conversationId,
                c.created_by_user_id AS createdByUserId,
                c.listing_id AS listingId,
                c.guest_user_id AS guestUserId,
                c.host_user_id AS hostUserId,
                c.booking_order_id AS bookingOrderId,
                COALESCE(c.last_message, latest_message.content) AS lastMessage,
                COALESCE(c.last_message_at, latest_message.created_at, c.updated_at) AS lastMessageAt,
                COUNT(unread_message.message_id) AS unreadCount,
                c.created_at AS createdAt,
                c.updated_at AS updatedAt,
                l.title AS listingTitle,
                listing_cover.url AS listingCoverImageUrl,
                other_user.user_id AS otherUserId,
                other_user.full_name AS otherFullName,
                other_user.avatar_url AS otherAvatarUrl,
                COALESCE(c.last_message_at, latest_message.created_at, c.updated_at) AS sortAt
            FROM conversation c
            LEFT JOIN conversation_participant current_participant
                ON current_participant.conversation_id = c.conversation_id
               AND current_participant.user_id = :userId
            LEFT JOIN message latest_message
                ON latest_message.message_id = (
                    SELECT m2.message_id
                    FROM message m2
                    WHERE m2.conversation_id = c.conversation_id
                    ORDER BY m2.created_at DESC, m2.message_id DESC
                    LIMIT 1
                )
            LEFT JOIN message unread_message
                ON unread_message.conversation_id = c.conversation_id
               AND unread_message.sender_id <> :userId
               AND (
                    current_participant.last_read_at IS NULL
                    OR unread_message.created_at > current_participant.last_read_at
               )
            LEFT JOIN listings l
                ON l.listing_id = c.listing_id
            LEFT JOIN listing_images listing_cover
                ON listing_cover.id = (
                    SELECT li.id
                    FROM listing_images li
                    WHERE li.listing_id = c.listing_id
                    ORDER BY li.is_cover DESC, li.sort_order ASC, li.id ASC
                    LIMIT 1
                )
            LEFT JOIN users other_user
                ON other_user.user_id = CASE
                    WHEN c.guest_user_id = :userId THEN c.host_user_id
                    WHEN c.host_user_id = :userId THEN c.guest_user_id
                    ELSE (
                        SELECT fallback_participant.user_id
                        FROM conversation_participant fallback_participant
                        WHERE fallback_participant.conversation_id = c.conversation_id
                          AND fallback_participant.user_id <> :userId
                        ORDER BY FIELD(fallback_participant.role, 'host', 'guest', 'admin'), fallback_participant.user_id
                        LIMIT 1
                    )
                END
            WHERE (
                    c.guest_user_id = :userId
                 OR c.host_user_id = :userId
                 OR current_participant.user_id = :userId
              )
              ${scopeClause}
              ${conversationClause}
            GROUP BY
                c.conversation_id,
                c.created_by_user_id,
                c.listing_id,
                c.guest_user_id,
                c.host_user_id,
                c.booking_order_id,
                c.last_message,
                c.last_message_at,
                c.created_at,
                c.updated_at,
                latest_message.content,
                latest_message.created_at,
                l.title,
                listing_cover.url,
                other_user.user_id,
                other_user.full_name,
                other_user.avatar_url
        ) conversation_rows
        ${unreadOnlyClause}
    `;
    const replacements = { userId, conversationId, limit, offset };

    const [items, countRows] = await Promise.all([
        sequelize.query<ConversationListRow>(
            `
            ${baseSql}
            ORDER BY sortAt DESC, conversationId DESC
            LIMIT :limit OFFSET :offset
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
        sequelize.query<{ totalItems: number }>(
            `
            SELECT COUNT(*) AS totalItems
            FROM (${baseSql}) counted_rows
            `,
            {
                replacements,
                type: QueryTypes.SELECT,
            },
        ),
    ]);

    return {
        items,
        pagination: {
            page,
            limit,
            total: Number(countRows[0]?.totalItems ?? 0),
            totalPages: Math.max(1, Math.ceil(Number(countRows[0]?.totalItems ?? 0) / limit)),
        },
    };
};

const getConversationForUser = async (conversationId: number, userId: number) => {
    const result = await getConversationRowsForUser(userId, { page: 1, limit: 1 }, conversationId);
    const row = result.items[0];

    if (!row) {
        throw new ApiError(404, "Conversation not found");
    }

    return serializeConversationRow(row);
};

const createMessageInTransaction = async (
    conversationId: number,
    senderId: number,
    content: string,
    messageType: MessageType,
    attachments: MessageAttachment[],
    transaction: Transaction,
) => {
    const now = new Date();
    const message = await Message.create(
        {
            conversationId,
            senderId,
            content: content || (messageType === "image" ? "[image]" : "[file]"),
            messageType,
            attachments,
            createdAt: now,
            updatedAt: now,
        },
        { transaction },
    );

    await Conversation.update(
        {
            lastMessage: message.content,
            lastMessageAt: now,
        },
        {
            where: {
                conversationId,
            },
            transaction,
        },
    );

    await ConversationParticipant.update(
        {
            lastReadAt: now,
        },
        {
            where: {
                conversationId,
                userId: senderId,
            },
            transaction,
        },
    );

    return message;
};

export const getConversations = async (user: AuthenticatedUser, query: ConversationQuery) => {
    const userId = getCurrentUserId(user);
    const result = await getConversationRowsForUser(userId, query);
    const items = result.items.map(serializeConversationRow);

    return {
        items,
        conversations: items,
        pagination: result.pagination,
    };
};

export const createConversation = async (user: AuthenticatedUser, input: CreateConversationInput) => {
    const currentUserId = getCurrentUserId(user);

    if (!input.listingId && !input.bookingId && !input.participantId && !input.hostUserId) {
        throw new ApiError(422, "Validation error", [
            {
                path: "listingId",
                msg: "listingId or participantId is required",
            },
        ]);
    }

    const result = await sequelize.transaction(async (transaction) => {
        let listingId = input.listingId ?? null;
        let bookingId = input.bookingId ?? null;
        let guestUserId = currentUserId;
        let hostUserId: number | null = null;

        if (bookingId) {
            const bookingAccess = await getBookingAccess(bookingId, transaction);
            const relatedUserIds = new Set([bookingAccess.guestUserId, bookingAccess.hostUserId]);

            if (!relatedUserIds.has(currentUserId)) {
                throw new ApiError(403, "Forbidden");
            }

            if (listingId && listingId !== bookingAccess.listingId) {
                throw new ApiError(422, "Validation error", [
                    {
                        path: "listingId",
                        msg: "listingId must match the booking",
                    },
                ]);
            }

            listingId = listingId ?? bookingAccess.listingId;
            guestUserId = bookingAccess.guestUserId;
            hostUserId = bookingAccess.hostUserId;
        }

        if (listingId && !bookingId) {
            const listing = await getListingOrThrow(listingId, transaction);

            hostUserId = listing.hostId;
            guestUserId = currentUserId;

            if (currentUserId === listing.hostId) {
                throw new ApiError(403, "Bạn không thể nhắn tin cho chính chỗ nghỉ của mình.");
            }

        } else if (!bookingId) {
            hostUserId = input.participantId ?? input.hostUserId ?? null;
            guestUserId = currentUserId;
        }

        if (!hostUserId) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "participantId",
                    msg: "participantId is required",
                },
            ]);
        }

        const participants = ensureTwoPartyConversation(guestUserId, hostUserId);

        if (currentUserId === hostUserId) {
            throw new ApiError(403, "Bạn không thể nhắn tin cho chính chỗ nghỉ của mình.");
        }

        await assertBasicUserExists(hostUserId, transaction);

        const dedupeKey = bookingId
            ? `booking:${bookingId}`
            : listingId
              ? buildListingConversationDedupeKey(Number(listingId), participants.guestUserId, participants.hostUserId)
              : buildPairDedupeKey(participants.guestUserId, participants.hostUserId);
        const legacyDedupeKey = bookingId
            ? dedupeKey
            : buildPairDedupeKey(participants.guestUserId, participants.hostUserId, listingId ?? undefined);
        const existingConversation = await Conversation.findOne({
            where: {
                [Op.or]: [
                    { dedupeKey: { [Op.in]: [dedupeKey, legacyDedupeKey] } },
                    {
                        listingId,
                        guestUserId: participants.guestUserId,
                        hostUserId: participants.hostUserId,
                    },
                ],
            },
            transaction,
        });

        if (existingConversation) {
            const existingGuestUserId = Number(existingConversation.guestUserId);
            const existingHostUserId = Number(existingConversation.hostUserId);
            const nextParticipants =
                Number.isInteger(existingGuestUserId) &&
                existingGuestUserId > 0 &&
                Number.isInteger(existingHostUserId) &&
                existingHostUserId > 0 &&
                existingGuestUserId !== existingHostUserId
                    ? {
                          guestUserId: existingGuestUserId,
                          hostUserId: existingHostUserId,
                      }
                    : participants;

            await existingConversation.update(
                {
                    listingId,
                    guestUserId: nextParticipants.guestUserId,
                    hostUserId: nextParticipants.hostUserId,
                    bookingOrderId: bookingId ?? existingConversation.bookingOrderId,
                    dedupeKey,
                },
                { transaction },
            );
            await ensureConversationParticipants(
                Number(existingConversation.conversationId),
                nextParticipants.guestUserId,
                nextParticipants.hostUserId,
                transaction,
            );

            return {
                conversationId: Number(existingConversation.conversationId),
                created: false,
            };
        }

        const now = new Date();
        const conversation = await Conversation.create(
            {
                createdByUserId: currentUserId,
                listingId,
                guestUserId: participants.guestUserId,
                hostUserId: participants.hostUserId,
                bookingOrderId: bookingId,
                dedupeKey,
                lastMessage: null,
                lastMessageAt: null,
                createdAt: now,
                updatedAt: now,
            },
            { transaction },
        );

        await ensureConversationParticipants(
            conversation.conversationId,
            participants.guestUserId,
            participants.hostUserId,
            transaction,
        );
        await ConversationParticipant.update(
            {
                lastReadAt: now,
            },
            {
                where: {
                    conversationId: conversation.conversationId,
                    userId: currentUserId,
                },
                transaction,
            },
        );

        if (input.firstMessage?.trim()) {
            const firstMessage = normalizeMessageContent(input.firstMessage);
            await createMessageInTransaction(
                conversation.conversationId,
                currentUserId,
                firstMessage,
                "text",
                [],
                transaction,
            );
        }

        return {
            conversationId: Number(conversation.conversationId),
            created: true,
        };
    });

    return {
        conversation: await getConversationForUser(result.conversationId, currentUserId),
        created: result.created,
    };
};

export const assertConversationParticipant = async (
    conversationId: number,
    userId: number,
    transaction?: Transaction,
) => {
    const conversation = await Conversation.findOne({
        where: {
            conversationId,
        },
        transaction,
    });

    if (!conversation) {
        throw new ApiError(404, "Conversation not found");
    }

    const participant = await ConversationParticipant.findOne({
        where: {
            conversationId,
            userId,
        },
        transaction,
    });

    if (participant) {
        return participant;
    }

    const directRole = getConversationDirectRole(conversation, userId);

    if (!directRole) {
        throw new ApiError(403, "Forbidden");
    }

    return ConversationParticipant.create(
        {
            conversationId,
            userId,
            role: directRole,
            joinedAt: new Date(),
            lastReadAt: null,
        },
        { transaction },
    );
};

export const getConversationMessages = async (
    conversationId: number,
    user: AuthenticatedUser,
    query: ConversationMessagesQuery,
) => {
    const userId = getCurrentUserId(user);
    const { page, limit } = toPagination(query.page, query.limit);
    const participant = await assertConversationParticipant(conversationId, userId);
    const [items, totalItems] = await Promise.all([
        Message.find({ conversationId })
            .sort({ createdAt: 1, messageId: 1 })
            .skip((page - 1) * limit)
            .limit(limit),
        Message.countDocuments({ conversationId }),
    ]);

    participant.lastReadAt = new Date();
    await participant.save();

    return {
        items: items.map(serializeMessage),
        messages: items.map(serializeMessage),
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

export const sendConversationMessage = async (
    conversationId: number,
    user: AuthenticatedUser,
    input: SendMessageInput,
) => {
    const userId = getCurrentUserId(user);
    const messageType = input.messageType ?? "text";
    const content = normalizeMessageContent(input.content, true);
    const attachments = normalizeAttachments(input.attachments ?? [], messageType);

    if (messageType === "text" && !content) {
        throw new ApiError(422, "Validation error", [
            {
                path: "content",
                msg: "content is required",
            },
        ]);
    }

    if (!content && attachments.length === 0) {
        throw new ApiError(422, "Validation error", [
            {
                path: "content",
                msg: "content or attachments is required",
            },
        ]);
    }

    const result = await sequelize.transaction(async (transaction) => {
        const conversation = await Conversation.findOne({
            where: {
                conversationId,
            },
            transaction,
            lock: transaction.LOCK.UPDATE,
        });

        if (!conversation) {
            throw new ApiError(404, "Conversation not found");
        }

        const participants = ensureTwoPartyConversation(conversation.guestUserId, conversation.hostUserId);
        let receiverUserId: number;

        if (userId === participants.guestUserId) {
            receiverUserId = participants.hostUserId;
        } else if (userId === participants.hostUserId) {
            receiverUserId = participants.guestUserId;
        } else {
            throw new ApiError(403, "Forbidden");
        }

        await ensureConversationParticipants(
            conversationId,
            participants.guestUserId,
            participants.hostUserId,
            transaction,
        );
        const message = await createMessageInTransaction(
            conversationId,
            userId,
            content,
            messageType,
            attachments,
            transaction,
        );

        return {
            message,
            receiverUserId,
            guestUserId: participants.guestUserId,
            hostUserId: participants.hostUserId,
        };
    });

    const message = serializeMessage(result.message);
    const conversation = await getConversationForUser(conversationId, userId);
    debugMessaging(
        "[message] sender",
        userId,
        "receiver",
        result.receiverUserId,
        "conversation",
        conversationId,
    );

    emitMessageNew({
        conversationId,
        senderUserId: userId,
        message,
        conversation: {
            id: conversation.id,
            conversationId: conversation.conversationId,
            lastMessage: conversation.lastMessage,
            lastMessageAt: conversation.lastMessageAt,
            guestUserId: result.guestUserId,
            hostUserId: result.hostUserId,
        },
        receiverUserId: result.receiverUserId,
    });

    return {
        message,
        conversation,
    };
};

export const markConversationRead = async (conversationId: number, user: AuthenticatedUser) => {
    const userId = getCurrentUserId(user);
    const participant = await assertConversationParticipant(conversationId, userId);
    const lastReadAt = new Date();

    participant.lastReadAt = lastReadAt;
    await participant.save();

    return {
        conversationId,
        lastReadAt,
    };
};
