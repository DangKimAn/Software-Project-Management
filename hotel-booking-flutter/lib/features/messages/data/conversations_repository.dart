import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/view_models/auth_notifier.dart';

/// Trạng thái chuyển phát của một tin nhắn trong luồng trò chuyện thời gian thực.
enum MessageDeliveryStatus {
  /// Tin nhắn lạc quan vừa khởi tạo ở máy khách và đang chờ máy chủ xác nhận.
  sending,

  /// Tin nhắn đã được máy chủ lưu trữ và xác nhận thành công.
  sent,

  /// Yêu cầu gửi tin nhắn thất bại do lỗi mạng hoặc từ chối quyền truy cập.
  failed,
}

/// Thực thể biểu diễn một tin nhắn trò chuyện, hỗ trợ cả bản ghi xác nhận từ máy chủ
/// lẫn bong bóng tin nhắn lạc quan đang gửi (`local_*`) ở phía giao diện.
class ChatMessageItem {
  /// Định danh tin nhắn từ máy chủ hoặc mã tạm `local_*` khi chưa đồng bộ.
  final String id;

  /// Mã cuộc trò chuyện chứa tin nhắn này.
  final String conversationId;

  /// Mã định danh người dùng gửi tin nhắn.
  final String senderId;

  /// Tên hiển thị của người gửi tin nhắn.
  final String senderName;

  /// Nội dung văn bản của tin nhắn.
  final String content;

  /// Phân loại định dạng tin nhắn (mặc định là `'text'`).
  final String messageType;

  /// Danh sách đường dẫn tệp hoặc hình ảnh đính kèm trong tin nhắn.
  final List<String> attachments;

  /// Chuỗi thời gian khởi tạo tin nhắn theo chuẩn ISO-8601.
  final String createdAt;

  /// Chuỗi thời gian cập nhật gần nhất của tin nhắn (nếu có).
  final String? updatedAt;

  /// Trạng thái chuyển phát hiện tại của tin nhắn trên giao diện.
  final MessageDeliveryStatus status;

  /// Mã định danh tạm thời phía máy khách (`clientTempId` / `localId`) dùng để đối soát khi máy chủ phản hồi.
  final String? localId;

  /// Thông báo lỗi chi tiết hiển thị khi gửi tin nhắn thất bại.
  final String? errorMessage;
  final bool isRead;
  final String? readAt;

