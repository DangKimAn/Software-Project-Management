import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/config/app_config.dart';
import 'package:hotel_booking_flutter/core/constants/app_constants.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';

class InMemorySecureStorageService extends SecureStorageService {
  final Map<String, String> _store = <String, String>{};

  InMemorySecureStorageService() : super();

  @override
  Future<void> saveAuthToken(String token) async {
    _store[AppConstants.storageAuthTokenKey] = token;
  }

  @override
  Future<String?> getAuthToken() async {
    return _store[AppConstants.storageAuthTokenKey];
  }

  @override
  Future<void> deleteAuthToken() async {
    _store.remove(AppConstants.storageAuthTokenKey);
  }

  @override
  Future<bool> hasAuthToken() async {
    final token = _store[AppConstants.storageAuthTokenKey];
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> saveRefreshCookie(String cookieValue) async {
    _store[AppConstants.storageRefreshCookieKey] = cookieValue;
  }

  @override
  Future<String?> getRefreshCookie() async {
    return _store[AppConstants.storageRefreshCookieKey];
  }

  @override
  Future<void> deleteRefreshCookie() async {
    _store.remove(AppConstants.storageRefreshCookieKey);
  }

  @override
  Future<bool> hasRefreshCookie() async {
    final cookie = _store[AppConstants.storageRefreshCookieKey];
    return cookie != null && cookie.isNotEmpty;
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    _store[AppConstants.storageRefreshTokenKey] = refreshToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    return _store[AppConstants.storageRefreshTokenKey];
  }

  @override
  Future<void> deleteRefreshToken() async {
    _store.remove(AppConstants.storageRefreshTokenKey);
  }

  @override
  Future<bool> hasRefreshToken() async {
    final token = _store[AppConstants.storageRefreshTokenKey];
    return token != null && token.isNotEmpty;
  }
}

class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (cancelFuture != null) {
      return Future.any<ResponseBody>([
        handler(options),
        cancelFuture.then((_) {
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'Cancelled by cancelFuture',
          );
        }),
      ]);
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponseBody(
  Map<String, dynamic> body, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      ...?headers,
    },
  );
}

