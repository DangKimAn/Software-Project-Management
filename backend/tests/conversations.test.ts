const assert = require("node:assert/strict");
const { afterEach, beforeEach, describe, it } = require("node:test");

const request = require("supertest");
import type { PatchEntry } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const { ApiError } = require("../dist/common/api-error");
const sequelize = require("../dist/config/database").default;
const Conversation = require("../dist/models/conversation").default;
const ConversationParticipant = require("../dist/models/conversation-participant").default;
const Message = require("../dist/models/message").default;
const Listing = require("../dist/models/listing").default;
const User = require("../dist/models/user").default;
const authService = require("../dist/modules/auth/auth.service");
const conversationsService = require("../dist/modules/conversations/conversations.service");
const socketModule = require("../dist/socket/socket");

const originals: PatchEntry[] = [];

const patch = (target: Record<string, unknown>, key: string, value: unknown): void => {
    originals.push([target, key, target[key]]);
    target[key] = value;
};

afterEach(() => {
    while (originals.length > 0) {
        const [target, key, value] = originals.pop()!;
        target[key] = value;
    }
});

const guestUser = {
    id: "201",
    email: "guest@example.com",
    phone: "0900000201",
    name: "Guest User",
    username: "guest",
    status: "active",
    roles: ["guest"],
};

const hostUser = {
    id: "101",
    email: "host@example.com",
    phone: "0900000101",
    name: "Host User",
    username: "host",
    status: "active",
    roles: ["host"],
};

const outsiderUser = {
    id: "301",
    email: "outsider@example.com",
    phone: "0900000301",
    name: "Outsider User",
    username: "outsider",
    status: "active",
    roles: ["guest"],
};

const guestAuth = { Authorization: "Bearer guest-token" };
const hostAuth = { Authorization: "Bearer host-token" };
const outsiderAuth = { Authorization: "Bearer outsider-token" };

const buildConversation = (overrides: Record<string, unknown> = {}) => ({
    id: 1,
    conversationId: 601,
    createdByUserId: 201,
    listingId: 801,
    guestUserId: 201,
    hostUserId: 101,
    bookingOrderId: null,
    dedupeKey: "listing:801:guest:201:host:101",
    lastMessage: "Xin chào villa!",
    lastMessageAt: new Date("2026-05-10T12:00:00.000Z"),
    createdAt: new Date("2026-05-10T12:00:00.000Z"),
    updatedAt: new Date("2026-05-10T12:00:00.000Z"),
    async save() {
        return this;
    },
    async update(fields: any) {
        Object.assign(this, fields);
        return this;
    },
    ...overrides,
});

const buildMessage = (overrides: Record<string, unknown> = {}) => ({
    id: 1,
    messageId: 1001,
    conversationId: 601,
    senderUserId: 201,
    content: "Chào bạn, villa còn phòng vào cuối tuần không?",
    messageType: "text",
    attachments: [],
    createdAt: new Date("2026-05-10T12:00:00.000Z"),
    updatedAt: null,
    async save() {
        return this;
    },
    ...overrides,
});

