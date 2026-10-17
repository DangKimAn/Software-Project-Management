import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/core/constants/app_constants.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hotel_booking_flutter/features/auth/data/services/google_auth_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';

class _TestSecureStorage extends SecureStorageService {
  final Map<String, String> _map = <String, String>{};

  @override
  Future<void> saveAuthToken(String token) async =>
      _map[AppConstants.storageAuthTokenKey] = token;

  @override
  Future<String?> getAuthToken() async =>
      _map[AppConstants.storageAuthTokenKey];

  @override
  Future<void> deleteAuthToken() async =>
      _map.remove(AppConstants.storageAuthTokenKey);

  @override
  Future<bool> hasAuthToken() async =>
      (_map[AppConstants.storageAuthTokenKey] ?? '').isNotEmpty;

  @override
  Future<void> saveRefreshCookie(String cookieValue) async =>
      _map[AppConstants.storageRefreshCookieKey] = cookieValue;

  @override
  Future<String?> getRefreshCookie() async =>
      _map[AppConstants.storageRefreshCookieKey];

  @override
  Future<void> deleteRefreshCookie() async =>
      _map.remove(AppConstants.storageRefreshCookieKey);

  @override
  Future<bool> hasRefreshCookie() async =>
      (_map[AppConstants.storageRefreshCookieKey] ?? '').isNotEmpty;

  @override
  Future<void> saveRefreshToken(String refreshToken) async =>
      _map[AppConstants.storageRefreshTokenKey] = refreshToken;

  @override
  Future<String?> getRefreshToken() async =>
      _map[AppConstants.storageRefreshTokenKey];

  @override
  Future<void> deleteRefreshToken() async =>
      _map.remove(AppConstants.storageRefreshTokenKey);

  @override
  Future<bool> hasRefreshToken() async =>
      (_map[AppConstants.storageRefreshTokenKey] ?? '').isNotEmpty;
}

class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _FakeAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}

class _FakeGoogleAuthService extends GoogleAuthService {
  final Future<String> Function() _onObtainIdToken;
  int signOutCount = 0;

  _FakeGoogleAuthService(this._onObtainIdToken)
      : super(enforceConfigGuard: false);

  @override
  Future<String> obtainIdToken() => _onObtainIdToken();

  @override
  Future<void> signOut() async {
    signOutCount++;
  }
}

ResponseBody _json(
  Map<String, dynamic> data, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      ...?headers,
    },
  );
}

