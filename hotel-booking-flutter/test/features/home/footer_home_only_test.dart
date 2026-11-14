import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/blog/data/blog_repository.dart';
import 'package:hotel_booking_flutter/features/blog/presentation/screens/blog_detail_screen.dart';
import 'package:hotel_booking_flutter/features/blog/presentation/screens/blog_screen.dart';
import 'package:hotel_booking_flutter/features/support/presentation/screens/contact_screen.dart';
import 'package:hotel_booking_flutter/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:hotel_booking_flutter/features/home/presentation/screens/home_screen.dart';
import 'package:hotel_booking_flutter/features/support/presentation/widgets/support_page_shell.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/payment_result_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/screens/villa_detail_screen.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/screens/villa_list_screen.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_footer.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header.dart';

class _StubSecureStorage extends SecureStorageService {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<void> saveAuthToken(String value) async {}

  @override
  Future<void> deleteAuthToken() async {}
}

class _StubAuthNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthNotifier {
  _StubAuthNotifier()
      : super(
          const AsyncValue.data(
            User(
              id: 'guest-1',
              email: 'guest@thepalmvilla.vn',
              firstName: 'Minh',
              lastName: 'Thanh',
              role: 'guest',
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubNotificationsNotifier extends StateNotifier<NotificationsState>
    implements NotificationsNotifier {
  _StubNotificationsNotifier() : super(const NotificationsState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dio _buildNoOpDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': const <dynamic>[],
                'unreadCount': 0,
                'pagination': {
                  'page': 1,
                  'limit': 12,
                  'total': 0,
                  'totalPages': 1,
                },
              },
            },
          ),
        );
      },
    ),
  );
  return dio;
}

Directory _resolveProjectRoot() {
  if (Directory('lib').existsSync()) return Directory.current;
  final nested = Directory('hotel-booking-flutter');
  if (Directory('${nested.path}/lib').existsSync()) return nested;
  throw StateError('Cannot locate hotel-booking-flutter root');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
  });

  const sampleVilla = Villa(
    id: 'villa-1',
    code: 'MTV-01',
    name: 'The Palm Ocean Villa',
    tagline: 'Bãi Sau',
    address: '28 Thi Sách, Vũng Tàu',
    description: 'Biệt thự nghỉ dưỡng gần biển.',
    imageUrls: <String>[],
    specs: VillaSpecs(bedrooms: 4, beds: 5, maxGuests: 12, bathrooms: 4),
    basePriceVnd: 5500000,
  );

  const samplePost = BlogPost(
    id: '1',
    slug: 'cam-nang-vung-tau',
    title: 'Kinh nghiệm đặt villa Vũng Tàu',
    excerpt: 'Tóm tắt bài viết cẩm nang.',
    content: 'Nội dung chi tiết',
    coverImage: '',
    category: 'Cẩm nang du lịch',
    authorName: 'The Palm Team',
    publishedAt: '2026-10-15',
  );

  List<Override> baseOverrides() {
    final storage = _StubSecureStorage();
    final dio = _buildNoOpDio();
    return [
      secureStorageProvider.overrideWithValue(storage),
      dioClientProvider.overrideWithValue(
        DioClient(dio: dio, secureStorage: storage),
      ),
      authNotifierProvider.overrideWith((ref) => _StubAuthNotifier()),
      notificationsProvider.overrideWith((ref) => _StubNotificationsNotifier()),
      activePendingBookingProvider.overrideWithValue(null),
      popularDestinationsProvider
          .overrideWith((ref) async => const <Villa>[sampleVilla]),
      villaListProvider.overrideWith((ref) async => const <Villa>[sampleVilla]),
      villaPaginatedProvider.overrideWith(
        (ref) async => const PaginatedResult<Villa>(
          items: <Villa>[sampleVilla],
          pagination: PaginationMeta(
            page: 1,
            limit: 12,
            total: 1,
            totalPages: 1,
          ),
        ),
      ),
      villaDetailProvider.overrideWith(
        (ref, id) async => id == 'villa-1' ? sampleVilla : null,
      ),
      villaRecommendationsProvider
          .overrideWith((ref, id) async => const <Villa>[]),
      blogHighlightsProvider
          .overrideWith((ref) async => const <BlogPost>[samplePost]),
      blogListProvider
          .overrideWith((ref, _) async => const <BlogPost>[samplePost]),
      blogPaginatedProvider.overrideWith(
        (ref, _) async => const BlogPaginatedResult(
          items: <BlogPost>[samplePost],
          pagination: BlogPagination(
            page: 1,
            limit: 12,
            total: 1,
            totalPages: 1,
          ),
        ),
      ),
      blogDetailProvider.overrideWith(
        (ref, slug) async => slug == 'cam-nang-vung-tau' ? samplePost : null,
      ),
    ];
  }

  group('Footer Placement Rule — Home Page Only', () {
    testWidgets('HomeScreen renders AppFooter at the bottom of scroll view',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(AppFooter),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(AppFooter), findsOneWidget);
    });

    testWidgets('Component screens do not render AppFooter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final subScreens = <Widget>[
        const VillaListScreen(),
        const VillaDetailScreen(villaId: 'villa-1'),
        const BlogScreen(),
        const BlogDetailScreen(slug: 'cam-nang-vung-tau'),
        const ContactScreen(),
        const FavoritesScreen(),
        const PaymentResultScreen(status: 'failed'),
        SupportPageShell(
          currentPath: '/ve-chung-toi',
          eyebrow: 'Giới thiệu',
          title: 'Về The Palm Villa',
          subtitle: 'Thông tin hệ thống biệt thự nghỉ dưỡng.',
          body: const Text('Nội dung trang thành phần'),
          ctaTitle: 'Cần hỗ trợ?',
          ctaDescription: 'Liên hệ đội ngũ tư vấn.',
          primaryActionLabel: 'Trang chủ',
          onPrimaryAction: () {},
        ),
      ];

      for (final screen in subScreens) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: baseOverrides(),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -1500));
          await tester.pumpAndSettle();
        }

        expect(
          find.byType(AppFooter),
          findsNothing,
          reason: '${screen.runtimeType} must not render AppFooter',
        );
      }
    });

    test(
        'Static source scan ensures AppFooter widget is only instantiated in HomeScreen',
        () {
      // Giải thuật quét cây thư mục đệ quy kết hợp biểu thức chính quy phủ định tiền tố static:
      // Phát hiện mọi lời gọi khởi tạo widget `AppFooter(` trong `lib/features/` (loại trừ truy cập hằng số tĩnh `AppFooter.xxx`).
      final root = _resolveProjectRoot();
      final featuresDir = Directory('${root.path}/lib/features');
      final footerWidgetConstructor = RegExp(r'\bAppFooter\s*\(');
      const allowedPathSuffix =
          'lib/features/home/presentation/screens/home_screen.dart';

      final offenders = <String>[];
      for (final entity in featuresDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalizedPath = entity.path.replaceAll(r'\', '/');
        if (normalizedPath.endsWith(allowedPathSuffix)) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final trimmed = lines[i].trim();
          if (trimmed.startsWith('//')) continue;
          if (footerWidgetConstructor.hasMatch(trimmed)) {
            offenders.add('$normalizedPath:${i + 1} -> $trimmed');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'AppFooter widget must only be placed on HomeScreen, found in: $offenders',
      );
    });
  });
}
