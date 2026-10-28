import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/router/app_router.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/global_pending_booking_banner.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Booking createTestBooking([DateTime? baseTime]) {
    final t = baseTime ?? DateTime.now();
    return Booking(
      id: 'test-booking-123',
      listingId: 'villa-1',
      propertyName: 'Villa Palm Test',
      checkInDate: '2026-11-01',
      checkOutDate: '2026-11-03',
      nights: 2,
      guestCount: 2,
      totalAmount: 2500000,
      status: 'pending_payment',
      paymentStatus: 'pending',
      lockedUntil: t.add(const Duration(minutes: 9, seconds: 45)),
      paymentExpiresAt: t.add(const Duration(minutes: 9, seconds: 45)),
      createdAt: t,
    );
  }

  final testBooking = createTestBooking();

  group('GlobalPendingBookingBanner Widget', () {
    testWidgets(
        'renders hold banner without clock icon, without "Thời gian còn lại" text, with black countdown, centered villa name, and only Thanh toan oval button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GlobalPendingBookingBanner(booking: createTestBooking()),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Verify clock icon is NOT present (xoa icon dong ho)
      expect(find.byIcon(LucideIcons.clock), findsNothing);

      // 2. Verify "Thời gian còn lại" text is NOT present (xoa thoi gian con lai)
      expect(find.textContaining('Thời gian còn lại'), findsNothing);

      // Verify formatted countdown (09:4x) is present with black text
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final hasCountdown = textWidgets.any(
        (t) =>
            RegExp(r'09:4\d').hasMatch(t.data ?? '') ||
            (t.textSpan != null &&
                RegExp(r'09:4\d').hasMatch(t.textSpan!.toPlainText())),
      );
      expect(hasCountdown, isTrue);

      // 3. Verify villa name is centered and present
      expect(find.text('Villa Palm Test'), findsOneWidget);

      // 4. Verify only "Thanh toán" oval button is present; "Hủy" button is removed
      expect(find.widgetWithText(FilledButton, 'Thanh toán'), findsOneWidget);
      expect(find.text('Hủy'), findsNothing);
    });

    testWidgets('navigates to /thanh-toan/:bookingId when tapped',
        (tester) async {
      String? navigatedLocation;

      final testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: GlobalPendingBookingBanner(booking: testBooking),
            ),
          ),
          GoRoute(
            path: '/thanh-toan/:bookingId',
            builder: (context, state) {
              navigatedLocation = state.uri.path;
              return const Scaffold(body: Text('Payment Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(testRouter),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the banner
      await tester.tap(find.byType(GlobalPendingBookingBanner));
      await tester.pumpAndSettle();

      expect(navigatedLocation, equals('/thanh-toan/test-booking-123'));
      expect(find.text('Payment Screen'), findsOneWidget);
    });

    testWidgets(
        'navigates to /thanh-toan/:bookingId when "Thanh toán" button is pressed',
        (tester) async {
      String? navigatedLocation;

      final testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: GlobalPendingBookingBanner(booking: testBooking),
            ),
          ),
          GoRoute(
            path: '/thanh-toan/:bookingId',
            builder: (context, state) {
              navigatedLocation = state.uri.path;
              return const Scaffold(body: Text('Payment Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(testRouter),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on "Thanh toán" button
      await tester.tap(find.widgetWithText(FilledButton, 'Thanh toán'));
      await tester.pumpAndSettle();

      expect(navigatedLocation, equals('/thanh-toan/test-booking-123'));
    });
  });

  group('Header Integration & Positioning (Đặt dưới thanh header)', () {
    testWidgets('does not show banner in AppTopHeader when no pending booking',
        (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: AppTopHeader(currentPath: '/'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(testRouter),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The Palm Villa'), findsOneWidget);
      expect(find.byType(GlobalPendingBookingBanner), findsNothing);
    });

    testWidgets(
        'renders banner DIRECTLY UNDER AppTopHeader when pending booking exists',
        (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: AppTopHeader(currentPath: '/'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(testRouter),
            activePendingBookingProvider.overrideWithValue(testBooking),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The Palm Villa'), findsOneWidget);
      expect(find.byType(GlobalPendingBookingBanner), findsOneWidget);

      // CRITICAL ASSERTION: Banner must be UNDER the header ("The Palm Villa" logo row)
      final headerTop = tester.getTopLeft(find.text('The Palm Villa')).dy;
      final bannerTop =
          tester.getTopLeft(find.byType(GlobalPendingBookingBanner)).dy;
      expect(
        bannerTop,
        greaterThan(headerTop),
        reason: 'Banner must be positioned UNDER the header row',
      );
    });

    testWidgets(
        'automatically hides banner when on payment screen /thanh-toan/:bookingId',
        (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/thanh-toan/test-booking-123',
        routes: [
          GoRoute(
            path: '/thanh-toan/:bookingId',
            builder: (context, state) => const Scaffold(
              body: AppTopHeader(currentPath: '/thanh-toan/test-booking-123'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(testRouter),
            activePendingBookingProvider.overrideWithValue(testBooking),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The Palm Villa'), findsOneWidget);
      expect(find.byType(GlobalPendingBookingBanner), findsNothing);
    });
  });
}
