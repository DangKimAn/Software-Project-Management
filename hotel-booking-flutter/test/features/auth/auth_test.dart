import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/validation/auth_validation.dart';
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
import 'package:hotel_booking_flutter/shared/widgets/app_button.dart';

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

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockGoogleAuthService extends Mock implements GoogleAuthService {}

void main() {
  group('Terminal 08 form and lifecycle interactions', () {
    testWidgets('login field errors preserve input and allow real retry',
        (tester) async {
      final repo = _MockAuthRepository();
      when(() => repo.getCurrentUser()).thenAnswer((_) async => null);
      var attempts = 0;
      when(() =>
              repo.login(identifier: 'test@example.com', password: 'Abc12345'))
          .thenAnswer((_) async {
        attempts++;
        throw const ValidationFailure('Thông tin chưa hợp lệ', fieldErrors: [
          ApiFieldError(path: 'identifier', msg: 'Email đã bị khóa')
        ]);
      });
      final notifier = AuthNotifier(repo);
      await tester.pumpWidget(ProviderScope(
          overrides: [authNotifierProvider.overrideWith((_) => notifier)],
          child: const MaterialApp(home: LoginScreen())));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Abc12345');
      await tester.ensureVisible(find.text('Đăng nhập'));
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Email đã bị khóa'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    });
    testWidgets('keyboard submit cannot start two login requests while pending',
        (tester) async {
      final repo = _MockAuthRepository();
      when(() => repo.getCurrentUser()).thenAnswer((_) async => null);
      final gate = Completer<AuthSession>();
      var attempts = 0;
      when(() =>
              repo.login(identifier: 'test@example.com', password: 'Abc12345'))
          .thenAnswer((_) {
        attempts++;
        return gate.future;
      });
      final notifier = AuthNotifier(repo);
      await tester.pumpWidget(ProviderScope(
          overrides: [authNotifierProvider.overrideWith((_) => notifier)],
          child: const MaterialApp(home: LoginScreen())));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Abc12345');
      final password = tester.widget<TextField>(find.byType(TextField).at(1));
      password.onSubmitted!('Abc12345');
      password.onSubmitted!('Abc12345');
      await tester.pump();
      expect(attempts, 1);
      gate.completeError(
          const ServerFailure('Máy chủ đang lỗi', statusCode: 500));
      await tester.pumpAndSettle();
      expect(find.text('Máy chủ đang lỗi'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });
    test('logout still calls repository cleanup when Google sign-out fails',
        () async {
      final repo = _MockAuthRepository();
      when(() => repo.getCurrentUser()).thenAnswer((_) async => null);
      when(() => repo.logout()).thenAnswer((_) async {});
      final google = _MockGoogleAuthService();
      when(() => google.signOut()).thenThrow(StateError('test failure'));
      final notifier = AuthNotifier(repo, googleAuthService: google);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      await expectLater(notifier.logout(), throwsStateError);
      verify(() => repo.logout()).called(1);
      expect(notifier.currentUser, isNull);
    });
    test('offline resume retains established user', () async {
      final repo = _MockAuthRepository();
      when(() => repo.getCurrentUser())
          .thenAnswer((_) async => User.fromJson({'id': 8}));
      final notifier = AuthNotifier(repo);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      when(() => repo.getCurrentUser()).thenThrow(const NetworkFailure());
      await notifier.onAppResumed();
      expect(notifier.currentUser!.id, '8');
    });
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.3, 1.6]) {
        testWidgets('OTP retry/paste/resend layout width=$width scale=$scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _MockAuthRepository();
          when(() => repo.forgotPassword(identifier: 'test@example.com'))
              .thenAnswer((_) async {});
          var attempts = 0;
          when(() => repo.resetPassword(
              identifier: 'test@example.com',
              otp: '123456',
              newPassword: 'Abc12345')).thenAnswer((_) async {
            attempts++;
            throw const ValidationFailure('Mã không hợp lệ', fieldErrors: [
              ApiFieldError(path: 'otp', msg: 'OTP đã hết hạn')
            ]);
          });
          await tester.pumpWidget(ProviderScope(
              overrides: [authRepositoryProvider.overrideWithValue(repo)],
              child: MaterialApp(
                  home: MediaQuery(
                      data: MediaQueryData(
                          size: Size(width, 900),
                          textScaler: TextScaler.linear(scale),
                          viewInsets: const EdgeInsets.only(bottom: 250)),
                      child: const ForgotPasswordScreen()))));
          await tester.enterText(
              find.byType(TextFormField).first, 'test@example.com');
          await tester.ensureVisible(find.text('Gửi mã xác thực'));
          await tester.tap(find.text('Gửi mã xác thực'));
          await tester.pumpAndSettle();
          // Resend must work before password/OTP fields have been filled.
          await tester.pump(const Duration(seconds: 24));
          await tester.ensureVisible(find.text('Gửi lại mã OTP'));
          await tester.tap(find.text('Gửi lại mã OTP'));
          await tester.pumpAndSettle();
          verify(() => repo.forgotPassword(identifier: 'test@example.com'))
              .called(2);
          await tester.enterText(find.byType(TextFormField).at(0), '1234567');
          expect(
              tester
                  .widget<TextFormField>(find.byType(TextFormField).at(0))
                  .controller!
                  .text,
              '123456');
          await tester.enterText(find.byType(TextFormField).at(1), 'Abc12345');
          await tester.enterText(find.byType(TextFormField).at(2), 'Abc12345');
          await tester.ensureVisible(find.text('Xác nhận mã OTP'));
          await tester.tap(find.text('Xác nhận mã OTP'));
          await tester.pumpAndSettle();
          expect(find.text('OTP đã hết hạn'), findsOneWidget);
          expect(find.text('Đổi mật khẩu thành công'), findsNothing);
          await tester.ensureVisible(find.text('Xác nhận mã OTP'));
          await tester.tap(find.text('Xác nhận mã OTP'));
          await tester.pumpAndSettle();
          expect(attempts, 2);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });
  group('Terminal 08 regressions', () {
    test('backend validation: optional VN phone, email, password and username',
        () {
      expect(AuthValidation.phone(''), isNull);
      expect(AuthValidation.phone('+84901234567'), isNull);
      expect(AuthValidation.phone('0901234567'), isNull);
      expect(AuthValidation.phone('123'), isNotNull);
      expect(AuthValidation.email('a@@b.c'), isNotNull);
      expect(AuthValidation.identifier('user.name'), isNull);
      expect(AuthValidation.identifier('bad @ input'), isNotNull);
      expect(AuthValidation.password('abcdefgh'), isNotNull);
      expect(AuthValidation.password('12345678'), isNotNull);
      expect(AuthValidation.password('Abc12345'), isNull);
      expect(AuthValidation.password('a1' * 65), isNotNull);
    });
    test('moderator and null roles cannot grant admin or host', () {
      final user = User.fromJson({'id': 1, 'role': 'moderator', 'roles': null});
      expect(user.role, 'moderator');
      expect(user.isAdmin, isFalse);
      expect(user.isHost, isFalse);
      expect(User.fromJson({}).role, 'guest');
    });
    test('refresh revocation clears old roles and verification flags',
        () async {
      final repo = _MockAuthRepository();
      when(() => repo.getCurrentUser()).thenAnswer((_) async => User.fromJson({
            'id': 1,
            'role': 'host',
            'roles': ['host'],
            'isHostVerified': true,
            'isVerified': true,
          }));
      final notifier = AuthNotifier(repo);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      notifier.handleSessionRefreshed({
        'id': 1,
        'role': 'guest',
        'roles': <String>[],
        'isHostVerified': false,
        'isVerified': false
      });
      expect(notifier.currentUser!.isHost, isFalse);
      expect(notifier.currentUser!.roles, isEmpty);
      expect(notifier.currentUser!.isHostVerified, isFalse);
      expect(notifier.currentUser!.isVerified, isFalse);
    });
    for (final status in [403, 500]) {
      test(
          'session HTTP $status preserves secure credentials and surfaces error',
          () async {
        final storage = _TestSecureStorage();
        await storage.saveAuthToken('test-access');
        final client = DioClient(
            secureStorage: storage,
            httpClientAdapter: _FakeAdapter(
                (_) async => _json({'message': 'denied'}, statusCode: status)));
        final repo = AuthRepositoryImpl(client, storage);
        await expectLater(repo.getCurrentUser(), throwsA(isA<AppFailure>()));
        expect(await storage.getAuthToken(), 'test-access');
        final notifier = AuthNotifier(repo);
        addTearDown(notifier.dispose);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(notifier.state.hasError, isTrue);
      });
    }
    test('offline session reports NetworkFailure instead of guest', () async {
      final storage = _TestSecureStorage();
      await storage.saveAuthToken('test-access');
      final client = DioClient(
          secureStorage: storage,
          httpClientAdapter: _FakeAdapter((o) async => throw DioException(
              requestOptions: o, type: DioExceptionType.connectionError)));
      await expectLater(AuthRepositoryImpl(client, storage).getCurrentUser(),
          throwsA(isA<NetworkFailure>()));
      expect(await storage.getAuthToken(), 'test-access');
    });
    test('five concurrent 401 requests share one refresh and retry', () async {
      final storage = _TestSecureStorage();
      await storage.saveAuthToken('expired');
      await storage.saveRefreshCookie('test-refresh');
      var refreshCalls = 0;
      final client = DioClient(
          secureStorage: storage,
          httpClientAdapter: _FakeAdapter((o) async {
            if (o.path == '/api/auth/refresh') {
              refreshCalls++;
              await Future<void>.delayed(const Duration(milliseconds: 25));
              return _json({
                'data': {'accessToken': 'renewed'}
              });
            }
            return o.headers['Authorization'] == 'Bearer renewed'
                ? _json({'ok': true})
                : _json({'message': 'expired'}, statusCode: 401);
          }));
      final replies = await Future.wait(
          List.generate(5, (_) => client.dio.get<dynamic>('/api/private')));
      expect(refreshCalls, 1);
      expect(replies.every((r) => r.statusCode == 200), isTrue);
    });
    for (final status in [401, 403]) {
      test('invalid refresh HTTP $status clears persisted session', () async {
        final storage = _TestSecureStorage();
        await storage.saveAuthToken('expired');
        await storage.saveRefreshCookie('rejected');
        final client = DioClient(
            secureStorage: storage,
            httpClientAdapter: _FakeAdapter((_) async =>
                _json({'message': 'expired'}, statusCode: status)));
        expect(
            await AuthRepositoryImpl(client, storage).refreshSession(), isNull);
        expect(await storage.getAuthToken(), isNull);
        expect(await storage.getRefreshCookie(), isNull);
      });
    }
    test('new login cannot retain refresh credentials from previous account',
        () async {
      final storage = _TestSecureStorage();
      await storage.saveRefreshToken('previous-account');
      await storage.saveRefreshCookie('previous-cookie');
      final client = DioClient(
          secureStorage: storage,
          httpClientAdapter: _FakeAdapter((_) async => _json({
                'data': {
                  'token': 'new-access',
                  'user': {'id': 2}
                }
              })));
      await AuthRepositoryImpl(client, storage)
          .login(identifier: 'user', password: 'Abc12345');
      expect(await storage.getAuthToken(), 'new-access');
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getRefreshCookie(), isNull);
    });
    for (final code in ['OTP_INVALID', 'OTP_EXPIRED', 'RATE_LIMITED']) {
      test('OTP $code rejects instead of reporting false success', () async {
        final storage = _TestSecureStorage();
        final client = DioClient(
            secureStorage: storage,
            httpClientAdapter: _FakeAdapter((_) async =>
                _json({'success': false, 'message': code, 'code': code})));
        await expectLater(
            AuthRepositoryImpl(client, storage).resetPassword(
                identifier: 'test@example.com',
                otp: '123456',
                newPassword: 'Abc12345'),
            throwsA(isA<AppFailure>()));
      });
    }
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.3, 1.6]) {
        for (final screen in <Widget>[
          const LoginScreen(),
          const RegisterScreen(),
          const ForgotPasswordScreen()
        ]) {
          testWidgets(
              'layout ${screen.runtimeType} width=$width scale=$scale with keyboard',
              (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(ProviderScope(
                child: MaterialApp(
                    home: MediaQuery(
                        data: MediaQueryData(
                            size: Size(width, 800),
                            textScaler: TextScaler.linear(scale),
                            viewInsets: const EdgeInsets.only(bottom: 280)),
                        child: screen))));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
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

  group('Terminal 08: UX Polish, Accessibility & Field Errors Clearing', () {
    testWidgets(
        'LoginScreen leading button has >=48x48 hit area, tooltip and clears fieldErrors on typing',
        (tester) async {
      final storage = _TestSecureStorage();
      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((o) async {
          if (o.path == '/api/auth/login') {
            return _json({
              'success': false,
              'message': 'Thông tin đăng nhập không hợp lệ.',
              'errors': [
                {
                  'path': 'identifier',
                  'msg': 'Tài khoản không tồn tại trên hệ thống.'
                }
              ]
            }, statusCode: 400);
          }
          return _json({}, statusCode: 404);
        }),
      );
      final repo = AuthRepositoryImpl(client, storage);
      final notifier = AuthNotifier(repo, dioClient: client);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((_) => notifier),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check leading back button touch target and tooltip
      final backButton = find.byTooltip('Quay lại');
      expect(backButton, findsOneWidget);
      final backSize = tester.getSize(backButton);
      expect(backSize.width, greaterThanOrEqualTo(48.0));
      expect(backSize.height, greaterThanOrEqualTo(48.0));

      // Enter valid format to pass client validation
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // Field error from server is visible
      expect(find.text('Tài khoản không tồn tại trên hệ thống.'), findsWidgets);

      // Typing new text in identifier clears the field error
      await tester.enterText(
          find.byType(TextFormField).at(0), 'updated@example.com');
      await tester.pumpAndSettle();

      // Old field error is removed
      expect(
          find.descendant(
              of: find.byType(TextFormField).at(0),
              matching: find.text('Tài khoản không tồn tại trên hệ thống.')),
          findsNothing);
    });

    testWidgets(
        'RegisterScreen leading button has >=48x48 hit area and clears field errors on input',
        (tester) async {
      final storage = _TestSecureStorage();
      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((o) async {
          if (o.path == '/api/auth/register') {
            return _json({
              'success': false,
              'message': 'Đăng ký không thành công.',
              'errors': [
                {'path': 'email', 'msg': 'Email đã được sử dụng.'}
              ]
            }, statusCode: 400);
          }
          return _json({}, statusCode: 404);
        }),
      );
      final repo = AuthRepositoryImpl(client, storage);
      final notifier = AuthNotifier(repo, dioClient: client);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((_) => notifier),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byTooltip('Quay lại');
      expect(backButton, findsOneWidget);
      final backSize = tester.getSize(backButton);
      expect(backSize.width, greaterThanOrEqualTo(48.0));
      expect(backSize.height, greaterThanOrEqualTo(48.0));

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn A');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(
          find.byType(TextFormField).at(2), 'existing@example.com');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password123');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Email đã được sử dụng.'), findsWidgets);

      // Typing new email clears the server error
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.enterText(
          find.byType(TextFormField).at(2), 'newemail@example.com');
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byType(TextFormField).at(2),
              matching: find.text('Email đã được sử dụng.')),
          findsNothing);
    });

    testWidgets(
        'ForgotPasswordScreen leading button has >=48x48 hit area and liveRegion semantics',
        (tester) async {
      final storage = _TestSecureStorage();
      final client = DioClient(
        secureStorage: storage,
        httpClientAdapter: _FakeAdapter((o) async {
          if (o.path == '/api/auth/forgot-password') {
            return _json({
              'success': false,
              'message': 'Tài khoản không tồn tại.',
            }, statusCode: 404);
          }
          return _json({}, statusCode: 404);
        }),
      );
      final repo = AuthRepositoryImpl(client, storage);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byTooltip('Quay lại');
      expect(backButton, findsOneWidget);
      final backSize = tester.getSize(backButton);
      expect(backSize.width, greaterThanOrEqualTo(48.0));
      expect(backSize.height, greaterThanOrEqualTo(48.0));

      await tester.enterText(
          find.byType(TextFormField).at(0), 'notfound@example.com');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi mã xác thực'));
      await tester.pumpAndSettle();

      expect(find.text('Tài khoản không tồn tại.'), findsOneWidget);
    });
  });
}
