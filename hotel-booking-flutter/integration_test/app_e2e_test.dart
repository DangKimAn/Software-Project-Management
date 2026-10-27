import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/config/app_config.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/home/presentation/screens/home_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/payment_result_screen.dart';
import 'package:hotel_booking_flutter/features/villas/data/repositories/villa_repository_impl.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime staging toggle (defaults to false so CI/local runs are 100% hermetic and safe).
/// When enabled (`--dart-define=E2E_USE_STAGING=true`), only read-only discovery and
/// non-mutating health checks are executed; real booking/payment mutations are strictly blocked.
const bool _kUseStagingBackend = bool.fromEnvironment(
  'E2E_USE_STAGING',
  defaultValue: false,
);

class _HermeticAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;
  _HermeticAdapter(this._handler);

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

class _InMemoryTestSecureStorage extends SecureStorageService {
  String? _token;

  @override
  Future<String?> getAuthToken() async => _token;

  @override
  Future<void> saveAuthToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteAuthToken() async {
    _token = null;
  }
}

ResponseBody _hermeticJson(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
    await initializeDateFormatting('vi', null);
  });

  group('Minh Thanh Villa Device/Emulator Integration E2E Suite', () {
    testWidgets(
      'E2E-01: Cold Start -> Home Discovery -> Availability & Nightly Pricing -> Anti-Fake-Payment Guard',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPrefs = await SharedPreferences.getInstance();
        final prefs = PreferencesService(sharedPrefs);
        final storage = _InMemoryTestSecureStorage();

        final client = _kUseStagingBackend
            ? DioClient(secureStorage: storage)
            : DioClient(
                secureStorage: storage,
                httpClientAdapter: _HermeticAdapter((options) async {
                  if (options.path.contains('/api/listings/101/pricing')) {
                    return _hermeticJson({
                      'success': true,
                      'data': {
                        'nightlyPrices': [
                          {
                            'date': '2026-12-18',
                            'price': 4500000,
                            'source': 'base',
                            'isWeekend': false,
                          },
                          {
                            'date': '2026-12-19',
                            'price': 5500000,
                            'source': 'weekend',
                            'isWeekend': true,
                          },
                        ],
                      },
                    });
                  }
                  if (options.path.contains('/api/listings')) {
                    return _hermeticJson({
                      'success': true,
                      'data': {
                        'items': [
                          {
                            'listingId': '101',
                            'id': '101',
                            'code': 'MTV-101',
                            'title': 'Minh Thành Ocean Pool Villa Bãi Sau',
                            'tagline': 'Cách biển Bãi Sau 150m',
                            'address': '28 Thi Sách, Vũng Tàu',
                            'locationGroup': 'bai_sau',
                            'propertyType': 'villa',
                            'description': 'Biệt thự nghỉ dưỡng cao cấp.',
                            'bedrooms': 5,
                            'beds': 7,
                            'maxGuests': 12,
                            'bathrooms': 5,
                            'pricePerNight': 4500000,
                            'weekendPrice': 5500000,
                            'avgRating': 4.95,
                            'reviewCount': 32,
                            'amenities': ['pool', 'bbq', 'wifi'],
                          },
                        ],
                        'pagination': {
                          'page': 1,
                          'limit': 12,
                          'total': 1,
                          'totalPages': 1,
                        },
                      },
                    });
                  }
                  if (options.path.contains('/api/payments/')) {
                    throw DioException(
                      requestOptions: options,
                      type: DioExceptionType.connectionTimeout,
                      message: 'Simulated callback verification timeout',
                    );
                  }
                  return _hermeticJson({
                    'success': true,
                    'data': <String, dynamic>{},
                  });
                }),
              );

        // Verify configuration safety: supported environments and normalized base URL
        expect(
          AppConfig.supportedEnvironments.contains(AppConfig.environment),
          isTrue,
        );
        expect(AppConfig.normalizeApiBaseUrl(AppConfig.apiBaseUrl), isNotEmpty);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(client),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        if (!_kUseStagingBackend) {
          expect(
            find.textContaining('Minh Thành Ocean Pool Villa Bãi Sau'),
            findsWidgets,
          );

          final repo = VillaRepositoryImpl(client);
          final nightly = await repo.getNightlyPrices(
            villaId: '101',
            checkIn: const BookingDate(year: 2026, month: 12, day: 18),
            checkOut: const BookingDate(year: 2026, month: 12, day: 20),
          );
          expect(nightly.length, 2);

          // Anti-Fake-Payment check on PaymentResultScreen
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const PaymentResultScreen(
                  bookingId: 'bk-e2e-1',
                  paymentId: 'pay-e2e-1',
                  status: 'paid',
                  method: 'vnpay',
                  amount: 10000000,
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.text('Thanh toán thành công!'), findsNothing);
          expect(find.text('Chưa xác nhận được giao dịch'), findsOneWidget);
        }

        expect(binding, isNotNull);
      },
    );
  });
}