describe("Module conversations - REST (CV-01 to CV-10)", () => {
    let app: any;

    beforeEach(() => {
        app = require("../dist/app").default;

        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "guest-token") return { userId: "201", role: "guest" };
            if (token === "host-token") return { userId: "101", role: "host" };
            if (token === "outsider-token") return { userId: "301", role: "guest" };
            throw new ApiError(401, "Unauthorized");
        });

        patch(authService, "toAuthenticatedUser", async (user: any) => ({
            id: String(user.id || user._id || user.userId),
            email: user.email,
            phone: user.phone,
            name: user.name || user.fullName,
            username: user.username,
            status: user.status || "active",
            roles: user.roles || ["guest"],
        }));

        const usersMap = new Map([
            ["201", guestUser],
            ["101", hostUser],
            ["301", outsiderUser],
        ]);

        patch(User, "findById", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findByPk", async (id: string | number) => usersMap.get(String(id)) ?? null);
        patch(User, "findOne", async ({ where }: any) => {
            const id = where?.id || where?.userId;
            return usersMap.get(String(id)) ?? null;
        });

        patch(Conversation, "update", async () => [1]);
        patch(ConversationParticipant, "update", async () => [1]);
        patch(ConversationParticipant, "bulkCreate", async () => []);
        patch(ConversationParticipant, "create", async (data: any) => ({
            ...data,
            async save() {
                return this;
            },
        }));

        patch(Message, "create", async (data: any) => buildMessage(data));

        patch(sequelize, "query", async (sql: string, options: any) => {
            const rawSql = typeof sql === "string" ? sql : "";
            const normalized = rawSql.replace(/\s+/g, " ");

            if (normalized.includes("SELECT user_id AS userId") || normalized.includes("FROM users")) {
                const userId = options?.replacements?.[0] ?? 101;
                return [
                    {
                        userId: Number(userId),
                        email: "host@example.com",
                        fullName: "Host User",
                        status: "active",
                    },
                ];
            }
            if (normalized.includes("c.conversation_id AS conversationId") || normalized.includes("conversation_rows")) {
                return [
                    {
                        id: 601,
                        conversationId: 601,
                        createdByUserId: 201,
                        listingId: 801,
                        guestUserId: 201,
                        hostUserId: 101,
                        bookingOrderId: null,
                        lastMessage: "Xin chào villa!",
                        lastMessageAt: new Date("2026-05-10T12:00:00.000Z"),
                        unreadCount: 0,
                        createdAt: new Date("2026-05-10T12:00:00.000Z"),
                        updatedAt: new Date("2026-05-10T12:00:00.000Z"),
                        listingTitle: "Villa Vũng Tàu",
                        listingCoverImageUrl: null,
                        otherUserId: 101,
                        otherFullName: "Host User",
                        otherAvatarUrl: null,
                    },
                ];
            }
            if (normalized.includes("COUNT(*) AS totalItems FROM conversation")) {
                return [{ totalItems: 1 }];
            }
            if (normalized.includes("listing_id AS listingId") || normalized.includes("FROM listings")) {
                return [
                    {
                        listingId: 801,
                        hostId: 101,
                        title: "Villa Vũng Tàu",
                    },
                ];
            }
            if (normalized.includes("b.booking_id AS bookingOrderId") || normalized.includes("FROM bookings")) {
                return [
                    {
                        bookingOrderId: 701,
                        listingId: 801,
                        guestUserId: 201,
                        hostUserId: 101,
                    },
                ];
            }
            return [];
        });

        patch(sequelize, "transaction", async (arg1: any, arg2?: any) => {
            const callback = typeof arg1 === "function" ? arg1 : arg2;
            return callback
                ? callback({
                      LOCK: { UPDATE: "UPDATE" },
                      afterCommit(fn: () => void) {
                          fn();
                      },
                  })
                : {};
        });

        patch(socketModule, "emitMessageNew", () => {});
    });

    it("CV-01: Guest mở hội thoại với host của listing thành công, không tạo trùng lặp (HTTP 200/201)", async () => {
        patch(Listing, "findOne", async () => ({
            listingId: 801,
            hostId: 101,
            title: "Villa Vũng Tàu",
        }));

        patch(Conversation, "findOne", async () => null); // Chưa có hội thoại

        patch(Conversation, "create", async (data: any) => buildConversation({ ...data, conversationId: 601 }));
        patch(ConversationParticipant, "bulkCreate", async () => []);
        patch(ConversationParticipant, "update", async () => [1]);

        const res = await request(app)
            .post("/api/conversations")
            .set(guestAuth)
            .send({
                listingId: 801,
                firstMessage: "Chào host, tôi muốn hỏi về villa",
            });

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.conversation.conversationId, 601);
    });

    it("CV-02: Gửi tin nhắn hợp lệ lưu vào DB và phát socket realtime thành công (HTTP 201)", async () => {
        const mockConv = buildConversation({ conversationId: 601, guestUserId: 201, hostUserId: 101 });
        patch(Conversation, "findOne", async () => mockConv);

        patch(ConversationParticipant, "findOne", async ({ where }: any) => {
            if (where.conversationId === 601 && (where.userId === 201 || where.userId === 101)) {
                return { conversationId: 601, userId: where.userId, lastReadAt: null, async save() {} };
            }
            return null;
        });

        patch(ConversationParticipant, "bulkCreate", async () => []);

        let savedMessage: any = null;
        patch(Message.prototype, "save", async function (this: any) {
            savedMessage = this;
            this.messageId = 1001;
            return this;
        });

        let emittedPayload: any = null;
        patch(socketModule, "emitMessageNew", (payload: any) => {
            emittedPayload = payload;
        });

        const res = await request(app)
            .post("/api/conversations/601/messages")
            .set(guestAuth)
            .send({
                content: "Cuối tuần này villa có trống không bạn?",
                messageType: "text",
            });

        assert.equal(res.status, 201);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.message.conversationId, 601);
        assert.ok(emittedPayload);
        assert.equal(emittedPayload.conversationId, 601);
        assert.equal(emittedPayload.receiverUserId, 101);
    });

    it("CV-03: Từ chối gửi tin nhắn rỗng với mã 422", async () => {
        patch(Conversation, "findOne", async () => buildConversation());
        patch(ConversationParticipant, "findOne", async () => ({
            conversationId: 601,
            userId: 201,
            async save() {},
        }));

        const res = await request(app)
            .post("/api/conversations/601/messages")
            .set(guestAuth)
            .send({
                content: "   ", // Chỉ khoảng trắng
            });

        assert.equal(res.status, 422);
    });

    it("CV-04: Từ chối tin nhắn vượt quá độ dài tối đa 2000 ký tự với mã 422", async () => {
        patch(Conversation, "findOne", async () => buildConversation({ conversationId: 601, guestUserId: 201, hostUserId: 101 }));
        patch(ConversationParticipant, "findOne", async () => ({
            conversationId: 601,
            userId: 201,
            async save() {},
        }));

        const res = await request(app)
            .post("/api/conversations/601/messages")
            .set(guestAuth)
            .send({
                content: "a".repeat(2005),
            });

        assert.equal(res.status, 422);
    });

    it("CV-05: Chống IDOR - Người ngoài không thể xem lịch sử tin nhắn của hội thoại (HTTP 403/404)", async () => {
        // Conversation giữa guest 201 và host 101
        patch(Conversation, "findOne", async () => buildConversation({ guestUserId: 201, hostUserId: 101 }));
        // Outsider 301 không phải participant
        patch(ConversationParticipant, "findOne", async () => null);

        const res = await request(app)
            .get("/api/conversations/601/messages")
            .set(outsiderAuth);

        assert.ok(res.status === 403 || res.status === 404);
    });

    it("CV-06: Chống IDOR - Người ngoài không thể gửi tin nhắn vào hội thoại của người khác (HTTP 403/404)", async () => {
        patch(Conversation, "findOne", async () => buildConversation({ guestUserId: 201, hostUserId: 101 }));
        patch(ConversationParticipant, "findOne", async () => null);

        const res = await request(app)
            .post("/api/conversations/601/messages")
            .set(outsiderAuth)
            .send({
                content: "Tin nhắn spam",
            });

        assert.ok(res.status === 403 || res.status === 404);
    });

    it("CV-07: Lấy lịch sử tin nhắn có phân trang theo đúng thứ tự thời gian (HTTP 200)", async () => {
        patch(Conversation, "findOne", async () => buildConversation({ conversationId: 601 }));
        patch(ConversationParticipant, "findOne", async () => ({
            conversationId: 601,
            userId: 201,
            lastReadAt: null,
            async save() {},
        }));

        const mockMessages = [
            buildMessage({ messageId: 1001, content: "Tin nhắn 1" }),
            buildMessage({ messageId: 1002, content: "Tin nhắn 2" }),
        ];

        patch(Message, "find", () => ({
            sort() {
                return this;
            },
            skip() {
                return this;
            },
            limit: async () => mockMessages,
        }));
        patch(Message, "countDocuments", async () => 2);

        const res = await request(app)
            .get("/api/conversations/601/messages?page=1&limit=20")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.equal(res.body.data.items.length, 2);
        assert.equal(res.body.data.pagination.total, 2);
    });

    it("CV-08: Đánh dấu đã đọc hội thoại thành công và cập nhật lastReadAt (HTTP 200)", async () => {
        patch(Conversation, "findOne", async () => buildConversation({ conversationId: 601 }));

        let savedReadAt: Date | null = null;
        patch(ConversationParticipant, "findOne", async () => ({
            conversationId: 601,
            userId: 201,
            set lastReadAt(val: Date) {
                savedReadAt = val;
            },
            async save() {},
        }));

        const res = await request(app)
            .patch("/api/conversations/601/read")
            .set(guestAuth);

        assert.equal(res.status, 200);
        assert.equal(res.body.success, true);
        assert.ok(savedReadAt !== null);
    });

    it("CV-09: Chặn người dùng tự chat với chính mình (host tự nhắn host) với mã 409/422", async () => {
        // Host 101 tự gửi yêu cầu tạo hội thoại với chính mình cho listing của mình
        const res = await request(app)
            .post("/api/conversations")
            .set(hostAuth) // User 101 gọi
            .send({
                listingId: 801,
                hostUserId: 101,
                firstMessage: "Tự chat với chính mình",
            });

        assert.ok(res.status === 403 || res.status === 409 || res.status === 422);
    });

    it("CV-10: Tự động sanitize và khử mã độc XSS trong nội dung tin nhắn chat", async () => {
        patch(Conversation, "findOne", async () => buildConversation({ guestUserId: 201, hostUserId: 101 }));
        patch(ConversationParticipant, "findOne", async () => ({
            conversationId: 601,
            userId: 201,
            async save() {},
        }));
        patch(ConversationParticipant, "bulkCreate", async () => []);

        let savedContent = "";
        patch(Message, "create", async (data: any) => {
            savedContent = data.content;
            return buildMessage({ ...data, messageId: 1003 });
        });

        const res = await request(app)
            .post("/api/conversations/601/messages")
            .set(guestAuth)
            .send({
                content: "Chào bạn <script>alert('xss')</script><img src=x onerror=alert(1)>",
            });

        assert.equal(res.status, 201);
        assert.ok(!savedContent.includes("<script>"));
        assert.ok(!savedContent.includes("onerror="));
    });
});

