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
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        final bellCenter = tester.getCenter(find.byType(NotificationBell)).dx;

        expect(searchBarCenter < bellCenter, isTrue);
        expect(
          find.byKey(const Key('header_currency_language_button')),
          findsNothing,
        );
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
            popularDestinationsProvider.overrideWith((ref) async => <Villa>[]),
            blogHighlightsProvider.overrideWith((ref) async => <BlogPost>[]),
            recentlyViewedProvider
                .overrideWith((ref) => _FakeRecentlyViewedNotifier()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At top (offset = 0): search in header is NOT visible and language globe icon is NOT rendered
      expect(
        find.byKey(const Key('header_currency_language_button')),
        findsNothing,
      );
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

    testWidgets(
        'Popular Destinations header hides subtitle and replaces Xem tất cả text with arrowRight toggle',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const sampleVilla = Villa(
        id: 'villa-1',
        code: 'MTV-01',
        name: 'The Palm Ocean Villa',
        tagline: 'Bãi Sau',
        address: '19 Trần Phú, Vũng Tàu',
        description: 'Biệt thự sát biển',
        imageUrls: <String>[],
        specs: VillaSpecs(
          bedrooms: 4,
          beds: 5,
          maxGuests: 12,
          bathrooms: 4,
        ),
        basePriceVnd: 5500000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
            notificationsProvider
                .overrideWith((ref) => _FakeNotificationsNotifier()),
            activePendingBookingProvider.overrideWithValue(null),
            popularDestinationsProvider
                .overrideWith((ref) async => <Villa>[sampleVilla]),
            blogHighlightsProvider.overrideWith((ref) async => <BlogPost>[]),
            recentlyViewedProvider
                .overrideWith((ref) => _FakeRecentlyViewedNotifier()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ĐIỂM ĐẾN NỔI BẬT'), findsOneWidget);
      expect(find.text('Điểm đến được yêu thích'), findsOneWidget);
      expect(
        find.text(
          'Khám phá các căn biệt thự và chỗ nghỉ được yêu thích nhất tại Vũng Tàu',
        ),
        findsNothing,
      );
      expect(find.text('Xem tất cả'), findsNothing);

      final arrowToggle = find.byTooltip('Xem tất cả');
      expect(arrowToggle, findsOneWidget);
      expect(
        find.descendant(
          of: arrowToggle,
          matching: find.byIcon(LucideIcons.arrowRight),
        ),
        findsOneWidget,
      );

      final toggleSize = tester.getSize(arrowToggle);
      expect(toggleSize.width, greaterThanOrEqualTo(44));
      expect(toggleSize.height, greaterThanOrEqualTo(44));

      await tester.ensureVisible(arrowToggle);
      await tester.tap(arrowToggle);
      await tester.pumpAndSettle();

      expect(find.text('Danh sách chỗ nghỉ đã duyệt'), findsOneWidget);
      expect(find.byTooltip('Thu gọn'), findsOneWidget);
    });

    testWidgets(
        'Search popover modal covers shell bottom navigation bar, renders curated area cards, advances tabs, and resets cleanly',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var submittedCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: const SizedBox(
                key: Key('shell_bottom_nav'),
                height: 68,
                child: Center(child: Text('Khám phá')),
              ),
              body: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Center(
                      child: SourceSearchBar(
                        onSearchSubmitted: () {
                          submittedCount += 1;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khám phá').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Bạn muốn đi đâu?'));
      await tester.pumpAndSettle();

      // Modal opens on the root navigator, covering the shell's bottom bar
      expect(find.text('Khám phá').hitTestable(), findsNothing);
      final submitRect =
          tester.getRect(find.byKey(const Key('search_sheet_submit_btn')));
      expect(submitRect.bottom, greaterThan(844 - 68));
      expect(submitRect.height, greaterThanOrEqualTo(48));

      // Quick actions & curated Vung Tau destination cards with street hints
      expect(find.text('Gần tôi (800m)'), findsOneWidget);
      expect(find.text('Chọn trên bản đồ'), findsOneWidget);
      expect(find.text('Khu vực nổi bật'), findsOneWidget);
      expect(find.text('Bãi Sau'), findsOneWidget);
      expect(find.text('Thùy Vân · Phan Chu Trinh'), findsOneWidget);
      expect(find.text('Bãi Trước'), findsOneWidget);
      expect(find.text('Trần Phú · Quang Trung'), findsOneWidget);

      // Selecting an area card auto-advances to Thời gian and shows live summary chip
      await tester.tap(find.text('Bãi Sau'));
      await tester.pumpAndSettle();

      expect(find.text('Ngày'), findsOneWidget);
      expect(find.text('Tháng'), findsOneWidget);
      expect(find.text('Bãi Sau').hitTestable(), findsOneWidget);

      // Switch to Khách tab and increment adults
      await tester.tap(find.text('Khách').last);
      await tester.pumpAndSettle();

      expect(find.text('Số lượng khách lưu trú'), findsOneWidget);
      expect(find.text('Người lớn'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tăng Người lớn'));
      await tester.pumpAndSettle();

      expect(find.text('1 khách').hitTestable(), findsOneWidget);

      // Clear all resets active summary chips
      await tester.tap(find.text('Xóa tất cả'));
      await tester.pumpAndSettle();

      expect(find.text('1 khách'), findsNothing);
      expect(find.text('Bãi Sau'), findsNothing);

      // Submit closes sheet and fires callback
      await tester.tap(find.byKey(const Key('search_sheet_submit_btn')));
      await tester.pumpAndSettle();

      expect(submittedCount, 1);
      expect(find.text('Khám phá').hitTestable(), findsOneWidget);
    });

    testWidgets(
        'Search popover modal renders zero overflow across 320–768dp and textScale 1.0–1.6 across all 3 tabs',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final widths = <double>[320, 360, 390, 430, 768];
      final scales = <double>[1.0, 1.3, 1.6];

      for (final width in widths) {
        for (final scale in scales) {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details.exceptionAsString());
          };

          try {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Center(
                      child: SourceSearchBar(
                        isCompact: width < 640,
                        onSearchSubmitted: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            await tester.tap(find.text('Bạn muốn đi đâu?'));
            await tester.pumpAndSettle();

            final dateTab = find.text('Thời gian').last;
            await tester.ensureVisible(dateTab);
            await tester.tap(dateTab);
            await tester.pumpAndSettle();

            final guestTab = find.text('Khách').last;
            await tester.ensureVisible(guestTab);
            await tester.tap(guestTab);
            await tester.pumpAndSettle();

            await tester.tap(find.byIcon(LucideIcons.x));
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = prevOnError;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Expected zero layout errors in SearchPopoverSheet at ${width}dp / textScale $scale, got: ${errors.join("; ")}',
          );
        }
      }
    });

    testWidgets(
        'Search popover supports live street filtering, multi-night date selection, quick presets, and single-chip clear without wiping other filters',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SourceSearchBar(
                  onSearchSubmitted: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bạn muốn đi đâu?'));
      await tester.pumpAndSettle();

      // 1. Live accent-insensitive street filtering surfaces matching street on Bãi Sau
      await tester.enterText(find.byType(TextField), 'ho quy ly');
      await tester.pumpAndSettle();
      expect(find.text('1 khu vực'), findsOneWidget);
      expect(find.text('Bãi Sau'), findsOneWidget);
      expect(find.text('Hồ Quý Ly · Thùy Vân'), findsOneWidget);
      expect(find.text('Bãi Trước'), findsNothing);

      // Selecting Bãi Sau clears custom text and advances to Thời gian
      await tester.tap(find.text('Bãi Sau'));
      await tester.pumpAndSettle();
      expect(find.text('Thời gian lưu trú'), findsOneWidget);

      // 2. Multi-night range selection on calendar (next month so days 10 & 13 are always in the future)
      final nextMonthBtn = find.bySemanticsLabel('Tháng sau');
      if (nextMonthBtn.evaluate().isNotEmpty) {
        await tester.tap(nextMonthBtn);
      } else {
        await tester.tap(find.bySemanticsLabel('Tháng tiếp theo'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ngày trả phòng'), findsOneWidget);

      await tester.tap(find.text('13'));
      await tester.pumpAndSettle();
      expect(find.text('3 đêm'), findsOneWidget);

      // 3. Quick group preset on Khách tab
      await tester.tap(find.text('Khách').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 khách'));
      await tester.pumpAndSettle();

      // 4. Clearing location chip alone keeps guest count and dates intact
      await tester.tap(find.byTooltip('Bỏ chọn địa điểm'));
      await tester.pumpAndSettle();
      expect(find.text('Bãi Sau'), findsNothing);
      expect(find.byTooltip('Bỏ chọn khách'), findsOneWidget);
      expect(find.byTooltip('Bỏ chọn ngày'), findsOneWidget);
    });
  });
}
