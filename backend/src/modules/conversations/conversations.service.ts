import { Op, QueryTypes, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import { isSafeExternalHttpUrl } from "../../common/url-security";
import sequelize from "../../config/database";
import Conversation from "../../models/conversation";
import ConversationParticipant from "../../models/conversation-participant";
import Message, { MessageAttachment, MessageDocument, MessageType } from "../../models/message";
import { emitMessageNew } from "../../socket/socket";
import { sendPushToUser } from "../../services/fcm-push.service";
import { sanitizeAndModerateText, sanitizeUserText } from "../../common/text-moderation";
import { assertBasicUserExists } from "../users/user-access.service";
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
    support?: boolean;
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
    otherRole?: string | null;
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

/**
 * Ép kiểu định danh người dùng đăng nhập sang số nguyên để đối chiếu khóa ngoại hội thoại.
 */
const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

/**
 * Ghi nhật ký gỡ lỗi luồng tin nhắn trên môi trường phát triển, tự động tắt trên môi trường `production` để tránh rò rỉ dữ liệu hội thoại.
 */
const debugMessaging = (...args: unknown[]) => {
    if (process.env.NODE_ENV !== "production") {
        console.log(...args);
    }
};

/**
 * Chuẩn hóa tham số phân trang hội thoại/tin nhắn trong biên an toàn (`page >= 1`, `1 <= limit <= 100`, mặc định 30).
 */
const toPagination = (page?: number, limit?: number) => ({
    page: Math.max(1, page ?? 1),
    limit: Math.min(100, Math.max(1, limit ?? defaultPageLimit)),
});

/**
 * Giải thuật làm sạch và kiểm duyệt nội dung tin nhắn (`normalizeMessageContent`):
 * Lọc XSS/ký tự nguy hiểm và kiểm duyệt nội dung qua `sanitizeAndModerateText`, đồng thời khống chế độ dài tối đa 2000 ký tự (`maxMessageLength`).
 */
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

/**
 * Tiện ích ném lỗi xác thực `422` chuẩn hóa kèm đường dẫn trường thuộc tính tệp đính kèm bị lỗi.
 */
const throwAttachmentValidationError = (path: string, msg: string): never => {
    throw new ApiError(422, "Validation error", [
        {
            path,
            msg,
        },
    ]);
};

/**
 * Phân tích cú pháp chuỗi URL đính kèm sang đối tượng `URL` chuẩn hoặc ném lỗi xác thực `422` nếu sai định dạng.
 */
const parseAttachmentUrl = (value: string, path: string): URL => {
    try {
        return new URL(value);
    } catch {
        return throwAttachmentValidationError(path, "attachments.url must be a valid URL");
    }
};

/**
 * Giải thuật chuẩn hóa và lọc bảo mật tệp đính kèm tin nhắn (`normalizeAttachments`):
 * 1. Kiểm tra định dạng URL và bắt buộc vượt qua `isSafeExternalHttpUrl` để ngăn chèn liên kết SSRF nội bộ / metadata cloud / IPv6 ánh xạ.
 * 2. Làm sạch chuỗi `type` và `name` qua `sanitizeUserText` để triệt tiêu mã độc XSS lưu trữ.
 */
const normalizeAttachments = (attachments: MessageAttachment[], messageType: MessageType) =>
    attachments.map((attachment, index) => {
        const url = parseAttachmentUrl(attachment.url, `attachments.${index}.url`);

        if (!["http:", "https:"].includes(url.protocol)) {
            throwAttachmentValidationError(`attachments.${index}.url`, "attachments.url must use http or https");
        }

        if (!isSafeExternalHttpUrl(url.toString())) {
            throwAttachmentValidationError(
                `attachments.${index}.url`,
                "attachments.url must reference a safe public http(s) resource",
            );
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

/**
 * Truy vấn thông tin tối thiểu của chỗ nghỉ (`listingId`, `hostId`, `status`, `title`) phục vụ khởi tạo hội thoại hoặc ném lỗi `404` nếu không tồn tại/đã xóa mềm.
 */
const getListingOrThrow = async (listingId: number, transaction?: Transaction) => {
    const rows = await sequelize.query<ListingAccessRow & { status?: string }>(
        `
        SELECT
            listing_id AS listingId,
            host_id AS hostId,
            status,
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

/**
 * Truy vấn cặp định danh `guestUserId` - `hostUserId` và `listingId` của đơn đặt phòng để kiểm tra phân quyền hội thoại chống BOLA/IDOR.
 */
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

/**
 * Giải thuật sinh khóa chống trùng lặp hội thoại trực tiếp bất biến theo thứ tự hai bên (`buildPairDedupeKey`):
 * Sắp xếp tăng dần `[leftUserId, rightUserId]` để khóa `direct:min:max` (hoặc `listing:id:min:max`) luôn duy nhất bất kể ai là người khởi tạo trước.
 */
const buildPairDedupeKey = (leftUserId: number, rightUserId: number, listingId?: number) => {
    const [firstUserId, secondUserId] = [leftUserId, rightUserId].sort((left, right) => left - right);

    return listingId
        ? `listing:${listingId}:${firstUserId}:${secondUserId}`
        : `direct:${firstUserId}:${secondUserId}`;
};

/**
 * Sinh khóa định danh duy nhất cho hội thoại gắn với chỗ nghỉ theo đúng vai trò `listing:{listingId}:guest:{guestUserId}:host:{hostUserId}`.
 */
const buildListingConversationDedupeKey = (listingId: number, guestUserId: number, hostUserId: number) =>
    `listing:${listingId}:guest:${guestUserId}:host:${hostUserId}`;

/**
 * Giải thuật kiểm tra tính toàn vẹn hai bên tham gia hội thoại (`ensureTwoPartyConversation`):
 * Ràng buộc `guestUserId` và `hostUserId` đều là số nguyên dương hợp lệ và khác nhau (`guestUserId !== hostUserId`), chặn hội thoại tự nhắn cho chính mình.
 */
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

/**
 * Xác định vai trò trực tiếp (`"guest"` hoặc `"host"`) của người dùng dựa trên hai cột khóa ngoại trên bản ghi `Conversation`.
 */
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

/**
 * Giải thuật đồng bộ bảng thành viên hội thoại `ConversationParticipant` bất biến (idempotent upsert):
 * Sử dụng `bulkCreate` kèm `updateOnDuplicate: ["role"]` để đảm bảo cả `guest` và `host` luôn có bản ghi theo dõi trạng thái đọc mà không gây lỗi trùng khóa.
 */
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

/**
 * Tuần tự hóa dòng kết quả truy vấn hội thoại thành cấu trúc phản hồi API kèm thông tin chỗ nghỉ và đối phương trò chuyện (`otherParticipant`).
 */
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
              ...(row.otherRole ? { role: row.otherRole } : {}),
          }
        : null,
});

/**
 * Tuần tự hóa bản ghi tin nhắn sang định dạng chuẩn đồng bộ cho cả REST API và sự kiện thời gian thực Socket.IO.
 */
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

/**
 * Giải thuật truy vấn danh sách hội thoại phân trang của người dùng chống BOLA/IDOR:
 * 1. Ràng buộc điều kiện thành viên trực tiếp (`guest_user_id`, `host_user_id` hoặc `conversation_participant.user_id = :userId`) bằng SQL tham số hóa.
 * 2. Tính số lượng tin nhắn chưa đọc (`unreadCount`) dựa trên mốc `last_read_at`, lấy ảnh bìa chỗ nghỉ, nhận diện vai trò `admin` của đối phương và sắp xếp giảm dần theo `sortAt`.
 */
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
                COALESCE(
                    c.last_message,
                    (
                        SELECT m2.content
                        FROM message m2
                        WHERE m2.conversation_id = c.conversation_id
                        ORDER BY m2.created_at DESC, m2.message_id DESC
                        LIMIT 1
                    )
                ) AS lastMessage,
                COALESCE(
                    c.last_message_at,
                    (
                        SELECT m2.created_at
                        FROM message m2
                        WHERE m2.conversation_id = c.conversation_id
                        ORDER BY m2.created_at DESC, m2.message_id DESC
                        LIMIT 1
                    ),
                    c.updated_at
                ) AS lastMessageAt,
                (
                    SELECT COUNT(*)
                    FROM message unread_message
                    WHERE unread_message.conversation_id = c.conversation_id
                      AND unread_message.sender_id <> :userId
                      AND (
                          current_participant.last_read_at IS NULL
                          OR unread_message.created_at > current_participant.last_read_at
                      )
                ) AS unreadCount,
                c.created_at AS createdAt,
                c.updated_at AS updatedAt,
                l.title AS listingTitle,
                (
                    SELECT li.url
                    FROM listing_images li
                    WHERE li.listing_id = c.listing_id
                    ORDER BY li.is_cover DESC, li.sort_order ASC, li.id ASC
                    LIMIT 1
                ) AS listingCoverImageUrl,
                other_user.user_id AS otherUserId,
                other_user.full_name AS otherFullName,
                other_user.avatar_url AS otherAvatarUrl,
                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM user_role ur_admin
                        INNER JOIN roles r_admin ON r_admin.role_id = ur_admin.role_id
                        WHERE ur_admin.user_id = other_user.user_id
                          AND r_admin.code = 'admin'
                    ) THEN 'admin'
                    ELSE NULL
                END AS otherRole,
                COALESCE(
                    c.last_message_at,
                    (
                        SELECT m2.created_at
                        FROM message m2
                        WHERE m2.conversation_id = c.conversation_id
                        ORDER BY m2.created_at DESC, m2.message_id DESC
                        LIMIT 1
                    ),
                    c.updated_at
                ) AS sortAt
            FROM conversation c
            LEFT JOIN conversation_participant current_participant
                ON current_participant.conversation_id = c.conversation_id
               AND current_participant.user_id = :userId
            LEFT JOIN listings l
                ON l.listing_id = c.listing_id
            LEFT JOIN users other_user
                ON other_user.user_id = CASE
                    WHEN c.guest_user_id = :userId THEN c.host_user_id
                    WHEN c.host_user_id = :userId THEN c.guest_user_id
                    ELSE COALESCE(c.guest_user_id, c.host_user_id)
                END
            WHERE (
                    c.guest_user_id = :userId
                 OR c.host_user_id = :userId
                 OR current_participant.user_id = :userId
              )
              ${scopeClause}
              ${conversationClause}
        ) conversation_rows
        ${unreadOnlyClause}
    `;
    const countSql = `
        SELECT COUNT(*) AS totalItems
        FROM conversation c
        LEFT JOIN conversation_participant current_participant
            ON current_participant.conversation_id = c.conversation_id
           AND current_participant.user_id = :userId
        WHERE (
                c.guest_user_id = :userId
             OR c.host_user_id = :userId
             OR current_participant.user_id = :userId
          )
          ${scopeClause}
          ${conversationClause}
          ${
              query.unreadOnly === true
                  ? `AND EXISTS (
                        SELECT 1
                        FROM message unread_message
                        WHERE unread_message.conversation_id = c.conversation_id
                          AND unread_message.sender_id <> :userId
                          AND (
                              current_participant.last_read_at IS NULL
                              OR unread_message.created_at > current_participant.last_read_at
                          )
                    )`
                  : ""
          }
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
            countSql,
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

/**
 * Truy vấn chi tiết một hội thoại cụ thể thuộc quyền truy cập của `userId` hoặc ném lỗi `404` nếu không tồn tại/không có quyền tham gia (chống BOLA).
 */
const getConversationForUser = async (conversationId: number, userId: number) => {
    const result = await getConversationRowsForUser(userId, { page: 1, limit: 1 }, conversationId);
    const row = result.items[0];

    if (!row) {
        throw new ApiError(404, "Conversation not found");
    }

    return serializeConversationRow(row);
};

/**
 * Giải thuật ghi nhận tin nhắn mới nguyên tử trong phạm vi giao dịch DB (`createMessageInTransaction`):
 * 1. Tạo bản ghi `Message` (dùng nhãn dự phòng `[image]`/`[file]` khi gửi tệp không kèm chữ).
 * 2. Cập nhật đồng bộ bản xem trước `lastMessage` và `lastMessageAt` trên bảng `Conversation`.
 * 3. Đánh dấu mốc đã đọc `lastReadAt = now` cho chính người gửi trên `ConversationParticipant`.
 */
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

/**
 * Liệt kê danh sách hội thoại phân trang của người dùng hiện tại theo bộ lọc vai trò (`guest`/`host`) hoặc chưa đọc (`unreadOnly`).
 */
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

/**
 * Giải thuật khởi tạo hoặc tái sử dụng hội thoại hai chiều an toàn trong giao dịch DB (`createConversation`):
 * 1. Phân giải người tham gia theo ngữ cảnh: kiểm tra thành viên đơn đặt phòng (`bookingId` chống BOLA), xác định chủ nhà thực tế từ `listings.host_id` (chặn tự nhắn cho chỗ nghỉ của mình), hoặc định tuyến tự động tới Quản trị viên đang hoạt động khi `support = true`.
 * 2. Sinh khóa khử trùng lặp `dedupeKey` (tương thích ngược với `legacyDedupeKey`) để tái sử dụng hội thoại sẵn có thay vì tạo bản ghi trùng.
 * 3. Đồng bộ `ConversationParticipant` và ghi tin nhắn mở đầu (`firstMessage`) nguyên tử nếu được cung cấp.
 */
export const createConversation = async (user: AuthenticatedUser, input: CreateConversationInput) => {
    const currentUserId = getCurrentUserId(user);

    if (!input.listingId && !input.bookingId && !input.participantId && !input.hostUserId && !input.support) {
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

            if (listing.status && listing.status !== "active" && listing.status !== "published") {
                throw new ApiError(403, "Chỗ nghỉ này hiện không khả dụng để liên hệ.");
            }

            hostUserId = listing.hostId;
            guestUserId = currentUserId;

            if (currentUserId === listing.hostId) {
                throw new ApiError(403, "Bạn không thể nhắn tin cho chính chỗ nghỉ của mình.");
            }

        } else if (!bookingId && input.support && !input.participantId && !input.hostUserId) {
            // Giải thuật định tuyến hội thoại hỗ trợ Quản trị viên (supportAdmin):
            // Tự động chọn tài khoản Admin đang hoạt động đầu tiên để tạo hội thoại thật trong CSDL thay cho ID giả 'admin_support'.
            const adminRows = await sequelize.query<{ userId: number }>(
                `
                SELECT u.user_id AS userId
                FROM users u
                INNER JOIN user_role ur ON ur.user_id = u.user_id
                INNER JOIN roles r ON r.role_id = ur.role_id
                WHERE r.code = 'admin'
                  AND u.status = 'active'
                  AND u.deleted_at IS NULL
                  AND u.user_id <> ?
                ORDER BY u.user_id ASC
                LIMIT 1
                `,
                {
                    replacements: [currentUserId],
                    type: QueryTypes.SELECT,
                    transaction,
                },
            );
            const supportAdminId = Number(adminRows[0]?.userId ?? 0);
            if (!supportAdminId) {
                throw new ApiError(404, "Hiện chưa có Quản trị viên trực tuyến để mở hội thoại hỗ trợ.");
            }
            if (user.roles?.includes("host")) {
                guestUserId = supportAdminId;
                hostUserId = currentUserId;
            } else {
                guestUserId = currentUserId;
                hostUserId = supportAdminId;
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

        if (!bookingId && !input.support && currentUserId === hostUserId) {
            throw new ApiError(403, "Bạn không thể nhắn tin cho chính chỗ nghỉ của mình.");
        }

        const targetOtherUserId = currentUserId === hostUserId ? guestUserId : hostUserId;
        await assertBasicUserExists(targetOtherUserId, transaction);

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

/**
 * Giải thuật xác thực quyền thành viên hội thoại chống BOLA/IDOR kèm cơ chế tự động bù đắp bản ghi (`assertConversationParticipant`):
 * 1. Truy vấn `Conversation` (`404` nếu không tồn tại) và kiểm tra bản ghi `ConversationParticipant`.
 * 2. Nếu chưa có bản ghi thành viên nhưng `userId` khớp với `guestUserId` hoặc `hostUserId` gốc trên `Conversation`, tự động khởi tạo bản ghi `ConversationParticipant` tương ứng; ngược lại ném `403 Forbidden`.
 */
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

/**
 * Giải thuật tải phân trang cửa sổ tin nhắn mới nhất theo trình tự thời gian tự nhiên (`getConversationMessages`):
 * 1. Xác thực quyền thành viên hội thoại qua `assertConversationParticipant`.
 * 2. Truy vấn CSDL giảm dần (`createdAt DESC, messageId DESC`) để trang 1 luôn lấy đúng `limit` tin nhắn mới nhất, sau đó đảo lại theo chiều tăng dần thời gian để hiển thị khung chat tự nhiên.
 * 3. Tự động cập nhật mốc đã đọc `lastReadAt` khi người dùng mở trang đầu tiên (`page === 1`).
 */
export const getConversationMessages = async (
    conversationId: number,
    user: AuthenticatedUser,
    query: ConversationMessagesQuery,
) => {
    const userId = getCurrentUserId(user);
    const { page, limit } = toPagination(query.page, query.limit);
    const participant = await assertConversationParticipant(conversationId, userId);
    // Giải thuật phân trang cửa sổ tin nhắn mới nhất (latest-window chronological pagination):
    // - Truy vấn CSDL giảm dần theo (createdAt DESC, messageId DESC) để trang 1 luôn chứa N tin nhắn mới nhất (không bị kẹt ở 50 tin đầu tiên).
    // - Sau khi lấy cửa sổ trang, sắp xếp lại tăng dần theo thời gian (createdAt ASC, messageId ASC) để khung chat hiển thị từ trên xuống dưới tự nhiên.
    // CONFLICT-RESOLVED: Khắc phục lỗi sort({ createdAt: 1 }) làm ẩn toàn bộ tin nhắn mới từ tin thứ 51 trở đi.
    const [rawItems, totalItems] = await Promise.all([
        Message.find({ conversationId })
            .sort({ createdAt: -1, messageId: -1 })
            .skip((page - 1) * limit)
            .limit(limit),
        Message.countDocuments({ conversationId }),
    ]);

    const chronologicalItems = [...rawItems].sort((left, right) => {
        const leftTime = left.createdAt ? new Date(left.createdAt).getTime() : 0;
        const rightTime = right.createdAt ? new Date(right.createdAt).getTime() : 0;
        if (leftTime !== rightTime) {
            return leftTime - rightTime;
        }
        return Number(left.messageId ?? 0) - Number(right.messageId ?? 0);
    });

    if (page === 1) {
        participant.lastReadAt = new Date();
        await participant.save();
    }

    const serializedItems = chronologicalItems.map(serializeMessage);

    return {
        items: serializedItems,
        messages: serializedItems,
        pagination: {
            page,
            limit,
            total: totalItems,
            totalPages: Math.max(1, Math.ceil(totalItems / limit)),
        },
    };
};

/**
 * Giải thuật gửi tin nhắn hội thoại an toàn đồng bộ DB - Socket.IO - Thông báo đẩy FCM (`sendConversationMessage`):
 * 1. Làm sạch/kiểm duyệt nội dung (`normalizeMessageContent`) và lọc bảo mật tệp đính kèm chống SSRF/XSS (`normalizeAttachments`).
 * 2. Mở giao dịch DB với khóa dòng bi quan (`LOCK.UPDATE`) trên `Conversation`, xác thực người gửi thuộc cặp `guest`/`host` (chống BOLA), đồng bộ thành viên và ghi tin nhắn nguyên tử.
 * 3. Sau khi commit giao dịch thành công, phát sự kiện thời gian thực `emitMessageNew` qua Socket.IO và gửi thông báo đẩy bất đồng bộ `sendPushToUser` tới người nhận.
 */
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

    const senderDisplayName = user.name?.trim() || "Tin nhắn mới";
    const listingSuffix = conversation.listing?.title ? ` • ${conversation.listing.title}` : "";
    const previewBody =
        message.messageType === "image"
            ? "Đã gửi một hình ảnh"
            : message.messageType === "file"
              ? "Đã gửi một tệp đính kèm"
              : message.content;

    void sendPushToUser(result.receiverUserId, {
        title: `${senderDisplayName}${listingSuffix}`,
        body: previewBody,
        actionUrl:
            result.receiverUserId === result.hostUserId
                ? "/host/tin-nhan"
                : `/tin-nhan?conversationId=${conversationId}`,
        eventType: "MESSAGE_NEW",
        targetType: "conversation",
        targetId: conversationId,
        data: {
            conversationId,
            messageId: message.messageId,
            senderUserId: userId,
        },
    });

    return {
        message,
        conversation,
    };
};

/**
 * Đánh dấu toàn bộ tin nhắn trong hội thoại là đã đọc đối với người dùng hiện tại sau khi xác thực quyền thành viên (`assertConversationParticipant`).
 */
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
