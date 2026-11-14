// CONFLICT-RESOLVED: Tách mô hình dữ liệu thông báo (AppNotificationItem & NotificationsState) thành tệp độc lập khỏi app_header_footer.dart theo nguyên tắc đơn trách nhiệm.
class AppNotificationItem {
  final String id;
  final String notificationLogId;
  final String eventType;
  final String? targetType;
  final String? targetId;
  final String title;
  final String body;
  final String? actionUrl;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final String? updatedAt;

  const AppNotificationItem({
    required this.id,
    String? notificationLogId,
    String? eventType,
    String? type,
    this.targetType,
    this.targetId,
    required this.title,
    String? body,
    String? message,
    this.actionUrl,
    this.payload,
    Map<String, dynamic>? metadata,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.updatedAt,
  })  : notificationLogId = notificationLogId ?? id,
        eventType = eventType ?? type ?? 'system',
        body = body ?? message ?? '';

  static final RegExp _legacyVillaBrandPattern =
      RegExp(r'Minh\s*Th(?:ành|anh)\s+Villa', caseSensitive: false);
  static final RegExp _legacyLuxuryBrandPattern =
      RegExp(r'MinhThanh\s+Luxury', caseSensitive: false);

  /// Normalizes legacy brand text from historical DB notification records to The Palm Villa.
  static String normalizeBrandText(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll(_legacyVillaBrandPattern, 'The Palm Villa')
        .replaceAll(_legacyLuxuryBrandPattern, 'The Palm Luxury');
  }

  /// Backward-compatible getters
  String get type => eventType;
  String get message => body;
  Map<String, dynamic>? get metadata => payload;
  bool get forAdmin =>
      payload?['forAdmin'] == true ||
      payload?['isAdminNotification'] == true ||
      payload?['targetRole'] == 'admin' ||
      title.startsWith('[Admin]');

