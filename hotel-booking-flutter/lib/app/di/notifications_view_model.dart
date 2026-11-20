// CONFLICT-RESOLVED: Chuyển `NotificationsNotifier` và `notificationsProvider` từ tệp Widget
// (`shared/widgets/app_notification_bell.dart`) sang tầng quản lý trạng thái ứng dụng (`app/di/`)
// theo chuẩn MVVM tại FLUTTER_RULES.md Mục 2, loại bỏ việc Widget gọi trực tiếp `dioClientProvider` / `socketServiceProvider`.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/socket_service.dart';
import 'providers.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
import '../../shared/widgets/app_notification_models.dart';

export '../../shared/widgets/app_notification_models.dart';

/// Quản lý trạng thái danh sách thông báo và bộ đếm chưa đọc theo thời gian thực.
///
/// Kết hợp ba kênh cập nhật đồng bộ:
/// 1. Tải phân trang ban đầu từ REST API `GET /api/notifications`.
/// 2. Đón luồng sự kiện `notification:new` và sự kiện tái kết nối từ `SocketService`.
/// 3. Chu kỳ thăm dò dự phòng mỗi 60 giây khi người dùng đang đăng nhập (tự tắt trong môi trường kiểm thử).
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final DioClient _client;
  final bool _isAuthenticated;
  final SocketService? _socketService;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<void>? _reconnectSub;
  Timer? _pollTimer;

  NotificationsNotifier(
    this._client,
    this._isAuthenticated,
    Stream<Map<String, dynamic>> socketStream, {
    SocketService? socketService,
    bool enablePolling = true,
    bool autoConnectSocket = true,
    bool autoFetch = true,
  })  : _socketService = socketService,
        super(const NotificationsState()) {
    if (_isAuthenticated) {
      if (autoConnectSocket) {
        _socketService?.connect();
      }
      if (autoFetch) {
        fetchNotifications();
      }
      _socketSub = socketStream.listen(_onSocketNotification);
      _reconnectSub = _socketService?.onConnected.listen((_) {
        if (mounted && _isAuthenticated) {
          fetchNotifications();
        }
      });
      if (enablePolling) {
        _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          if (mounted && _isAuthenticated) {
            fetchNotifications();
          }
        });
      }
    } else {
      _socketService?.disconnect();
    }
  }

  // Giải thuật hợp nhất bản tin thông báo thời gian thực & bảo toàn bộ đếm chưa đọc (`unreadCount`):
  // Thay thế tại chỗ nếu trùng `id` hoặc chèn đầu danh sách khi là bản tin mới; cộng `state.unreadCount + 1`
  // khi nhận thông báo chưa đọc mới thay vì đếm lại trên lát cắt 20 bản ghi cục bộ.
  // CONFLICT-RESOLVED: Giữ nguyên tổng `unreadCount` thực tế từ máy chủ (kể cả khi >20 thông báo).
  void _onSocketNotification(Map<String, dynamic> payload) {
    if (!mounted || !_isAuthenticated) return;
    final item = AppNotificationItem.fromJson(payload);
    if (item.id.isNotEmpty) {
      final existingIdx = state.items.indexWhere((e) => e.id == item.id);
      List<AppNotificationItem> nextItems;
      var nextUnreadCount = state.unreadCount;
      if (existingIdx >= 0) {
        final wasUnread = !state.items[existingIdx].isRead;
        final isNowUnread = !item.isRead;
        if (wasUnread && !isNowUnread) {
          nextUnreadCount = math.max(0, state.unreadCount - 1);
        } else if (!wasUnread && isNowUnread) {
          nextUnreadCount = state.unreadCount + 1;
        }
        nextItems = [...state.items];
        nextItems[existingIdx] = item;
      } else {
        nextItems = [item, ...state.items];
        if (!item.isRead) {
          nextUnreadCount = state.unreadCount + 1;
        }
      }
      state = state.copyWith(
        items: nextItems,
        unreadCount: nextUnreadCount,
      );
    } else {
      fetchNotifications();
    }
  }

  /// Dọn dẹp bộ hẹn giờ, hủy đăng ký luồng Socket.IO và đặt lại trạng thái rỗng khi người dùng đăng xuất.
  void clearForLogout() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    _reconnectSub?.cancel();
    _reconnectSub = null;
    _socketService?.disconnect();
    if (mounted) {
      state = const NotificationsState();
    }
  }

  // Giải thuật đồng bộ danh sách thông báo phân trang từ `/api/notifications`:
  // Bóc tách dữ liệu từ phong bì chuẩn và ưu tiên `unreadCount` do máy chủ trả về (nếu có).
  /// Đồng bộ danh sách thông báo phân trang từ máy chủ và cập nhật tổng số thông báo chưa đọc.
  Future<void> fetchNotifications() async {
    if (!_isAuthenticated) return;
    state = state.copyWith(isLoading: true);
    try {
      final res = await _client.dio.get<Map<String, dynamic>>(
        '/api/notifications',
        queryParameters: {'page': 1, 'limit': 20},
      );
      final data = DioClient.unwrapEnvelope(res.data);
      List<dynamic> rawItems = [];
      int? explicitUnread;
      if (data is Map<String, dynamic>) {
        if (data['items'] is List) {
          rawItems = data['items'] as List<dynamic>;
        }
        explicitUnread = (data['unreadCount'] as num?)?.toInt();
      } else if (data is List) {
        rawItems = data;
      }
      final parsed = rawItems
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationItem.fromJson)
          .toList();
      final unread = explicitUnread ?? parsed.where((n) => !n.isRead).length;
      if (mounted && _isAuthenticated) {
        state = state.copyWith(
          items: parsed,
          unreadCount: unread,
          isLoading: false,
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  // Giải thuật giảm trừ chính xác bộ đếm thông báo chưa đọc (`unreadCount`):
  // Khi đánh dấu đã đọc một thông báo trước đó chưa đọc, tính `math.max(0, state.unreadCount - 1)`
  // thay vì đếm lại `updated.where((n) => !n.isRead).length` (vốn làm tụt từ 35 xuống 19 do chỉ giữ 20 mục).
  // CONFLICT-RESOLVED: Ngăn sụt giảm sai lệch `unreadCount` khi người dùng có nhiều hơn 20 thông báo chưa đọc.
  /// Đánh dấu một thông báo theo `id` là đã đọc theo cơ chế cập nhật lạc quan (Optimistic Update) và giảm trừ chính xác `unreadCount`.
  Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;
    final existingIdx = state.items.indexWhere((e) => e.id == id);
    if (existingIdx >= 0 && state.items[existingIdx].isRead) {
      return;
    }
    final updated = state.items
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    final unread = math.max(0, state.unreadCount - 1);
    state = state.copyWith(items: updated, unreadCount: unread);
    try {
      await _client.dio
          .patch<Map<String, dynamic>>('/api/notifications/$id/read');
    } catch (_) {}
  }

  // Giải thuật đánh dấu toàn bộ thông báo là đã đọc và đưa `unreadCount` về 0.
  /// Đánh dấu toàn bộ thông báo hiện có là đã đọc và đưa bộ đếm `unreadCount` về `0`.
  Future<void> markAllAsRead() async {
    final updated = state.items.map((e) => e.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated, unreadCount: 0);
    try {
      await _client.dio
          .patch<Map<String, dynamic>>('/api/notifications/read-all');
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }
}

/// Provider toàn cục quản lý trạng thái thông báo của người dùng hiện tại, tự động phản ứng khi đổi phiên xác thực.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final client = ref.watch(dioClientProvider);
  final socket = ref.watch(socketServiceProvider);
  final user = ref.watch(authNotifierProvider).valueOrNull;
  final isTest =
      WidgetsBinding.instance.runtimeType.toString().contains('Test');
  return NotificationsNotifier(
    client,
    user != null,
    socket.onNotificationNew,
    socketService: socket,
    enablePolling: !isTest,
    autoConnectSocket: !isTest,
    autoFetch: !isTest,
  );
});
