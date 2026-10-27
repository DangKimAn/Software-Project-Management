import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_client.dart';

enum MessageDeliveryStatus {
  sending,
  sent,
  failed,
}

class ChatMessageItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final String messageType;
  final List<String> attachments;
  final String createdAt;
  final String? updatedAt;
  final MessageDeliveryStatus status;
  final String? localId;
  final String? errorMessage;

  const ChatMessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName = '',
    required this.content,
    this.messageType = 'text',
    this.attachments = const [],
    required this.createdAt,
    this.updatedAt,
    this.status = MessageDeliveryStatus.sent,
    this.localId,
    this.errorMessage,
  });

  bool get isPending => status == MessageDeliveryStatus.sending;
  bool get isSent => status == MessageDeliveryStatus.sent;
  bool get isFailed => status == MessageDeliveryStatus.failed;
  bool get isLocalOnly =>
      id.startsWith('local_') || status != MessageDeliveryStatus.sent;

  ChatMessageItem copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    String? messageType,
    List<String>? attachments,
    String? createdAt,
    String? updatedAt,
    MessageDeliveryStatus? status,
    String? localId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatMessageItem(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      localId: localId ?? this.localId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory ChatMessageItem.fromJson(
    Map<String, dynamic> json, {
    String? fallbackConversationId,
  }) {
    // Support both direct message JSON and Socket.IO `{ conversationId, message: {...}, conversation: {...} }` envelope
    final Map<String, dynamic> msgMap = json['message'] is Map
        ? Map<String, dynamic>.from(json['message'] as Map)
        : json;
    final envelopeConvId =
        (json['conversationId'] ?? fallbackConversationId ?? '').toString();

    final sender = msgMap['sender'] is Map
        ? Map<String, dynamic>.from(msgMap['sender'] as Map)
        : null;

    final rawContent = msgMap['content'] ??
        msgMap['body'] ??
        msgMap['text'] ??
        (msgMap['message'] is String ? msgMap['message'] : '');

    final rawAttachments = msgMap['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
            .map((e) {
              if (e is Map) {
                return (e['url'] ?? e['imageUrl'] ?? e['fileUrl'] ?? '')
                    .toString();
              }
              return e?.toString() ?? '';
            })
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];

    return ChatMessageItem(
      id: (msgMap['messageId'] ?? msgMap['id'] ?? '').toString(),
      conversationId: (msgMap['conversationId'] ?? envelopeConvId).toString(),
      senderId: (msgMap['senderUserId'] ??
              msgMap['senderId'] ??
              sender?['userId'] ??
              sender?['id'] ??
              '')
          .toString(),
      senderName:
          (msgMap['senderName'] ?? sender?['fullName'] ?? sender?['name'] ?? '')
              .toString(),
      content: rawContent?.toString() ?? '',
      messageType: (msgMap['messageType'] ?? 'text').toString(),
      attachments: attachments,
      createdAt: (msgMap['createdAt'] ?? '').toString(),
      updatedAt: msgMap['updatedAt']?.toString(),
      status: MessageDeliveryStatus.sent,
    );
  }

  /// Merges incoming messages with existing messages for a specific [conversationId],
  /// filtering out invalid/cross-conversation messages, reconciling pending local messages
  /// when a confirmed server message arrives, deduplicating by [id], and sorting chronologically
  /// by `(createdAt, id)` so out-of-order/late events stay ordered.
  static List<ChatMessageItem> mergeAndSortMessages(
    List<ChatMessageItem> existing,
    Iterable<ChatMessageItem> incoming, {
    required String conversationId,
    String? replaceLocalId,
  }) {
    final targetConvId = conversationId.trim();
    final byId = <String, ChatMessageItem>{};

    for (final msg in existing) {
      if (msg.id.isEmpty) continue;
      if (replaceLocalId != null &&
          (msg.id == replaceLocalId || msg.localId == replaceLocalId)) {
        continue;
      }
      if (targetConvId.isNotEmpty &&
          msg.conversationId.isNotEmpty &&
          msg.conversationId != targetConvId) {
        continue;
      }
      byId[msg.id] = msg;
    }

    for (final msg in incoming) {
      if (msg.id.isEmpty) continue;
      if (targetConvId.isNotEmpty &&
          msg.conversationId.isNotEmpty &&
          msg.conversationId != targetConvId) {
        continue;
      }

      // If this is a confirmed server message, reconcile any matching in-flight pending local message
      // so a Socket `message:new` arriving before/with the POST response never renders twice.
      if (msg.isSent && !msg.id.startsWith('local_')) {
        String? matchedPendingKey;
        for (final entry in byId.entries) {
          final candidate = entry.value;
          if (!candidate.isPending) continue;
          if (msg.localId != null &&
              msg.localId!.isNotEmpty &&
              (candidate.id == msg.localId ||
                  candidate.localId == msg.localId)) {
            matchedPendingKey = entry.key;
            break;
          }
          if (candidate.senderId.isNotEmpty &&
              candidate.senderId == msg.senderId &&
              candidate.content.trim() == msg.content.trim()) {
            matchedPendingKey = entry.key;
            break;
          }
        }
        if (matchedPendingKey != null) {
          byId.remove(matchedPendingKey);
        }
      }

      byId[msg.id] = msg;
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      // Keep local pending/failed messages without server IDs at the end if timestamps tie
      final timeA = DateTime.tryParse(a.createdAt);
      final timeB = DateTime.tryParse(b.createdAt);
      if (timeA != null && timeB != null) {
        final cmp = timeA.compareTo(timeB);
        if (cmp != 0) return cmp;
      }
      final idA = int.tryParse(a.id);
      final idB = int.tryParse(b.id);
      if (idA != null && idB != null) {
        return idA.compareTo(idB);
      }
      if (idA != null && idB == null) return -1;
      if (idA == null && idB != null) return 1;
      return a.id.compareTo(b.id);
    });
    return merged;
  }
}

