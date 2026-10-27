import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/core/config/app_config.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';

class _InMemorySecureStorage extends SecureStorageService {
  String? _accessToken;
  String? _refreshToken;
  String? _refreshCookie;

  _InMemorySecureStorage({
    String? accessToken,
    String? refreshToken,
    String? refreshCookie,
  })  : _accessToken = accessToken,
        _refreshToken = refreshToken,
        _refreshCookie = refreshCookie;

  @override
  Future<void> saveAuthToken(String token) async {
    _accessToken = token;
  }

  @override
  Future<String?> getAuthToken() async => _accessToken;

  @override
  Future<void> deleteAuthToken() async {
    _accessToken = null;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> deleteRefreshToken() async {
    _refreshToken = null;
  }

  @override
  Future<void> saveRefreshCookie(String cookieValue) async {
    _refreshCookie = cookieValue;
  }

  @override
  Future<String?> getRefreshCookie() async => _refreshCookie;

  @override
  Future<void> deleteRefreshCookie() async {
    _refreshCookie = null;
  }

  @override
  Future<void> clearAuthSession() async {
    _accessToken = null;
    _refreshToken = null;
    _refreshCookie = null;
  }
}

typedef _MockHandler = Future<ResponseBody> Function(RequestOptions options);

class _MockHttpClientAdapter implements HttpClientAdapter {
  final _MockHandler handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.cancelToken?.isCancelled == true) {
      throw options.cancelToken!.cancelError!;
    }
    if (cancelFuture != null) {
      final completer = Completer<ResponseBody>();
      unawaited(
        cancelFuture.then((_) {
          if (!completer.isCompleted) {
            completer.completeError(
              options.cancelToken?.cancelError ??
                  DioException.requestCancelled(
                    requestOptions: options,
                    reason: 'Cancelled',
                  ),
            );
          }
        }),
      );
      unawaited(
        handler(options).then((res) {
          if (!completer.isCompleted) {
            completer.complete(res);
          }
        }).catchError((Object e, StackTrace st) {
          if (!completer.isCompleted) {
            completer.completeError(e, st);
          }
        }),
      );
      return completer.future;
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    },
  );
}

