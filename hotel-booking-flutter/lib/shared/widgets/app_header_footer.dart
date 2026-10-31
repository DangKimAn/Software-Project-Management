import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/di/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/socket_service.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
import '../../features/search/presentation/widgets/source_search_bar.dart';
import '../../features/trips/presentation/widgets/global_pending_booking_banner.dart';
import 'app_semantic_icons.dart';
import 'currency_language_selector.dart';
import 'notification_glass_widgets.dart';

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

  /// Resolves a safe internal app route matching `NotificationBell.tsx` (`resolveNotificationUrl`),
  /// blocking any untrusted external URL (`http://`, `https://`, `//`, `javascript:`, etc.).
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
      if (convId.isNotEmpty) {
        return '/messages?conversationId=$convId';
      }
      return '/messages';
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

  static String _normalizeInternalRoute(String route) {
    // Map legacy web routes to Flutter router equivalents where needed
    if (route == '/host/bookings') return '/chu-nha/dat-phong';
    if (route == '/host/listings') return '/chu-nha/cho-nghi';
    if (route == '/admin/moderation') return '/admin/kiem-duyet';
    if (route == '/admin/host-applications') return '/admin/ho-so-host';
    return route;
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

  void _onSocketNotification(Map<String, dynamic> payload) {
    if (!mounted || !_isAuthenticated) return;
    final item = AppNotificationItem.fromJson(payload);
    if (item.id.isNotEmpty) {
      final existingIdx = state.items.indexWhere((e) => e.id == item.id);
      List<AppNotificationItem> nextItems;
      if (existingIdx >= 0) {
        nextItems = [...state.items];
        nextItems[existingIdx] = item;
      } else {
        nextItems = [item, ...state.items];
      }
      final unread = nextItems.where((n) => !n.isRead).length;
      state = state.copyWith(
        items: nextItems,
        unreadCount: unread,
      );
    } else {
      fetchNotifications();
    }
  }

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

  Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;
    final updated = state.items
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    final unread = updated.where((e) => !e.isRead).length;
    state = state.copyWith(items: updated, unreadCount: unread);
    try {
      await _client.dio
          .patch<Map<String, dynamic>>('/api/notifications/$id/read');
    } catch (_) {}
  }

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

/// NotificationBell widget styled with frosted glass capsule cards, pastel icon rings,
/// and slender SF Pro typography while preserving 100% of existing notification content.
class NotificationBell extends ConsumerWidget {
  final bool isOverlayTop;

  const NotificationBell({
    super.key,
    this.isOverlayTop = false,
  });

  String _formatNotificationTime(String raw) {
    if (raw.trim().isEmpty) return '';
    final dt = DateTime.tryParse(raw.trim())?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _openNotificationsSheet(BuildContext context, WidgetRef ref) {
    ref.read(notificationsProvider.notifier).fetchNotifications();
    showGlassNotificationsOverlay(
      context: context,
      formatTime: _formatNotificationTime,
      onSelectNotification: (item) {
        if (context.mounted) {
          _navigateForNotification(context, item);
        }
      },
    );
  }

  void _navigateForNotification(
    BuildContext context,
    AppNotificationItem item,
  ) {
    final route = item.resolveInternalRoute();
    if (route != null && route.isNotEmpty) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);

    return GlassNotificationBellButton(
      unreadCount: notifState.unreadCount,
      isOverlayTop: isOverlayTop,
      onTap: () => _openNotificationsSheet(context, ref),
    );
  }
}

/// Top header variant equipped with the pill search bar ("Bạn muốn đi đâu?"),
/// notification bell, and popup menu across main tabs (Tin nhắn, Chuyến đi, Tài khoản).
class AppSearchHeader extends StatelessWidget {
  final String currentPath;
  final bool hidePendingBanner;

  const AppSearchHeader({
    super.key,
    required this.currentPath,
    this.hidePendingBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppTopHeader(
      currentPath: currentPath,
      hidePendingBanner: hidePendingBanner,
      centerSearchTrigger: SourceSearchBar(
        isCompact: true,
        isInHeader: true,
        onSearchSubmitted: () {
          try {
            context.push('/tim-kiem');
          } catch (_) {}
        },
      ),
    );
  }
}

/// Top Header / Navbar matching `Source goc/frontend/src/views/components/common/Header.tsx` & `Navbar.tsx`.
class AppTopHeader extends ConsumerWidget {
  final String currentPath;
  final Widget? centerSearchTrigger;
  final bool isOverlayTop;
  final bool hidePendingBanner;

