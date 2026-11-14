import type { Server as HttpServer } from "node:http";

import { Server as SocketIOServer, type Socket } from "socket.io";

import { getEnv } from "../config/env";
import { logger } from "../config/logger";
import Conversation from "../models/conversation";
import ConversationParticipant from "../models/conversation-participant";
import User from "../models/user";
import {
    assertUserCanAuthenticate,
    toAuthenticatedUser,
    verifyAuthToken,
    type AuthenticatedUser,
} from "../modules/auth/auth.service";

type AuthenticatedSocket = Socket & {
    data: {
        user?: AuthenticatedUser;
        tokenExp?: number;
    };
};

type MessageNewPayload = {
    conversationId: number;
    message: {
        id: number;
        messageId: number;
        conversationId: number;
        senderUserId: number;
        senderId: number;
        content: string;
        body: string;
        messageType: string;
        attachments: unknown[];
        createdAt: Date;
        updatedAt: Date | null;
    };
    conversation: {
        id: number;
        conversationId: number;
        lastMessage: string | null;
        lastMessageAt: Date | null;
        guestUserId: number;
        hostUserId: number;
    };
    receiverUserId: number;
    senderUserId: number;
};

export type NotificationNewPayload = {
    id: number;
    notificationLogId: number;
    eventType: string;
    targetType: string;
    targetId: string;
    title: string | null;
    body: string | null;
    actionUrl: string | null;
    payload: Record<string, unknown> | null;
    readAt: Date | null;
    createdAt: Date;
};

let io: SocketIOServer | null = null;

const SOCKET_MAX_HTTP_BUFFER_SIZE = 64 * 1024;
const SOCKET_EVENT_WINDOW_MS = 10_000;
const SOCKET_EVENT_MAX_PER_WINDOW = 60;

const userRoom = (userId: string | number) => `user:${userId}`;
const conversationRoom = (conversationId: string | number) => `conversation:${conversationId}`;

const debugSocket = (...args: unknown[]) => {
    if (getEnv().nodeEnv !== "production") {
        console.log(...args);
    }
};

/**
 * Giải thuật xác định danh sách Origin hợp lệ cho kết nối thời gian thực Socket.IO.
 */
const getSocketCorsOrigin = () => {
    const env = getEnv();

    if (env.nodeEnv !== "production") {
        if (env.corsOrigins.length === 0) {
            return true;
        }
        return [
            ...env.corsOrigins,
            /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i,
        ];
    }

    return env.corsOrigins;
};

/**
 * Giải thuật trích xuất JWT Access Token trong bắt tay kết nối Socket.IO (`handshake.auth.token` hoặc `Authorization` header).
 */
const extractSocketToken = (socket: Socket) => {
    const authToken = socket.handshake.auth?.token;

    if (typeof authToken === "string" && authToken.trim()) {
        return authToken.replace(/^Bearer\s+/i, "").trim();
    }

    const headerToken = socket.handshake.headers.authorization;

    if (typeof headerToken === "string" && headerToken.startsWith("Bearer ")) {
        return headerToken.slice("Bearer ".length).trim();
    }

    return null;
};

const extractRawConversationId = (payload: unknown): unknown => {
    if (typeof payload === "object" && payload !== null && "conversationId" in payload) {
        return (payload as { conversationId?: unknown }).conversationId;
    }

    if (typeof payload === "number" || typeof payload === "string") {
        return payload;
    }

    return undefined;
};

/**
 * Giải thuật xác thực bắt tay kết nối WebSocket/Socket.IO:
 * - Xác minh chữ ký JWT, đối chiếu trạng thái người dùng trên CSDL và lưu mốc hết hạn `tokenExp` vào `socket.data` để tái kiểm tra khi tham gia phòng.
 */
const authenticateSocket = async (socket: AuthenticatedSocket, next: (error?: Error) => void) => {
    try {
        const token = extractSocketToken(socket);

        if (!token) {
            return next(new Error("Unauthorized"));
        }

        const payload = verifyAuthToken(token) as {
            userId: string;
            role: string;
            exp?: number;
        };
        const user = await User.findById(payload.userId);

        if (!user) {
            return next(new Error("Unauthorized"));
        }

        assertUserCanAuthenticate(user);
        socket.data.user = await toAuthenticatedUser(user);
        socket.data.tokenExp = typeof payload.exp === "number" ? payload.exp : undefined;

        return next();
    } catch {
        return next(new Error("Unauthorized"));
    }
};

/**
 * Giải thuật tái xác thực phiên Socket đang mở nhằm chặn kết nối có token đã hết hạn hoặc tài khoản vừa bị khóa sau thời điểm bắt tay.
 */
const assertSocketSessionStillActive = async (socket: AuthenticatedSocket, userId: number) => {
    const tokenExp = socket.data.tokenExp;
    if (typeof tokenExp === "number" && tokenExp * 1000 <= Date.now()) {
        return false;
    }

    if (typeof User.findById === "function") {
        const currentUser = await User.findById(String(userId));
        if (!currentUser) {
            return false;
        }
        try {
            assertUserCanAuthenticate(currentUser);
        } catch {
            return false;
        }
    }

    return true;
};

/**
 * Giải thuật kiểm tra quyền thành viên phòng hội thoại trên kênh Socket (chống nghe lén hội thoại IDOR).
 */
