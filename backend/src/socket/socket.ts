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

export const getSocketServer = () => io;

export const disconnectUserSockets = (userId: string | number) => {
    if (!io) {
        return;
    }

    io.in(userRoom(userId)).disconnectSockets(true);
};

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

export const emitNotificationNew = (userId: string | number, payload: NotificationNewPayload) => {
    if (!io) {
        return;
    }

    debugSocket("[socket] emit notification:new to", userRoom(userId));
    io.to(userRoom(userId)).emit("notification:new", payload);
};
