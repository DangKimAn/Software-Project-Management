import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/network/socket_service.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/favorites/data/repositories/wishlist_repository_impl.dart';
import 'package:hotel_booking_flutter/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:hotel_booking_flutter/features/home/presentation/screens/home_screen.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hotel_booking_flutter/features/search/presentation/screens/ai_search_screen.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/booking_date_range_picker.dart';
import 'package:hotel_booking_flutter/features/trips/data/repositories/booking_repository_impl.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/payment_result_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/trips_screen.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/screens/villa_detail_screen.dart';
import 'package:hotel_booking_flutter/features/villas/data/repositories/villa_repository_impl.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/screens/villa_list_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [SecureStorageService] fake for hermetic QA E2E testing.
/// Never stores real secrets or touches platform keychains.
class _InMemorySecureStorage extends SecureStorageService {
  String? _authToken;
  String? _refreshCookie;
  String? _refreshToken;

  _InMemorySecureStorage({
    String? initialAuthToken,
    String? initialRefreshCookie,
  })  : _authToken = initialAuthToken,
        _refreshCookie = initialRefreshCookie;

  @override
  Future<void> saveAuthToken(String token) async {
    _authToken = token;
  }

  @override
  Future<String?> getAuthToken() async => _authToken;

  @override
  Future<void> deleteAuthToken() async {
    _authToken = null;
  }

  @override
  Future<void> saveRefreshCookie(String cookieValue) async {
    _refreshCookie = cookieValue.trim().isEmpty ? null : cookieValue.trim();
  }

  @override
  Future<String?> getRefreshCookie() async => _refreshCookie;

  @override
  Future<void> deleteRefreshCookie() async {
    _refreshCookie = null;
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    _refreshToken = refreshToken.trim().isEmpty ? null : refreshToken.trim();
  }

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> deleteRefreshToken() async {
    _refreshToken = null;
  }
}

/// No-op [SocketService] for hermetic widget/E2E tests so Socket.IO never opens
/// real OS network sockets while still supporting lifecycle connect/disconnect calls.
class _NoopSocketService extends SocketService {
  _NoopSocketService({super.secureStorage})
      : super(
          channelFactory: (uri) => throw StateError('No live socket in tests'),
        );

  @override
  Future<void> connect({bool isAutoReconnect = false}) async {}

  @override
  void disconnect() {}
}

