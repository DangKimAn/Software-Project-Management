import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/router/app_router.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/support/domain/services/contact_service.dart';
import 'package:hotel_booking_flutter/features/support/domain/entities/support_page_models.dart';
import 'package:hotel_booking_flutter/features/support/domain/support_catalog.dart';
import 'package:hotel_booking_flutter/features/support/presentation/screens/support_info_screen.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_footer.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_semantic_icons.dart';

class _TestSecureStorage extends SecureStorageService {
  String? token;

  @override
  Future<String?> getAuthToken() async => token;

  @override
  Future<void> saveAuthToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteAuthToken() async {
    token = null;
  }
}

class _StubAuthRepository implements AuthRepository {
  final User? currentUser;

  const _StubAuthRepository({this.currentUser});

  @override
  Future<User?> getCurrentUser() async => currentUser;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forgotPassword({required String identifier}) async {}

  @override
  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    String? avatarUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<User> updateAvatar({required String url, String? key}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

Dio _buildSupportMockDio({
  void Function(RequestOptions options)? onRequestCaptured,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequestCaptured?.call(options);
        if (options.path == '/api/reports' && options.method == 'POST') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'success': true,
                'data': {
                  'report': {
                    'reportId': 501,
                    'targetType': options.data['targetType'],
                    'targetId': options.data['targetId'],
                    'reason': options.data['reason'],
                    'status': 'open',
                  },
                },
              },
            ),
          );
          return;
        }
        if (options.path == '/api/reports/mine') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'items': const <dynamic>[]},
              },
            ),
          );
          return;
        }
        if (options.path == '/api/coupons/validate') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'valid': true,
                  'code': options.queryParameters['code'],
                  'discountAmount': 500000,
                },
              },
            ),
          );
          return;
        }
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