/// Represents the real-time `message:new` payload emitted by backend `socket.ts`:
/// `{ conversationId, message: {...}, conversation: {...} }`.
class SocketMessageEnvelope {
  final String conversationId;
  final ChatMessageItem? message;
  final Map<String, dynamic>? conversationPatch;
  final String? senderUserId;
  final String? receiverUserId;

  const SocketMessageEnvelope({
    required this.conversationId,
    required this.message,
    this.conversationPatch,
    this.senderUserId,
    this.receiverUserId,
  });

  ConversationItem? get conversation => conversationPatch != null
      ? ConversationItem.fromJson(conversationPatch!)
      : null;

  factory SocketMessageEnvelope.fromJson(Map<String, dynamic> payload) {
    final convPatch = payload['conversation'] is Map
        ? Map<String, dynamic>.from(payload['conversation'] as Map)
        : null;
    final rawConvId = (payload['conversationId'] ??
            convPatch?['conversationId'] ??
            convPatch?['id'] ??
            '')
        .toString();

    ChatMessageItem? parsedMessage;
    if (payload['message'] is Map) {
      final msgMap = Map<String, dynamic>.from(payload['message'] as Map);
      parsedMessage = ChatMessageItem.fromJson(
        msgMap,
        fallbackConversationId: rawConvId,
      );
    } else if (payload['messageId'] != null || payload['id'] != null) {
      parsedMessage = ChatMessageItem.fromJson(
        payload,
        fallbackConversationId: rawConvId,
      );
    }

    final resolvedConvId = rawConvId.isNotEmpty
        ? rawConvId
        : (parsedMessage?.conversationId ?? '');

    return SocketMessageEnvelope(
      conversationId: resolvedConvId,
      message: (parsedMessage != null && parsedMessage.id.isNotEmpty)
          ? parsedMessage
          : null,
      conversationPatch: convPatch,
      senderUserId: payload['senderUserId']?.toString(),
      receiverUserId: payload['receiverUserId']?.toString(),
    );
  }
}

class ConversationItem {
  final String id;
  final String listingId;
  final String listingTitle;
  final String? listingImage;
  final String guestId;
  final String guestName;
  final String hostId;
  final String hostName;
  final String? otherParticipantId;
  final String? otherParticipantName;
  final String? otherParticipantAvatar;
  final String? lastMessage;
  final String? lastMessageAt;
  final String? updatedAt;
  final int unreadCount;

  const ConversationItem({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    this.listingImage,
    required this.guestId,
    required this.guestName,
    required this.hostId,
    required this.hostName,
    this.otherParticipantId,
    this.otherParticipantName,
    this.otherParticipantAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.updatedAt,
    this.unreadCount = 0,
  });