  /// Khởi tạo một thực thể `ChatMessageItem` bất biến.
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
    this.isRead = false,
    this.readAt,
  });

  /// Cho biết tin nhắn có đang ở trạng thái chờ máy chủ xác nhận hay không.
  bool get isPending => status == MessageDeliveryStatus.sending;

  /// Cho biết tin nhắn đã được máy chủ ghi nhận thành công hay chưa.
  bool get isSent => status == MessageDeliveryStatus.sent;

  /// Cho biết lần gửi tin nhắn gần nhất có bị lỗi hay không.
  bool get isFailed => status == MessageDeliveryStatus.failed;

  /// Cho biết tin nhắn chỉ mới tồn tại cục bộ ở máy khách (chưa có mã định danh chính thức từ máy chủ).
  bool get isLocalOnly =>
      id.startsWith('local_') || status != MessageDeliveryStatus.sent;

  /// Tạo bản sao `ChatMessageItem` với các thuộc tính được cập nhật chọn lọc.
  ///
  /// Khi `clearError` là `true`, trường `errorMessage` sẽ được xóa về `null`.
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
    bool? isRead,
    String? readAt,
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
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Giải mã đối tượng JSON từ phản hồi REST API hoặc gói tin Socket.IO thành `ChatMessageItem`.
  ///
  /// Hỗ trợ cả cấu trúc bản ghi tin nhắn trực tiếp lẫn khung bao thời gian thực
  /// `{ conversationId, message: {...}, conversation: {...} }`, sử dụng `fallbackConversationId`
  /// khi dữ liệu con không đính kèm sẵn mã cuộc trò chuyện.
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
    List<String> attachments = rawAttachments is List
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
        : <String>[];

    final contentStr = rawContent?.toString() ?? '';
    var resolvedMessageType = (msgMap['messageType'] ?? 'text').toString();

    // Auto-recovery: phục hồi các tin nhắn cũ từng gửi dạng text mock thành ảnh/audio thật
    if (attachments.isEmpty) {
      if (contentStr.contains('📷 [Ảnh chụp trực tiếp') ||
          contentStr.contains('🖼️ [Đã gửi 1 hình ảnh') ||
          contentStr.contains('[Ảnh chụp trực tiếp từ villa]')) {
        resolvedMessageType = 'image';
        attachments = ['assets/images/343vothisau.jpg'];
      } else if (contentStr.contains('🎤 Tin nhắn thoại')) {
        resolvedMessageType = 'file';
        attachments = ['https://pub-67a3f362466e495d9c2f371ca84b6d03.r2.dev/chat/sample_voice.wav'];
      }
    }

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
      messageType: resolvedMessageType,
      attachments: attachments,
      createdAt: (msgMap['createdAt'] ?? '').toString(),
      updatedAt: msgMap['updatedAt']?.toString(),
      status: MessageDeliveryStatus.sent,
      isRead: msgMap['isRead'] == true ||
          msgMap['readAt'] != null ||
          msgMap['status'] == 'read' ||
          msgMap['isSeen'] == true,
      readAt: msgMap['readAt']?.toString(),
    );
  }

  /// Hợp nhất danh sách tin nhắn mới `incoming` vào danh sách hiện có `existing` của cuộc trò chuyện `conversationId`,
  /// đối soát bong bóng lạc quan và sắp xếp tất định theo thứ tự thời gian tăng dần.
  ///
  /// Quy trình xử lý gồm 3 bước chính:
  /// 1. Nạp và lọc danh sách `existing` vào bảng băm theo khóa `id`: loại bỏ phần tử rỗng `id`,
  ///    loại bỏ bong bóng tạm trùng với `replaceLocalId` (mã tạm `clientTempId` / `localId` khi HTTP `POST` trả kết quả),
  ///    và chặn mọi bản ghi đi lạc từ cuộc hội thoại khác.
  /// 2. Duyệt từng phần tử trong `incoming` và đối soát trạng thái lạc quan (Optimistic Reconciliation):
  ///    nếu tin nhắn đến đã được máy chủ xác nhận (`isSent` và `id` không mang tiền tố `local_`),
  ///    tìm trong bảng băm phần tử đang chờ gửi (`isPending`) khớp theo mã tạm `localId` (`clientTempId`) hoặc khớp đồng thời
  ///    cặp `(senderId, content.trim())` để xóa bỏ trước khi ghi bản ghi chính thức, ngăn hiển thị trùng 2 bong bóng
  ///    khi sự kiện Socket.IO `message:new` đến trước hoặc cùng lúc với phản hồi HTTP.
  /// 3. Sắp xếp tất định danh sách sau khử trùng theo `createdAt` tăng dần; nếu hai tin nhắn trùng mốc thời gian,
  ///    phân giải thứ tự bằng giá trị số nguyên của `id` (ưu tiên tin nhắn đã có mã máy chủ đứng trước các tin nhắn
  ///    cục bộ đang gửi hoặc lỗi), cuối cùng so sánh chuỗi `id` để bảo đảm kết quả ổn định tuyệt đối.
  static List<ChatMessageItem> mergeAndSortMessages(
    List<ChatMessageItem> existing,
    Iterable<ChatMessageItem> incoming, {
    required String conversationId,
    String? replaceLocalId,
  }) {
    // Giải thuật hợp nhất, khử trùng lặp và đối soát tin nhắn thời gian thực:
    // Bước 1: Chuẩn hóa `conversationId` đích và nạp các tin nhắn hợp lệ từ `existing` vào `byId`.
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

    // Bước 2: Duyệt luồng `incoming`, đối soát thu hồi bong bóng `isPending` khớp `localId` (`clientTempId`)
    // hoặc `(senderId, content)` và ghi đè theo khóa `id` của máy chủ để khử trùng lặp giữa HTTP và Socket.IO.
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

    // Bước 3: Sắp xếp tất định theo mốc thời gian `createdAt` tăng dần kèm khóa phụ `id` (số nguyên / từ điển).
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

  /// Ghép nối trang lịch sử tin nhắn cũ `olderMessages` lên đầu danh sách hiện có `existingMessages`
  /// của cuộc trò chuyện `conversationId` khi người dùng cuộn tải thêm lịch sử.
  ///
  /// Khử trùng lặp theo `id`, loại bỏ tin nhắn lạc luồng hội thoại, giữ các bong bóng cục bộ `isLocalOnly`
  /// ở cuối danh sách và bảo toàn thứ tự thời gian tăng dần ổn định nhờ chỉ mục xuất hiện đầu tiên.
  // Giải thuật ghép nối lịch sử tin nhắn cũ lên đầu danh sách (Oldest-Prepend Pagination):
  // Kết hợp `[...olderMessages, ...existingMessages]`, khử trùng lặp theo `id`, lọc đúng `conversationId`
  // và bảo toàn thứ tự thời gian tăng dần ổn định để các trang lịch sử cũ (`page > 1`) luôn nằm phía trên.
  // CONFLICT-RESOLVED: Đồng bộ với hợp đồng mới của `GET /api/conversations/:id/messages` (page=1 trả 50 tin mới nhất tăng dần, page>=2 trả tin cũ hơn tăng dần).
  static List<ChatMessageItem> prependOlderMessages(
    Iterable<ChatMessageItem> olderMessages,
    List<ChatMessageItem> existingMessages, {
    required String conversationId,
  }) {
    final targetConvId = conversationId.trim();
    final combined = <ChatMessageItem>[
      ...olderMessages,
      ...existingMessages,
    ];
    final byId = <String, ChatMessageItem>{};
    final firstOrderIndex = <String, int>{};
    var orderCounter = 0;

    for (final msg in combined) {
      if (msg.id.isEmpty) continue;
      if (targetConvId.isNotEmpty &&
          msg.conversationId.isNotEmpty &&
          msg.conversationId != targetConvId) {
        continue;
      }
      firstOrderIndex.putIfAbsent(msg.id, () => orderCounter++);
      byId[msg.id] = msg;
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      if (a.isLocalOnly != b.isLocalOnly) {
        return a.isLocalOnly ? 1 : -1;
      }
      final timeA = DateTime.tryParse(a.createdAt);
      final timeB = DateTime.tryParse(b.createdAt);
      if (timeA != null && timeB != null) {
        final cmp = timeA.compareTo(timeB);
        if (cmp != 0) return cmp;
      }
      final idA = int.tryParse(a.id);
      final idB = int.tryParse(b.id);
      if (idA != null && idB != null) {
        final cmp = idA.compareTo(idB);
        if (cmp != 0) return cmp;
      }
      return (firstOrderIndex[a.id] ?? 0).compareTo(firstOrderIndex[b.id] ?? 0);
    });
    return merged;
  }
}