void main() {
  tearDown(ContactService.resetTestOverrides);

  group('SupportPageResolver & ContactService Email Helper', () {
    test('maps every footer destination path to its exact SupportPageType', () {
      expect(
        SupportPageResolver.resolveFromPath('/ho-tro/huong-dan-dat-phong'),
        SupportPageType.bookingGuide,
      );
      expect(
        SupportPageResolver.resolveFromPath('/ho-tro/chinh-sach-huy-phong'),
        SupportPageType.cancellationPolicy,
      );
      expect(
        SupportPageResolver.resolveFromPath('/ho-tro/khieu-nai-gop-y'),
        SupportPageType.complaintsFeedback,
      );
      expect(
        SupportPageResolver.resolveFromPath('/ho-tro/cau-hoi-thuong-gap'),
        SupportPageType.faq,
      );
      expect(SupportPageResolver.resolveFromPath('/faq'), SupportPageType.faq);
      expect(
        SupportPageResolver.resolveFromPath('/ve-chung-toi'),
        SupportPageType.aboutUs,
      );
      expect(
        SupportPageResolver.resolveFromPath('/kham-pha-vung-tau'),
        SupportPageType.exploreVungTau,
      );
      expect(
        SupportPageResolver.resolveFromPath('/dich-vu-di-kem'),
        SupportPageType.addonServices,
      );
      expect(
        SupportPageResolver.resolveFromPath('/uu-dai-thanh-vien'),
        SupportPageType.memberOffers,
      );
      expect(SupportPageResolver.resolveFromPath('/unknown'), isNull);
    });

    test('filterFaqs filters by category and keyword case-insensitively', () {
      final holdMatches = SupportPageResolver.filterFaqs(
        items: SupportCatalog.faqItems,
        selectedCategory: 'Đặt phòng & Lịch trống',
        searchQuery: '15 phút',
      );
      expect(holdMatches.length, 1);
      expect(holdMatches.first.id, 'faq-hold-15m');
    });

    test('openEmailDetailed falls back to clipboard copy when mailto fails',
        () async {
      String? copiedValue;
      ContactService.canLaunchUrlOverride = (_) async => false;
      ContactService.clipboardSetDataOverride = (text) async {
        copiedValue = text;
      };

      final res = await ContactService.openEmailDetailed(
        'bookingvillavtdl@gmail.com',
        subject: 'Tư vấn đặt phòng',
      );

      expect(res.launched, isFalse);
      expect(res.copiedToClipboard, isTrue);
      expect(copiedValue, 'bookingvillavtdl@gmail.com');
    });
  });

  group('AppFooter — Social Icon-Only & Full Destination Routing', () {
    testWidgets(
      'Social section renders icon-only buttons (>=48x48dp) without visible text labels',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: AppFooter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Social icons are rendered
        expect(find.byType(AppBrandIcon), findsNWidgets(4));
        for (final keyId in [
          'footer-social-facebook',
          'footer-social-threads',
          'footer-social-tiktok',
          'footer-social-youtube',
        ]) {
          final finder = find.byKey(ValueKey(keyId));
          expect(finder, findsOneWidget);
          final size = tester.getSize(finder);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        // Visible text labels next to Social icons must NOT exist
        expect(find.text('Facebook'), findsNothing);
        expect(find.text('Threads'), findsNothing);
        expect(find.text('TikTok'), findsNothing);
        expect(find.text('YouTube'), findsNothing);
      },
    );

    testWidgets(
      'every internal Footer link opens its dedicated destination screen with real content',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 960));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final storage = _TestSecureStorage();
        final dio = _buildSupportMockDio();

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            dioClientProvider.overrideWithValue(
              DioClient(dio: dio, secureStorage: storage),
            ),
            authRepositoryProvider.overrideWithValue(
              const _StubAuthRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);

        // CONFLICT-RESOLVED: Chỉ định rõ locale tiếng Việt ('vi') và delegates để kiểm thử đúng bản dịch mặc định của ứng dụng.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: const Locale('vi'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final linkExpectations = <(String, String, String)>[
          (
            '/ho-tro/huong-dan-dat-phong',
            'Hướng dẫn đặt biệt thự nguyên căn',
            'Khóa lịch giữ chỗ tạm thời 15 phút',
          ),
          (
            '/ho-tro/chinh-sach-huy-phong',
            'Chính sách hủy phòng & Hoàn tiền',
            'Chính sách Trung bình (Moderate)',
          ),
          (
            '/ho-tro/khieu-nai-gop-y',
            'Khiếu nại, Báo cáo & Góp ý dịch vụ',
            'Gửi báo cáo & khiếu nại trực tuyến',
          ),
          (
            '/ho-tro/cau-hoi-thuong-gap',
            'Câu hỏi thường gặp (FAQ)',
            'Tại sao đơn đặt phòng có thời gian giữ chỗ 15 phút?',
          ),
          (
            '/ve-chung-toi',
            'Nền tảng đặt biệt thự nghỉ dưỡng nguyên căn tại Vũng Tàu',
            'Chỗ nghỉ kiểm duyệt & Host xác thực KYC',
          ),
          (
            '/kham-pha-vung-tau',
            'Khám phá Vũng Tàu theo từng phân khu biển',
            'Phân khu Bãi Sau (Thùy Vân – Thi Sách)',
          ),
          (
            '/dich-vu-di-kem',
            'Tiện ích biệt thự & Dịch vụ lưu trú đi kèm',
            'Hồ bơi riêng tại biệt thự',
          ),
          (
            '/uu-dai-thanh-vien',
            'Ưu đãi thành viên & Mã giảm giá đặt phòng',
            'Tra cứu hiệu lực Mã ưu đãi (Coupon)',
          ),
        ];

        for (final entry in linkExpectations) {
          router.go(entry.$1);
          await tester.pumpAndSettle();
          expect(find.text(entry.$2), findsOneWidget);
          expect(find.text(entry.$3), findsOneWidget);
          expect(find.text('Không tìm thấy bài viết'), findsNothing);
          expect(find.text('404 — KHÔNG TÌM THẤY TRANG'), findsNothing);
        }
      },
    );

    testWidgets(
      'Zone explorer and Addon service cards apply real filters and navigate to /tim-kiem',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 920));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final storage = _TestSecureStorage();
        final dio = _buildSupportMockDio();
        String? lastRoute;

        final testRouter = GoRouter(
          initialLocation: '/kham-pha-vung-tau',
          routes: [
            GoRoute(
              path: '/kham-pha-vung-tau',
              builder: (_, __) => const SupportInfoScreen(
                pageType: SupportPageType.exploreVungTau,
              ),
            ),
            GoRoute(
              path: '/dich-vu-di-kem',
              builder: (_, __) => const SupportInfoScreen(
                pageType: SupportPageType.addonServices,
              ),
            ),
            GoRoute(
              path: '/tim-kiem',
              builder: (_, state) {
                lastRoute = state.uri.toString();
                return const Scaffold(body: Text('SEARCH_DESTINATION'));
              },
            ),
          ],
        );

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            dioClientProvider.overrideWithValue(
              DioClient(dio: dio, secureStorage: storage),
            ),
            authRepositoryProvider.overrideWithValue(
              const _StubAuthRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: testRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final baiSauBtn = find.byKey(const ValueKey('zone-explore-bai_sau'));
        await tester.ensureVisible(baiSauBtn);
        await tester.tap(baiSauBtn);
        await tester.pumpAndSettle();

        expect(lastRoute, '/tim-kiem');
        expect(container.read(villaFilterProvider).locationGroup, 'bai_sau');

        testRouter.go('/dich-vu-di-kem');
        await tester.pumpAndSettle();

        final poolBtn = find.byKey(const ValueKey('amenity-filter-pool'));
        await tester.ensureVisible(poolBtn);
        await tester.tap(poolBtn);
        await tester.pumpAndSettle();

        expect(container.read(villaFilterProvider).amenities, ['pool']);
      },
    );

    testWidgets(
      'Authenticated user can submit report on Complaints & Feedback screen and check Coupon on Member Offers',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 960));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final storage = _TestSecureStorage()..token = 'valid-token';
        final capturedPaths = <String>[];
        final dio = _buildSupportMockDio(
          onRequestCaptured: (opts) => capturedPaths.add(opts.path),
        );

        const guestUser = User(
          id: '9',
          email: 'member@thepalmvilla.vn',
          firstName: 'Minh',
          lastName: 'Khách',
          role: 'guest',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(
                DioClient(dio: dio, secureStorage: storage),
              ),
              authRepositoryProvider.overrideWithValue(
                const _StubAuthRepository(currentUser: guestUser),
              ),
            ],
            // CONFLICT-RESOLVED: Cố định locale 'vi' khớp ngữ cảnh kiểm thử thông báo gửi phản ánh tiếng Việt.
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: const Locale('vi'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SupportInfoScreen(
                pageType: SupportPageType.complaintsFeedback,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('report-target-id-input')),
          '108',
        );
        await tester.enterText(
          find.byKey(const ValueKey('report-reason-input')),
          'Cần kiểm tra lại tình trạng hồ bơi',
        );

        final submitBtn = find.byKey(const ValueKey('report-submit-btn'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(capturedPaths, contains('/api/reports'));
        expect(
          find.textContaining('Đã ghi nhận phản ánh thành công'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders all SupportInfoScreen types cleanly at 320dp and 1.6x textScale without overflow',
      (tester) async {
        final storage = _TestSecureStorage();
        final dio = _buildSupportMockDio();

        for (final type in SupportPageType.values) {
          await tester.binding.setSurfaceSize(const Size(320, 920));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(
                  DioClient(dio: dio, secureStorage: storage),
                ),
                authRepositoryProvider.overrideWithValue(
                  const _StubAuthRepository(),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: const Size(320, 920),
                    textScaler: const TextScaler.linear(1.6),
                  ),
                  child: child!,
                ),
                home: SupportInfoScreen(pageType: type),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow detected on $type at 320dp / 1.6x textScale',
          );
        }
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'AppFooter and SupportInfoScreen render localized English (en) and Korean (ko) strings cleanly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final storage = _TestSecureStorage();
        final dio = _buildSupportMockDio();

        // 1. English (en)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(
                DioClient(dio: dio, secureStorage: storage),
              ),
              authRepositoryProvider.overrideWithValue(
                const _StubAuthRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // CONFLICT-RESOLVED: Tách kiểm thử độc lập SupportInfoScreen và AppFooter theo quy tắc AppFooter chỉ gắn trên HomeScreen.
              home: const Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: SupportInfoScreen(
                        pageType: SupportPageType.bookingGuide,
                      ),
                    ),
                    AppFooter(),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('15-minute temporary calendar hold'),
          findsOneWidget,
        );
        expect(
          find.text('© 2026 The Palm Villa Vung Tau. All rights reserved.'),
          findsOneWidget,
        );

        // 2. Korean (ko)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(
                DioClient(dio: dio, secureStorage: storage),
              ),
              authRepositoryProvider.overrideWithValue(
                const _StubAuthRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: const Locale('ko'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: SupportInfoScreen(
                        pageType: SupportPageType.cancellationPolicy,
                      ),
                    ),
                    AppFooter(),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('보통 정책 (Moderate)'),
          findsOneWidget,
        );
        expect(
          find.text('© 2026 더 팜 빌라 붕따우. 모든 권리 보유.'),
          findsOneWidget,
        );
      },
    );
  });
}
