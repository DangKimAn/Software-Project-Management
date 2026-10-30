import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/blog/data/blog_repository.dart';
import 'package:hotel_booking_flutter/features/home/presentation/screens/home_screen.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/source_search_bar.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthNotifier {
  _FakeAuthNotifier()
      : super(
          const AsyncValue.data(
            User(
              id: 'user-1',
              email: 'lehoang@example.com',
              firstName: 'Lê',
              lastName: 'Hoàng',
              role: 'user',
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationsNotifier extends StateNotifier<NotificationsState>
    implements NotificationsNotifier {
  _FakeNotificationsNotifier()
      : super(const NotificationsState(unreadCount: 5));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecentlyViewedNotifier
    extends StateNotifier<List<RecentlyViewedItem>>
    implements RecentlyViewedNotifier {
  _FakeRecentlyViewedNotifier() : super(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Pinned Header Search Bar', () {
    testWidgets(
        'AppTopHeader with centerSearchTrigger renders without overflow across viewports',
        (tester) async {
      final viewports = [
        const Size(360, 780),
        const Size(390, 844),
        const Size(412, 915),
        const Size(768, 1024),
        const Size(1200, 800),
        const Size(1440, 900),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
              notificationsProvider
                  .overrideWith((ref) => _FakeNotificationsNotifier()),
              activePendingBookingProvider.overrideWithValue(null),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: AppTopHeader(
                  currentPath: '/',
                  isOverlayTop: false,
                  centerSearchTrigger: SourceSearchBar(
                    isCompact: true,
                    isInHeader: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must find header search bar
        expect(
          find.byKey(const ValueKey<String>('header-search-bar')),
          findsOneWidget,
          reason:
              'Header search bar should render at ${size.width}x${size.height}',
        );

        // Must find notification bell
        expect(
          find.byType(NotificationBell),
          findsOneWidget,
          reason:
              'Notification bell should render at ${size.width}x${size.height}',
        );

        // Verify layout order: search bar X < notification bell X
        final searchBarCenter = tester
            .getCenter(find.byKey(const ValueKey<String>('header-search-bar')))
            .dx;
        final bellCenter =
            tester.getCenter(find.byType(NotificationBell)).dx;

        expect(searchBarCenter < bellCenter, isTrue);
      }
    });

    testWidgets(
        'HomeScreen keeps search bar pinned when scrolling down and does not disappear',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
            notificationsProvider
                .overrideWith((ref) => _FakeNotificationsNotifier()),
            activePendingBookingProvider.overrideWithValue(null),
            popularDestinationsProvider
                .overrideWith((ref) async => <Villa>[]),
            blogHighlightsProvider
                .overrideWith((ref) async => <BlogPost>[]),
            recentlyViewedProvider
                .overrideWith((ref) => _FakeRecentlyViewedNotifier()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At top (offset = 0): search in header is NOT visible
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsNothing,
      );

      // Scroll down by 250px
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      // Header search bar MUST appear
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsOneWidget,
      );

      // Scroll down further by another 300px (user scrolling down!)
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Header search bar MUST REMAIN visible (not disappear on scroll-down)
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsOneWidget,
      );

      // Scroll back up to the top
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();

      // Should hide when back at hero top
      expect(
        find.byKey(const ValueKey<String>('header-search-bar')),
        findsNothing,
      );
    });
  });
}