  /// Checks whether [currentUserId] is a valid participant (`guest` or `host`) of this conversation.
  bool isParticipant(String currentUserId) {
    final uid = currentUserId.trim();
    if (uid.isEmpty) return false;
    final gId = guestId.trim();
    final hId = hostId.trim();
    if (gId.isNotEmpty || hId.isNotEmpty) {
      return gId == uid || hId == uid;
    }
    return true;
  }

  /// Checks whether [currentUserId] is authorized to access this conversation in the current portal scope.
  /// Prevents a guest from reading a thread belonging to another guest/host pair, and enforces host scope in Host Portal.
  bool canAccess(String currentUserId, {bool isHostPortal = false}) {
    final uid = currentUserId.trim();
    if (uid.isEmpty) return false;
    if (!isParticipant(uid)) return false;
    if (isHostPortal && hostId.trim().isNotEmpty && hostId.trim() != uid) {
      return false;
    }
    return true;
  }

  /// Resolves the counterpart's display name without falling back every conversation to "Chủ nhà".
  String displayNameFor(String currentUserId) {
    final otherName = otherParticipantName?.trim() ?? '';
    if (otherName.isNotEmpty) {
      return otherName;
    }

    final trimmedUserId = currentUserId.trim();
    if (trimmedUserId.isNotEmpty) {
      if (hostId == trimmedUserId) {
        if (guestName.trim().isNotEmpty) return guestName.trim();
        if (guestId.isNotEmpty) return 'Khách #$guestId';
      }
      if (guestId == trimmedUserId) {
        if (hostName.trim().isNotEmpty) return hostName.trim();
        if (hostId.isNotEmpty) return 'Chủ nhà #$hostId';
      }
    }

    if (otherParticipantId != null && otherParticipantId!.trim().isNotEmpty) {
      return 'Người dùng #${otherParticipantId!.trim()}';
    }
    if (guestName.trim().isNotEmpty) return guestName.trim();
    if (hostName.trim().isNotEmpty) return hostName.trim();
    if (guestId.isNotEmpty) return 'Khách #$guestId';
    if (hostId.isNotEmpty) return 'Chủ nhà #$hostId';
    return 'Người đối thoại';
  }

  String? get displayAvatar => (otherParticipantAvatar != null &&
          otherParticipantAvatar!.trim().isNotEmpty)
      ? otherParticipantAvatar!.trim()
      : listingImage;

  String? avatarFor(String currentUserId) => displayAvatar;