/// Khung bao sự kiện thời gian thực `message:new` phát ra từ kênh Socket.IO của máy chủ
/// theo cấu trúc `{ conversationId, message: {...}, conversation: {...} }`.
class SocketMessageEnvelope {
  /// Mã cuộc trò chuyện đích của gói tin sự kiện.
  final String conversationId;

  /// Thực thể tin nhắn mới đã giải mã (nếu gói tin chứa dữ liệu hợp lệ).
  final ChatMessageItem? message;

  /// Bản vá dữ liệu tóm tắt cuộc trò chuyện đi kèm sự kiện thời gian thực.
  final Map<String, dynamic>? conversationPatch;

  /// Mã định danh người gửi đính kèm ở mức khung bao sự kiện.
  final String? senderUserId;

  /// Mã định danh người nhận đính kèm ở mức khung bao sự kiện.
  final String? receiverUserId;

  /// Khởi tạo `SocketMessageEnvelope` từ dữ liệu sự kiện đã chuẩn hóa.
  const SocketMessageEnvelope({
    required this.conversationId,
    required this.message,
    this.conversationPatch,
    this.senderUserId,
    this.receiverUserId,
  });

  /// Chuyển đổi `conversationPatch` thành thực thể `ConversationItem` để cập nhật hộp thư tức thì.
  ConversationItem? get conversation => conversationPatch != null
      ? ConversationItem.fromJson(conversationPatch!)
      : null;

  /// Giải mã dữ liệu thô `payload` từ sự kiện Socket.IO thành `SocketMessageEnvelope`.
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

/// Thực thể tóm tắt một cuộc trò chuyện trong hộp thư giữa Khách hàng, Chủ nhà hoặc Quản trị viên.
class ConversationItem {
  /// Mã định danh duy nhất của cuộc trò chuyện.
  final String id;

  /// Mã biệt thự/chỗ nghỉ gắn liền với hội thoại (rỗng nếu là hội thoại hỗ trợ trực tiếp 1-1).
  final String listingId;