const assertSocketConversationParticipant = async (
    socket: AuthenticatedSocket,
    conversationId: number,
    userId: number,
) => {
    const active = await assertSocketSessionStillActive(socket, userId);
    if (!active) {
        socket.emit("conversation:error", {
            conversationId,
            message: "Unauthorized",
        });
        socket.disconnect(true);
        return null;
    }

    const conversation = await Conversation.findOne({
        where: {
            conversationId,
        },
    });

    if (!conversation) {
        return false;
    }

    if (Number(conversation.guestUserId) === userId || Number(conversation.hostUserId) === userId) {
        return true;
    }

    const participant = await ConversationParticipant.findOne({
        where: {
            conversationId,
            userId,
        },
    });

    return Boolean(participant);
};

/**
 * Giải thuật khởi tạo máy chủ Socket.IO thời gian thực kèm hạn mức bộ đệm gói tin (64KB) và bộ đếm hạn ngạch sự kiện mỗi cửa sổ 10 giây.
 */
export const initializeSocket = (server: HttpServer) => {
    io = new SocketIOServer(server, {
        maxHttpBufferSize: SOCKET_MAX_HTTP_BUFFER_SIZE,
        cors: {
            origin: getSocketCorsOrigin(),
            credentials: true,
        },
    });

    io.use((socket, next) => {
        void authenticateSocket(socket as AuthenticatedSocket, next);
    });

    io.on("connection", (socket: Socket) => {
        const authenticatedSocket = socket as AuthenticatedSocket;
        const user = authenticatedSocket.data.user;

        if (!user) {
            authenticatedSocket.disconnect(true);
            return;
        }

        let windowStartedAt = Date.now();
        let eventsInWindow = 0;

        const consumeEventQuota = () => {
            const now = Date.now();
            if (now - windowStartedAt >= SOCKET_EVENT_WINDOW_MS) {
                windowStartedAt = now;
                eventsInWindow = 0;
            }
            eventsInWindow += 1;
            if (eventsInWindow > SOCKET_EVENT_MAX_PER_WINDOW) {
                authenticatedSocket.emit("conversation:error", {
                    message: "Too many socket events",
                });
                authenticatedSocket.disconnect(true);
                return false;
            }
            return true;
        };

        authenticatedSocket.join(userRoom(user.id));
        debugSocket("[socket] connected user", user.id);

        authenticatedSocket.on("conversation:join", (payload?: unknown) => {
            if (!consumeEventQuota()) {
                return;
            }

            const rawConversationId = extractRawConversationId(payload);

            void (async () => {
                const conversationId = Number(rawConversationId);

                if (!Number.isInteger(conversationId) || conversationId < 1) {
                    authenticatedSocket.emit("conversation:error", {
                        conversationId: rawConversationId,
                        message: "conversationId is invalid",
                    });
                    return;
                }

                const allowed = await assertSocketConversationParticipant(
                    authenticatedSocket,
                    conversationId,
                    Number(user.id),
                );

                if (allowed === null) {
                    return;
                }

                if (!allowed) {
                    authenticatedSocket.emit("conversation:error", {
                        conversationId,
                        message: "Forbidden",
                    });
                    return;
                }

                authenticatedSocket.join(conversationRoom(conversationId));
                debugSocket("[socket] join conversation", conversationId, "user", user.id);
            })().catch((error) => {
                logger.error("Failed to join conversation socket room", error, {
                    userId: user.id,
                    conversationId: rawConversationId,
                });
                authenticatedSocket.emit("conversation:error", {
                    conversationId: rawConversationId,
                    message: "Could not join conversation",
                });
            });
        });

        authenticatedSocket.on("conversation:leave", (payload?: unknown) => {
            if (!consumeEventQuota()) {
                return;
            }

            const rawConversationId = extractRawConversationId(payload);
            const conversationId = Number(rawConversationId);

            if (Number.isInteger(conversationId) && conversationId > 0) {
                authenticatedSocket.leave(conversationRoom(conversationId));
            }
        });
    });

    return io;
};

/** Trả về thể hiện máy chủ Socket.IO hiện hành (nếu đã khởi tạo). */
export const getSocketServer = () => io;

/**
 * Giải thuật ngắt cưỡng bức toàn bộ kết nối Socket đang mở của một người dùng khi tài khoản bị thu hồi quyền hoặc khóa khẩn cấp.
 */
export const disconnectUserSockets = (userId: string | number) => {
    if (!io) {
        return;
    }

    io.in(userRoom(userId)).disconnectSockets(true);
};

/**
 * Giải thuật phát sóng tin nhắn mới (`message:new`) tới phòng hội thoại và phòng cá nhân của người nhận nhưng loại trừ người gửi để tránh nhân đôi bản ghi phía client.
 */
export const emitMessageNew = (payload: MessageNewPayload) => {
    if (!io) {
        return;
    }

    debugSocket(
        "[socket] emit message:new to",
        userRoom(payload.receiverUserId),
        conversationRoom(payload.conversationId),
    );

    io.to(conversationRoom(payload.conversationId))
        .to(userRoom(payload.receiverUserId))
        .except(userRoom(payload.senderUserId))
        .emit("message:new", {
            conversationId: payload.conversationId,
            message: payload.message,
            conversation: payload.conversation,
        });
};

/**
 * Giải thuật đẩy thông báo thời gian thực (`notification:new`) tới phòng cá nhân của người nhận.
 */
export const emitNotificationNew = (userId: string | number, payload: NotificationNewPayload) => {
    if (!io) {
        return;
    }

    debugSocket("[socket] emit notification:new to", userRoom(userId));
    io.to(userRoom(userId)).emit("notification:new", payload);
};