  factory AppNotificationItem.fromJson(Map<String, dynamic> rawJson) {
    final json = rawJson['notification'] is Map
        ? Map<String, dynamic>.from(rawJson['notification'] as Map)
        : rawJson;

    final resolvedId = (json['notificationLogId'] ??
            json['notificationId'] ??
            json['id'] ??
            '')
        .toString();

    Map<String, dynamic>? parsedPayload;
    if (json['payload'] is Map) {
      parsedPayload = Map<String, dynamic>.from(json['payload'] as Map);
    } else if (json['metadata'] is Map) {
      parsedPayload = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    final rawActionUrl = json['actionUrl']?.toString().trim();
    final rawTargetType = json['targetType']?.toString().trim();
    final rawTargetId = json['targetId']?.toString().trim();

    return AppNotificationItem(
      id: resolvedId,
      notificationLogId: (json['notificationLogId'] ?? resolvedId).toString(),
      eventType: (json['eventType'] ?? json['type'] ?? 'system').toString(),
      targetType: (rawTargetType != null && rawTargetType.isNotEmpty)
          ? rawTargetType
          : null,
      targetId:
          (rawTargetId != null && rawTargetId.isNotEmpty) ? rawTargetId : null,
      title: normalizeBrandText((json['title'] ?? 'Thông báo').toString()),
      body: normalizeBrandText(
          (json['body'] ?? json['message'] ?? json['content'] ?? '')
              .toString()),
      actionUrl: (rawActionUrl != null && rawActionUrl.isNotEmpty)
          ? rawActionUrl
          : null,
      payload: parsedPayload,
      isRead: json['isRead'] == true || json['readAt'] != null,
      readAt: json['readAt']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  // Giải thuật phân giải đường dẫn nội bộ an toàn cho thông báo (Safe Internal Route Resolution):
  // Kiểm tra tính hợp lệ của `actionUrl` chống Open Redirect / XSS trước khi ánh xạ theo `targetType` và `eventType`.
  String? resolveInternalRoute() {
    final candidate = actionUrl?.trim() ?? '';
    if (candidate.isNotEmpty && isSafeInternalRoute(candidate)) {
      return _normalizeInternalRoute(candidate);
    }

    final tType = (targetType ?? '').toLowerCase();
    final eType = eventType.toLowerCase();

    if (tType == 'booking' || eType.startsWith('booking.')) {
      if (eType == 'booking.created') {
        return '/chu-nha/dat-phong';
      }
      return '/account/trips';
    }

    if (tType == 'payment' || eType.startsWith('payment.')) {
      final bookingId = payload?['bookingId']?.toString() ?? '';
      if (bookingId.isNotEmpty) {
        return '/thanh-toan/$bookingId';
      }
      return '/account/trips';
    }

    if (tType == 'listing' ||
        eType.startsWith('listing.') ||
        eType.startsWith('listing_')) {
      if (forAdmin ||
          eType == 'listing.submitted_for_review' ||
          eType == 'listing_submitted' ||
          eType == 'listing.submitted') {
        return '/admin/kiem-duyet';
      }
      return '/chu-nha/cho-nghi';
    }

    if (tType == 'host_application' ||
        eType.startsWith('host_application.') ||
        eType.startsWith('host_application_')) {
      if (forAdmin ||
          eType == 'host_application.submitted' ||
          eType == 'host_application_submitted') {
        return '/admin/ho-so-host';
      }
      return '/tro-thanh-host/trang-thai';
    }

    if (tType == 'conversation' ||
        eType.contains('message') ||
        eType.contains('chat')) {
      final convId = targetId ?? payload?['conversationId']?.toString() ?? '';
      if (forAdmin) {
        return convId.isNotEmpty
            ? '/admin/tin-nhan?conversationId=$convId'
            : '/admin/tin-nhan';
      }
      if (convId.isNotEmpty) {
        return '/messages?conversationId=$convId';
      }
      return '/messages';
    }

    if (tType.contains('platform_fee') ||
        eType.contains('platform_fee') ||
        tType == 'payout' ||
        eType.startsWith('payout.')) {
      return forAdmin ? '/admin/tai-chinh' : '/chu-nha/bao-cao';
    }

    return null;
  }

  static bool isSafeInternalRoute(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('/') || trimmed.startsWith('//')) {
      return false;
    }
    if (RegExp(r'[\x00-\x1F\x7F\\]').hasMatch(trimmed)) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower.contains('://') ||
        lower.contains('..') ||
        lower.contains('%2f') ||
        lower.contains('%5c') ||
        lower.contains('%2e') ||
        lower.startsWith('/javascript:') ||
        lower.startsWith('/data:') ||
        lower.startsWith('/vbscript:')) {
      return false;
    }
    return true;
  }

  // Giải thuật ánh xạ chuẩn hóa đường dẫn thông báo nội bộ (`/host/...` -> `/chu-nha/...`):
  // Tách bảo toàn query string, ánh xạ tường minh `/host/bao-cao` -> `/chu-nha/bao-cao`
  // và tổng quát hóa mọi đường dẫn `/host/...` sang `/chu-nha/...` để thông báo Host (`PLATFORM_FEE_SCHEDULED`, v.v.) không bị lỗi 404.
  // CONFLICT-RESOLVED: Đồng bộ tiền tố route `/host/...` từ thông báo backend sang cây điều hướng `/chu-nha/...` trên GoRouter.
  static String _normalizeInternalRoute(String route) {
    final trimmed = route.trim();
    final qIndex = trimmed.indexOf('?');
    final pathPart = qIndex >= 0 ? trimmed.substring(0, qIndex) : trimmed;
    final querySuffix = qIndex >= 0 ? trimmed.substring(qIndex) : '';

    String mappedPath = pathPart;
    if (pathPart == '/host' || pathPart == '/host/') {
      mappedPath = '/chu-nha/tong-quan';
    } else if (pathPart == '/host/bookings') {
      mappedPath = '/chu-nha/dat-phong';
    } else if (pathPart == '/host/listings') {
      mappedPath = '/chu-nha/cho-nghi';
    } else if (pathPart == '/host/bao-cao' ||
        pathPart == '/host/reports' ||
        pathPart == '/host/earnings' ||
        pathPart == '/host/platform-fees') {
      mappedPath = '/chu-nha/bao-cao';
    } else if (pathPart == '/host/messages') {
      mappedPath = '/chu-nha/tin-nhan';
    } else if (pathPart == '/host/calendar') {
      mappedPath = '/chu-nha/lich';
    } else if (pathPart.startsWith('/host/')) {
      mappedPath = '/chu-nha/${pathPart.substring('/host/'.length)}';
    } else if (pathPart == '/admin/moderation') {
      mappedPath = '/admin/kiem-duyet';
    } else if (pathPart == '/admin/host-applications') {
      mappedPath = '/admin/ho-so-host';
    } else if (pathPart == '/admin/messages') {
      mappedPath = '/admin/tin-nhan';
    }

    return '$mappedPath$querySuffix';
  }

  AppNotificationItem copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return AppNotificationItem(
      id: id,
      notificationLogId: notificationLogId,
      eventType: eventType,
      targetType: targetType,
      targetId: targetId,
      title: title,
      body: body,
      actionUrl: actionUrl,
      payload: payload,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class NotificationsState {
  final List<AppNotificationItem> items;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<AppNotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