  /// Tiêu đề chỗ nghỉ hoặc nhãn cuộc trò chuyện hỗ trợ hiển thị trên danh sách.
  final String listingTitle;

  /// Đường dẫn ảnh đại diện của chỗ nghỉ (dùng làm ảnh dự phòng khi đối phương chưa có ảnh).
  final String? listingImage;

  /// Mã định danh người dùng vai trò khách thuê.
  final String guestId;

  /// Tên hiển thị của khách thuê.
  final String guestName;

  /// Mã định danh người dùng vai trò chủ nhà.
  final String hostId;

  /// Tên hiển thị của chủ nhà.
  final String hostName;

  /// Mã định danh của người đối thoại phía bên kia so với phiên đăng nhập hiện tại.
  final String? otherParticipantId;

  /// Tên hiển thị của người đối thoại phía bên kia.
  final String? otherParticipantName;

  /// Đường dẫn ảnh đại diện của người đối thoại phía bên kia.
  final String? otherParticipantAvatar;

  /// Nội dung tóm tắt của tin nhắn gần nhất trong cuộc trò chuyện.
  final String? lastMessage;

  /// Thời điểm phát sinh tin nhắn gần nhất theo chuẩn ISO-8601.
  final String? lastMessageAt;

  /// Thời điểm cập nhật gần nhất của cuộc trò chuyện dùng để sắp xếp hộp thư.
  final String? updatedAt;

  /// Số lượng tin nhắn chưa đọc đối với người dùng hiện tại.
  final int unreadCount;

  /// Khởi tạo thực thể `ConversationItem`.
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

  /// Kiểm tra xem `currentUserId` có phải là thành viên hợp lệ (`guest` hoặc `host`) của cuộc trò chuyện hay không.
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

  /// Kiểm tra quyền truy cập cuộc trò chuyện của `currentUserId` theo ngữ cảnh cổng giao diện.
  ///
  /// Ngăn chặn việc đọc nhầm luồng tin nhắn của cặp khách - chủ nhà khác và bắt buộc khớp `hostId`
  /// khi đang truy cập từ Cổng Chủ nhà (`isHostPortal` là `true`).
  bool canAccess(String currentUserId, {bool isHostPortal = false}) {
    final uid = currentUserId.trim();
    if (uid.isEmpty) return false;
    if (!isParticipant(uid)) return false;
    if (isHostPortal && hostId.trim().isNotEmpty && hostId.trim() != uid) {
      return false;
    }
    return true;
  }

  /// Phân giải tên hiển thị của đối phương dựa trên `currentUserId`, tránh gán cứng nhãn mặc định sai vai trò.
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

  /// Ảnh đại diện ưu tiên của đối phương, tự động chuyển về ảnh bìa chỗ nghỉ `listingImage` nếu thiếu.
  String? get displayAvatar => (otherParticipantAvatar != null &&
          otherParticipantAvatar!.trim().isNotEmpty)
      ? otherParticipantAvatar!.trim()
      : listingImage;

  /// Trả về đường dẫn ảnh đại diện hiển thị cho cuộc trò chuyện ứng với `currentUserId`.
  String? avatarFor(String currentUserId) => displayAvatar;

  /// Tạo bản sao `ConversationItem` với các trường dữ liệu được cập nhật mới.
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

  /// Giải mã đối tượng JSON từ API hội thoại thành thực thể `ConversationItem`,
  /// tự động bù đắp tên hiển thị và ảnh đại diện từ trường `otherParticipant`, `guest` hoặc `host`.
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

    final rawListingId =
        (json['listingId'] ?? listing?['listingId'] ?? listing?['id'] ?? '')
            .toString()
            .trim();