void main() {
  group('Auth Domain & Role Hierarchy Tests', () {
    test(
        'User.fromJson correctly parses guest, host, host new, and admin roles',
        () {
      final guest = User.fromJson({
        'id': 101,
        'email': 'guest@example.com',
        'firstName': 'Nguyen',
        'lastName': 'An',
        'role': 'guest',
        'phone': '0901234567',
        'isVerified': true,
      });
      expect(guest.id, '101');
      expect(guest.fullName, 'Nguyen An');
      expect(guest.isHost, isFalse);
      expect(guest.isNewHost, isFalse);
      expect(guest.isAdmin, isFalse);

      final pendingHost = User.fromJson({
        'id': 102,
        'email': 'pending@example.com',
        'name': 'Pending Host',
        'role': 'host new',
        'roles': ['guest', 'host new'],
      });
      expect(pendingHost.isHost, isFalse,
          reason: 'host new must NOT be treated as approved host');
      expect(pendingHost.isNewHost, isTrue);
      expect(pendingHost.isAdmin, isFalse);

      final approvedHost = User.fromJson({
        'userId': 202,
        'email': 'host@example.com',
        'firstName': 'Tran',
        'lastName': 'Host',
        'role': 'host',
        'roles': ['guest', 'host'],
      });
      expect(approvedHost.isHost, isTrue);
      expect(approvedHost.isNewHost, isFalse);
      expect(approvedHost.isAdmin, isFalse);

      final admin = User.fromJson({
        'id': 999,
        'email': 'admin@example.com',
        'name': 'Admin Root',
        'roles': ['guest', 'host', 'admin'],
      });
      expect(admin.role, 'admin');
      expect(admin.isAdmin, isTrue);
    });

    test('AuthSession.fromJson parses access token and nested user', () {
      final json = {
        'token': 'jwt_access_token_xyz',
        'user': {
          'id': 303,
          'email': 'user@example.com',
          'firstName': 'Le',
          'lastName': 'Binh',
          'role': 'guest',
        },
      };

      final session = AuthSession.fromJson(json);

      expect(session.token, 'jwt_access_token_xyz');
      expect(session.user.id, '303');
      expect(session.user.fullName, 'Le Binh');
    });
  });

  group('BUG-18 & BUG-36: Google Sign-In SDK Flow & Session Lifecycle Tests',
      () {
    test(
        'signInWithGoogle exchanges SDK idToken via POST /api/auth/google and persists session only after backend verification',
        () async {
      final storage = _TestSecureStorage();
      Map<String, dynamic>? postedBody;

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((options) async {
          if (options.path == '/api/auth/me') {
            return _json({'message': 'No token'}, statusCode: 401);
          }
          if (options.path == '/api/auth/google' && options.method == 'POST') {
            postedBody = options.data as Map<String, dynamic>?;
            return _json(
              {
                'success': true,
                'data': {
                  'token': 'google_jwt_token_99',
                  'accessToken': 'google_jwt_token_99',
                  'isNewUser': true,
                  'user': {
                    'id': '501',
                    'email': 'newgoogleuser@gmail.com',
                    'name': 'Google User',
                    'role': 'guest',
                  },
                },
              },
              headers: {
                'set-cookie': <String>[
                  'refreshToken=google_refresh_cookie_99; Path=/api/auth; HttpOnly',
                ],
              },
            );
          }
          return _json({'message': 'Not found'}, statusCode: 404);
        }),
      );

      final repo = AuthRepositoryImpl(client, storage);
      final googleService = _FakeGoogleAuthService(
        () async => 'verified_google_id_token_from_sdk',
      );
      final notifier = AuthNotifier(
        repo,
        googleAuthService: googleService,
        dioClient: client,
      );

      final user = await notifier.signInWithGoogle();

      expect(postedBody, {'idToken': 'verified_google_id_token_from_sdk'});
      expect(user.id, '501');
      expect(user.email, 'newgoogleuser@gmail.com');
      expect(notifier.currentUser?.id, '501');
      expect(await storage.getAuthToken(), 'google_jwt_token_99');
      expect(await storage.getRefreshCookie(), 'google_refresh_cookie_99');
    });

    test(
        'signInWithGoogle does not authenticate if backend rejects Google token or user cancels picker',
        () async {
      final storage = _TestSecureStorage();
      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((options) async {
          if (options.path == '/api/auth/google') {
            return _json(
              {'success': false, 'message': 'Invalid Google token'},
              statusCode: 401,
            );
          }
          return _json({'message': 'Unauthorized'}, statusCode: 401);
        }),
      );

      final repo = AuthRepositoryImpl(client, storage);

      // 1. User cancels Google Sign-In picker
      final cancelledNotifier = AuthNotifier(
        repo,
        googleAuthService: _FakeGoogleAuthService(() async {
          throw const GoogleSignInCancelledException();
        }),
        dioClient: client,
      );

      await expectLater(
        cancelledNotifier.signInWithGoogle(),
        throwsA(isA<GoogleSignInCancelledException>()),
      );
      expect(cancelledNotifier.currentUser, isNull);
      expect(await storage.getAuthToken(), isNull);

      // 2. Backend rejects invalid Google token
      final rejectedNotifier = AuthNotifier(
        repo,
        googleAuthService: _FakeGoogleAuthService(() async => 'bad_id_token'),
        dioClient: client,
      );

      await expectLater(
        rejectedNotifier.signInWithGoogle(),
        throwsA(isA<AuthFailure>()),
      );
      expect(rejectedNotifier.currentUser, isNull);
      expect(await storage.getAuthToken(), isNull);
    });

    test(
        'DioClient session expiry and session refresh callbacks automatically update AuthNotifier state',
        () async {
      final storage = _TestSecureStorage();
      await storage.saveAuthToken('valid_initial_token');
      await storage.saveRefreshCookie('valid_refresh_cookie');

      bool failRefresh = false;

      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((options) async {
          if (options.path == '/api/auth/me') {
            final auth = options.headers['Authorization']?.toString() ?? '';
            if (auth == 'Bearer valid_initial_token' ||
                auth == 'Bearer refreshed_token_2') {
              return _json({
                'success': true,
                'data': {
                  'user': {
                    'id': '77',
                    'email': 'member@minhthanhvilla.com',
                    'name': auth == 'Bearer refreshed_token_2'
                        ? 'Member Upgraded'
                        : 'Member',
                    'role':
                        auth == 'Bearer refreshed_token_2' ? 'host' : 'guest',
                  },
                },
              });
            }
            return _json({'message': 'Expired'}, statusCode: 401);
          }
          if (options.path == '/api/users/me') {
            final auth = options.headers['Authorization']?.toString() ?? '';
            return _json({
              'success': true,
              'data': {
                'id': '77',
                'email': 'member@minhthanhvilla.com',
                'name': auth == 'Bearer refreshed_token_2'
                    ? 'Member Upgraded'
                    : 'Member',
                'role': auth == 'Bearer refreshed_token_2' ? 'host' : 'guest',
              },
            });
          }
          if (options.path == '/api/auth/refresh') {
            if (failRefresh) {
              return _json({'message': 'Refresh expired'}, statusCode: 403);
            }
            return _json({
              'success': true,
              'data': {
                'token': 'refreshed_token_2',
                'user': {
                  'id': '77',
                  'email': 'member@minhthanhvilla.com',
                  'name': 'Member Upgraded',
                  'role': 'host',
                },
              },
            });
          }
          return _json({'message': 'Expired'}, statusCode: 401);
        }),
      );

      final repo = AuthRepositoryImpl(client, storage);
      final notifier = AuthNotifier(repo, dioClient: client);
      await notifier.checkCurrentUser();
      expect(notifier.currentUser?.id, '77');
      expect(notifier.currentUser?.isHost, isFalse);

      // Simulate access token expiry followed by successful refresh returning updated role
      await storage.saveAuthToken('expired_token');
      await notifier.onAppResumed();
      expect(notifier.currentUser?.isHost, isTrue);

      // Simulate refresh failure -> triggers onSessionExpired -> clears AuthNotifier user
      failRefresh = true;
      await storage.saveAuthToken('expired_token_2');
      await expectLater(
        client.dio.get<Map<String, dynamic>>('/api/bookings/my'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.currentUser, isNull);
    });

    testWidgets(
        'LoginScreen does NOT show manual ID token dialog and navigates to safe redirectTo after Google Sign-In',
        (tester) async {
      final storage = _TestSecureStorage();
      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((options) async {
          if (options.path == '/api/auth/google') {
            return _json({
              'success': true,
              'data': {
                'token': 'widget_google_jwt',
                'user': {
                  'id': '88',
                  'email': 'google@minhthanhvilla.com',
                  'name': 'Khach Google',
                  'role': 'guest',
                },
              },
            });
          }
          return _json({'message': 'Unauthorized'}, statusCode: 401);
        }),
      );

      final repo = AuthRepositoryImpl(client, storage);
      final notifier = AuthNotifier(
        repo,
        googleAuthService:
            _FakeGoogleAuthService(() async => 'sdk_id_token_88'),
        dioClient: client,
      );

      final router = GoRouter(
        initialLocation: '/dang-nhap?redirectTo=%2Fgio-cho-dat',
        routes: [
          GoRoute(
            path: '/dang-nhap',
            builder: (context, state) => LoginScreen(
              redirectTo: state.uri.queryParameters['redirectTo'],
            ),
          ),
          GoRoute(
            path: '/gio-cho-dat',
            builder: (context, state) =>
                const Scaffold(body: Text('MULTI_BOOKING_DESTINATION')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Đăng nhập với Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập với Google'));
      await tester.pumpAndSettle();

      // Must NOT show any manual token input AlertDialog
      expect(
        find.textContaining('Nhập Google ID Token'),
        findsNothing,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('MULTI_BOOKING_DESTINATION'), findsOneWidget);
    });
  });
}
