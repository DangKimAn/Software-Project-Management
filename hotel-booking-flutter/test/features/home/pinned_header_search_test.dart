import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:hotel_booking_flutter/shared/widgets/app_header.dart';
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
  _FakeRecentlyViewedNotifier([super.initial = const []]);

  @override
  Future<void> clear() async {
    state = const [];
  }

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

    testWidgets(
        'Recently Viewed section renders horizontal cards like Popular Destinations, keeps Xóa lịch sử on the same row across viewports/scales, and clears on tap',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const sampleRecent = <RecentlyViewedItem>[
        RecentlyViewedItem(
          id: '101',
          title: 'Seaside Sunset Homestay Vũng Tàu',
          imageUrl: '',
          location: '84 Hạ Long, Phường 2, Thành phố Vũng Tàu',
          pricePerNight: 1200000,
          rating: 5.0,
        ),
        RecentlyViewedItem(
          id: '102',
          title: 'Ocean Pearl Garden Villa',
          imageUrl: '',
          location: '15 Quang Trung, Phường 1, Thành phố Vũng Tàu',
          pricePerNight: 3500000,
          rating: 4.0,
        ),
        RecentlyViewedItem(
          id: '103',
          title: 'White Sand Pool Villa Bãi Sau',
          imageUrl: '',
          location: '28 Thi Sách, Vũng Tàu',
          pricePerNight: 4800000,
          rating: 4.9,
        ),
      ];

      // 1. Verify zero overflow & single-row header alignment across 320–1200dp and textScale 1.0–1.6
      for (final width in <double>[320, 360, 390, 430, 768, 1200]) {
        for (final scale in <double>[1.0, 1.3, 1.6]) {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details.exceptionAsString());
          };

          try {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [
                  authNotifierProvider
                      .overrideWith((ref) => _FakeAuthNotifier()),
                  notificationsProvider
                      .overrideWith((ref) => _FakeNotificationsNotifier()),
                  activePendingBookingProvider.overrideWithValue(null),
                  popularDestinationsProvider
                      .overrideWith((ref) async => <Villa>[]),
                  blogHighlightsProvider
                      .overrideWith((ref) async => <BlogPost>[]),
                  recentlyViewedProvider.overrideWith(
                    (ref) => _FakeRecentlyViewedNotifier(sampleRecent),
                  ),
                ],
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: const HomeScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final titleRect = tester.getRect(find.text('Đã xem gần đây'));
            final clearBtnRect = tester.getRect(
              find.byKey(const ValueKey<String>('clear-recently-viewed-btn')),
            );

            // Clear button MUST sit to the right of the title on the same row (never wrapped onto a new line below)
            expect(
              clearBtnRect.left >= titleRect.right ||
                  clearBtnRect.center.dx > titleRect.center.dx,
              isTrue,
              reason:
                  'Clear button should sit to the right of title at ${width}dp / scale $scale',
            );
            expect(
              clearBtnRect.top < titleRect.bottom,
              isTrue,
              reason:
                  'Clear button must stay on the same row (not wrap below title) at ${width}dp / scale $scale',
            );
          } finally {
            FlutterError.onError = prevOnError;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Expected zero layout errors in Recently Viewed at ${width}dp / scale $scale, got: ${errors.join("; ")}',
          );
        }
      }

      // 2. Verify horizontal card layout, `<` / `>` carousel buttons, and tapping clear button
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      final recentNotifier = _FakeRecentlyViewedNotifier(sampleRecent);

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
            notificationsProvider
                .overrideWith((ref) => _FakeNotificationsNotifier()),
            activePendingBookingProvider.overrideWithValue(null),
            popularDestinationsProvider.overrideWith((ref) async => <Villa>[]),
            blogHighlightsProvider.overrideWith((ref) async => <BlogPost>[]),
            recentlyViewedProvider.overrideWith((ref) => recentNotifier),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final horizontalScroll = find.byKey(
        const ValueKey<String>('recently-viewed-horizontal-scroll'),
      );
      expect(horizontalScroll, findsOneWidget);
      final scrollWidget =
          tester.widget<SingleChildScrollView>(horizontalScroll);
      expect(scrollWidget.scrollDirection, Axis.horizontal);

      // First two cards sit side-by-side horizontally (same top Y, card1 left < card2 left)
      final card1Pos =
          tester.getTopLeft(find.text('Seaside Sunset Homestay Vũng Tàu'));
      final card2Pos = tester.getTopLeft(find.text('Ocean Pearl Garden Villa'));
      expect((card1Pos.dy - card2Pos.dy).abs(), lessThan(2.0));
      expect(card1Pos.dx, lessThan(card2Pos.dx));

      // Carousel nav buttons are rendered when > 2 items
      expect(find.byTooltip('Căn đã xem trước'), findsOneWidget);
      expect(find.byTooltip('Căn đã xem tiếp theo'), findsOneWidget);

      // Tap clear button and verify section disappears
      final clearBtn = find.byKey(
        const ValueKey<String>('clear-recently-viewed-btn'),
      );
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Đã xem gần đây'), findsNothing);
      expect(recentNotifier.state, isEmpty);
    });

    testWidgets(
        'Blog Highlights cards truncate long title and excerpt with ellipsis (maxLines 2) without vertical clipping across viewports and textScale 1.0–2.0',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longPost = BlogPost(
        id: 'blog-vt-1',
        slug: 'kinh-nghiem-chon-thue-biet-thu-vung-tau',
        title:
            'Kinh nghiệm chọn thuê biệt thự nghỉ dưỡng Vũng Tàu cho gia đình đông người dịp cuối tuần',
        excerpt:
            'Những tiêu chí quan trọng khi đặt villa: hồ bơi riêng, tiện ích BBQ, vị trí sát biển và độ uy tín của chủ nhà để kỳ nghỉ trọn vẹn.',
        content: 'Nội dung chi tiết bài viết.',
        coverImage: '',
        category: 'Review Villa & Homestay',
        readTime: '7 phút đọc',
        location: 'Bãi Sau, Thành phố Vũng Tàu',
        authorName: 'Minh Thanh Villa',
        publishedAt: '2026-10-20',
      );

      for (final width in <double>[320, 360, 390, 430, 768, 1200]) {
        for (final scale in <double>[1.0, 1.3, 1.6, 2.0]) {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details.toString());
          };

          try {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [
                  authNotifierProvider
                      .overrideWith((ref) => _FakeAuthNotifier()),
                  notificationsProvider
                      .overrideWith((ref) => _FakeNotificationsNotifier()),
                  activePendingBookingProvider.overrideWithValue(null),
                  popularDestinationsProvider
                      .overrideWith((ref) async => <Villa>[]),
                  blogHighlightsProvider
                      .overrideWith((ref) async => const <BlogPost>[longPost]),
                  recentlyViewedProvider
                      .overrideWith((ref) => _FakeRecentlyViewedNotifier()),
                ],
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: const HomeScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final cardFinder = find.byKey(
              const ValueKey<String>(
                'home-blog-card-kinh-nghiem-chon-thue-biet-thu-vung-tau',
              ),
            );
            await tester.scrollUntilVisible(
              cardFinder,
              250,
              scrollable: find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();

            final titleFinder = find.descendant(
              of: cardFinder,
              matching: find.text(longPost.title),
            );
            final excerptFinder = find.descendant(
              of: cardFinder,
              matching: find.text(longPost.excerpt),
            );

            expect(titleFinder, findsOneWidget);
            expect(excerptFinder, findsOneWidget);

            final titleWidget = tester.widget<Text>(titleFinder);
            final excerptWidget = tester.widget<Text>(excerptFinder);
            expect(titleWidget.maxLines, 2);
            expect(titleWidget.overflow, TextOverflow.ellipsis);
            expect(excerptWidget.maxLines, 2);
            expect(excerptWidget.overflow, TextOverflow.ellipsis);

            // RenderParagraph height must NEVER be clamped smaller than laid-out textSize.height
            final titleRender = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: titleFinder,
                matching: find.byType(RichText),
              ),
            );
            final excerptRender = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: excerptFinder,
                matching: find.byType(RichText),
              ),
            );

            expect(
              titleRender.size.height + 0.5,
              greaterThanOrEqualTo(titleRender.textSize.height),
              reason:
                  'Blog title was vertically clipped at ${width}dp / scale $scale',
            );
            expect(
              excerptRender.size.height + 0.5,
              greaterThanOrEqualTo(excerptRender.textSize.height),
              reason:
                  'Blog excerpt was vertically clipped at ${width}dp / scale $scale',
            );
            expect(
              excerptRender.didExceedMaxLines,
              isTrue,
              reason:
                  'Long blog excerpt should truncate with ellipsis at 2 lines at ${width}dp / scale $scale',
            );
          } finally {
            FlutterError.onError = prevOnError;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Expected zero layout errors in HomeScreen Blog Highlights at ${width}dp / scale $scale, got: ${errors.join("; ")}',
          );
        }
      }
    });
  });
}