  const AppTopHeader({
    super.key,
    this.currentPath = '/',
    this.centerSearchTrigger,
    this.isOverlayTop = false,
    this.hidePendingBanner = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = screenWidth >= 900;
      final isCompactMobile = screenWidth < 380;

      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isOverlayTop ? Colors.transparent : Colors.white,
          border: isOverlayTop
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE4E4E7), width: 1),
                ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? (centerSearchTrigger != null ? 24 : 40)
              : (isCompactMobile ? 12.0 : 16.0),
          vertical: 10,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Row(
                    children: [
                      // Left & Center Area: Switches smoothly between (Brand Logo + Nav Links) and (Pinned Search Bar)
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            final isSearch = (child.key as ValueKey?)?.value ==
                                'pinned_search_content';
                            if (isSearch) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.70),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: animation,
                                    curve: const Interval(0.1, 1.0,
                                        curve: Curves.easeOut),
                                  ),
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.94,
                                      end: 1.0,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    )),
                                    child: child,
                                  ),
                                ),
                              );
                            } else {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, -0.2),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            }
                          },
                          child: centerSearchTrigger != null
                              ? KeyedSubtree(
                                  key: const ValueKey('pinned_search_content'),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: isDesktop ? 16 : 8,
                                    ),
                                    child: centerSearchTrigger!,
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('top_header_content'),
                                  child: Row(
                                    children: [
                                      // Left: Brand Logo + "The Palm Villa"
                                      Flexible(
                                        child: InkWell(
                                          onTap: () => context.go('/'),
                                          splashColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                minHeight: 48),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AppBrandIcon.minhThanhLogo(
                                                  size: 26,
                                                  color: isOverlayTop
                                                      ? Colors.white
                                                      : AppColors.iconStrong,
                                                ),
                                                if (screenWidth >= 380) ...[
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      'The Palm Villa',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: isDesktop
                                                            ? 19
                                                            : (isCompactMobile
                                                                ? 16
                                                                : 19),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -0.4,
                                                        color: isOverlayTop
                                                            ? Colors.white
                                                            : AppColors
                                                                .textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      if (isDesktop) ...[
                                        const Spacer(),
                                        // Center: 4 Navigation Links (`Navbar.tsx`)
                                        Flexible(
                                          flex: 3,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _NavTextLink(
                                                  label: 'Trang chủ',
                                                  isActive: currentPath == '/',
                                                  isOverlayTop: isOverlayTop,
                                                  onTap: () => context.go('/'),
                                                ),
                                                SizedBox(
                                                    width: screenWidth >= 1280
                                                        ? 28
                                                        : (screenWidth >= 1080
                                                            ? 20
                                                            : 14)),
                                                _NavTextLink(
                                                  label: 'Nơi lưu trú',
                                                  isActive: currentPath
                                                          .startsWith(
                                                              '/search') ||
                                                      currentPath.startsWith(
                                                          '/tim-kiem') ||
                                                      currentPath.startsWith(
                                                          '/noi-luu-tru') ||
                                                      currentPath.startsWith(
                                                          '/villas'),
                                                  isOverlayTop: isOverlayTop,
                                                  onTap: () =>
                                                      context.push('/tim-kiem'),
                                                ),
                                                SizedBox(
                                                    width: screenWidth >= 1280
                                                        ? 28
                                                        : (screenWidth >= 1080
                                                            ? 20
                                                            : 14)),
                                                _NavTextLink(
                                                  label: 'Blog',
                                                  isActive: currentPath
                                                          .startsWith(
                                                              '/blog') ||
                                                      currentPath.startsWith(
                                                          '/cam-nang'),
                                                  isOverlayTop: isOverlayTop,
                                                  onTap: () =>
                                                      context.push('/cam-nang'),
                                                ),
                                                SizedBox(
                                                    width: screenWidth >= 1280
                                                        ? 28
                                                        : (screenWidth >= 1080
                                                            ? 20
                                                            : 14)),
                                                _NavTextLink(
                                                  label: 'Liên hệ',
                                                  isActive: currentPath
                                                      .startsWith('/lien-he'),
                                                  isOverlayTop: isOverlayTop,
                                                  onTap: () =>
                                                      context.push('/lien-he'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                      ] else
                                        const Spacer(),
                                    ],
                                  ),
                                ),
                        ),
                      ),

                      // Right: Host action (only when not scrolled down), NotificationBell, then Menu
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: (centerSearchTrigger == null &&
                                (authUser == null || !authUser.isAdmin) &&
                                screenWidth >= 1260)
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (authUser != null && authUser.isHost) {
                                        context.push('/chu-nha/cho-nghi');
                                      } else {
                                        context.push('/tro-thanh-host');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOverlayTop
                                            ? Colors.transparent
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            authUser != null && authUser.isHost
                                                ? 'Khu vực host'
                                                : 'Trở thành host',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isOverlayTop
                                                  ? Colors.white
                                                  : const Color(0xFF18181B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Notification Bell (Icon thông báo)
                      NotificationBell(isOverlayTop: isOverlayTop),
                      const SizedBox(width: 2),

                      // Menu Button (Icon menu)
                      PopupMenuButton<String>(
                        tooltip: 'Menu',
                        offset: const Offset(0, 48),
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        onSelected: (value) async {
                          switch (value) {
                            case 'home':
                              context.go('/');
                              break;
                            case 'login':
                              unawaited(context.push('/dang-nhap'));
                              break;
                            case 'register':
                              unawaited(context.push('/dang-ky'));
                              break;
                            case 'profile':
                              unawaited(context.push('/account/profile'));
                              break;
                            case 'trips':
                              unawaited(context.push('/account/trips'));
                              break;
                            case 'wishlist':
                              unawaited(context.push('/yeu-thich'));
                              break;
                            case 'messages':
                              unawaited(context.push('/messages'));
                              break;
                            case 'ai-search':
                              unawaited(context.push('/tim-kiem-ai'));
                              break;
                            case 'stays':
                              unawaited(context.push('/tim-kiem'));
                              break;
                            case 'blog':
                              unawaited(context.push('/cam-nang'));
                              break;
                            case 'contact':
                              unawaited(context.push('/lien-he'));
                              break;
                            case 'language-currency':
                              unawaited(
                                showCurrencyLanguageBottomSheet(context),
                              );
                              break;
                            case 'host':
                              if (authUser != null && authUser.isHost) {
                                unawaited(context.push('/chu-nha/cho-nghi'));
                              } else {
                                unawaited(context.push('/tro-thanh-host'));
                              }
                              break;
                            case 'admin':
                              unawaited(context.push('/admin'));
                              break;
                            case 'logout':
                              ref
                                  .read(notificationsProvider.notifier)
                                  .clearForLogout();
                              await ref
                                  .read(authNotifierProvider.notifier)
                                  .logout();
                              if (context.mounted) {
                                context.go('/');
                              }
                              break;
                          }
                        },
                        itemBuilder: (context) {
                          if (authUser == null) {
                            return [
                              if (!isDesktop) ...[
                                const PopupMenuItem(
                                  value: 'home',
                                  child: _MenuItemRow(
                                    icon: AppSemanticIcons.home,
                                    label: 'Trang chủ',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'stays',
                                  child: _MenuItemRow(
                                    icon: LucideIcons.search,
                                    label: 'Nơi lưu trú',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'blog',
                                  child: _MenuItemRow(
                                    icon: LucideIcons.bookOpen,
                                    label: 'Blog',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'contact',
                                  child: _MenuItemRow(
                                    icon: LucideIcons.phone,
                                    label: 'Liên hệ',
                                  ),
                                ),
                                const PopupMenuDivider(),
                              ],
                              const PopupMenuItem(
                                value: 'wishlist',
                                child: _MenuItemRow(
                                  icon: LucideIcons.heart,
                                  label: 'Danh sách yêu thích',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'trips',
                                child: _MenuItemRow(
                                  icon: AppSemanticIcons.bookings,
                                  label: 'Chuyến đi',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'messages',
                                child: _MenuItemRow(
                                  icon: AppSemanticIcons.messageHost,
                                  label: 'Tin nhắn',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'profile',
                                child: _MenuItemRow(
                                  icon: AppSemanticIcons.userProfile,
                                  label: 'Hồ sơ',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'language-currency',
                                child: _MenuItemRow(
                                  icon: LucideIcons.globe,
                                  label:
                                      '${ref.read(moneyFormatterProvider).l10n.settingsLanguage} • ${ref.read(effectiveCurrencyProvider).code} (${ref.read(effectiveCurrencyProvider).symbol})',
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'host',
                                child: _MenuItemRow(
                                  icon: AppSemanticIcons.becomeHost,
                                  label: 'Trở thành host',
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'login',
                                child: _MenuItemRow(
                                  icon: LucideIcons.logIn,
                                  label: 'Đăng nhập',
                                  isBold: true,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'register',
                                child: _MenuItemRow(
                                  icon: LucideIcons.userPlus,
                                  label: 'Đăng ký',
                                ),
                              ),
                            ];
                          }
                          return [
                            PopupMenuItem(
                              enabled: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authUser.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    authUser.email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            if (!isDesktop) ...[
                              const PopupMenuItem(
                                value: 'home',
                                child: _MenuItemRow(
                                  icon: AppSemanticIcons.home,
                                  label: 'Trang chủ',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'stays',
                                child: _MenuItemRow(
                                  icon: LucideIcons.search,
                                  label: 'Nơi lưu trú',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'blog',
                                child: _MenuItemRow(
                                  icon: LucideIcons.bookOpen,
                                  label: 'Blog',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'contact',
                                child: _MenuItemRow(
                                  icon: LucideIcons.phone,
                                  label: 'Liên hệ',
                                ),
                              ),
                              const PopupMenuDivider(),
                            ],
                            const PopupMenuItem(
                              value: 'wishlist',
                              child: _MenuItemRow(
                                icon: LucideIcons.heart,
                                label: 'Danh sách yêu thích',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'trips',
                              child: _MenuItemRow(
                                icon: AppSemanticIcons.bookings,
                                label: 'Chuyến đi',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'messages',
                              child: _MenuItemRow(
                                icon: AppSemanticIcons.messageHost,
                                label: 'Tin nhắn',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'profile',
                              child: _MenuItemRow(
                                icon: AppSemanticIcons.userProfile,
                                label: 'Hồ sơ',
                              ),
                            ),
                            PopupMenuItem(
                              value: 'language-currency',
                              child: _MenuItemRow(
                                icon: LucideIcons.globe,
                                label:
                                    '${ref.read(moneyFormatterProvider).l10n.settingsLanguage} • ${ref.read(effectiveCurrencyProvider).code} (${ref.read(effectiveCurrencyProvider).symbol})',
                              ),
                            ),
                            const PopupMenuDivider(),
                            if (!authUser.isAdmin)
                              PopupMenuItem(
                                value: 'host',
                                child: _MenuItemRow(
                                  icon: authUser.isHost
                                      ? AppSemanticIcons.home
                                      : AppSemanticIcons.becomeHost,
                                  label: authUser.isHost
                                      ? 'Khu vực host'
                                      : 'Trở thành host',
                                ),
                              ),
                            if (authUser.isAdmin)
                              const PopupMenuItem(
                                value: 'admin',
                                child: _MenuItemRow(
                                  icon: AppSemanticIcons.adminPortal,
                                  label: 'Khu vực admin',
                                  isBold: true,
                                ),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'logout',
                              child: _MenuItemRow(
                                icon: AppSemanticIcons.logout,
                                label: 'Đăng xuất',
                              ),
                            ),
                          ];
                        },
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.menu,
                              size: 20,
                              color: isOverlayTop
                                  ? Colors.white
                                  : AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!hidePendingBanner)
                const GlobalPendingBookingHeaderBanner(
                  margin: EdgeInsets.only(top: 8),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBold;

  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: AppColors.iconStrong,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavTextLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isOverlayTop;
  final VoidCallback onTap;

  const _NavTextLink({
    required this.label,
    required this.isActive,
    this.isOverlayTop = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isOverlayTop
        ? (isActive ? Colors.white : Colors.white.withValues(alpha: 0.85))
        : (isActive ? const Color(0xFF0F172A) : const Color(0xFF475569));

    final indicatorColor = isOverlayTop ? Colors.white : AppColors.primary;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 2,
              width: isActive ? 28 : 0,
              decoration: BoxDecoration(
                color: isActive ? indicatorColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer matching `Source goc/frontend/src/views/components/common/Footer.tsx` 100%.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = width >= 1024 ? 80.0 : (width >= 768 ? 24.0 : 16.0);

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(horizontalPad, 40, horizontalPad, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 960
                      ? 4
                      : (constraints.maxWidth >= 560 ? 2 : 1);
                  final colWidth =
                      (constraints.maxWidth - ((cols - 1) * 32)) / cols;

                  return Wrap(
                    spacing: 32,
                    runSpacing: 32,
                    children: [
                      SizedBox(
                        width: colWidth,
                        child: _FooterColumn(
                          title: 'Hỗ trợ',
                          links: [
                            (
                              'Hướng dẫn đặt phòng',
                              () => context.push(
                                    '/cam-nang/checklist-truoc-khi-dat-villa',
                                  )
                            ),
                            (
                              'Chính sách hủy phòng',
                              () => context.push(
                                    '/cam-nang/kinh-nghiem-dat-villa-vung-tau-lan-dau',
                                  )
                            ),
                            (
                              'Khiếu nại & Góp ý',
                              () => context.push('/lien-he')
                            ),
                            (
                              'Câu hỏi thường gặp (FAQ)',
                              () => context.push('/lien-he')
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: colWidth,
                        child: _FooterColumn(
                          title: 'Khám phá Vũng Tàu',
                          links: [
                            ('Về chúng tôi', () => context.push('/lien-he')),
                            (
                              'Cẩm nang du lịch',
                              () => context.push('/cam-nang')
                            ),
                            (
                              'Dịch vụ đi kèm',
                              () => context.push(
                                    '/cam-nang/lich-trinh-vung-tau-2-ngay-1-dem-cho-nhom-ban',
                                  )
                            ),
                            (
                              'Ưu đãi thành viên',
                              () => context.push('/tim-kiem')
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: colWidth,
                        child: _FooterColumn(
                          title: 'Liên hệ',
                          links: [
                            if (AppConfig.verifiedHotlineOrNull != null)
                              (
                                'Hotline: ${AppConfig.verifiedHotlineOrNull}',
                                () => _openExternalUrl(
                                      'tel:${AppConfig.verifiedHotlineOrNull}',
                                    )
                              )
                            else
                              (
                                'Liên hệ tư vấn trực tuyến',
                                () => context.push('/lien-he')
                              ),
                            (
                              'Địa chỉ: 28 Thi Sách',
                              () => _openExternalUrl(
                                    'https://www.google.com/maps/search/?api=1&query=28%20Thi%20Sach%20Vung%20Tau',
                                  )
                            ),
                            (
                              'Email: bookingvillavtdl@gmail.com',
                              () => _openExternalUrl(
                                    'mailto:bookingvillavtdl@gmail.com',
                                  )
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: colWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Social',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                _SocialIconButton(
                                  tooltip: 'Facebook',
                                  label: 'Facebook',
                                  icon: const AppBrandIcon.facebook(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openExternalUrl(
                                    'https://www.facebook.com/villavungtauuytin',
                                  ),
                                ),
                                _SocialIconButton(
                                  tooltip: 'Threads',
                                  label: 'Threads',
                                  icon: const AppBrandIcon.threads(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openExternalUrl(
                                    'https://www.threads.com/athanhnee',
                                  ),
                                ),
                                _SocialIconButton(
                                  tooltip: 'TikTok',
                                  label: 'TikTok',
                                  icon: const AppBrandIcon.tiktok(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openExternalUrl(
                                    'https://www.tiktok.com/@minhthanh.villavungtau',
                                  ),
                                ),
                                _SocialIconButton(
                                  tooltip: 'YouTube',
                                  label: 'YouTube',
                                  icon: const AppBrandIcon.youtube(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openExternalUrl(
                                    'https://www.youtube.com/@VillaVungTau-MinhThanh',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
              const Divider(color: Color(0xFF374151), height: 1),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  '© Copyright Villa Vung Tau 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<(String, VoidCallback)> links;

  const _FooterColumn({
    required this.title,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        for (final item in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: item.$2,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Text(
                item.$1,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final String label;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
