import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/router/app_router.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/trips_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/global_pending_booking_banner.dart';

void main() {
  final now = DateTime.now();
  const testUser = User(
    id: 'user-1',
    email: 'guest@example.com',
    firstName: 'Minh',
    lastName: 'Thành',
    role: 'guest',
  );

  final testPendingBooking = Booking(
    id: 'test-pending-123',
    listingId: 'villa-1',
    propertyName: 'MinhThanh Luxury Sea View Villa Bãi Dâu',
    checkInDate: '2026-11-01',
    checkOutDate: '2026-11-03',
    nights: 2,
    guestCount: 2,
    totalAmount: 3500000,
    status: 'pending_payment',
    paymentStatus: 'pending',
    lockedUntil: now.add(const Duration(minutes: 9, seconds: 40)),
    paymentExpiresAt: now.add(const Duration(minutes: 9, seconds: 40)),
    createdAt: now,
  );

  group('TripsScreen pending booking header replacement', () {
    testWidgets(
        'renders "Chuyến đi của bạn" title when there is NO pending booking',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            myBookingsProvider.overrideWith((ref) => Future.value([])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title "Chuyến đi của bạn" is removed
      expect(find.text('Chuyến đi của bạn'), findsNothing);
      // Banner is NOT shown
      expect(find.byType(GlobalPendingBookingBanner), findsNothing);
      // Tabs are shown
      expect(find.text('Sắp tới'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);
    });

    testWidgets(
        'replaces "Chuyến đi của bạn" with pinned banner at the top when there IS a pending booking',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            myBookingsProvider.overrideWith((ref) => Future.value([testPendingBooking])),
            activePendingBookingProvider.overrideWithValue(testPendingBooking),
          ],
          child: const MaterialApp(
            home: TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. "Chuyến đi của bạn" text is REMOVED
      expect(find.text('Chuyến đi của bạn'), findsNothing);

      // 2. Pinned banner is shown in its place at the top
      expect(find.byType(GlobalPendingBookingBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlobalPendingBookingBanner),
          matching: find.text('MinhThanh Luxury Sea View Villa Bãi Dâu'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(GlobalPendingBookingBanner),
          matching: find.widgetWithText(FilledButton, 'Thanh toán'),
        ),
        findsOneWidget,
      );

      // 3. Banner is positioned ABOVE the tabs
      final bannerTop =
          tester.getTopLeft(find.byType(GlobalPendingBookingBanner)).dy;
      final tabsTop = tester.getTopLeft(find.text('Sắp tới')).dy;
      expect(bannerTop, lessThan(tabsTop),
          reason: 'Pinned banner must be placed at the top, ABOVE the tabs');

      // 4. Tabs are still present
      expect(find.text('Sắp tới'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);
    });

    testWidgets(
        'tapping "Thanh toán" on the pinned banner navigates to /thanh-toan/:bookingId',
        (tester) async {
      String? navigatedLocation;

      final testRouter = GoRouter(
        initialLocation: '/trips',
        routes: [
          GoRoute(
            path: '/trips',
            builder: (context, state) => const TripsScreen(),
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
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            myBookingsProvider.overrideWith((ref) => Future.value([testPendingBooking])),
            activePendingBookingProvider.overrideWithValue(testPendingBooking),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlobalPendingBookingBanner), findsOneWidget);
      final bannerPayButton = find.descendant(
        of: find.byType(GlobalPendingBookingBanner),
        matching: find.widgetWithText(FilledButton, 'Thanh toán'),
      );
      await tester.tap(bannerPayButton);
      await tester.pumpAndSettle();

      expect(navigatedLocation, '/thanh-toan/test-pending-123');
      expect(find.text('Payment Screen'), findsOneWidget);
    });
  });
}

class _FakeAuthNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthNotifier {
  _FakeAuthNotifier([User? user]) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