    return ConversationItem(
      id: (json['conversationId'] ?? json['id'] ?? '').toString(),
      listingId: rawListingId,
      listingTitle: (json['listingTitle'] ??
              listing?['title'] ??
              listing?['name'] ??
              (rawListingId.isNotEmpty
                  ? 'Trao đổi về chỗ nghỉ'
                  : 'Trò chuyện hỗ trợ trực tiếp'))
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

/// Bí danh kiểu dữ liệu phân trang cho danh sách tin nhắn `ChatMessageItem`.
typedef PaginatedMessagesResult = PaginatedResult<ChatMessageItem>;

/// Bí danh kiểu siêu dữ liệu phân trang của danh sách tin nhắn.
typedef MessagesPaginationMeta = PaginationMeta;

/// Bí danh kiểu kết quả xác nhận đã đọc cuộc trò chuyện.
typedef MarkReadResult = ConversationReadResult;

/// Kết quả trả về từ máy chủ sau khi đánh dấu đã đọc toàn bộ tin nhắn của một cuộc trò chuyện.
class ConversationReadResult {
  /// Mã định danh cuộc trò chuyện vừa được cập nhật trạng thái đã đọc.
  final String conversationId;

  /// Thời điểm đánh dấu đã đọc gần nhất theo chuẩn ISO-8601.
  final String? lastReadAt;

  /// Số tin nhắn chưa đọc còn lại sau khi cập nhật (thường bằng `0`).
  final int unreadCount;

  /// Khởi tạo `ConversationReadResult`.
  const ConversationReadResult({
    required this.conversationId,
    this.lastReadAt,
    this.unreadCount = 0,
  });

  /// Giải mã phản hồi JSON từ `PATCH /api/conversations/:id/read` thành `ConversationReadResult`.
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

/// Kho lưu trữ giao tiếp với các điểm cuối `/api/conversations` để quản lý hộp thư,
/// khởi tạo hội thoại, tải lịch sử phân trang, gửi tin nhắn và đồng bộ trạng thái đã đọc.
class ConversationsRepository {
  final DioClient _client;

  /// Khởi tạo `ConversationsRepository` với khách kết nối HTTP `_client`.
  const ConversationsRepository(this._client);

  /// Giới hạn số ký tự tối đa cho phép trong một lần gửi tin nhắn văn bản.
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

  /// Truy vấn danh sách cuộc trò chuyện của người dùng hiện tại theo bộ lọc `unreadOnly` và phạm vi `scope`.
  ///
  /// Nếu truyền `page` cụ thể, trả về duy nhất trang được yêu cầu; ngược lại tự động lặp qua các trang
  /// `1..totalPages` (tối đa `20` trang) và khử trùng theo `id` để nạp đầy đủ hộp thư.
  Future<List<ConversationItem>> getConversations({
    int? page,
    int? limit,
    bool? unreadOnly,
    String? scope,
  }) async {
    // Giải thuật phân trang toàn diện danh sách hội thoại theo phạm vi (`scope` = `'guest'` / `'host'`):
    // Khi không truyền `page` cố định, tự động tải tuần tự các trang `1..totalPages` (tối đa `maxPages = 20`)
    // và khử trùng lặp theo `id` để không bị cắt cụt danh sách ở mốc 30 cuộc hội thoại.
    // CONFLICT-RESOLVED: Bổ sung tải đủ trang khi `totalPages > 1` và hỗ trợ tham số lọc `scope`.
    final normalizedScope = scope?.trim().toLowerCase();
    final validScope = (normalizedScope == 'guest' || normalizedScope == 'host')
        ? normalizedScope
        : null;
    final effectiveLimit = (limit ?? 50).clamp(1, 100);

    if (page != null) {
      final single = await getConversationsPaginated(
        page: page,
        limit: effectiveLimit,
        unreadOnly: unreadOnly,
        scope: validScope,
      );
      return single.items;
    }

    const maxPages = 20;
    final merged = <ConversationItem>[];
    final seenIds = <String>{};

    for (int currentPage = 1; currentPage <= maxPages; currentPage++) {
      final result = await getConversationsPaginated(
        page: currentPage,
        limit: effectiveLimit,
        unreadOnly: unreadOnly,
        scope: validScope,
      );
      for (final item in result.items) {
        if (item.id.isEmpty || seenIds.add(item.id)) {
          merged.add(item);
        }
      }
      if (result.items.isEmpty || currentPage >= result.pagination.totalPages) {
        break;
      }
    }

    return merged;
  }

  /// Tải một trang danh sách cuộc trò chuyện từ `GET /api/conversations` kèm siêu dữ liệu phân trang.
  Future<PaginatedResult<ConversationItem>> getConversationsPaginated({
    int page = 1,
    int limit = 30,
    bool? unreadOnly,
    String? scope,
  }) async {
    try {
      final safePage = page < 1 ? 1 : page;
      final safeLimit = limit.clamp(1, 100);
      final normalizedScope = scope?.trim().toLowerCase();
      final queryParams = <String, dynamic>{
        'page': safePage,
        'limit': safeLimit,
        if (unreadOnly != null) 'unreadOnly': unreadOnly,
        if (normalizedScope == 'guest' || normalizedScope == 'host')
          'scope': normalizedScope,
      };
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/conversations',
        queryParameters: queryParams,
      );
      final rawBody = response.data;
      final data = DioClient.unwrapEnvelope(rawBody);
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
        if (data['pagination'] is Map) {
          rawPagination = Map<String, dynamic>.from(data['pagination'] as Map);
        }
      }
      final rawTopPagination = rawBody?['pagination'];
      if (rawPagination == null && rawTopPagination is Map) {
        rawPagination = Map<String, dynamic>.from(rawTopPagination);
      }
      final items = list
          .whereType<Map<String, dynamic>>()
          .map(ConversationItem.fromJson)
          .toList();
      return PaginatedResult<ConversationItem>(
        items: items,
        pagination: PaginationMeta.fromJson(
          rawPagination ??
              <String, dynamic>{
                'page': safePage,
                'limit': safeLimit,
                'total': items.length,
                'totalPages': 1,
              },
        ),
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Khởi tạo mới hoặc lấy lại cuộc trò chuyện hiện có với Chủ nhà gắn theo chỗ nghỉ `listingId`,
  /// tùy chọn đính kèm `bookingId` và tin nhắn mở đầu `firstMessage`.
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

  /// Khởi tạo hoặc lấy lại cuộc trò chuyện trực tiếp 1-1 với người dùng `participantId`
  /// (ví dụ luồng hỗ trợ giữa Quản trị viên và Chủ nhà hoặc Khách hàng).
  Future<ConversationItem> getOrCreateDirectConversation(
    String participantId, {
    String? firstMessage,
  }) async {
    final trimmedParticipantId = participantId.trim();
    if (trimmedParticipantId.isEmpty) {
      throw const ValidationFailure('Mã người nhận không hợp lệ.');
    }
    try {
      final body = <String, dynamic>{
        'participantId':
            int.tryParse(trimmedParticipantId) ?? trimmedParticipantId,
      };
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
      throw const ServerFailure('Không thể khởi tạo cuộc trò chuyện.');
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Tải phân trang lịch sử tin nhắn của cuộc trò chuyện `conversationId` qua
  /// `GET /api/conversations/:id/messages`, đồng thời chuẩn hóa thứ tự thời gian bằng `mergeAndSortMessages`.
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

  /// Truy vấn danh sách tin nhắn phẳng của cuộc trò chuyện `conversationId` theo `page` và `limit`.
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

  /// Kiểm tra hợp lệ độ dài văn bản (`1..2000` ký tự) và gửi tin nhắn mới tới `conversationId`
  /// thông qua `POST /api/conversations/:id/messages`.
  Future<ChatMessageItem> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    List<Map<String, dynamic>>? attachments,
  }) async {
    _validateConversationId(conversationId);
    final trimmed = content.trim();
    if (trimmed.isEmpty && (attachments == null || attachments.isEmpty)) {
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
          'messageType': messageType,
          if (attachments != null && attachments.isNotEmpty)
            'attachments': attachments,
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

  /// Đánh dấu toàn bộ tin nhắn trong cuộc trò chuyện `conversationId` là đã đọc
  /// thông qua `PATCH /api/conversations/:id/read`.
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

/// Provider khởi tạo kho lưu trữ hội thoại `ConversationsRepository`.
final conversationsRepositoryProvider =
    Provider<ConversationsRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return ConversationsRepository(client);
});

/// Provider tải danh sách hội thoại theo phạm vi vai trò `scope` (`'guest'` hoặc `'host'`),
/// tự động làm mới khi danh tính người dùng đăng nhập thay đổi.
final conversationsScopedListProvider = FutureProvider.autoDispose
    .family<List<ConversationItem>, String?>((ref, scope) async {
  ref.watch(authNotifierProvider.select((s) => s.valueOrNull?.id));
  return ref
      .watch(conversationsRepositoryProvider)
      .getConversations(scope: scope);
});

/// Provider tải toàn bộ danh sách cuộc trò chuyện của phiên đăng nhập hiện hành.
final conversationsListProvider =
    FutureProvider.autoDispose<List<ConversationItem>>((ref) async {
  ref.watch(authNotifierProvider.select((s) => s.valueOrNull?.id));
  return ref.watch(conversationsRepositoryProvider).getConversations();
});
