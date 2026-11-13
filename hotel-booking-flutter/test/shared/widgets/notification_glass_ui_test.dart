import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';
import 'package:hotel_booking_flutter/shared/widgets/notification_glass_widgets.dart';

class _FakeLocaleNotifier extends StateNotifier<String>
    implements LocaleNotifier {
  _FakeLocaleNotifier([super.locale = 'vi']);

  @override
  Future<void> setLocale(String languageCode) async {
    state = languageCode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubNotificationsNotifier extends StateNotifier<NotificationsState>
    implements NotificationsNotifier {
  int fetchCalls = 0;
  final List<String> markedIds = [];
  int markAllCalls = 0;

  _StubNotificationsNotifier(super.initialState);

  @override
  Future<void> fetchNotifications() async {
    fetchCalls++;
  }

  @override
  Future<void> markAsRead(String id) async {
    markedIds.add(id);
    final updated = state.items
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((e) => !e.isRead).length,
    );
  }

  @override
  Future<void> markAllAsRead() async {
    markAllCalls++;
    final updated = state.items.map((e) => e.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated, unreadCount: 0);
  }

  @override
  void clearForLogout() {
    state = const NotificationsState();
  }
}

void main() {
  final sampleItems = <AppNotificationItem>[
    const AppNotificationItem(
      id: 'n-msg',
      eventType: 'MESSAGE_NEW',
      targetType: 'conversation',
      targetId: 'conv-42',
      title: 'Tin nhắn mới từ Chủ nhà',
      body: 'Ava: “Biệt thự đã sẵn sàng đón bạn lúc 14:00!”',
      isRead: false,
      createdAt: '2026-10-31T08:30:00.000Z',
    ),
    const AppNotificationItem(
      id: 'n-remind',
      eventType: 'PAYMENT_PENDING',
      targetType: 'payment',
      payload: {'bookingId': 'bk-101'},
      title: 'Nhắc thanh toán giữ phòng',
      body: 'Đơn đặt phòng sẽ hết hạn giữ chỗ sau 15 phút.',
      isRead: false,
      createdAt: '2026-10-31T08:15:00.000Z',
    ),
    const AppNotificationItem(
      id: 'n-admin',
      eventType: 'LISTING_SUBMITTED',
      targetType: 'listing',
      payload: {'forAdmin': true},
      title: 'Chỗ nghỉ mới chờ duyệt',
      body: 'The Palm Ocean Villa vừa gửi hồ sơ kiểm duyệt.',
      isRead: false,
      createdAt: '2026-10-31T07:50:00.000Z',
    ),
    const AppNotificationItem(
      id: 'n-confirm',
      eventType: 'BOOKING_CONFIRMED',
      targetType: 'booking',
      title: 'Xác nhận đặt phòng thành công',
      body: 'Chuyến đi Vũng Tàu của bạn đã được xác nhận.',
      isRead: true,
      createdAt: '2026-10-30T20:00:00.000Z',
    ),
  ];

  group('Frosted Glass Notification UI Redesign', () {
    testWidgets(
      'preserves all notification content, unread count, markAllAsRead, markAsRead & route navigation',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = _StubNotificationsNotifier(
          NotificationsState(items: sampleItems, unreadCount: 3),
        );
        String? pushedRoute;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: NotificationBell(),
                ),
              ),
            ),
            GoRoute(
              path: '/messages',
              builder: (_, state) {
                pushedRoute = state.uri.toString();
                return const Scaffold(body: Text('Messages Page'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith((_) => notifier),
              localeProvider.overrideWith((ref) => _FakeLocaleNotifier('vi')),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger button displays unread count badge "3"
        expect(find.byType(GlassNotificationBellButton), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        // Open frosted glass notification overlay
        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();
        expect(notifier.fetchCalls, 1);

        // Verify blurred backdrop & intact Vietnamese texts
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(find.text('Thông báo (3 chưa đọc)'), findsOneWidget);
        expect(find.text('Đánh dấu tất cả đã đọc'), findsOneWidget);
        expect(find.text('ADMIN'), findsOneWidget);
        expect(find.text('Tin nhắn mới từ Chủ nhà'), findsOneWidget);
        expect(
          find.text('Ava: “Biệt thự đã sẵn sàng đón bạn lúc 14:00!”'),
          findsOneWidget,
        );
        expect(find.text('Nhắc thanh toán giữ phòng'), findsOneWidget);
        expect(find.text('Chỗ nghỉ mới chờ duyệt'), findsOneWidget);
        expect(find.text('Xác nhận đặt phòng thành công'), findsOneWidget);

        // Verify title and body enforce single-line ellipsis truncation ("...")
        final titleText = tester.widget<Text>(
          find.text('Chỗ nghỉ mới chờ duyệt'),
        );
        final bodyText = tester.widget<Text>(
          find.text('Ava: “Biệt thự đã sẵn sàng đón bạn lúc 14:00!”'),
        );
        expect(titleText.maxLines, 1);
        expect(titleText.overflow, TextOverflow.ellipsis);
        expect(bodyText.maxLines, 1);
        expect(bodyText.overflow, TextOverflow.ellipsis);

        // Tap first unread card -> marks as read, closes modal, navigates to /messages?conversationId=conv-42
        await tester.tap(find.text('Tin nhắn mới từ Chủ nhà'));
        await tester.pumpAndSettle();

        expect(notifier.markedIds, contains('n-msg'));
        expect(pushedRoute, '/messages?conversationId=conv-42');
      },
    );

    testWidgets(
      'renders empty state and markAllAsRead cleanly, and closes via floating bell anchor',
      (tester) async {
        final notifier = _StubNotificationsNotifier(
          NotificationsState(items: sampleItems, unreadCount: 3),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith((_) => notifier),
              localeProvider.overrideWith((ref) => _FakeLocaleNotifier('vi')),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: Center(child: NotificationBell()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();

        // Tap mark all as read
        await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
        await tester.pumpAndSettle();

        expect(notifier.markAllCalls, 1);
        expect(find.text('Thông báo (0 chưa đọc)'), findsOneWidget);
        expect(find.text('Đánh dấu tất cả đã đọc'), findsNothing);

        // Close using the bottom circular bell toggle button
        await tester.tap(
          find.byKey(const Key('notification_overlay_bell_close_btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Thông báo (0 chưa đọc)'), findsNothing);

        // Verify empty state content
        notifier.clearForLogout();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có thông báo mới.'), findsOneWidget);
      },
    );

    testWidgets(
      'renders without RenderFlex overflow across 320/360/390/768/1280dp and 1.0x/1.6x text scales',
      (tester) async {
        final notifier = _StubNotificationsNotifier(
          NotificationsState(items: sampleItems, unreadCount: 120),
        );

        const viewports = <Size>[
          Size(320, 640),
          Size(360, 780),
          Size(390, 844),
          Size(768, 1024),
          Size(1280, 800),
        ];
        const scales = <double>[1.0, 1.6];

        for (final size in viewports) {
          for (final scale in scales) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  notificationsProvider.overrideWith((_) => notifier),
                  localeProvider
                      .overrideWith((ref) => _FakeLocaleNotifier('vi')),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: Align(
                      alignment: Alignment.topRight,
                      child: NotificationBell(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // 99+ cap works on header bell
            expect(find.text('99+'), findsOneWidget);

            await tester.tap(find.byType(NotificationBell));
            await tester.pumpAndSettle();

            expect(find.text('Thông báo (120 chưa đọc)'), findsOneWidget);

            // Dismiss via backdrop
            await tester.tapAt(const Offset(4, 4));
            await tester.pumpAndSettle();
          }
        }
      },
    );

    testWidgets(
      'localizes notifications header, items, and converts currency to USD and KRW',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final testItems = <AppNotificationItem>[
          const AppNotificationItem(
            id: 'n-pay',
            eventType: 'PAYMENT_SUCCESS',
            title: 'Thanh toán thành công',
            body:
                'Booking #42 đã thanh toán thành công. Host sẽ xác nhận đặt phòng.',
            isRead: false,
            createdAt: '2026-10-31T08:30:00.000Z',
          ),
          const AppNotificationItem(
            id: 'n-pending',
            eventType: 'PAYMENT_PENDING',
            title: 'Thanh toán đang chờ xử lý',
            body: 'Thanh toán #903 cho booking #43 đang chờ xử lý.',
            isRead: false,
            createdAt: '2026-10-31T08:15:00.000Z',
          ),
          const AppNotificationItem(
            id: 'n-created',
            eventType: 'BOOKING_CREATED',
            title: 'Booking đã được tạo',
            body: 'Vui lòng hoàn tất thanh toán để giữ chỗ.',
            isRead: false,
            createdAt: '2026-10-31T08:00:00.000Z',
          ),
          const AppNotificationItem(
            id: 'n-expired',
            eventType: 'PAYMENT_EXPIRED',
            title: 'Phiên thanh toán đã hết hạn',
            body: 'Booking #41 đã hết hạn thanh toán.',
            isRead: true,
            createdAt: '2026-10-31T07:45:00.000Z',
          ),
          const AppNotificationItem(
            id: 'n-refund',
            eventType: 'REFUND_CREATED',
            title: 'Yêu cầu hoàn tiền đã được tạo',
            body: 'Hoàn tiền 1.580.000 ₫ cho booking #42 đang chờ xử lý.',
            isRead: true,
            createdAt: '2026-10-31T07:30:00.000Z',
          ),
        ];

        final testFxSnapshot = ExchangeRateSnapshot.validated(
          usdRateDecimal: '0.00004',
          krwRateDecimal: '0.054',
          source: 'test_fixture',
          sourceUpdatedAt:
              DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          fetchedAt: DateTime.now().toUtc(),
          serverMarkedStale: false,
          validationNow: DateTime.now().toUtc(),
        );

        // --- Test English + USD ---
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('en_scope'),
            overrides: [
              notificationsProvider.overrideWith(
                (_) => _StubNotificationsNotifier(
                  NotificationsState(items: testItems, unreadCount: 3),
                ),
              ),
              localeProvider.overrideWith((ref) => _FakeLocaleNotifier('en')),
              moneyFormatterProvider.overrideWithValue(
                MoneyFormatter(
                  localeCode: 'en',
                  effectiveCurrency: AppCurrency.usd,
                  snapshot: testFxSnapshot,
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: NotificationBell(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();

        // Header localized to English
        expect(find.text('Notifications (3 unread)'), findsOneWidget);
        expect(find.text('Mark all as read'), findsOneWidget);

        // Titles localized to English
        expect(find.text('Payment successful'), findsOneWidget);
        expect(find.text('Payment pending'), findsOneWidget);
        expect(find.text('Booking created'), findsOneWidget);
        expect(find.text('Payment session expired'), findsOneWidget);
        expect(find.text('Refund request created'), findsOneWidget);

        // Bodies localized to English + currency converted (1.580.000 * 0.00004 = $63.20)
        expect(
          find.text(
              'Booking #42 paid successfully. Host will confirm your booking.'),
          findsOneWidget,
        );
        expect(
          find.text('Payment #903 for booking #43 is pending completion.'),
          findsOneWidget,
        );
        expect(
          find.text('Please complete payment to secure your reservation.'),
          findsOneWidget,
        );
        expect(
          find.text('Booking #41 payment session has expired.'),
          findsOneWidget,
        );
        expect(
          find.text('Refund of ≈ \$63.20 for booking #42 is pending processing.'),
          findsOneWidget,
        );

        // Close notifications via floating bell button
        await tester.tap(
          find.byKey(const Key('notification_overlay_bell_close_btn')),
        );
        await tester.pumpAndSettle();

        // --- Test Korean + KRW ---
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('ko_scope'),
            overrides: [
              notificationsProvider.overrideWith(
                (_) => _StubNotificationsNotifier(
                  NotificationsState(items: testItems, unreadCount: 3),
                ),
              ),
              localeProvider.overrideWith((ref) => _FakeLocaleNotifier('ko')),
              moneyFormatterProvider.overrideWithValue(
                MoneyFormatter(
                  localeCode: 'ko',
                  effectiveCurrency: AppCurrency.krw,
                  snapshot: testFxSnapshot,
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: NotificationBell(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();

        // Header localized to Korean
        expect(find.text('알림 (3개 안 읽음)'), findsOneWidget);
        expect(find.text('모두 읽음으로 표시'), findsOneWidget);

        // Titles localized to Korean
        expect(find.text('결제 완료'), findsOneWidget);
        expect(find.text('결제 대기 중'), findsOneWidget);
        expect(find.text('예약 생성 완료'), findsOneWidget);
        expect(find.text('결제 세션 만료'), findsOneWidget);
        expect(find.text('환불 요청 생성'), findsOneWidget);

        // Bodies localized to Korean + currency converted (1.580.000 * 0.054 = ₩85,320)
        expect(
          find.text('예약 #42 결제가 완료되었습니다. 호스트가 확정할 예정입니다.'),
          findsOneWidget,
        );
        expect(
          find.text('예약 #43의 결제 #903 처리가 대기 중입니다.'),
          findsOneWidget,
        );
        expect(
          find.text('예약을 유지하려면 결제를 완료해 주세요.'),
          findsOneWidget,
        );
        expect(
          find.text('예약 #41의 결제 유효 시간이 만료되었습니다.'),
          findsOneWidget,
        );
        expect(
          find.text('예약 #42의 환불금 ≈ ₩85,320 처리가 대기 중입니다.'),
          findsOneWidget,
        );
      },
    );
  });
}

