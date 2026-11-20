import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications/push_notification_service.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/view_models/auth_notifier.dart';
import '../features/trips/presentation/view_models/trips_view_model.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/app_header.dart';
import 'di/providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Widget gốc của ứng dụng The Palm Villa quản lý định tuyến, đa ngôn ngữ và vòng đời toàn cục.
///
/// Đóng vai trò điều phối trung tâm giữa giao diện `MaterialApp.router`, chủ đề `AppTheme.lightTheme`,
/// bộ ngôn ngữ (`vi`, `en`, `ko`), đồng bộ tỷ giá ngoại tệ nền và luồng thông báo đẩy FCM / Socket.IO.
class ThePalmVillaApp extends ConsumerStatefulWidget {
  const ThePalmVillaApp({super.key});

  @override
  ConsumerState<ThePalmVillaApp> createState() => _ThePalmVillaAppState();
}

class _ThePalmVillaAppState extends ConsumerState<ThePalmVillaApp>
    with WidgetsBindingObserver {
  StreamSubscription<PushNotificationTapEvent>? _pushTapSub;
  StreamSubscription<void>? _foregroundPushSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Giải thuật khởi tạo hậu khung hình đầu tiên (Post-Frame Initialization):
    // Trì hoãn các tác vụ mạng không chặn giao diện (làm mới tỷ giá ngoại tệ, đăng ký lắng nghe
    // thông báo đẩy, xử lý thao tác chạm thông báo khi mở lạnh `takePendingInitialTap` và đồng bộ
    // mã thiết bị FCM của người dùng đang đăng nhập) sang sau khung hình đầu tiên.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(effectiveCurrencyProvider).isForeign) {
        unawaited(ref.read(exchangeRatesProvider.notifier).refreshIfNeeded());
      }
      final pushService = ref.read(pushNotificationServiceProvider);

      _pushTapSub = pushService.onNotificationTap.listen(_handlePushTap);
      _foregroundPushSub = pushService.onForegroundPush.listen((_) {
        if (!mounted) return;
        ref.read(notificationsProvider.notifier).fetchNotifications();
        ref.invalidate(myBookingsProvider);
      });

      unawaited(() async {
        await pushService.initialize();
        if (!mounted) return;
        final pendingTap = pushService.takePendingInitialTap();
        if (pendingTap != null) {
          _handlePushTap(pendingTap);
        }
        final currentUser = ref.read(authNotifierProvider).valueOrNull;
        if (currentUser != null) {
          await pushService.syncAuthenticatedUser(currentUser.id);
        }
      }());
    });
  }

  /// Xử lý sự kiện người dùng chạm vào thông báo đẩy để đánh dấu đã đọc và điều hướng tới màn hình đích.
  void _handlePushTap(PushNotificationTapEvent event) {
    if (!mounted) return;
    final notifId = event.notificationId;
    if (notifId != null && notifId.isNotEmpty) {
      unawaited(ref.read(notificationsProvider.notifier).markAsRead(notifId));
    }
    if (event.route.isNotEmpty) {
      final clean = event.route.split('?').first.toLowerCase();
      final isTab = clean == '/' ||
          clean == '/messages' ||
          clean == '/tin-nhan' ||
          clean == '/trips' ||
          clean == '/account/trips' ||
          clean == '/settings' ||
          clean == '/account/profile';
      if (isTab) {
        ref.read(appRouterProvider).go(event.route);
      } else {
        ref.read(appRouterProvider).push(event.route);
      }
    }
  }

  @override
  void dispose() {
    _pushTapSub?.cancel();
    _foregroundPushSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Giải thuật hồi phục trạng thái khi ứng dụng quay lại tiền cảnh (`resumed`):
    // Kiểm tra lại phiên xác thực, làm mới danh sách đặt phòng, cập nhật tỷ giá ngoại tệ nếu cần
    // và đồng bộ lại mã thông báo thiết bị FCM cho người dùng hiện tại.
    if (state == AppLifecycleState.resumed) {
      ref.read(authNotifierProvider.notifier).onAppResumed();
      ref.invalidate(myBookingsProvider);
      if (ref.read(effectiveCurrencyProvider).isForeign) {
        unawaited(ref.read(exchangeRatesProvider.notifier).refreshIfNeeded());
      }
      final currentUser = ref.read(authNotifierProvider).valueOrNull;
      if (currentUser != null) {
        unawaited(
          ref
              .read(pushNotificationServiceProvider)
              .syncAuthenticatedUser(currentUser.id),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      unawaited(
        ref
            .read(pushNotificationServiceProvider)
            .syncAuthenticatedUser(user?.id),
      );
    });

    final router = ref.watch(appRouterProvider);
    final currentLanguageCode = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'The Palm Villa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: Locale(currentLanguageCode),
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
        Locale('ko'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
