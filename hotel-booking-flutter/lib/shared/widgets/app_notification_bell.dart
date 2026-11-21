// CONFLICT-RESOLVED: Tách thuần giao diện `NotificationBell` khỏi `NotificationsNotifier`,
// chỉ giao tiếp với tầng ViewModel (`notificationsProvider`) theo đúng phân lớp MVVM (FLUTTER_RULES.md Mục 2).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/di/notifications_view_model.dart';
import 'notification_glass_widgets.dart';

export '../../app/di/notifications_view_model.dart';

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
      final clean = route.split('?').first.toLowerCase();
      final isTab = clean == '/' ||
          clean == '/messages' ||
          clean == '/tin-nhan' ||
          clean == '/trips' ||
          clean == '/account/trips' ||
          clean == '/settings' ||
          clean == '/account/profile';
      if (isTab) {
        context.go(route);
      } else {
        context.push(route);
      }
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
