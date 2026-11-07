import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hotel_booking_flutter/features/settings/presentation/screens/settings_screen.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/trips_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/global_pending_booking_banner.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthNotifier {
  _FakeAuthNotifier([User? user])
      : super(
          AsyncValue.data(
            user ??
                const User(
                  id: 'test-user-1',
                  email: 'test@example.com',
                  firstName: 'Minh',
                  lastName: 'Thanh',
                  role: 'guest',
                ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testUser = User(
    id: 'test-user-1',
    email: 'test@example.com',
    firstName: 'Minh',
    lastName: 'Thanh',
    role: 'guest',
  );

  final now = DateTime.now();
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

  group('Header & Pending Booking Banner Alternation across Tabs (Messages, Trips, Account)', () {
    testWidgets(
        '1. MessagesScreen without pending booking: shows header (search bar & bell)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            conversationsListProvider
                .overrideWith((ref) => Future.value(<ConversationItem>[])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MessagesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('header-search-bar')), findsOneWidget);
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byType(GlobalPendingBookingBanner), findsNothing);
    });

    testWidgets(
        '2. MessagesScreen with pending booking: prioritizes pending banner and hides search header & bell',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            conversationsListProvider
                .overrideWith((ref) => Future.value(<ConversationItem>[])),
            activePendingBookingProvider.overrideWithValue(testPendingBooking),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MessagesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlobalPendingBookingBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlobalPendingBookingBanner),
          matching: find.text('MinhThanh Luxury Sea View Villa Bãi Dâu'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('header-search-bar')), findsNothing);
      expect(find.byType(NotificationBell), findsNothing);
    });

    testWidgets(
        '3. TripsScreen without pending booking: shows header (search bar & bell)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            myBookingsProvider.overrideWith((ref) => Future.value(<Booking>[])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('header-search-bar')), findsOneWidget);
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byType(GlobalPendingBookingBanner), findsNothing);
    });

    testWidgets(
        '4. TripsScreen with pending booking: prioritizes pending banner and hides search header & bell',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            myBookingsProvider.overrideWith((ref) => Future.value(<Booking>[testPendingBooking])),
            activePendingBookingProvider.overrideWithValue(testPendingBooking),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlobalPendingBookingBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlobalPendingBookingBanner),
          matching: find.text('MinhThanh Luxury Sea View Villa Bãi Dâu'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('header-search-bar')), findsNothing);
      expect(find.byType(NotificationBell), findsNothing);
    });

    testWidgets(
        '5. SettingsScreen without pending booking: shows header (search bar & bell)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('header-search-bar')), findsOneWidget);
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byType(GlobalPendingBookingBanner), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('settings_bottom_logout_button')),
          matching: find.byIcon(LucideIcons.doorOpen),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        '6. SettingsScreen with pending booking: prioritizes pending banner and hides search header & bell',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            activePendingBookingProvider.overrideWithValue(testPendingBooking),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlobalPendingBookingBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlobalPendingBookingBanner),
          matching: find.text('MinhThanh Luxury Sea View Villa Bãi Dâu'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('header-search-bar')), findsNothing);
      expect(find.byType(NotificationBell), findsNothing);
    });
  });
}
