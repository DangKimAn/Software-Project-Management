// CONFLICT-RESOLVED: Bổ sung `MessagesViewModel` cho phân hệ Tin nhắn (`messages_screen.dart`) theo chuẩn MVVM
// (FLUTTER_RULES.md Mục 2), loại bỏ việc Screen gọi trực tiếp `conversationsRepositoryProvider` và `socketServiceProvider`.
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/socket_service.dart';
import '../../data/conversations_repository.dart';
import '../../services/chat_media_upload_service.dart';

export '../../../../app/di/providers.dart' show villaDetailProvider;
export '../../data/conversations_repository.dart'
    show
        ChatMessageItem,
        SocketMessageEnvelope,
        ConversationItem,
        ConversationReadResult,
        MarkReadResult,
        MessageDeliveryStatus,
        MessagesPaginationMeta,
        PaginatedMessagesResult,
        conversationsListProvider,
        conversationsScopedListProvider;

/// ViewModel điều phối kết nối thời gian thực (Socket.IO) và truy vấn/gửi tin nhắn qua `ConversationsRepository`.
///
/// Đóng vai trò cầu nối MVVM cho màn hình trò chuyện: cung cấp các luồng sự kiện thời gian thực
/// (`onMessageNew`, `onConversationError`, `onTyping`, `onConnected`) và thực thi gửi nhận,
/// phân trang lịch sử cũng như đánh dấu đã đọc mà không lộ `DioClient` hay `SocketService` ra tầng giao diện.
class MessagesViewModel {
  final Ref _ref;
  final ConversationsRepository _repository;
  final SocketService _socket;

  /// Khởi tạo `MessagesViewModel` với `Ref`, kho dữ liệu hội thoại và dịch vụ Socket.IO.
  const MessagesViewModel(this._ref, this._repository, this._socket);

  /// Luồng phát các gói tin sự kiện `message:new` thời gian thực từ máy chủ Socket.IO.
  Stream<Map<String, dynamic>> get onMessageNew => _socket.onMessageNew;

  /// Luồng phát thông báo lỗi truy cập phòng hội thoại (ví dụ `FORBIDDEN` / `403`) từ kênh Socket.IO.
  Stream<Map<String, dynamic>> get onConversationError =>
      _socket.onConversationError;

  /// Luồng phát trạng thái đối phương đang gõ văn bản (`typing`) theo từng cuộc hội thoại.
  Stream<Map<String, dynamic>> get onTyping => _socket.onTyping;

  /// Luồng thông báo sự kiện kết nối lại Socket.IO thành công để đồng bộ bù tin nhắn bị lỡ.
  Stream<void> get onConnected => _socket.onConnected;

  /// Kích hoạt kết nối kênh Socket.IO thời gian thực cho phiên người dùng hiện tại.
  // Giải thuật kích hoạt kết nối kênh Socket thời gian thực cho phiên người dùng hiện tại.
  Future<void> connectSocket() => _socket.connect();

  /// Phát tín hiệu trạng thái nhập văn bản `isTyping` tới phòng hội thoại `conversationId`.
  // Giải thuật phát tín hiệu đang nhập văn bản (`typing`) tới phòng hội thoại hiện hành.
  void sendTyping(String conversationId, {required bool isTyping}) {
    _socket.sendTyping(conversationId, isTyping: isTyping);
  }

  /// Đăng ký tham gia phòng lắng nghe sự kiện thời gian thực của cuộc trò chuyện `conversationId`.
  // Giải thuật tham gia phòng lắng nghe tin nhắn thời gian thực theo `conversationId`.
  void joinConversation(String conversationId) {
    _socket.joinConversation(conversationId);
  }

  /// Rời khỏi phòng lắng nghe thời gian thực `conversationId` khi chuyển cuộc trò chuyện hoặc đăng xuất.
  // Giải thuật rời phòng hội thoại thời gian thực khi chuyển cuộc trò chuyện hoặc đăng xuất.
  void leaveConversation(String conversationId) {
    _socket.leaveConversation(conversationId);
  }

  /// Tải một trang lịch sử tin nhắn của cuộc hội thoại `conversationId` theo `page` và `limit`.
  // Giải thuật tải phân trang lịch sử tin nhắn của một cuộc hội thoại.
  Future<PaginatedMessagesResult> getMessagesPaginated(
    String conversationId, {
    int page = 1,
    int limit = 30,
  }) {
    return _repository.getMessagesPaginated(
      conversationId,
      page: page,
      limit: limit,
    );
  }

  /// Đánh dấu toàn bộ tin nhắn trong cuộc trò chuyện `conversationId` là đã đọc trên máy chủ.
  // Giải thuật đánh dấu đã đọc toàn bộ tin nhắn trong cuộc trò chuyện trên máy chủ.
  Future<MarkReadResult> markConversationRead(String conversationId) {
    return _repository.markConversationRead(conversationId);
  }

  /// Gửi tin nhắn văn bản hoặc đính kèm đa phương tiện tới cuộc hội thoại `conversationId`.
  // Giải thuật gửi tin nhắn văn bản/hình ảnh/ghi âm tới cuộc hội thoại đang mở.
  // CONFLICT-RESOLVED: Bổ sung `messageType`, `attachments` và hàm `uploadChatMedia` từ develop vào ViewModel để tuân thủ chuẩn MVVM.
  Future<ChatMessageItem> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    List<Map<String, dynamic>>? attachments,
  }) {
    return _repository.sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: messageType,
      attachments: attachments,
    );
  }

  /// Tải tệp ảnh hoặc ghi âm lên Cloudflare R2 thông qua `ChatMediaUploadService`.
  // Giải thuật tải byte đa phương tiện lên kho R2 phục vụ gửi ảnh/ghi âm trong hội thoại.
  Future<ChatUploadResult> uploadChatMedia({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) {
    return _ref.read(chatMediaUploadServiceProvider).uploadMediaBytesToR2(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
  }

  /// Chuẩn hóa mọi ngoại lệ tầng mạng hoặc API thành `AppFailure` thống nhất cho tầng giao diện.
  // Giải thuật chuẩn hóa ngoại lệ tầng mạng/API thành `AppFailure` mà không lộ `DioClient` ra tầng Screen.
  static AppFailure mapError(Object error) => DioClient.handleError(error);

  /// Khởi tạo hoặc mở lại cuộc hội thoại với Chủ nhà theo mã biệt thự `villaId`,
  /// gửi ngay tin nhắn đầu tiên `content` và làm mới danh sách hộp thư.
  // Giải thuật khởi tạo (hoặc mở lại) hội thoại với Chủ nhà theo `villaId`, gửi tin nhắn đầu tiên và làm mới hộp thư.
  Future<ConversationItem> startVillaConversationAndSend({
    required String villaId,
    required String content,
  }) async {
    final conv = await _repository.getOrCreateConversation(villaId);
    await _repository.sendMessage(conversationId: conv.id, content: content);
    _ref.invalidate(conversationsListProvider);
    return conv;
  }
}

/// Provider cung cấp `MessagesViewModel` kết hợp kho lưu trữ hội thoại và dịch vụ Socket.IO.
final messagesViewModelProvider = Provider<MessagesViewModel>((ref) {
  final repository = ref.watch(conversationsRepositoryProvider);
  final socket = ref.watch(socketServiceProvider);
  return MessagesViewModel(ref, repository, socket);
});