/// Deterministic HTTP adapter for E2E & resilience verification.
class _FakeBackendHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(
    RequestOptions options,
    Map<String, dynamic> bodyJson,
  ) _handler;

  _FakeBackendHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var bodyMap = <String, dynamic>{};
    if (options.data is Map<String, dynamic>) {
      bodyMap = options.data as Map<String, dynamic>;
    } else if (options.data is Map) {
      bodyMap = Map<String, dynamic>.from(options.data as Map);
    } else if (options.data is String && (options.data as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(options.data as String);
        if (decoded is Map) {
          bodyMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return _handler(options, bodyMap);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
  Map<String, List<String>>? extraHeaders,
}) {
  return ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?extraHeaders,
    },
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 6}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _sampleListingJson({
  String id = '101',
  String code = 'MTV-101',
  String title = 'Minh Thành Ocean Pool Villa Bãi Sau',
  int pricePerNight = 4500000,
  int weekendPrice = 5500000,
  String locationGroup = 'bai_sau',
}) {
  return <String, dynamic>{
    'listingId': id,
    'id': id,
    'code': code,
    'title': title,
    'tagline': 'Biệt thự nghỉ dưỡng cao cấp cách biển Bãi Sau 150m',
    'address': '28 Thi Sách, Phường Thắng Tam, Vũng Tàu',
    'ward': 'Phường Thắng Tam',
    'district': 'Bãi Sau',
    'city': 'Vũng Tàu',
    'locationGroup': locationGroup,
    'latitude': 10.3412,
    'longitude': 107.0921,
    'propertyType': 'villa',
    'description':
        'Biệt thự hồ bơi riêng chuẩn Light Luxury, 5 phòng ngủ, sân BBQ rộng.',
    'images': [
      {
        'imageId': 'img-1',
        'url': 'https://example.com/villa-101-cover.jpg',
        'type': 'pool',
        'isCover': true,
      },
    ],
    'bedrooms': 5,
    'beds': 7,
    'maxGuests': 12,
    'bathrooms': 5,
    'beachDistanceMeters': 150,
    'pricePerNight': pricePerNight,
    'weekendPrice': weekendPrice,
    'cleaningFee': 300000,
    'serviceFee': 200000,
    'extraGuestFee': 250000,
    'includedGuests': 10,
    'minNights': 1,
    'maxNights': 14,
    'instantBook': true,
    'cancellationPolicy': 'moderate',
    'status': 'approved',
    'avgRating': 4.92,
    'reviewCount': 38,
    'amenities': ['pool', 'bbq', 'wifi', 'parking', 'near_beach'],
    'host': {
      'userId': 'host-7',
      'fullName': 'Minh Thành Host',
      'isVerified': true,
    },
  };
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
    await initializeDateFormatting('vi', null);
  });

  group(
    'FLOW 1: Cold Start -> Home -> Search (Regular & AI Semantic) -> List -> Detail',
    () {
      testWidgets(
        '1.1 Cold start renders HomeScreen, loads featured villas & blog posts, and records recently viewed on detail visit',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final sharedPrefs = await SharedPreferences.getInstance();
          final prefs = PreferencesService(sharedPrefs);
          final storage = _InMemorySecureStorage();

          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              final path = options.path;
              if (path.contains('/api/auth/me')) {
                return _jsonResponse(
                  {'success': false, 'message': 'Unauthenticated'},
                  statusCode: 401,
                );
              }
              if (path.contains('/api/listings/101/availability')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'days': [
                      {
                        'date': '2026-12-12',
                        'isAvailable': false,
                        'price': 5500000,
                      },
                    ],
                  },
                });
              }
              if (path.contains('/api/listings/101/rules')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'checkInFrom': '14:00',
                    'checkOutBefore': '12:00',
                    'allowPets': false,
                  },
                });
              }
              if (path.contains('/api/listings/101/recommendations')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': <dynamic>[],
                  },
                });
              }
              if (path.contains('/api/listings/101')) {
                return _jsonResponse({
                  'success': true,
                  'data': _sampleListingJson(id: '101'),
                });
              }
              if (path.contains('/api/listings')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      _sampleListingJson(id: '101'),
                      _sampleListingJson(
                        id: '102',
                        code: 'MTV-102',
                        title: 'Minh Thành Sunset Villa Bãi Trước',
                        locationGroup: 'bai_truoc',
                      ),
                    ],
                    'pagination': {
                      'page': 1,
                      'limit': 12,
                      'total': 2,
                      'totalPages': 1,
                    },
                  },
                });
              }
              if (path.contains('/api/blog')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'id': 'blog-1',
                        'slug': 'cam-nang-nghi-duong-vung-tau',
                        'title': 'Cẩm nang nghỉ dưỡng Vũng Tàu cuối tuần',
                        'excerpt':
                            'Khám phá các biệt thự biển Bãi Sau cho gia đình.',
                        'category': 'Cẩm nang du lịch',
                        'publishedAt': '2026-10-01T00:00:00.000Z',
                      },
                    ],
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final fakeSocket = _NoopSocketService(secureStorage: storage);
          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
                socketServiceProvider.overrideWithValue(fakeSocket),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const HomeScreen(),
              ),
            ),
          );

          await _pumpFrames(tester);

          // Verify HomeScreen loaded featured listings from API
          expect(
            find.textContaining('Minh Thành Ocean Pool Villa Bãi Sau'),
            findsWidgets,
          );

          // Verify VillaListScreen renders list items
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
                socketServiceProvider.overrideWithValue(fakeSocket),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const VillaListScreen(),
              ),
            ),
          );
          await _pumpFrames(tester);
          expect(
            find.textContaining('Minh Thành Ocean Pool Villa Bãi Sau'),
            findsWidgets,
          );

          // Verify VillaDetailScreen & RecentlyViewed recording
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
                socketServiceProvider.overrideWithValue(fakeSocket),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const VillaDetailScreen(villaId: '101'),
              ),
            ),
          );
          await _pumpFrames(tester);

          final container = ProviderScope.containerOf(
            tester.element(find.byType(VillaDetailScreen)),
          );
          final detailVilla =
              container.read(villaDetailProvider('101')).valueOrNull;
          expect(detailVilla, isNotNull);
          expect(detailVilla!.id, '101');
          expect(detailVilla.bookedDatesIso, contains('2026-12-12'));

          await container
              .read(recentlyViewedProvider.notifier)
              .recordVilla(detailVilla);
          expect(container.read(recentlyViewedProvider).first.id, '101');
        },
      );

      testWidgets(
        '1.2 Regular search filter & AI Semantic search (/tim-kiem-ai) return normalized results and handle rejected queries',
        (tester) async {
          Map<String, dynamic>? capturedSemanticBody;
          Map<String, dynamic>? capturedListQuery;

          final storage = _InMemorySecureStorage();
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/search/semantic')) {
                capturedSemanticBody = body;
                final queryText = (body['query'] ?? '').toString();
                if (queryText.contains('vé máy bay')) {
                  return _jsonResponse({
                    'success': true,
                    'data': {
                      'query': queryText,
                      'mode': 'rejected',
                      'reason': 'out_of_domain',
                      'message':
                          'Hệ thống chỉ hỗ trợ tìm kiếm biệt thự và chỗ nghỉ tại Vũng Tàu.',
                      'items': <dynamic>[],
                    },
                  });
                }
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'query': queryText,
                    'mode': 'semantic',
                    'detectedRoomType': 'pool',
                    'dateIntent': {
                      'label': 'Cuối tuần này',
                      'checkIn': '2026-12-18',
                      'checkOut': '2026-12-20',
                      'isAutoFilled': true,
                    },
                    'items': [
                      {
                        ..._sampleListingJson(id: '101'),
                        'similarityScore': 0.94,
                        'matchedRoomType': 'pool',
                        'matchedReasons': ['Có hồ bơi riêng', 'Gần Bãi Sau'],
                      },
                    ],
                  },
                });
              }
              if (options.path.contains('/api/listings')) {
                capturedListQuery = options.queryParameters;
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [_sampleListingJson(id: '101')],
                    'pagination': {
                      'page': 1,
                      'limit': 12,
                      'total': 1,
                      'totalPages': 1,
                    },
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final repo = VillaRepositoryImpl(client);

          await tester.runAsync(() async {
            // 1. Regular search with Vietnamese amenity labels & locationGroup
            final listResult = await repo.getVillasPaginated(
              searchQuery: 'Bãi Sau',
              locationGroup: 'Bãi Sau',
              amenities: const ['Hồ bơi riêng', 'bbq'],
              minGuests: 8,
              checkIn: const BookingDate(year: 2026, month: 12, day: 18),
              checkOut: const BookingDate(year: 2026, month: 12, day: 20),
            );
            expect(listResult.items.length, 1);
            expect(capturedListQuery?['locationGroup'], 'Bãi Sau');
            expect(capturedListQuery?['amenities'], 'pool,bbq');
            expect(capturedListQuery?['checkIn'], '2026-12-18');
            expect(capturedListQuery?['checkOut'], '2026-12-20');

            // 2. AI Semantic Search screen UI & repository verification
            final semanticResp = await repo.semanticSearch(
              query: 'villa gần biển Bãi Sau có hồ bơi riêng cho 10 người',
            );
            expect(
              capturedSemanticBody?['query'],
              'villa gần biển Bãi Sau có hồ bơi riêng cho 10 người',
            );
            expect(semanticResp.isRejected, isFalse);
            expect(semanticResp.items.first.id, '101');
            expect(semanticResp.dateIntent?.checkIn, '2026-12-18');

            // 3. Rejected out-of-domain AI query
            final rejectedResp =
                await repo.semanticSearch(query: 'đặt vé máy bay đi Hà Nội');
            expect(rejectedResp.isRejected, isTrue);
          });

          // Render AiSearchScreen widget
          final prefs = PreferencesService.inMemory();
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const AiSearchScreen(
                  initialQuery:
                      'villa gần biển Bãi Sau có hồ bơi riêng cho 10 người',
                ),
              ),
            ),
          );
          await _pumpFrames(tester);
          expect(
            find.textContaining('Minh Thành Ocean Pool Villa Bãi Sau'),
            findsWidgets,
          );
        },
      );
    },
  );

  group(
    'FLOW 2: Availability Calendar -> Date/Guest -> Pricing/Coupon -> Booking -> Pending Payment -> Paid/Unverified',
    () {
      testWidgets(
        '2.1 BookingDateRangePicker enforces half-open [checkIn, checkOut) availability rules',
        (tester) async {
          BookingDate? selectedCheckIn;
          BookingDate? selectedCheckOut;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: BookingDateRangePicker(
                    minDate: const BookingDate(year: 2026, month: 12, day: 1),
                    bookedDatesIso: const {'2026-12-12'},
                    initialCheckIn:
                        const BookingDate(year: 2026, month: 12, day: 10),
                    onRangeSelected: (range) {
                      selectedCheckIn = range.$1;
                      selectedCheckOut = range.$2;
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Selecting 2026-12-12 as check-out when check-in is 2026-12-10 MUST be allowed
          // because [2026-12-10, 2026-12-12) only occupies nights of Dec 10 and Dec 11.
          await tester.tap(find.text('12').first);
          await tester.pump();

          expect(
            selectedCheckIn,
            const BookingDate(year: 2026, month: 12, day: 10),
          );
          expect(
            selectedCheckOut,
            const BookingDate(year: 2026, month: 12, day: 12),
          );
        },
      );

      testWidgets(
        '2.2 Full Booking -> Coupon Validation -> PaymentResultScreen (Anti-Fake-Payment unverified & confirmed paid)',
        (tester) async {
          var paymentBackendMode = 'network_drop'; // 'network_drop' | 'paid'
          Uri? launchedGatewayUri;

          final storage = _InMemorySecureStorage(
            initialAuthToken: 'test-jwt-token',
          );
          final client = DioClient(
            secureStorage: storage,
            maxGetRetries: 0,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              final path = options.path;
              if (path.contains('/api/listings/101/availability')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'days': [
                      {
                        'date': '2026-12-10',
                        'price': 4500000,
                        'isAvailable': true,
                      },
                      {
                        'date': '2026-12-11',
                        'price': 5500000,
                        'isAvailable': true,
                      },
                    ],
                  },
                });
              }
              if (path.contains('/api/coupons/validate')) {
                final code =
                    (options.queryParameters['code'] ?? body['code'] ?? '')
                        .toString()
                        .toUpperCase();
                if (code == 'SUMMER10') {
                  return _jsonResponse({
                    'success': true,
                    'data': {
                      'valid': true,
                      'code': 'SUMMER10',
                      'discountAmount': 500000,
                      'finalAmount': 10000000,
                    },
                  });
                }
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'valid': false,
                    'code': code,
                    'discountAmount': 999999,
                    'reason': 'Coupon expired',
                  },
                });
              }
              if (path == '/api/bookings' && options.method == 'POST') {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'bookingId': 'bk-201',
                    'listingId': '101',
                    'propertyName': 'Minh Thành Ocean Pool Villa Bãi Sau',
                    'checkInDate': '2026-12-10',
                    'checkOutDate': '2026-12-12',
                    'nights': 2,
                    'guestCount': 8,
                    'status': 'pending_payment',
                    'paymentStatus': 'unpaid',
                    'totalAmount': 10000000,
                    'subtotalAmount': 10000000,
                    'cleaningFeeAmount': 300000,
                    'serviceFeeAmount': 200000,
                    'discountAmount': 500000,
                    'remainingPaymentSeconds': 890,
                    'paymentExpiresAt': DateTime.now()
                        .toUtc()
                        .add(const Duration(minutes: 15))
                        .toIso8601String(),
                  },
                });
              }
              if (path.contains('/api/payments/methods')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'methods': [
                      {'method': 'vnpay', 'label': 'VNPay', 'available': true},
                      {
                        'method': 'momo',
                        'label': 'MoMo',
                        'available': false,
                        'unavailableReason': 'MoMo bảo trì',
                      },
                    ],
                  },
                });
              }
              if (path == '/api/payments' && options.method == 'POST') {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'paymentId': 'pay-301',
                    'bookingId': 'bk-201',
                    'method': 'vnpay',
                    'paymentStatus': 'pending',
                    'amount': 10000000,
                    'paymentUrl':
                        'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?txn=pay-301',
                  },
                });
              }
              if (path.contains('/api/payments/pay-301') ||
                  path.contains('/api/bookings/bk-201')) {
                if (paymentBackendMode == 'network_drop') {
                  throw DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    message: 'Connection reset by peer',
                  );
                }
                if (path.contains('/api/payments/pay-301')) {
                  return _jsonResponse({
                    'success': true,
                    'data': {
                      'paymentId': 'pay-301',
                      'bookingId': 'bk-201',
                      'method': 'vnpay',
                      'paymentStatus': 'paid',
                      'paymentResultStatus': 'paid',
                      'amount': 10000000,
                      'providerTransactionNo': 'VNP14567890',
                      'paidAt': '2026-10-27T10:00:00.000Z',
                    },
                  });
                }
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'bookingId': 'bk-201',
                    'listingId': '101',
                    'propertyName': 'Minh Thành Ocean Pool Villa Bãi Sau',
                    'checkInDate': '2026-12-10',
                    'checkOutDate': '2026-12-12',
                    'nights': 2,
                    'guestCount': 8,
                    'status': 'confirmed',
                    'paymentStatus': 'paid',
                    'totalAmount': 10000000,
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final villaRepo = VillaRepositoryImpl(client);
          final bookingRepo = BookingRepositoryImpl(client);

          await tester.runAsync(() async {
            // Step 1: Verify Nightly Pricing
            final prices = await villaRepo.getNightlyPrices(
              villaId: '101',
              checkIn: const BookingDate(year: 2026, month: 12, day: 10),
              checkOut: const BookingDate(year: 2026, month: 12, day: 12),
            );
            expect(prices.length, 2);
            expect(prices[0].priceVnd, 4500000);
            expect(prices[1].priceVnd, 5500000);

            // Step 2: Verify Coupon Validation (valid vs expired)
            final validCoupon = await bookingRepo.validateCoupon(
              code: 'SUMMER10',
              listingId: '101',
              subtotalAmount: 10000000,
            );
            expect(validCoupon.valid, isTrue);
            expect(validCoupon.discountAmount, 500000);

            final expiredCoupon = await bookingRepo.validateCoupon(
              code: 'EXPIRED',
              listingId: '101',
              subtotalAmount: 10000000,
            );
            expect(expiredCoupon.valid, isFalse);
            expect(expiredCoupon.discountAmount, 0);

            // Step 3: Create Booking -> Pending Payment
            final createdBooking = await bookingRepo.createBooking(
              listingId: '101',
              checkInDate: '2026-12-10',
              checkOutDate: '2026-12-12',
              guestsCount: 8,
              couponCode: 'SUMMER10',
            );
            expect(createdBooking.id, 'bk-201');
            expect(createdBooking.status, 'pending_payment');
            expect(
              createdBooking.computeRemainingPaymentSeconds(),
              greaterThan(800),
            );

            // Step 4: Initiate Payment Session
            final paymentSession = await bookingRepo.createPayment(
              bookingId: 'bk-201',
              method: 'vnpay',
            );
            expect(paymentSession.paymentId, 'pay-301');
            expect(paymentSession.paymentUrl, contains('sandbox.vnpayment.vn'));
            launchedGatewayUri = Uri.parse(paymentSession.paymentUrl!);
            expect(launchedGatewayUri?.host, 'sandbox.vnpayment.vn');
          });

          // Step 5A: PaymentResultScreen receives ?status=paid in redirect URL while network drops
          // MUST NOT display false payment success! MUST display 'Chưa xác nhận được giao dịch'.
          tester.view.physicalSize = const Size(1280, 1400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          paymentBackendMode = 'network_drop';
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const PaymentResultScreen(
                  bookingId: 'bk-201',
                  paymentId: 'pay-301',
                  status: 'paid',
                  method: 'vnpay',
                  amount: 10000000,
                ),
              ),
            ),
          );
          await _pumpFrames(tester);

          expect(
            find.text('Thanh toán đặt phòng thành công!'),
            findsNothing,
          );
          expect(find.text('Chưa xác nhận được giao dịch'), findsOneWidget);
          expect(find.text('Kiểm tra lại trạng thái'), findsOneWidget);

          // Step 5B: Network recovers & backend confirms paymentStatus == 'paid'
          paymentBackendMode = 'paid';
          await tester.tap(find.text('Kiểm tra lại trạng thái'));
          await _pumpFrames(tester);

          expect(
            find.text('Thanh toán đặt phòng thành công!'),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    },
  );

  group(
    'FLOW 3: Trips -> Favorites Guest/Login Merge -> Profile -> Messages',
    () {
      testWidgets(
        '3.1 TripsScreen renders active/completed/cancelled tabs and executes booking cancellation',
        (tester) async {
          String? cancelledBookingId;
          String? cancelledReason;

          final storage = _InMemorySecureStorage(initialAuthToken: 'jwt-1');
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/auth/me') ||
                  options.path.contains('/api/users/me')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'user-1',
                      'email': 'guest@minhthanhvilla.com',
                      'firstName': 'Minh',
                      'lastName': 'Nguyễn',
                      'role': 'guest',
                    },
                  },
                });
              }
              if (options.path.contains('/api/bookings/mine') ||
                  options.path.contains('/api/bookings/me')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'bookingId': 'bk-active-1',
                        'listingId': '101',
                        'propertyName': 'Minh Thành Ocean Pool Villa Bãi Sau',
                        'checkInDate': '2026-12-20',
                        'checkOutDate': '2026-12-22',
                        'nights': 2,
                        'guestCount': 6,
                        'status': 'confirmed',
                        'paymentStatus': 'paid',
                        'totalAmount': 9500000,
                      },
                      {
                        'bookingId': 'bk-completed-2',
                        'listingId': '102',
                        'propertyName': 'Minh Thành Sunset Villa Bãi Trước',
                        'checkInDate': '2026-08-10',
                        'checkOutDate': '2026-08-12',
                        'nights': 2,
                        'guestCount': 4,
                        'status': 'completed',
                        'paymentStatus': 'paid',
                        'totalAmount': 8000000,
                      },
                    ],
                  },
                });
              }
              if (options.path.contains('/api/bookings/bk-active-1/cancel')) {
                cancelledBookingId = 'bk-active-1';
                cancelledReason = body['reason']?.toString();
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'bookingId': 'bk-active-1',
                    'status': 'cancelled',
                    'cancellationReason': cancelledReason,
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final fakeSocket = _NoopSocketService(secureStorage: storage);
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
                socketServiceProvider.overrideWithValue(fakeSocket),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const TripsScreen(),
              ),
            ),
          );
          await _pumpFrames(tester);

          expect(
            find.textContaining('Minh Thành Ocean Pool Villa Bãi Sau'),
            findsOneWidget,
          );

          // Cancel booking via repository and verify payload
          final repo = BookingRepositoryImpl(client);
          await tester.runAsync(() async {
            await repo.cancelBooking(
              bookingId: 'bk-active-1',
              reason: 'Đổi lịch công tác đột xuất',
            );
          });
          expect(cancelledBookingId, 'bk-active-1');
          expect(cancelledReason, 'Đổi lịch công tác đột xuất');
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        '3.2 Favorites guest local storage -> login merge migrates valid IDs, drops 404 invalid IDs, and renders FavoritesScreen',
        (tester) async {
          final prefs = PreferencesService.inMemory();
          PreferencesService.activeInstance = prefs;

          // Guest saves favorites '101', '102', and stale '999' while unauthenticated
          await prefs.setFavorites(['101', '102', '999']);
          expect(prefs.getPendingGuestFavorites(), ['101', '102', '999']);

          final migratedOnServer = <String>[];
          final storage =
              _InMemorySecureStorage(initialAuthToken: 'jwt-user-1');
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.method == 'POST' &&
                  options.path.startsWith('/api/wishlist/')) {
                final listingId = options.path.split('/').last;
                if (listingId == '999') {
                  return _jsonResponse(
                    {'success': false, 'message': 'Listing not found'},
                    statusCode: 404,
                  );
                }
                migratedOnServer.add(listingId);
                return _jsonResponse({
                  'success': true,
                  'data': <String, dynamic>{},
                });
              }
              if (options.method == 'GET' && options.path == '/api/wishlist') {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'userId': 'user-1',
                    'listingIds': ['103', ...migratedOnServer],
                    'items': [
                      _sampleListingJson(id: '101'),
                      _sampleListingJson(
                        id: '102',
                        code: 'MTV-102',
                        title: 'Minh Thành Sunset Villa Bãi Trước',
                      ),
                    ],
                    'invalidListingIds': <String>[],
                  },
                });
              }
              if (options.path.contains('/api/listings')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      _sampleListingJson(id: '101'),
                      _sampleListingJson(
                        id: '102',
                        code: 'MTV-102',
                        title: 'Minh Thành Sunset Villa Bãi Trước',
                      ),
                    ],
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final wishlistRepo = WishlistRepositoryImpl(client, prefs: prefs);
          var syncedIds = <String>[];
          await tester.runAsync(() async {
            syncedIds = await wishlistRepo.getWishlistListingIds();
          });

          expect(migratedOnServer, ['101', '102']);
          expect(syncedIds.toSet(), {'101', '102', '103'});
          expect(syncedIds, isNot(contains('999')));
          expect(prefs.getPendingGuestFavorites(), isEmpty);

          tester.view.physicalSize = const Size(1280, 1400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const FavoritesScreen(),
              ),
            ),
          );
          await _pumpFrames(tester);
          expect(find.byType(FavoritesScreen), findsOneWidget);
        },
      );

      test(
        '3.3 Profile update (PATCH /api/users/me) preserves active user state when server fails with 500 and updates on retry',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final sharedPrefs = await SharedPreferences.getInstance();
          final prefs = PreferencesService(sharedPrefs);
          final storage = _InMemorySecureStorage(initialAuthToken: 'jwt-1');

          var failProfileUpdate = true;
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/auth/me') ||
                  (options.path.contains('/api/users/me') &&
                      options.method == 'GET')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'user-1',
                      'email': 'guest@minhthanhvilla.com',
                      'firstName': 'Minh',
                      'lastName': 'Nguyễn',
                      'phone': '0909123456',
                      'role': 'guest',
                      'bio': 'Yêu du lịch biển',
                    },
                  },
                });
              }
              if (options.path.contains('/api/users/me') &&
                  (options.method == 'PATCH' || options.method == 'PUT')) {
                if (failProfileUpdate) {
                  return _jsonResponse(
                    {
                      'success': false,
                      'message': 'Lỗi máy chủ khi lưu hồ sơ (500)',
                    },
                    statusCode: 500,
                  );
                }
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'user-1',
                      'email': 'guest@minhthanhvilla.com',
                      'fullName': body['fullName'] ?? 'Minh Nguyễn Mới',
                      'phone': body['phone'] ?? '0909123456',
                      'role': 'guest',
                      'bio': body['bio'] ?? 'Bio mới đã lưu',
                    },
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final fakeSocket = _NoopSocketService(secureStorage: storage);

          final container = ProviderContainer(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(fakeSocket),
            ],
          );
          addTearDown(container.dispose);

          container.read(authNotifierProvider.notifier);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(
            container.read(authNotifierProvider).valueOrNull?.fullName,
            'Minh Nguyễn',
          );

          // Attempt profile update while server returns 500 -> throws ServerFailure
          await expectLater(
            container.read(authNotifierProvider.notifier).updateProfile(
                  fullName: 'Minh Nguyễn Mới',
                  bio: 'Bio mới',
                ),
            throwsA(isA<ServerFailure>()),
          );
          // Existing user session is preserved (not logged out on 500)
          expect(container.read(authNotifierProvider).valueOrNull, isNotNull);

          // Retry when server recovers -> succeeds
          failProfileUpdate = false;
          final updatedUser =
              await container.read(authNotifierProvider.notifier).updateProfile(
                    fullName: 'Minh Nguyễn Mới',
                    bio: 'Bio mới đã lưu',
                  );
          expect(updatedUser.fullName, 'Minh Nguyễn Mới');
          expect(updatedUser.bio, 'Bio mới đã lưu');
        },
      );

      testWidgets(
        '3.4 MessagesScreen loads conversations, sends message, and deduplicates Socket.IO message:new events',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final sharedPrefs = await SharedPreferences.getInstance();
          final prefs = PreferencesService(sharedPrefs);
          final storage = _InMemorySecureStorage(initialAuthToken: 'jwt-1');

          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/auth/me')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'user-1',
                      'email': 'guest@minhthanhvilla.com',
                      'firstName': 'Minh',
                      'lastName': 'Nguyễn',
                      'role': 'guest',
                    },
                  },
                });
              }
              if (options.path == '/api/conversations' &&
                  options.method == 'GET') {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'conversationId': 'conv-55',
                        'listingId': '101',
                        'listingTitle': 'Minh Thành Ocean Pool Villa Bãi Sau',
                        'guestId': 'user-1',
                        'hostId': 'host-7',
                        'hostName': 'Minh Thành Host',
                        'lastMessagePreview': 'Chào bạn, villa còn trống ạ!',
                        'lastMessageAt': '2026-10-27T09:00:00.000Z',
                        'unreadCount': 1,
                      },
                    ],
                  },
                });
              }
              if (options.path == '/api/conversations/conv-55/messages' &&
                  options.method == 'GET') {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'messageId': 'msg-1',
                        'conversationId': 'conv-55',
                        'senderUserId': 'host-7',
                        'content': 'Chào bạn, villa còn trống ạ!',
                        'createdAt': '2026-10-27T09:00:00.000Z',
                      },
                    ],
                  },
                });
              }
              if (options.path == '/api/conversations/conv-55/messages' &&
                  options.method == 'POST') {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'messageId': 'msg-2',
                    'conversationId': 'conv-55',
                    'senderUserId': 'user-1',
                    'content':
                        body['content'] ?? 'Cho mình hỏi giờ nhận phòng?',
                    'createdAt': '2026-10-27T09:05:00.000Z',
                  },
                });
              }
              if (options.path.contains('/read')) {
                return _jsonResponse({
                  'success': true,
                  'data': <String, dynamic>{},
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final fakeSocket = _NoopSocketService(secureStorage: storage);

          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                preferencesServiceProvider.overrideWithValue(prefs),
                secureStorageProvider.overrideWithValue(storage),
                dioClientProvider.overrideWithValue(client),
                socketServiceProvider.overrideWithValue(fakeSocket),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const MessagesScreen(),
              ),
            ),
          );
          await _pumpFrames(tester);

          expect(
            find.textContaining('Chào bạn, villa còn trống ạ!'),
            findsWidgets,
          );

          final convRepo = ConversationsRepository(client);
          await tester.runAsync(() async {
            final sentMsg = await convRepo.sendMessage(
              conversationId: 'conv-55',
              content: 'Cho mình hỏi giờ nhận phòng?',
            );
            expect(sentMsg.id, 'msg-2');
            expect(sentMsg.content, 'Cho mình hỏi giờ nhận phòng?');
          });

          // Verify deduplication when Socket.IO pushes message:new for msg-1 and a message for another conversation
          final merged = ChatMessageItem.mergeAndSortMessages(
            const [
              ChatMessageItem(
                id: 'msg-1',
                conversationId: 'conv-55',
                senderId: 'host-7',
                content: 'Chào bạn, villa còn trống ạ!',
                createdAt: '2026-10-27T09:00:00.000Z',
              ),
            ],
            const [
              ChatMessageItem(
                id: 'msg-1',
                conversationId: 'conv-55',
                senderId: 'host-7',
                content: 'Chào bạn, villa còn trống ạ!',
                createdAt: '2026-10-27T09:00:00.000Z',
              ),
              ChatMessageItem(
                id: 'msg-other-conv',
                conversationId: 'conv-999',
                senderId: 'host-9',
                content: 'Tin nhắn hội thoại khác',
                createdAt: '2026-10-27T09:01:00.000Z',
              ),
            ],
            conversationId: 'conv-55',
          );
          expect(merged.length, 1);
          expect(merged.first.id, 'msg-1');
        },
      );
    },
  );

  group(
    'FLOW 4: Host KYC / Host Portal / Admin Role & Route Access Guards',
    () {
      test(
        '4.1 Role normalization & post-auth redirect rules route Guest, Host New (KYC), Verified Host, and Admin accurately',
        () {
          const guestUser = User(
            id: 'u-guest',
            email: 'guest@minhthanhvilla.com',
            firstName: 'Khách',
            lastName: 'Hàng',
            role: 'guest',
          );
          const pendingKycHost = User(
            id: 'u-host-new',
            email: 'kyc@minhthanhvilla.com',
            firstName: 'Chủ Nhà',
            lastName: 'Mới',
            role: 'host new',
          );
          const verifiedHost = User(
            id: 'u-host',
            email: 'host@minhthanhvilla.com',
            firstName: 'Chủ Nhà',
            lastName: 'Xác Minh',
            role: 'host',
          );
          const adminUser = User(
            id: 'u-admin',
            email: 'admin@minhthanhvilla.com',
            firstName: 'Quản Trị',
            lastName: 'Viên',
            role: 'admin',
          );

          expect(
            AuthNotifier.defaultRouteForUser(guestUser),
            '/account/profile',
          );
          expect(
            AuthNotifier.defaultRouteForUser(pendingKycHost),
            '/tro-thanh-host/trang-thai',
          );
          expect(
            AuthNotifier.defaultRouteForUser(verifiedHost),
            '/chu-nha/cho-nghi',
          );
          expect(AuthNotifier.defaultRouteForUser(adminUser), '/admin');

          // Guest attempting to redirect to /admin or /chu-nha is safely downgraded
          expect(
            AuthNotifier.resolvePostAuthRedirectPath(
              guestUser,
              redirectTo: '/admin/kiem-duyet',
            ),
            '/account/profile',
          );
          expect(
            AuthNotifier.resolvePostAuthRedirectPath(
              pendingKycHost,
              redirectTo: '/chu-nha/cho-nghi',
            ),
            '/tro-thanh-host/trang-thai',
          );
          expect(
            AuthNotifier.resolvePostAuthRedirectPath(
              verifiedHost,
              redirectTo: '/chu-nha/dat-phong',
            ),
            '/chu-nha/dat-phong',
          );
          expect(
            AuthNotifier.resolvePostAuthRedirectPath(
              adminUser,
              redirectTo: '/admin/ho-so-host',
            ),
            '/admin/ho-so-host',
          );
        },
      );

      test(
        '4.2 AdminRepository parses live overview metrics, clamps pagination limits, and distinguishes 500 from offline',
        () async {
          Map<String, dynamic>? capturedUsersQuery;
          final storage = _InMemorySecureStorage(initialAuthToken: 'jwt-admin');
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/admin/reports/')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'totals': {
                      'grossRevenue': 425000000,
                      'totalBookings': 89,
                      'activeListings': 26,
                      'totalHosts': 18,
                    },
                  },
                });
              }
              if (options.path.contains('/api/admin/listings/pending')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': <dynamic>[],
                    'pagination': {'total': 3},
                  },
                });
              }
              if (options.path.contains('/api/users')) {
                capturedUsersQuery = options.queryParameters;
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'id': 'u-1',
                        'email': 'host@minhthanhvilla.com',
                        'fullName': 'Minh Thành Host',
                        'role': 'host',
                        'status': 'active',
                      },
                    ],
                    'pagination': {
                      'page': 1,
                      'limit': 100,
                      'total': 142,
                      'totalPages': 2,
                    },
                  },
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final adminRepo = AdminRepository(client.dio);
          final stats = await adminRepo.getOverviewStats();
          expect(stats.users, 142);
          expect(stats.pendingListings, 3);
          expect(stats.grossRevenue, 425000000);

          final usersPage = await adminRepo.getAdminUsersPaginated(limit: 999);
          expect(usersPage.items.length, 1);
          expect(capturedUsersQuery?['limit'], 100);
        },
      );
    },
  );

  group(
    'FLOW 5: Resilience Scenarios — Offline / Timeout / 500 / 401 Single-Flight Refresh / Resume / Logout',
    () {
      test(
        '5.1 Offline & Timeout map to NetworkFailure (isOffline: true), while HTTP 500 maps to ServerFailure (isOffline: false — never fake offline)',
        () async {
          var mode = 'offline'; // 'offline' | 'timeout' | '500'
          final storage = _InMemorySecureStorage();
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (mode == 'offline') {
                throw DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  message: 'Failed host lookup',
                );
              }
              if (mode == 'timeout') {
                throw DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                  message: 'Receive timeout',
                );
              }
              return _jsonResponse(
                {
                  'success': false,
                  'message': 'Internal database connection pool exhausted',
                },
                statusCode: 500,
              );
            }),
          );

          final repo = VillaRepositoryImpl(client);

          // 1. Offline -> NetworkFailure
          await expectLater(
            repo.getVillas(),
            throwsA(isA<NetworkFailure>()),
          );

          // 2. Timeout -> NetworkFailure
          mode = 'timeout';
          await expectLater(
            repo.getVillas(),
            throwsA(isA<NetworkFailure>()),
          );

          // 3. HTTP 500 -> ServerFailure (MUST NOT be classified as NetworkFailure / offline)
          mode = '500';
          try {
            await repo.getVillas();
            fail('Expected ServerFailure on HTTP 500');
          } catch (e) {
            expect(e, isA<ServerFailure>());
            expect(e, isNot(isA<NetworkFailure>()));
            expect(AdminRepository.isOfflineError(e), isFalse);
            expect((e as ServerFailure).statusCode, 500);
          }
        },
      );

      test(
        '5.2 Concurrent HTTP 401 responses trigger single-flight POST /api/auth/refresh and replay requests; unrecoverable 401 clears session',
        () async {
          var refreshCallCount = 0;
          var allowRefreshSuccess = true;
          var sessionExpiredNotified = false;

          final storage = _InMemorySecureStorage(
            initialAuthToken: 'expired-access-token',
            initialRefreshCookie: 'valid-refresh-cookie',
          );

          late final DioClient client;
          client = DioClient(
            secureStorage: storage,
            onSessionExpired: () {
              sessionExpiredNotified = true;
            },
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/auth/refresh')) {
                refreshCallCount++;
                await Future<void>.delayed(const Duration(milliseconds: 30));
                if (!allowRefreshSuccess) {
                  return _jsonResponse(
                    {'success': false, 'message': 'Refresh token expired'},
                    statusCode: 401,
                  );
                }
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'accessToken': 'fresh-access-token-2',
                    'user': {
                      'id': 'user-1',
                      'email': 'guest@minhthanhvilla.com',
                      'firstName': 'Minh',
                      'lastName': 'Nguyễn',
                      'role': 'guest',
                    },
                  },
                });
              }

              final authHeader =
                  options.headers['Authorization']?.toString() ?? '';
              if (authHeader != 'Bearer fresh-access-token-2') {
                return _jsonResponse(
                  {'success': false, 'message': 'Token expired'},
                  statusCode: 401,
                );
              }
              return _jsonResponse({
                'success': true,
                'data': {'endpoint': options.path},
              });
            }),
          );

          // Fire 3 concurrent authenticated requests with expired access token
          final results = await Future.wait([
            client.dio.get<Map<String, dynamic>>('/api/bookings/mine'),
            client.dio.get<Map<String, dynamic>>('/api/wishlist'),
            client.dio.get<Map<String, dynamic>>('/api/conversations'),
          ]);

          expect(results.length, 3);
          expect(refreshCallCount, 1);
          expect(await storage.getAuthToken(), 'fresh-access-token-2');
          expect(sessionExpiredNotified, isFalse);

          // Now simulate unrecoverable 401 when refresh token itself is rejected
          await storage.saveAuthToken('expired-again');
          allowRefreshSuccess = false;

          await expectLater(
            client.dio.get<Map<String, dynamic>>('/api/bookings/mine'),
            throwsA(isA<DioException>()),
          );
          expect(sessionExpiredNotified, isTrue);
          expect(await storage.getAuthToken(), isNull);
        },
      );

      test(
        '5.3 App resume (onAppResumed) silently re-verifies session, and logout clears tokens, cookies, and session caches',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final sharedPrefs = await SharedPreferences.getInstance();
          final prefs = PreferencesService(sharedPrefs);
          final storage = _InMemorySecureStorage(
            initialAuthToken: 'valid-token-1',
            initialRefreshCookie: 'refresh-cookie-1',
          );

          var meRole = 'guest';
          final client = DioClient(
            secureStorage: storage,
            httpClientAdapter:
                _FakeBackendHttpClientAdapter((options, body) async {
              if (options.path.contains('/api/auth/me')) {
                return _jsonResponse({
                  'success': true,
                  'data': {
                    'user': {
                      'id': 'user-1',
                      'email': 'guest@minhthanhvilla.com',
                      'firstName': 'Minh',
                      'lastName': 'Nguyễn',
                      'role': meRole,
                    },
                  },
                });
              }
              if (options.path.contains('/api/auth/logout')) {
                return _jsonResponse({
                  'success': true,
                  'data': <String, dynamic>{},
                });
              }
              return _jsonResponse({
                'success': true,
                'data': <String, dynamic>{},
              });
            }),
          );

          final fakeSocket = _NoopSocketService(secureStorage: storage);

          final container = ProviderContainer(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
              secureStorageProvider.overrideWithValue(storage),
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(fakeSocket),
            ],
          );
          addTearDown(container.dispose);

          final notifier = container.read(authNotifierProvider.notifier);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(notifier.currentUser?.role, 'guest');

          // Simulate backend approving user as 'host' while app was backgrounded, then resuming
          meRole = 'host';
          await notifier.onAppResumed();
          expect(notifier.currentUser?.role, 'host');
          expect(notifier.currentUser?.isHost, isTrue);

          // Add an item to booking queue, then logout -> verify full session cleanup
          await prefs.addToBookingQueue(
            const BookingQueueItem(
              listingId: '101',
              title: 'Minh Thành Ocean Pool Villa',
              imageUrl: 'https://example.com/101.jpg',
              pricePerNight: 4500000,
            ),
          );
          expect(prefs.getBookingQueue(), isNotEmpty);

          await notifier.logout();
          expect(notifier.currentUser, isNull);
          expect(await storage.getAuthToken(), isNull);
          expect(await storage.getRefreshCookie(), isNull);
          expect(prefs.getBookingQueue(), isEmpty);
        },
      );
    },
  );
}