  ConversationItem copyWith({
    String? id,
    String? listingId,
    String? listingTitle,
    String? listingImage,
    String? guestId,
    String? guestName,
    String? hostId,
    String? hostName,
    String? otherParticipantId,
    String? otherParticipantName,
    String? otherParticipantAvatar,
    String? lastMessage,
    String? lastMessageAt,
    String? updatedAt,
    int? unreadCount,
  }) {
    return ConversationItem(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImage: listingImage ?? this.listingImage,
      guestId: guestId ?? this.guestId,
      guestName: guestName ?? this.guestName,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      otherParticipantId: otherParticipantId ?? this.otherParticipantId,
      otherParticipantName: otherParticipantName ?? this.otherParticipantName,
      otherParticipantAvatar:
          otherParticipantAvatar ?? this.otherParticipantAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] is Map
        ? Map<String, dynamic>.from(json['listing'] as Map)
        : null;
    final guest = json['guest'] is Map
        ? Map<String, dynamic>.from(json['guest'] as Map)
        : null;
    final host = json['host'] is Map
        ? Map<String, dynamic>.from(json['host'] as Map)
        : null;
    final otherParticipant = json['otherParticipant'] is Map
        ? Map<String, dynamic>.from(json['otherParticipant'] as Map)
        : null;

    final lastMsgObj = json['lastMessage'] ?? json['lastMessagePreview'];
    String? lastMsgText;
    if (lastMsgObj is Map) {
      lastMsgText =
          (lastMsgObj['content'] ?? lastMsgObj['body'] ?? lastMsgObj['message'])
              ?.toString();
    } else if (lastMsgObj is String) {
      lastMsgText = lastMsgObj;
    }

    final guestId = (json['guestUserId'] ??
            json['guestId'] ??
            guest?['userId'] ??
            guest?['id'] ??
            '')
        .toString();
    final hostId = (json['hostUserId'] ??
            json['hostId'] ??
            host?['userId'] ??
            host?['id'] ??
            '')
        .toString();
    final otherId =
        (otherParticipant?['userId'] ?? otherParticipant?['id'] ?? '')
            .toString();
    final otherName = (otherParticipant?['fullName'] ??
            otherParticipant?['name'] ??
            otherParticipant?['username'] ??
            '')
        .toString()
        .trim();
    final otherAvatar =
        (otherParticipant?['avatarUrl'] ?? otherParticipant?['avatar'] ?? '')
            .toString()
            .trim();

    String guestName =
        (json['guestName'] ?? guest?['fullName'] ?? guest?['name'] ?? '')
            .toString()
            .trim();
    String hostName =
        (json['hostName'] ?? host?['fullName'] ?? host?['name'] ?? '')
            .toString()
            .trim();

    if (otherName.isNotEmpty) {
      if (otherId.isNotEmpty && otherId == guestId && guestName.isEmpty) {
        guestName = otherName;
      } else if (otherId.isNotEmpty && otherId == hostId && hostName.isEmpty) {
        hostName = otherName;
      }
    }

    final lastMessageAt = json['lastMessageAt']?.toString();
    final updatedAt =
        (json['lastMessageAt'] ?? json['updatedAt'] ?? json['createdAt'])
            ?.toString();

    return ConversationItem(
      id: (json['conversationId'] ?? json['id'] ?? '').toString(),
      listingId:
          (json['listingId'] ?? listing?['listingId'] ?? listing?['id'] ?? '')
              .toString(),
      listingTitle: (json['listingTitle'] ??
              listing?['title'] ??
              listing?['name'] ??
              'Trao đổi về chỗ nghỉ')
          .toString(),
      listingImage: (json['listingImage'] ??
              listing?['coverImageUrl'] ??
              (listing?['coverImage'] is Map
                  ? listing!['coverImage']['url']
                  : null))
          ?.toString(),
      guestId: guestId,
      guestName: guestName,
      hostId: hostId,
      hostName: hostName,
      otherParticipantId: otherId.isEmpty ? null : otherId,
      otherParticipantName: otherName.isEmpty ? null : otherName,
      otherParticipantAvatar: otherAvatar.isEmpty ? null : otherAvatar,
      lastMessage: lastMsgText,
      lastMessageAt: lastMessageAt,
      updatedAt: updatedAt,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConversationReadResult {
  final String conversationId;
  final String? lastReadAt;
  final int unreadCount;

  const ConversationReadResult({
    required this.conversationId,
    this.lastReadAt,
    this.unreadCount = 0,
  });

  factory ConversationReadResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackConversationId,
  }) {
    return ConversationReadResult(
      conversationId:
          (json['conversationId'] ?? json['id'] ?? fallbackConversationId)
              .toString(),
      lastReadAt: json['lastReadAt']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConversationsRepository {
  final DioClient _client;

  const ConversationsRepository(this._client);

  static const int maxMessageCharacters = 2000;

  static void _validateConversationId(String conversationId) {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Mã cuộc trò chuyện không hợp lệ.');
    }
    final numeric = int.tryParse(trimmed);
    if (numeric != null && numeric < 1) {
      throw const ValidationFailure('Mã cuộc trò chuyện không hợp lệ.');
    }
  }

  Future<List<ConversationItem>> getConversations({
    int? page,
    int? limit,
    bool? unreadOnly,
    String? scope,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page < 1 ? 1 : page;
      if (limit != null) queryParams['limit'] = limit.clamp(1, 100);
      if (unreadOnly != null) queryParams['unreadOnly'] = unreadOnly;
      if (scope != null && (scope == 'guest' || scope == 'host')) {
        queryParams['scope'] = scope;
      }

      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/conversations',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final data = DioClient.unwrapEnvelope(response.data);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        list = data['items'] as List<dynamic>;
      } else if (data is Map<String, dynamic> &&
          data['conversations'] is List) {
        list = data['conversations'] as List<dynamic>;
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(ConversationItem.fromJson)
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<PaginatedResult<ConversationItem>> getConversationsPaginated({
    int page = 1,
    int limit = 30,
    bool? unreadOnly,
    String? scope,
  }) async {
    try {
      final safePage = page < 1 ? 1 : page;
      final safeLimit = limit.clamp(1, 100);
      final queryParams = <String, dynamic>{
        'page': safePage,
        'limit': safeLimit,
        if (unreadOnly != null) 'unreadOnly': unreadOnly,
        if (scope == 'guest' || scope == 'host') 'scope': scope,
      };
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/conversations',
        queryParameters: queryParams,
      );
      final data = DioClient.unwrapEnvelope(response.data);
      List<dynamic> list = [];
      Map<String, dynamic>? rawPagination;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['items'] is List) {
          list = data['items'] as List<dynamic>;
        } else if (data['conversations'] is List) {
          list = data['conversations'] as List<dynamic>;
        }
        if (data['pagination'] is Map<String, dynamic>) {
          rawPagination = data['pagination'] as Map<String, dynamic>;
        }
      }
      final items = list
          .whereType<Map<String, dynamic>>()
          .map(ConversationItem.fromJson)
          .toList();
      return PaginatedResult<ConversationItem>(
        items: items,
        pagination: PaginationMeta.fromJson(rawPagination),
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<ConversationItem> getOrCreateConversation(
    String listingId, {
    String? bookingId,
    String? firstMessage,
  }) async {
    try {
      final body = <String, dynamic>{
        'listingId': int.tryParse(listingId) ?? listingId,
      };
      if (bookingId != null && bookingId.trim().isNotEmpty) {
        body['bookingId'] = int.tryParse(bookingId.trim()) ?? bookingId.trim();
      }
      if (firstMessage != null && firstMessage.trim().isNotEmpty) {
        body['firstMessage'] = firstMessage.trim();
      }

      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/conversations',
        data: body,
      );
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        final convJson = data['conversation'] is Map<String, dynamic>
            ? data['conversation'] as Map<String, dynamic>
            : data;
        return ConversationItem.fromJson(convJson);
      }
      throw const ServerFailure('Không thể khởi tạo hội thoại với chủ nhà.');
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<PaginatedResult<ChatMessageItem>> getMessagesPaginated(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    _validateConversationId(conversationId);
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, 100);
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/conversations/${conversationId.trim()}/messages',
        queryParameters: {'page': safePage, 'limit': safeLimit},
      );
      final data = DioClient.unwrapEnvelope(response.data);
      List<dynamic> list = [];
      Map<String, dynamic>? rawPagination;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['items'] is List) {
          list = data['items'] as List<dynamic>;
        } else if (data['messages'] is List) {
          list = data['messages'] as List<dynamic>;
        }
        if (data['pagination'] is Map<String, dynamic>) {
          rawPagination = data['pagination'] as Map<String, dynamic>;
        }
      }
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => ChatMessageItem.fromJson(
              m,
              fallbackConversationId: conversationId.trim(),
            ),
          )
          .toList();
      final sorted = ChatMessageItem.mergeAndSortMessages(
        const [],
        parsed,
        conversationId: conversationId.trim(),
      );
      return PaginatedResult<ChatMessageItem>(
        items: sorted,
        pagination: PaginationMeta.fromJson(
          rawPagination ??
              <String, dynamic>{
                'page': safePage,
                'limit': safeLimit,
                'total': sorted.length,
                'totalPages': 1,
              },
        ),
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<List<ChatMessageItem>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final result = await getMessagesPaginated(
      conversationId,
      page: page,
      limit: limit,
    );
    return result.items;
  }

  Future<ChatMessageItem> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    _validateConversationId(conversationId);
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Nội dung tin nhắn không được để trống.');
    }
    if (trimmed.length > maxMessageCharacters) {
      throw const ValidationFailure(
        'Nội dung tin nhắn không được vượt quá 2000 ký tự.',
      );
    }

    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/conversations/${conversationId.trim()}/messages',
        data: {
          'content': trimmed,
        },
      );
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        final msgJson = data['message'] is Map<String, dynamic>
            ? data['message'] as Map<String, dynamic>
            : data;
        return ChatMessageItem.fromJson(
          msgJson,
          fallbackConversationId: conversationId.trim(),
        );
      }
      throw const ServerFailure('Không thể gửi tin nhắn.');
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Marks all messages in [conversationId] as read via `PATCH /api/conversations/:id/read`.
  Future<ConversationReadResult> markConversationRead(
    String conversationId,
  ) async {
    _validateConversationId(conversationId);
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/api/conversations/${conversationId.trim()}/read',
      );
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        return ConversationReadResult.fromJson(
          data,
          fallbackConversationId: conversationId.trim(),
        );
      }
      return ConversationReadResult(conversationId: conversationId.trim());
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}

final conversationsRepositoryProvider =
    Provider<ConversationsRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return ConversationsRepository(client);
});

final conversationsListProvider =
    FutureProvider.autoDispose<List<ConversationItem>>((ref) async {
  return ref.watch(conversationsRepositoryProvider).getConversations();
});
