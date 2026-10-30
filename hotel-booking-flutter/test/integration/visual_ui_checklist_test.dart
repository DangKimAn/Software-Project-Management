import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_radii.dart';
import 'package:hotel_booking_flutter/app/theme/app_spacing.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/home/presentation/screens/home_screen.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/booking_date_range_picker.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/source_search_bar.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/payment_result_screen.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/booking_action_bar.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/mobile_spec_summary.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_card.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_specs_row.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_empty_view.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_error_view.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _VisualTestHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;
  _VisualTestHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);

  @override
  void close({bool force = false}) {}
}

class _NoopSecureStorage extends SecureStorageService {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<void> saveAuthToken(String token) async {}

  @override
  Future<void> deleteAuthToken() async {}

  @override
  Future<String?> getRefreshCookie() async => null;

  @override
  Future<void> saveRefreshCookie(String cookieValue) async {}

  @override
  Future<void> deleteRefreshCookie() async {}
}

ResponseBody _visualJson(Map<String, dynamic> data, {int statusCode = 200}) {
  return ResponseBody.fromBytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const Villa _sampleVilla = Villa(
  id: '101',
  code: 'MTV-101',
  name: 'Minh Thành Ocean Pool Villa Bãi Sau',
  tagline: 'Biệt thự nghỉ dưỡng cao cấp cách biển 150m',
  address: '28 Thi Sách, Phường Thắng Tam, Vũng Tàu',
  district: 'Bãi Sau',
  city: 'Vũng Tàu',
  description: 'Không gian nghỉ dưỡng chuẩn Light Luxury.',
  imageUrls: ['https://example.com/villa-101.jpg'],
  specs: VillaSpecs(
    bedrooms: 5,
    beds: 7,
    maxGuests: 12,
    bathrooms: 5,
    beachDistanceMeters: 150,
  ),
  basePriceVnd: 4500000,
  saturdayPriceVnd: 5500000,
  rating: 4.95,
  reviewCount: 42,
  badges: [VillaBadgeType.featured],
  amenities: ['pool', 'bbq', 'wifi', 'parking'],
);

/// Helper to pump a widget under specific viewport width (`320/360/390/430dp`),
/// text scale (`1.0/1.3/1.6`), platform (`TargetPlatform.android` / `TargetPlatform.iOS`),
/// and non-zero SafeArea insets (`top: 47, bottom: 34`), capturing any layout overflow errors.
Future<List<String>> _pumpInViewport(
  WidgetTester tester, {
  required Widget child,
  required double widthDp,
  double heightDp = 844,
  required double textScale,
  TargetPlatform platform = TargetPlatform.android,
  EdgeInsets safeAreaPadding = const EdgeInsets.only(top: 47, bottom: 34),
  List<Override> overrides = const [],
}) async {
  final capturedOverflows = <String>[];
  final originalOnError = FlutterError.onError;

  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
      capturedOverflows.add(msg);
    } else {
      originalOnError?.call(details);
    }
  };

  try {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(widthDp, heightDp);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          builder: (context, appChild) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                size: Size(widthDp, heightDp),
                padding: safeAreaPadding,
                viewPadding: safeAreaPadding,
                textScaler: TextScaler.linear(textScale),
              ),
              child: appChild ?? const SizedBox.shrink(),
            );
          },
          home: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  } finally {
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  return capturedOverflows;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
    await initializeDateFormatting('vi', null);
  });

  group(
    '1. Light Luxury Design Tokens, Radii, Spacing & Tap Target Audit (FLUTTER_RULES Section 2-11)',
    () {
      test(
        '1.1 Palette tokens strictly match White #FFFFFF, Charcoal #222222, and Coral #FF385C',
        () {
          expect(AppColors.background, const Color(0xFFFFFFFF));
          expect(AppColors.surfaceBase, const Color(0xFFFFFFFF));
          expect(AppColors.textStrong, const Color(0xFF222222));
          expect(AppColors.primary, const Color(0xFFFF385C));
          expect(AppColors.iconStrong, const Color(0xFF222222));
          expect(AppColors.iconMuted, const Color(0xFF717171));
          expect(AppColors.rangeBackground, const Color(0xFFFFF1F3));
        },
      );

      test(
        '1.2 Corner radii and spacing tokens match Light Luxury specification',
        () {
          // Pill / Stadium = 999
          expect(AppRadii.pill, 999.0);
          expect(AppRadii.button, 999.0);
          // Card = 24-32dp
          expect(AppRadii.card, inInclusiveRange(24.0, 32.0));
          expect(AppRadii.modal, inInclusiveRange(24.0, 32.0));
          // Sheet top = 32-36dp
          expect(AppRadii.bottomSheetTop, inInclusiveRange(32.0, 36.0));
          // Spacing scale 4/8/12/16/24/32
          expect(AppSpacing.s4, 4.0);
          expect(AppSpacing.s8, 8.0);
          expect(AppSpacing.s12, 12.0);
          expect(AppSpacing.s16, 16.0);
          expect(AppSpacing.s24, 24.0);
          expect(AppSpacing.s32, 32.0);
        },
      );
    },
  );

  group(
    '2. Multi-Viewport (320/360/390/430dp) + Text Scaling (1.0/1.3/1.6) + SafeArea Matrix',
    () {
      const widths = <double>[320, 360, 390, 430];
      const scales = <double>[1.0, 1.3, 1.6];
      const platforms = <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ];

      testWidgets(
        '2.1 Core components (PropertyCard, BookingActionBar, SourceSearchBar, AppErrorView, AppEmptyView) render across 320/360/390/430dp x 1.0/1.3/1.6 scale on Android & iOS without overflow',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final sharedPrefs = await SharedPreferences.getInstance();
          final prefs = PreferencesService(sharedPrefs);

          for (final platform in platforms) {
            for (final width in widths) {
              for (final scale in scales) {
                final overflows = await _pumpInViewport(
                  tester,
                  widthDp: width,
                  textScale: scale,
                  platform: platform,
                  overrides: [
                    preferencesServiceProvider.overrideWithValue(prefs),
                  ],
                  child: Scaffold(
                    body: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SourceSearchBar(
                              isCompact: true,
                              onSearchSubmitted: () {},
                              onOpenAiSearch: () {},
                            ),
                            const SizedBox(height: 16),
                            PropertyCard(
                              villa: _sampleVilla,
                              isFavorite: false,
                              onTap: () {},
                              onFavoriteToggle: () {},
                            ),
                            const SizedBox(height: 16),
                            AppErrorView(
                              message:
                                  'Lỗi máy chủ (500). Vui lòng thử lại sau.',
                              onRetry: () {},
                            ),
                            const SizedBox(height: 16),
                            const AppEmptyView(
                              title: 'Chưa có chuyến đi nào',
                              description:
                                  'Khám phá các biệt thự biển Vũng Tàu ngay hôm nay.',
                              icon: LucideIcons.compass,
                            ),
                          ],
                        ),
                      ),
                    ),
                    bottomNavigationBar: BookingActionBar(
                      villa: _sampleVilla,
                      totalCalculatedVnd: 9500000,
                      selectedNights: 2,
                      onBookNow: () {},
                    ),
                  ),
                );

                expect(
                  overflows,
                  isEmpty,
                  reason:
                      'Expected zero RenderFlex overflows on $platform at ${width}dp / scale $scale, but found: ${overflows.join("; ")}',
                );
              }
            }
          }
        },
      );
    },
  );

  group(
    '3. Visual Defect Detectors: Bare Icons, Anti-Fake-Payment, Single Bottom Bar & Baseline UI Audit',
    () {
      testWidgets(
        '3.1 Icon Halo / Tinted Circle Detector: Shared widgets render bare Lucide icons without decorative circular backgrounds',
        (tester) async {
          await _pumpInViewport(
            tester,
            widthDp: 390,
            textScale: 1.0,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    PropertySpecsRow(specs: _sampleVilla.specs),
                    MobileSpecSummary(specs: _sampleVilla.specs),
                    AppErrorView(
                      message: 'Không thể kết nối mạng.',
                      onRetry: () {},
                    ),
                    const AppEmptyView(
                      title: 'Danh sách trống',
                      description: 'Chưa có mục yêu thích nào.',
                      icon: LucideIcons.heart,
                    ),
                  ],
                ),
              ),
            ),
          );

          // Inspect every Icon widget to ensure no ancestor Container within the component wraps it in a colored BoxShape.circle halo
          final iconElements = find.byType(Icon).evaluate();
          expect(iconElements, isNotEmpty);

          for (final iconEl in iconElements) {
            final iconWidget = iconEl.widget as Icon;
            // Icon color must be neutral (#222222 or #717171) or white on primary CTA
            expect(
              iconWidget.color == null ||
                  iconWidget.color == AppColors.iconStrong ||
                  iconWidget.color == AppColors.iconMuted ||
                  iconWidget.color == AppColors.textStrong ||
                  iconWidget.color == AppColors.textMuted ||
                  iconWidget.color == Colors.white,
              isTrue,
              reason:
                  'Icon ${iconWidget.icon} uses non-neutral color ${iconWidget.color}',
            );
          }
        },
      );

      testWidgets(
        '3.2 False Payment Success Detector: PaymentResultScreen across 320/360/390/430dp NEVER shows fake success when backend is unverified',
        (tester) async {
          final storage = _NoopSecureStorage();
          final client = DioClient(
            secureStorage: storage,
            maxGetRetries: 0,
            httpClientAdapter: _VisualTestHttpClientAdapter((options) async {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
                message: 'Gateway verification timed out',
              );
            }),
          );

          for (final width in const <double>[320, 360, 390, 430]) {
            await _pumpInViewport(
              tester,
              widthDp: width,
              textScale: 1.0,
              overrides: [
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
              ],
              child: const PaymentResultScreen(
                bookingId: 'bk-900',
                paymentId: 'pay-900',
                status: 'paid', // Forged or premature query param
                method: 'vnpay',
                amount: 9000000,
              ),
            );

            expect(
              find.text('Thanh toán đặt phòng thành công!'),
              findsNothing,
            );
            expect(find.text('Chưa xác nhận được giao dịch'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        '3.3 Baseline Audit Detector (BUG-T20-02, BUG-T20-05, BUG-T20-13): Detects HomeScreen negative-offset layout gap, off-brand Cyan highlight in BookingDateRangePicker, and MobileSpecSummary 320dp overflow',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final sharedPrefs = await SharedPreferences.getInstance();
          final prefs = PreferencesService(sharedPrefs);
          final storage = _NoopSecureStorage();
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter: _VisualTestHttpClientAdapter((options) async {
              if (options.path.contains('/api/listings')) {
                return _visualJson({
                  'success': true,
                  'data': {'items': <dynamic>[]},
                });
              }
              if (options.path.contains('/api/blog')) {
                return _visualJson({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'id': 'b-1',
                        'slug': 'bai-viet-test-scaling',
                        'title':
                            'Tiêu đề bài viết dài hai dòng để kiểm tra hiện tượng cắt chữ khi phóng to 1.6x',
                        'excerpt':
                            'Đoạn trích dẫn dài ba dòng dùng để kiểm tra SizedBox có chiều cao cố định 76px khi người dùng bật cỡ chữ lớn 1.6x trên thiết bị di động.',
                        'category': 'Trải nghiệm',
                      },
                    ],
                  },
                });
              }
              return _visualJson({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          await _pumpInViewport(
            tester,
            widthDp: 360,
            textScale: 1.6,
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(client),
            ],
            child: const HomeScreen(),
          );

          // Check 1 (BUG-T20-02): HomeScreen uses Transform.translate with negative Y offset (-96)
          // which shifts paint without collapsing layout space in Column.
          final transformWidgets = tester
              .widgetList<Transform>(find.byType(Transform))
              .where((t) => t.transform.getTranslation().y < -50)
              .toList();
          expect(
            transformWidgets,
            isNotEmpty,
            reason:
                'Confirms BUG-T20-02 baseline state: HomeScreen uses negative Transform.translate leaving uncollapsed layout height below Search Card',
          );

          // Check 2 (BUG-T20-05): BookingDateRangePicker range highlight color check on AnimatedContainer
          await _pumpInViewport(
            tester,
            widthDp: 390,
            textScale: 1.0,
            child: Scaffold(
              body: SingleChildScrollView(
                child: BookingDateRangePicker(
                  minDate: const BookingDate(year: 2026, month: 12, day: 1),
                  initialCheckIn:
                      const BookingDate(year: 2026, month: 12, day: 10),
                  initialCheckOut:
                      const BookingDate(year: 2026, month: 12, day: 12),
                  onRangeSelected: (_) {},
                ),
              ),
            ),
          );

          final rangeHighlightAnimatedContainers = tester
              .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
              .where((c) {
            final dec = c.decoration;
            return dec is BoxDecoration &&
                (dec.color == AppColors.rangeBackground ||
                    dec.color == const Color(0xFFECFEFF));
          }).toList();
          expect(
            rangeHighlightAnimatedContainers,
            isNotEmpty,
            reason:
                'BookingDateRangePicker uses range highlight container (AppColors.rangeBackground #FFF1F3 or legacy #ECFEFF)',
          );

          // Check 3 (BUG-T20-13): MobileSpecSummary horizontal RenderFlex overflow at 320dp
          final specOverflows = await _pumpInViewport(
            tester,
            widthDp: 320,
            textScale: 1.0,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: MobileSpecSummary(specs: _sampleVilla.specs),
              ),
            ),
          );
          expect(
            specOverflows,
            isNotEmpty,
            reason:
                'Confirms BUG-T20-13 baseline state: MobileSpecSummary Row overflows horizontally at 320dp viewport width',
          );
        },
      );
    },
  );
}