void main() {
  group('DioClient Network, P0 Error Classification & DI Audit', () {
    test('URL normalization never duplicates /api across baseUrl and path', () {
      expect(
        DioClient.normalizeBaseUrl('https://api.minhthanhvilla.com/api/'),
        'https://api.minhthanhvilla.com',
      );
      expect(
        DioClient.normalizeBaseUrl('https://api.minhthanhvilla.com/api'),
        'https://api.minhthanhvilla.com',
      );
      expect(
        DioClient.normalizeBaseUrl('http://localhost:7000/'),
        'http://localhost:7000',
      );

      expect(DioClient.normalizeApiPath('/api/listings'), '/api/listings');
      expect(DioClient.normalizeApiPath('/listings'), '/api/listings');
      expect(DioClient.normalizeApiPath('listings'), '/api/listings');
      expect(DioClient.normalizeApiPath('/api/api/listings'), '/api/listings');
      expect(DioClient.normalizeApiPath('api/listings'), '/api/listings');
      expect(DioClient.normalizeApiPath('/health'), '/health');
      expect(
        DioClient.normalizeApiPath(
          '/api/listings',
          baseUrl: 'https://api.minhthanhvilla.com/api',
        ),
        '/listings',
      );
      expect(
        DioClient.buildEndpointUri(
          'https://api.minhthanhvilla.com/api/',
          '/api/listings',
        ).toString(),
        'https://api.minhthanhvilla.com/api/listings',
      );
    });

    test(
        'Live request interceptor guarantees /api is joined once even with custom Dio baseUrl',
        () async {
      final requestedUris = <String>[];
      final customDio = Dio(
        BaseOptions(baseUrl: 'https://api.minhthanhvilla.com/api/'),
      );
      final client = DioClient(
        dio: customDio,
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          requestedUris.add(options.uri.toString());
          return _jsonResponse({'success': true, 'data': <dynamic>[]});
        }),
      );

      await client.dio.get<dynamic>('/api/listings');
      await client.dio.get<dynamic>('/listings');
      await client.dio.get<dynamic>('listings');
      await client.dio.get<dynamic>('/api/api/listings');
      await client.dio.get<dynamic>('/health');

      expect(requestedUris, [
        'https://api.minhthanhvilla.com/api/listings',
        'https://api.minhthanhvilla.com/api/listings',
        'https://api.minhthanhvilla.com/api/listings',
        'https://api.minhthanhvilla.com/api/listings',
        'https://api.minhthanhvilla.com/health',
      ]);
    });

    test(
        '2xx envelope unwrap and parsePaginated handle boundary cases and string pagination safely',
        () {
      final rawEnvelope = {
        'success': true,
        'data': {
          'listings': [
            {'id': 'v1', 'title': 'Villa 1'},
            {'id': 'v2', 'title': 'Villa 2'},
          ],
          'pagination': {
            'page': '2',
            'limit': '10',
            'total': '25',
          },
        },
      };

      final pageResult = DioClient.parsePaginated<String>(
        rawEnvelope,
        (json) => '${json['id']}:${json['title']}',
      );

      expect(pageResult.items, ['v1:Villa 1', 'v2:Villa 2']);
      expect(pageResult.pagination.page, 2);
      expect(pageResult.pagination.limit, 10);
      expect(pageResult.pagination.total, 25);
      expect(pageResult.pagination.totalPages, 3);
      expect(pageResult.pagination.hasPrev, isTrue);
      expect(pageResult.pagination.hasNext, isTrue);

      // Envelope with success=false throws ValidationFailure
      expect(
        () => DioClient.unwrapEnvelope({
          'success': false,
          'message': 'Dữ liệu không hợp lệ',
          'code': 'INVALID_QUERY',
        }),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.code, 'code', 'INVALID_QUERY'),
        ),
      );

      // Mapper failure throws SerializationFailure, NOT NetworkFailure/OfflineFailure
      expect(
        () => DioClient.parsePaginated<int>(
          {
            'success': true,
            'data': [
              {'id': 'not-an-int'},
            ],
          },
          (json) => json['id'] as int,
        ),
        throwsA(
          isA<SerializationFailure>()
              .having(
                  (f) => f.isSerializationError, 'isSerializationError', true)
              .having((f) => f.isOffline, 'isOffline', false),
        ),
      );
    });

    test(
        '401 single-flight race shares a single refresh call and sessionEpoch abort discards stale refresh',
        () async {
      final storage = _InMemorySecureStorage(
        accessToken: 'expired-jwt',
        refreshCookie: 'valid-refresh-cookie',
      );
      int refreshCount = 0;
      String? refreshedTokenFromCallback;

      final client = DioClient(
        secureStorage: storage,
        onSessionRefreshed: (token, _) {
          refreshedTokenFromCallback = token;
        },
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          if (options.path == '/api/auth/refresh') {
            refreshCount++;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return _jsonResponse({
              'success': true,
              'data': {
                'accessToken': 'fresh-jwt-token',
                'user': {'id': 'u1', 'role': 'USER'},
              },
            });
          }

          final auth = options.headers['Authorization']?.toString();
          if (auth != 'Bearer fresh-jwt-token') {
            throw DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'message': 'Token expired', 'code': 'TOKEN_EXPIRED'},
              ),
              type: DioExceptionType.badResponse,
            );
          }

          return _jsonResponse({
            'success': true,
            'data': {'path': options.path},
          });
        }),
      );

      final responses = await Future.wait([
        client.dio.get<Map<String, dynamic>>('/api/bookings/me'),
        client.dio.get<Map<String, dynamic>>('/api/wishlist'),
        client.dio.get<Map<String, dynamic>>('/api/conversations'),
      ]);

      expect(refreshCount, 1);
      expect(refreshedTokenFromCallback, 'fresh-jwt-token');
      expect(await storage.getAuthToken(), 'fresh-jwt-token');
      expect(responses.length, 3);

      // Verify abortSession increments sessionEpoch and cancels active tokens
      final epochBefore = client.sessionEpoch;
      final token = client.createSessionCancelToken();
      await client.abortSession(clearStorage: true);
      expect(client.sessionEpoch, greaterThan(epochBefore));
      expect(token.isCancelled, isTrue);
      expect(await storage.getAuthToken(), isNull);
    });

    test(
        'Public endpoints work without token and fallback anonymously when stored token is expired',
        () async {
      // Case 1: Guest with no token calls GET /api/listings -> no Authorization header, no refresh on 401
      final emptyStorage = _InMemorySecureStorage();
      int guestRefreshCalls = 0;
      String? capturedAuthHeader;

      final guestClient = DioClient(
        secureStorage: emptyStorage,
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          if (options.path == '/api/auth/refresh') {
            guestRefreshCalls++;
          }
          capturedAuthHeader = options.headers['Authorization']?.toString();
          return _jsonResponse({'success': true, 'data': <dynamic>[]});
        }),
      );

      final guestRes =
          await guestClient.dio.get<Map<String, dynamic>>('/api/listings');
      expect(guestRes.statusCode, 200);
      expect(capturedAuthHeader, isNull);
      expect(guestRefreshCalls, 0);

      // Case 2: Stale token in storage on public GET /api/listings where refresh fails ->
      // clears dead session and retries once anonymously without Authorization
      final staleStorage = _InMemorySecureStorage(
        accessToken: 'dead-access-token',
        refreshCookie: 'dead-refresh-cookie',
      );
      int listingsAttempts = 0;
      int sessionExpiredNotified = 0;

      final fallbackClient = DioClient(
        secureStorage: staleStorage,
        onSessionExpired: () => sessionExpiredNotified++,
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          if (options.path == '/api/auth/refresh') {
            throw DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'message': 'Refresh expired'},
              ),
              type: DioExceptionType.badResponse,
            );
          }

          if (options.path == '/api/listings') {
            listingsAttempts++;
            final hasAuth = options.headers.containsKey('Authorization');
            if (hasAuth) {
              throw DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'message': 'Invalid token'},
                ),
                type: DioExceptionType.badResponse,
              );
            }
            return _jsonResponse({
              'success': true,
              'data': [
                {'id': 'public-villa-1'},
              ],
            });
          }

          throw UnimplementedError();
        }),
      );

      final publicRes =
          await fallbackClient.dio.get<Map<String, dynamic>>('/api/listings');
      expect(publicRes.statusCode, 200);
      expect(listingsAttempts, 2);
      expect(sessionExpiredNotified, 1);
      expect(await staleStorage.getAuthToken(), isNull);
    });

    test(
        'Status mapping accurately distinguishes 401, 403, 404, 409, 422, 429, and 500',
        () {
      RequestOptions req(String path) => RequestOptions(path: path);

      final err401 = DioClient.handleError(
        DioException(
          requestOptions: req('/api/auth/me'),
          response: Response(
            requestOptions: req('/api/auth/me'),
            statusCode: 401,
            data: {'message': 'Unauthorized', 'code': 'AUTH_REQUIRED'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(err401, isA<AuthFailure>());
      expect(err401.isUnauthorized, isTrue);
      expect(err401.isForbidden, isFalse);
      expect(err401.isOffline, isFalse);

      final err403 = DioClient.handleError(
        DioException(
          requestOptions: req('/api/admin/users'),
          response: Response(
            requestOptions: req('/api/admin/users'),
            statusCode: 403,
            data: {'message': 'Forbidden role', 'code': 'FORBIDDEN_ROLE'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(err403, isA<ForbiddenFailure>());
      expect(err403, isA<AuthFailure>());
      expect(err403.isForbidden, isTrue);
      expect(err403.isUnauthorized, isFalse);
      expect(err403.isOffline, isFalse);

      final err409 = DioClient.handleError(
        DioException(
          requestOptions: req('/api/bookings'),
          response: Response(
            requestOptions: req('/api/bookings'),
            statusCode: 409,
            data: {
              'message': 'Dates already booked',
              'code': 'DATES_CONFLICT',
              'details': [
                {'field': 'checkIn', 'msg': 'Ngày đã có người đặt'},
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(err409, isA<ConflictFailure>());
      expect((err409 as ConflictFailure).fieldErrors.first.field, 'checkIn');
      expect(err409.isOffline, isFalse);

      final err422 = DioClient.handleError(
        DioException(
          requestOptions: req('/api/bookings'),
          response: Response(
            requestOptions: req('/api/bookings'),
            statusCode: 422,
            data: {
              'message': 'Validation failed',
              'code': 'VALIDATION_ERROR',
              'errors': [
                {'field': 'guests', 'message': 'Vượt quá số khách tối đa'},
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(err422, isA<ValidationFailure>());
      expect(err422.message, 'Vượt quá số khách tối đa');
      expect((err422 as ValidationFailure).statusCode, 422);

      final err429 = DioClient.handleError(
        DioException(
          requestOptions: req('/api/listings'),
          response: Response(
            requestOptions: req('/api/listings'),
            statusCode: 429,
            headers: Headers.fromMap({
              'Retry-After': ['15'],
            }),
            data: {'message': 'Too many requests', 'code': 'RATE_LIMITED'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(err429, isA<RateLimitFailure>());
      expect((err429 as RateLimitFailure).retryAfterSeconds, 15);
      expect(err429.isRateLimited, isTrue);

      final err500 = DioClient.handleError(
        DioException(
          requestOptions: req('/api/listings'),
          response: Response(
            requestOptions: req('/api/listings'),
            statusCode: 500,
            data: {'message': 'Database error', 'code': 'INTERNAL_ERROR'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(err500, isA<ServerFailure>());
      expect(err500.isServerError, isTrue);
      expect(err500.isOffline, isFalse);
    });

    test(
        '429 retries idempotent GET with backoff, but NEVER retries POST bookings or payments',
        () async {
      int getListingCalls = 0;
      int postBookingCalls = 0;
      int postPaymentCalls = 0;

      final client = DioClient(
        maxGetRetries: 2,
        retryBaseDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 30),
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          if (options.method == 'GET' && options.path == '/api/listings') {
            getListingCalls++;
            if (getListingCalls < 3) {
              throw DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  data: {'message': 'Rate limit exceeded'},
                ),
                type: DioExceptionType.badResponse,
              );
            }
            return _jsonResponse({
              'success': true,
              'data': [
                {'id': 'v1'},
              ],
            });
          }

          if (options.method == 'POST' && options.path == '/api/bookings') {
            postBookingCalls++;
            throw DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 429,
                data: {'message': 'Rate limit on booking'},
              ),
              type: DioExceptionType.badResponse,
            );
          }

          if (options.method == 'POST' &&
              options.path == '/api/payments/create') {
            postPaymentCalls++;
            throw DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 503,
                data: {'message': 'Payment gateway busy'},
              ),
              type: DioExceptionType.badResponse,
            );
          }

          throw UnimplementedError();
        }),
      );

      // Idempotent GET succeeds after 2 retries (3 total calls)
      final getResponse =
          await client.dio.get<Map<String, dynamic>>('/api/listings');
      expect(getResponse.statusCode, 200);
      expect(getListingCalls, 3);

      // POST /api/bookings is NEVER retried (1 call total)
      await expectLater(
        () => client.dio.post<Map<String, dynamic>>(
          '/api/bookings',
          data: {'listingId': 'v1'},
        ),
        throwsA(isA<DioException>()),
      );
      expect(postBookingCalls, 1);

      // POST /api/payments/create is NEVER retried (1 call total)
      await expectLater(
        () => client.dio.post<Map<String, dynamic>>(
          '/api/payments/create',
          data: {'bookingId': 'b1'},
        ),
        throwsA(isA<DioException>()),
      );
      expect(postPaymentCalls, 1);
    });

    test(
        'P0 transport & TLS classification never conflates DNS, ConnectionRefused, TLS cert, Timeout, or Cancel with Offline',
        () {
      final req = RequestOptions(path: '/api/listings');

      final dnsFailure = DioClient.handleError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
          message:
              "SocketException: Failed host lookup: 'dev-api.minhthanhvilla.com' (OS Error: No address associated with hostname, errno = 7)",
        ),
      );
      expect(dnsFailure, isA<DnsFailure>());
      expect(dnsFailure, isA<NetworkFailure>());
      expect(dnsFailure.isDnsError, isTrue);
      expect(dnsFailure.isOffline, isFalse);

      final connRefused = DioClient.handleError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
          message:
              'SocketException: Connection refused (OS Error: Connection refused, errno = 111)',
        ),
      );
      expect(connRefused, isA<ConnectionRefusedFailure>());
      expect(connRefused, isA<NetworkFailure>());
      expect(connRefused.isConnectionRefused, isTrue);
      expect(connRefused.isOffline, isFalse);

      final certFailure = DioClient.handleError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badCertificate,
          message: 'HandshakeException: CERTIFICATE_VERIFY_FAILED',
        ),
      );
      expect(certFailure, isA<CertificateFailure>());
      expect(certFailure.isTlsError, isTrue);
      expect(certFailure.isOffline, isFalse);

      final timeoutFailure = DioClient.handleError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout',
        ),
      );
      expect(timeoutFailure, isA<TimeoutFailure>());
      expect(timeoutFailure.isTimeout, isTrue);
      expect(timeoutFailure.isOffline, isFalse);

      final cancelledFailure = DioClient.handleError(
        DioException.requestCancelled(
          requestOptions: req,
          reason: 'Superseded by newer search query',
        ),
      );
      expect(cancelledFailure, isA<RequestCancelledFailure>());
      expect(cancelledFailure.isCancelled, isTrue);
      expect(cancelledFailure.isOffline, isFalse);

      final offlineFailure = DioClient.handleError(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
          message: 'SocketException: Network is unreachable (errno = 101)',
        ),
      );
      expect(offlineFailure, isA<OfflineFailure>());
      expect(offlineFailure.isOffline, isTrue);
    });

    test(
        'Stale request cancellation automatically cancels previous in-flight request with same requestKey',
        () async {
      final client = DioClient(
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          final q = options.queryParameters['q'];
          if (q == 'slow') {
            await Future<void>.delayed(const Duration(milliseconds: 120));
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          return _jsonResponse({
            'success': true,
            'data': {'q': q},
          });
        }),
      );

      final firstFuture = client.dio.get<Map<String, dynamic>>(
        '/api/listings',
        queryParameters: {'q': 'slow'},
        options: Options(extra: {'requestKey': 'listings-search'}),
      );

      await Future<void>.delayed(const Duration(milliseconds: 15));

      final secondFuture = client.dio.get<Map<String, dynamic>>(
        '/api/listings',
        queryParameters: {'q': 'fast'},
        options: Options(extra: {'requestKey': 'listings-search'}),
      );

      Object? firstError;
      try {
        await firstFuture;
      } catch (e) {
        firstError = e;
      }
      final secondRes = await secondFuture;

      expect(firstError, isA<DioException>());
      final mappedFirst = DioClient.handleError(firstError);
      expect(mappedFirst, isA<RequestCancelledFailure>());
      expect(mappedFirst.isCancelled, isTrue);
      expect(secondRes.data?['data']?['q'], 'fast');
    });

    test(
        'Riverpod DI container injects DioClient, PreferencesService, and VillaRepository cleanly',
        () async {
      final prefs = PreferencesService.inMemory();
      final storage = _InMemorySecureStorage();
      final mockClient = DioClient(
        secureStorage: storage,
        httpClientAdapter: _MockHttpClientAdapter((options) async {
          return _jsonResponse({
            'success': true,
            'data': {
              'listings': <Map<String, dynamic>>[],
              'pagination': {
                'page': 1,
                'limit': 12,
                'total': 0,
                'totalPages': 1,
              },
            },
          });
        }),
      );

      final container = ProviderContainer(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(storage),
          dioClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(dioClientProvider), same(mockClient));
      expect(container.read(preferencesServiceProvider), same(prefs));
      expect(container.read(dioClientProvider).dio.options.baseUrl,
          AppConfig.apiBaseUrl);

      final villas = await container.read(villaListProvider.future);
      expect(villas, isEmpty);
    });
  });
}