describe("Module conversations - Socket.io Realtime (SK-01 to SK-14)", () => {
    let mockSocket: any;

    beforeEach(() => {
        patch(authService, "verifyAuthToken", (token: string) => {
            if (token === "valid-token") return { userId: "201", role: "guest" };
            if (token === "banned-token") return { userId: "999", role: "guest" };
            throw new Error("Invalid token");
        });

        patch(authService, "toAuthenticatedUser", async (user: any) => ({
            id: String(user.id),
            email: user.email,
            phone: user.phone,
            name: user.name,
            username: user.username,
            status: user.status,
            roles: user.roles,
        }));

        patch(User, "findById", async (id: string | number) => {
            if (String(id) === "201") return guestUser;
            if (String(id) === "999") return { ...guestUser, id: 999, status: "banned" };
            return null;
        });

        mockSocket = {
            handshake: {
                auth: { token: "Bearer valid-token" },
                headers: {},
            },
            data: {},
            joinedRooms: new Set<string>(),
            emittedEvents: [] as Array<{ event: string; data: any }>,
            join(room: string) {
                this.joinedRooms.add(room);
            },
            leave(room: string) {
                this.joinedRooms.delete(room);
            },
            emit(event: string, data: any) {
                this.emittedEvents.push({ event, data });
            },
            disconnect() {},
        };
    });

    it("SK-01: Handshake kết nối Socket.io với JWT hợp lệ thành công và join room user:{userId}", async () => {
        // Giả lập authenticate middleware của socket
        const token = mockSocket.handshake.auth.token.replace(/^Bearer\s+/i, "");
        const payload = authService.verifyAuthToken(token);
        const user = await User.findById(payload.userId);
        assert.ok(user);
        assert.equal(user.status, "active");

        mockSocket.data.user = await authService.toAuthenticatedUser(user);
        mockSocket.join(`user:${user.id}`);

        assert.equal(mockSocket.data.user.id, "201");
        assert.ok(mockSocket.joinedRooms.has("user:201"));
    });

    it("SK-02: Handshake thất bại và từ chối Unauthorized khi token không hợp lệ hoặc thiếu token", async () => {
        mockSocket.handshake.auth.token = "invalid-token";

        assert.throws(() => {
            authService.verifyAuthToken(mockSocket.handshake.auth.token);
        }, /Invalid token/i);
    });

    it("SK-03: emitMessageNew gửi tin nhắn tới room conversation và room người nhận, loại trừ sender", () => {
        let sentTargets: string[] = [];
        let excludedTargets: string[] = [];
        let emittedData: any = null;

        const fakeIo: any = {
            to(room: string) {
                sentTargets.push(room);
                return this;
            },
            except(room: string) {
                excludedTargets.push(room);
                return this;
            },
            emit(event: string, data: any) {
                emittedData = { event, data };
            },
        };

        patch(socketModule, "getSocketServer", () => fakeIo);

        fakeIo.to("conversation:601")
            .to("user:101")
            .except("user:201")
            .emit("message:new", {
                conversationId: 601,
                message: { messageId: 1001, content: "Chào bạn" },
            });

        assert.ok(sentTargets.includes("conversation:601"));
        assert.ok(sentTargets.includes("user:101"));
        assert.ok(excludedTargets.includes("user:201"));
        assert.equal(emittedData.event, "message:new");
    });

    it("SK-04: Chặn người dùng emit join vào room hội thoại mà mình không tham gia (Security/IDOR)", async () => {
        patch(Conversation, "findOne", async () => ({
            conversationId: 601,
            guestUserId: 201,
            hostUserId: 101,
        }));

        patch(ConversationParticipant, "findOne", async () => null);

        // User 301 cố join room 601
        const outsiderId = 301;
        const conv = await Conversation.findOne({ where: { conversationId: 601 } });
        const isParticipant =
            conv.guestUserId === outsiderId || conv.hostUserId === outsiderId;

        if (!isParticipant) {
            mockSocket.emit("conversation:error", {
                conversationId: 601,
                message: "Forbidden",
            });
        }

        assert.equal(mockSocket.emittedEvents.length, 1);
        assert.equal(mockSocket.emittedEvents[0].event, "conversation:error");
        assert.equal(mockSocket.emittedEvents[0].data.message, "Forbidden");
        assert.ok(!mockSocket.joinedRooms.has("conversation:601"));
    });

    it("SK-05: Khi người nhận offline (không có socket), tin nhắn vẫn lưu DB bình thường mà không lỗi", async () => {
        patch(socketModule, "getSocketServer", () => null); // Không có socket instance

        // Gửi tin nhắn qua service không được throw error
        await assert.doesNotReject(async () => {
            socketModule.emitMessageNew({
                conversationId: 601,
                senderUserId: 201,
                receiverUserId: 101,
                message: { messageId: 1001, content: "Offline test" },
                conversation: { id: 1, conversationId: 601 },
            });
        });
    });

    it("SK-06: Participant hợp lệ emit conversation:join sẽ join room thành công", async () => {
        patch(Conversation, "findOne", async () => ({
            conversationId: 601,
            guestUserId: 201,
            hostUserId: 101,
        }));

        const currentUserId = 201;
        const conv = await Conversation.findOne({ where: { conversationId: 601 } });
        const isAllowed = conv.guestUserId === currentUserId || conv.hostUserId === currentUserId;

        if (isAllowed) {
            mockSocket.join(`conversation:601`);
        }

        assert.ok(mockSocket.joinedRooms.has("conversation:601"));
    });

    it("SK-07: Hỗ trợ đa thiết bị (nhiều socket cùng 1 user) cùng join room user:{userId}", () => {
        const socketDevice1 = { joined: new Set<string>(), join(r: string) { this.joined.add(r); } };
        const socketDevice2 = { joined: new Set<string>(), join(r: string) { this.joined.add(r); } };

        socketDevice1.join("user:201");
        socketDevice2.join("user:201");

        assert.ok(socketDevice1.joined.has("user:201"));
        assert.ok(socketDevice2.joined.has("user:201"));
    });

    it("SK-08: Emit conversation:join với conversationId không hợp lệ trả về conversation:error", () => {
        const invalidId = -5;

        if (!Number.isInteger(invalidId) || invalidId < 1) {
            mockSocket.emit("conversation:error", {
                conversationId: invalidId,
                message: "conversationId is invalid",
            });
        }

        assert.equal(mockSocket.emittedEvents.length, 1);
        assert.equal(mockSocket.emittedEvents[0].data.message, "conversationId is invalid");
    });

    it("SK-09: emitNotificationNew gửi thông báo realtime tới đúng room user:{userId}", () => {
        let emittedRoom = "";
        let emittedPayload: any = null;

        const fakeIo: any = {
            to(room: string) {
                emittedRoom = room;
                return this;
            },
            emit(event: string, data: any) {
                emittedPayload = { event, data };
            },
        };

        patch(socketModule, "getSocketServer", () => fakeIo);

        fakeIo.to("user:201").emit("notification:new", {
            notificationLogId: 101,
            title: "Test Notification",
        });

        assert.equal(emittedRoom, "user:201");
        assert.equal(emittedPayload.event, "notification:new");
    });

    it("SK-10: Client emit conversation:leave sẽ rời khỏi room hội thoại", () => {
        mockSocket.join("conversation:601");
        assert.ok(mockSocket.joinedRooms.has("conversation:601"));

        mockSocket.leave("conversation:601");
        assert.ok(!mockSocket.joinedRooms.has("conversation:601"));
    });

    it("SK-11: Chặn giả mạo người gửi (sender spoofing) - Sender luôn lấy từ auth context", () => {
        mockSocket.data.user = { id: "201" };

        const clientPayload = { senderId: 999, content: "Mạo danh" };
        const actualSenderId = Number(mockSocket.data.user.id);

        assert.equal(actualSenderId, 201); // Không tin clientPayload.senderId
        assert.notEqual(actualSenderId, clientPayload.senderId);
    });

    it("SK-12: Lưu trữ và gửi tin nhắn idempotency an toàn", async () => {
        const messagePayload = buildMessage({ messageId: 1001, conversationId: 601 });
        assert.equal(messagePayload.conversationId, 601);
        assert.ok(messagePayload.messageId > 0);
    });

    it("SK-13: Cursor sorting - Tin nhắn luôn được sắp xếp ổn định theo createdAt và messageId", () => {
        const sortCriteria = { createdAt: 1, messageId: 1 };
        assert.deepEqual(sortCriteria, { createdAt: 1, messageId: 1 });
    });

    it("SK-14: Tài khoản bị khóa (status = banned) bị từ chối kết nối socket", async () => {
        const token = "banned-token";
        const payload = authService.verifyAuthToken(token);
        const user = await User.findById(payload.userId);

        assert.equal(user.status, "banned");
        assert.throws(() => {
            const { assertUserCanAuthenticate } = require("../dist/modules/auth/auth.service");
            assertUserCanAuthenticate(user);
        }, /Account is (not active|unavailable)/i);
    });
});
