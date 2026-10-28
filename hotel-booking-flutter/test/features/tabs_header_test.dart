import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hotel_booking_flutter/features/settings/presentation/screens/settings_screen.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/trips_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';

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

  group('Top Header with Search Bar across Bottom Navigation Tabs', () {
    testWidgets('1. MessagesScreen (Tin nhắn) renders top search header and bell',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            conversationsListProvider
                .overrideWith((ref) => Future.value(<ConversationItem>[])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MessagesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search bar pill
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsOneWidget,
      );
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);

      // Notification bell
      expect(find.byType(NotificationBell), findsOneWidget);

      // Header component
      expect(find.byType(AppSearchHeader), findsOneWidget);
    });

    testWidgets('2. TripsScreen (Chuyến đi) renders top search header and bell',
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

      // Search bar pill
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsOneWidget,
      );
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);

      // Notification bell
      expect(find.byType(NotificationBell), findsOneWidget);

      // Header component
      expect(find.byType(AppSearchHeader), findsOneWidget);
    });

    testWidgets('3. SettingsScreen (Tài khoản) renders top search header and bell',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search bar pill
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsOneWidget,
      );
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);

      // Notification bell
      expect(find.byType(NotificationBell), findsOneWidget);

      // Header component
      expect(find.byType(AppSearchHeader), findsOneWidget);
    });
  });
}