void main() {
  group('BUG-01: DioClient Real Transport & Zero Mock Interceptor Tests', () {
    test(
        'DioClient registers no StandaloneBackendInterceptor and uses AppConfig.apiBaseUrl with proper headers and timeouts',
        () async {
      final storage = InMemorySecureStorageService();
      await storage.saveAuthToken('initial_jwt_token');

      RequestOptions? capturedOptions;
      final adapter = MockHttpClientAdapter((options) async {
        capturedOptions = options;
        return jsonResponseBody({
          'success': true,
          'data': {'items': <dynamic>[]},
        });
      });

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: adapter,
      );

      final interceptorTypes =
          client.dio.interceptors.map((i) => i.runtimeType.toString()).toList();
      expect(
        interceptorTypes.any((name) => name.contains('StandaloneBackend')),
        isFalse,
      );
      expect(client.dio.options.baseUrl, AppConfig.apiBaseUrl);
      expect(client.dio.options.connectTimeout, AppConstants.connectTimeout);
      expect(client.dio.options.receiveTimeout, AppConstants.receiveTimeout);
      expect(client.dio.options.sendTimeout, AppConstants.sendTimeout);

      final response =
          await client.dio.get<Map<String, dynamic>>('/api/listings');
      expect(response.statusCode, 200);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.uri.toString(),
          '${AppConfig.apiBaseUrl}/api/listings');
      expect(capturedOptions!.headers['Authorization'],
          'Bearer initial_jwt_token');
      expect(capturedOptions!.headers['Accept'], 'application/json');
    });

    test(
        'DioClient propagates network and HTTP errors (400/401/403/404/422/500) without swallowing or returning fake 200',
        () async {
      final storage = InMemorySecureStorageService();

      for (final statusCode in <int>[400, 401, 403, 404, 422, 500]) {
        final adapter = MockHttpClientAdapter((options) async {
          return jsonResponseBody(
            {
              'success': false,
              'message': 'Backend error $statusCode',
            },
            statusCode: statusCode,
          );
        });

        final client = DioClient(
          secureStorage: storage,
          httpClientAdapter: adapter,
        );

        AppFailure? caughtError;
        try {
          await client.dio.get<Map<String, dynamic>>(
            '/api/listings/999',
            options: Options(extra: const {'skipAuthRefresh': true}),
          );
        } catch (e) {
          caughtError = DioClient.handleError(e);
        }

        expect(caughtError, isNotNull, reason: 'Status $statusCode must throw');
        if (statusCode == 400 || statusCode == 422) {
          expect(caughtError, isA<ValidationFailure>());
        } else if (statusCode == 401 || statusCode == 403) {
          expect(caughtError, isA<AuthFailure>());
          expect(caughtError!.statusCode, statusCode);
        } else if (statusCode == 404) {
          expect(caughtError, isA<NotFoundFailure>());
        } else if (statusCode == 500) {
          expect(caughtError, isA<ServerFailure>());
        }
      }

      // Network disconnect must throw NetworkFailure, never fallback to sample data
      final offlineClient = DioClient(
        secureStorage: storage,
        httpClientAdapter: MockHttpClientAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'Connection refused',
          );
        }),
      );

      await expectLater(
        () async {
          try {
            await offlineClient.dio.get<Map<String, dynamic>>('/api/listings');
          } catch (e) {
            throw DioClient.handleError(e);
          }
        }(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group(
      'BUG-02: Refresh Token Single-Flight, Concurrency, Failure & Logout Cancellation Tests',
      () {
    test(
        '401 triggers POST /api/auth/refresh with refreshToken cookie, updates credentials, and retries original request once',
        () async {
      final storage = InMemorySecureStorageService();
      await storage.saveAuthToken('expired_access_token');
      await storage.saveRefreshCookie('valid_refresh_cookie_1');

      int refreshCallCount = 0;
      int meCallCount = 0;
      String? refreshCookieHeaderSent;

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCallCount++;
          refreshCookieHeaderSent = options.headers['Cookie']?.toString();
          return jsonResponseBody(
            {
              'success': true,
              'data': {
                'token': 'rotated_access_token_2',
                'accessToken': 'rotated_access_token_2',
                'user': {
                  'id': '10',
                  'email': 'guest@minhthanhvilla.com',
                  'name': 'Guest User',
                  'role': 'guest',
                },
              },
            },
            headers: {
              'set-cookie': <String>[
                'refreshToken=rotated_refresh_cookie_2; Path=/api/auth; HttpOnly',
              ],
            },
          );
        }

        if (options.path == '/api/auth/me') {
          meCallCount++;
          final authHeader = options.headers['Authorization']?.toString() ?? '';
          if (authHeader == 'Bearer expired_access_token') {
            return jsonResponseBody(
              {'success': false, 'message': 'Token expired'},
              statusCode: 401,
            );
          }
          if (authHeader == 'Bearer rotated_access_token_2') {
            return jsonResponseBody({
              'success': true,
              'data': {
                'user': {
                  'id': '10',
                  'email': 'guest@minhthanhvilla.com',
                  'name': 'Guest User',
                  'role': 'guest',
                },
              },
            });
          }
        }

        return jsonResponseBody({'message': 'Not found'}, statusCode: 404);
      });

      Map<String, dynamic>? refreshedUserPayload;
      String? refreshedTokenValue;
      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: adapter,
        onSessionRefreshed: (accessToken, userJson) {
          refreshedTokenValue = accessToken;
          refreshedUserPayload = userJson;
        },
      );

      final response =
          await client.dio.get<Map<String, dynamic>>('/api/auth/me');

      expect(response.statusCode, 200);
      expect(refreshCallCount, 1);
      expect(meCallCount, 2);
      expect(refreshCookieHeaderSent,
          contains('refreshToken=valid_refresh_cookie_1'));
      expect(await storage.getAuthToken(), 'rotated_access_token_2');
      expect(await storage.getRefreshCookie(), 'rotated_refresh_cookie_2');
      expect(refreshedTokenValue, 'rotated_access_token_2');
      expect(refreshedUserPayload?['id'], '10');
    });

    test(
        'Concurrent 401 requests execute only ONE refresh call and retry all waiting requests once',
        () async {
      final storage = InMemorySecureStorageService();
      await storage.saveAuthToken('expired_token');
      await storage.saveRefreshCookie('seed_refresh_token');

      int refreshCount = 0;
      final endpointAttempts = <String, int>{};

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCount++;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return jsonResponseBody({
            'success': true,
            'data': {
              'token': 'fresh_concurrent_token',
              'user': {'id': '77', 'email': 'u@test.com', 'role': 'guest'},
            },
          });
        }

        final count = (endpointAttempts[options.path] ?? 0) + 1;
        endpointAttempts[options.path] = count;

        final authHeader = options.headers['Authorization']?.toString() ?? '';
        if (authHeader != 'Bearer fresh_concurrent_token') {
          return jsonResponseBody(
            {'success': false, 'message': 'Expired'},
            statusCode: 401,
          );
        }

        return jsonResponseBody({
          'success': true,
          'data': {'path': options.path, 'attempt': count},
        });
      });

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: adapter,
      );

      final paths = <String>[
        '/api/bookings/my',
        '/api/wishlist',
        '/api/messages/conversations',
        '/api/users/me',
        '/api/notifications',
      ];

      final responses = await Future.wait(
        paths.map((p) => client.dio.get<Map<String, dynamic>>(p)),
      );

      expect(refreshCount, 1,
          reason:
              'Only one refresh request may be executed for concurrent 401s');
      for (final res in responses) {
        expect(res.statusCode, 200);
        expect(res.data?['data']?['attempt'], 2);
      }
      expect(await storage.getAuthToken(), 'fresh_concurrent_token');
    });

    test(
        'Refresh failure (403) clears session storage, fires onSessionExpired once, and does not loop',
        () async {
      final storage = InMemorySecureStorageService();
      await storage.saveAuthToken('expired_token');
      await storage.saveRefreshCookie('revoked_refresh_token');

      int refreshCount = 0;
      int expiredCallbackCount = 0;

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCount++;
          return jsonResponseBody(
            {'success': false, 'message': 'Invalid or expired refresh token'},
            statusCode: 403,
          );
        }
        return jsonResponseBody(
          {'success': false, 'message': 'Unauthorized'},
          statusCode: 401,
        );
      });

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: adapter,
        onSessionExpired: () {
          expiredCallbackCount++;
        },
      );

      final futures = <Future<Response<Map<String, dynamic>>>>[
        client.dio.get<Map<String, dynamic>>('/api/bookings/my'),
        client.dio.get<Map<String, dynamic>>('/api/wishlist'),
      ];

      for (final f in futures) {
        await expectLater(f, throwsA(isA<DioException>()));
      }

      expect(refreshCount, 1);
      expect(expiredCallbackCount, 1);
      expect(await storage.getAuthToken(), isNull);
      expect(await storage.getRefreshCookie(), isNull);
    });

    test(
        'Retried request returning 401 again does not trigger infinite refresh loop',
        () async {
      final storage = InMemorySecureStorageService();
      await storage.saveAuthToken('expired_token');
      await storage.saveRefreshCookie('valid_cookie');

      int refreshCount = 0;
      int protectedCallCount = 0;

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCount++;
          return jsonResponseBody({
            'success': true,
            'data': {
              'token': 'still_rejected_token',
              'user': {'id': '1', 'email': 'a@b.com'},
            },
          });
        }
        protectedCallCount++;
        return jsonResponseBody(
          {'success': false, 'message': 'Still unauthorized'},
          statusCode: 401,
        );
      });

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: adapter,
      );

      await expectLater(
        client.dio.get<Map<String, dynamic>>('/api/bookings/my'),
        throwsA(isA<DioException>()),
      );

      expect(refreshCount, 1, reason: 'Must not loop on repeated 401');
      expect(protectedCallCount, 2, reason: 'Initial request + 1 retry only');
    });

    test(
        'abortSession during logout cancels in-flight refresh task and prevents stale token persistence',
        () async {
      final storage = InMemorySecureStorageService();
      await storage.saveAuthToken('expired_token');
      await storage.saveRefreshCookie('active_cookie');

      final refreshStarted = Completer<void>();

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return jsonResponseBody({
            'success': true,
            'data': {
              'token': 'stale_token_after_logout',
              'user': {'id': '1', 'email': 'a@b.com'},
            },
          });
        }
        return jsonResponseBody({'message': 'Unauthorized'}, statusCode: 401);
      });

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: adapter,
      );

      final pendingRequest =
          client.dio.get<Map<String, dynamic>>('/api/bookings/my');
      await refreshStarted.future;

      // User logs out while refresh is in flight
      await client.abortSession(clearStorage: true);

      await expectLater(pendingRequest, throwsA(isA<DioException>()));
      expect(await storage.getAuthToken(), isNull);
      expect(await storage.getRefreshCookie(), isNull);
    });
  });
}
