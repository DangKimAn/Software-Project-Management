import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/settings/domain/account_profile_models.dart';
import 'package:hotel_booking_flutter/features/settings/presentation/screens/settings_screen.dart';
import 'package:hotel_booking_flutter/features/settings/presentation/view_models/account_settings_view_model.dart';
import 'package:hotel_booking_flutter/features/settings/services/avatar_upload_service.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_semantic_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthRepository implements AuthRepository {
  User? currentUserResponse;
  Object? getCurrentUserError;
  Object? updateProfileError;
  Object? updateAvatarError;
  Completer<User>? updateProfileCompleter;

  int updateProfileCallCount = 0;
  int updateAvatarCallCount = 0;
  int logoutCallCount = 0;

  Map<String, dynamic>? lastUpdateProfilePayload;
  Map<String, dynamic>? lastUpdateAvatarPayload;

  FakeAuthRepository({this.currentUserResponse});

  @override
  Future<User?> getCurrentUser() async {
    if (getCurrentUserError != null) {
      throw getCurrentUserError!;
    }
    return currentUserResponse;
  }

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
  }) async {
    updateProfileCallCount += 1;
    lastUpdateProfilePayload = <String, dynamic>{
      'fullName': fullName,
      'phone': phone,
      'bio': bio,
      'location': location,
      'job': job,
      'dreamDestination': dreamDestination,
      'school': school,
      'languages': languages,
      'avatarUrl': avatarUrl,
    };

    if (updateProfileCompleter != null) {
      return updateProfileCompleter!.future;
    }

    if (updateProfileError != null) {
      throw updateProfileError!;
    }

    final base = currentUserResponse ??
        const User(
          id: 'user-1',
          email: 'guest@example.com',
          firstName: 'Minh',
          lastName: 'Thanh',
        );
    final split = User.splitFullName(fullName ?? base.fullName);
    final updated = base.copyWith(
      firstName: split.firstName,
      lastName: split.lastName,
      phone: phone ?? base.phone,
      bio: bio ?? base.bio,
      location: location ?? base.location,
      job: job ?? base.job,
      dreamDestination: dreamDestination ?? base.dreamDestination,
      school: school ?? base.school,
      languages: languages ?? base.languages,
      avatarUrl: avatarUrl ?? base.avatarUrl,
    );
    currentUserResponse = updated;
    return updated;
  }

  @override
  Future<User> updateAvatar({required String url, String? key}) async {
    updateAvatarCallCount += 1;
    lastUpdateAvatarPayload = <String, dynamic>{
      'url': url,
      'key': key,
    };
    if (updateAvatarError != null) {
      throw updateAvatarError!;
    }
    final base = currentUserResponse ??
        const User(
          id: 'user-1',
          email: 'guest@example.com',
          firstName: 'Minh',
          lastName: 'Thanh',
        );
    final updated = base.copyWith(avatarUrl: url);
    currentUserResponse = updated;
    return updated;
  }

  @override
  Future<void> logout() async {
    logoutCallCount += 1;
    currentUserResponse = null;
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> forgotPassword({required String identifier}) {
    throw UnimplementedError();
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }
}

class ControlledAuthNotifier extends AuthNotifier {
  bool _initialized = false;

  ControlledAuthNotifier(
    super.repository, {
    super.prefs,
    AsyncValue<User?>? initialState,
  }) {
    _initialized = true;
    if (initialState != null) {
      state = initialState;
    }
  }

  @override
  Future<void> checkCurrentUser() async {
    if (!_initialized) return;
    await super.checkCurrentUser();
  }

  void emitState(AsyncValue<User?> next) {
    state = next;
  }
}

class FakeAvatarPickerService implements AvatarPickerService {
  AvatarPickedFile? fileToReturn;
  AvatarPickException? exceptionToThrow;
  int pickCallCount = 0;

  FakeAvatarPickerService({
    this.fileToReturn,
    this.exceptionToThrow,
  });

  @override
  Future<AvatarPickedFile?> pickAvatarFromDevice({
    ImageSource source = ImageSource.gallery,
  }) async {
    pickCallCount += 1;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return fileToReturn;
  }
}

class FakeAvatarUploadService extends AvatarUploadService {
  AvatarR2PresignResult? resultToReturn;
  Object? errorToThrow;
  int uploadCallCount = 0;
  AvatarPickedFile? lastUploadedFile;

  FakeAvatarUploadService({
    this.resultToReturn,
    this.errorToThrow,
  }) : super(apiDio: Dio());

  @override
  Future<AvatarR2PresignResult> uploadAvatarToR2(AvatarPickedFile file) async {
    uploadCallCount += 1;
    lastUploadedFile = file;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return resultToReturn ??
        const AvatarR2PresignResult(
          uploadUrl: 'https://r2.example.com/upload-presigned',
          publicUrl: 'https://cdn.example.com/avatars/new-avatar.jpg',
          key: 'avatars/new-avatar.jpg',
        );
  }
}

class FakeAccountSyncNotifier extends AccountSyncNotifier {
  int refreshCallCount = 0;
  AccountSyncState? nextStateOnRefresh;

  FakeAccountSyncNotifier(super.ref, {AccountSyncState? initial}) {
    if (initial != null) {
      state = initial;
    }
  }

  void emitSyncState(AccountSyncState next) {
    state = next;
  }

  @override
  Future<void> refreshProfile() async {
    refreshCallCount += 1;
    if (nextStateOnRefresh != null) {
      state = nextStateOnRefresh!;
    }
  }
}

Uint8List _validJpegBytes({int length = 128}) {
  final bytes = Uint8List(length);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  bytes[3] = 0xE0;
  return bytes;
}

Widget _buildTestRouterApp({
  required List<Override> overrides,
  List<String>? pushedLocations,
  Size surfaceSize = const Size(390, 844),
  double textScale = 1.0,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  final recorded = pushedLocations ?? <String>[];
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/dang-nhap',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return Scaffold(
            appBar: AppBar(title: const Text('Đăng nhập')),
            body: Text('LOGIN_ROUTE:${state.uri}'),
          );
        },
      ),
      GoRoute(
        path: '/account/trips',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return Scaffold(
            appBar: AppBar(title: const Text('Chuyến đi')),
            body: const Text('TRIPS_ROUTE'),
          );
        },
      ),
      GoRoute(
        path: '/yeu-thich',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return Scaffold(
            appBar: AppBar(title: const Text('Yêu thích')),
            body: const Text('FAVORITES_ROUTE'),
          );
        },
      ),
      GoRoute(
        path: '/gio-cho-dat',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('CART_ROUTE'));
        },
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('MESSAGES_ROUTE'));
        },
      ),
      GoRoute(
        path: '/tro-thanh-host',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('BECOME_HOST_ROUTE'));
        },
      ),
      GoRoute(
        path: '/tro-thanh-host/trang-thai',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('HOST_STATUS_ROUTE'));
        },
      ),
      GoRoute(
        path: '/chu-nha/cho-nghi',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('HOST_PORTAL_ROUTE'));
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('ADMIN_PORTAL_ROUTE'));
        },
      ),
      GoRoute(
        path: '/lien-he',
        builder: (context, state) {
          recorded.add(state.uri.toString());
          return const Scaffold(body: Text('CONTACT_ROUTE'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            size: surfaceSize,
            textScaler: TextScaler.linear(textScale),
            viewInsets: viewInsets,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

void main() {
  late SharedPreferences sharedPrefs;
  late PreferencesService preferencesService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefs = await SharedPreferences.getInstance();
    preferencesService = PreferencesService(sharedPrefs);
  });

  group('Domain & Service Validation Tests', () {
    test(
        'validateProfileDraft enforces fullName, phone, lengths, languages, and URL rules',
        () {
      const invalidDraft = ProfileDraftData(
        userId: 'u1',
        fullName: '   ',
        phone: '12345',
        bio: 'ok',
        location: 'Vung Tau',
        dreamDestination: 'Da Lat',
        job: 'Architect',
        school: 'HCMUT',
        languages: 'Vietnamese, English',
        avatarUrl: 'ftp://invalid-scheme.com/a.png',
      );
      final res1 = validateProfileDraft(invalidDraft);
      expect(res1.isValid, isFalse);
      expect(res1.fieldErrors['fullName'], isNotNull);
      expect(res1.fieldErrors['phone'], isNotNull);
      expect(res1.fieldErrors['avatarUrl'], isNotNull);

      final tooManyLangs =
          List<String>.generate(21, (i) => 'Lang$i').join(', ');
      final longBio = 'a' * 2001;
      final res2 = validateProfileDraft(
        invalidDraft.copyWith(
          fullName: 'Nguyen Van A',
          phone: '+84912345678',
          avatarUrl: 'https://cdn.example.com/a.jpg',
          languages: tooManyLangs,
          bio: longBio,
        ),
      );
      expect(res2.isValid, isFalse);
      expect(res2.fieldErrors['languages'], isNotNull);
      expect(res2.fieldErrors['bio'], isNotNull);

      final validRes = validateProfileDraft(
        invalidDraft.copyWith(
          fullName: 'Nguyen Van A',
          phone: '0912345678',
          avatarUrl: 'https://cdn.example.com/a.jpg',
          languages: 'Tiếng Việt, English',
          bio: 'Yêu thích du lịch nghỉ dưỡng biển.',
        ),
      );
      expect(validRes.isValid, isTrue);
      expect(validRes.fieldErrors, isEmpty);
    });

    test('ProfileDraftData.toString redacts PII (fullName and phone)', () {
      const draft = ProfileDraftData(
        userId: 'user-secret-1',
        fullName: 'Sensitive Full Name',
        phone: '0988777666',
        bio: '',
        location: '',
        dreamDestination: '',
        job: '',
        school: '',
        languages: '',
        avatarUrl: '',
      );
      final str = draft.toString();
      expect(str, contains('user-secret-1'));
      expect(str, isNot(contains('Sensitive Full Name')));
      expect(str, isNot(contains('0988777666')));
      expect(str, contains('[REDACTED]'));
    });

    test(
        'AvatarUploadService validates 5MB limit and uploads via presign + clean PUT without Authorization header',
        () async {
      Map<String, dynamic>? capturedPresignBody;
      Map<String, dynamic>? capturedPutHeaders;

      final apiDio = Dio();
      apiDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/uploads/presign') {
              capturedPresignBody =
                  Map<String, dynamic>.from(options.data as Map);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'success': true,
                    'data': <String, dynamic>{
                      'uploadUrl':
                          'https://r2.minhthanh.vn/avatars/u1.jpg?sig=1',
                      'publicUrl': 'https://cdn.minhthanh.vn/avatars/u1.jpg',
                      'key': 'avatars/u1.jpg',
                      'expiresIn': 300,
                    },
                  },
                ),
              );
              return;
            }
            handler.next(options);
          },
        ),
      );

      final r2Dio = Dio();
      r2Dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPutHeaders = Map<String, dynamic>.from(options.headers);
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data: '',
              ),
            );
          },
        ),
      );

      final service = AvatarUploadService(
        apiDio: apiDio,
        cleanR2Dio: r2Dio,
      );

      // 1. Oversized file (> 5MB) must throw AvatarPickException(fileTooLarge)
      final oversizedFile = AvatarPickedFile(
        name: 'huge.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: kMaxAvatarFileSizeBytes + 1024,
        bytes: Uint8List(kMaxAvatarFileSizeBytes + 1024),
      );
      await expectLater(
        () => service.uploadAvatarToR2(oversizedFile),
        throwsA(
          isA<AvatarPickException>().having(
            (e) => e.code,
            'code',
            AvatarPickErrorCode.fileTooLarge,
          ),
        ),
      );

      // 2. Valid JPEG file uploads via presign and PUT without Authorization header
      final validFile = AvatarPickedFile(
        name: 'avatar.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 256,
        bytes: _validJpegBytes(length: 256),
      );
      final result = await service.uploadAvatarToR2(validFile);
      expect(result.publicUrl, 'https://cdn.minhthanh.vn/avatars/u1.jpg');
      expect(result.key, 'avatars/u1.jpg');
      expect(capturedPresignBody?['folder'], 'avatars');
      expect(capturedPresignBody?['contentType'], 'image/jpeg');
      expect(capturedPutHeaders, isNotNull);
      expect(capturedPutHeaders!.containsKey('Authorization'), isFalse);
      expect(capturedPutHeaders!.containsKey('authorization'), isFalse);
    });
  });

  group('SettingsScreen Modes, Async States & 401/403/Offline/500 Retry', () {
    testWidgets('shows loading state when authState is loading',
        (tester) async {
      final repo = FakeAuthRepository(currentUserResponse: null);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.loading(),
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings_loading_state')), findsOneWidget);
      expect(find.byKey(const Key('settings_logged_out_card')), findsNothing);
    });

    testWidgets(
        'renders logged-out view and redirects protected menu items to /dang-nhap with redirectTo',
        (tester) async {
      final repo = FakeAuthRepository(currentUserResponse: null);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(null),
      );
      final pushed = <String>[];

      await tester.pumpWidget(
        _buildTestRouterApp(
          pushedLocations: pushed,
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_logged_out_card')), findsOneWidget);
      expect(find.text('Chưa đăng nhập'), findsOneWidget);

      // Tapping protected "Chuyến đi của tôi" while logged out guards route -> /dang-nhap?redirectTo=/account/trips
      await tester.tap(find.byKey(const Key('menu_trips_history')));
      await tester.pumpAndSettle();
      expect(
        pushed.last,
        '/dang-nhap?redirectTo=%2Faccount%2Ftrips',
      );
    });

    testWidgets(
        'distinguishes offline NetworkFailure vs 500 ServerFailure vs 401/403 AuthFailure and triggers real retry',
        (tester) async {
      final repo = FakeAuthRepository(currentUserResponse: null);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(null),
      );
      late FakeAccountSyncNotifier syncNotifier;

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
            accountSyncNotifierProvider.overrideWith((ref) {
              syncNotifier = FakeAccountSyncNotifier(
                ref,
                initial: const AccountSyncState(
                  status: AccountSyncStatus.offline,
                  message:
                      'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng.',
                ),
              );
              return syncNotifier;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 1. Offline banner
      expect(find.byKey(const Key('settings_offline_banner')), findsOneWidget);
      expect(find.text('Thiết bị đang ngoại tuyến'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_retry_button')));
      await tester.pump();
      expect(syncNotifier.refreshCallCount, 1);

      // 2. 500 Server error banner (never mislabeled as offline)
      syncNotifier.emitSyncState(
        const AccountSyncState(
          status: AccountSyncStatus.error,
          message: 'Lỗi hệ thống máy chủ (500). Vui lòng thử lại sau.',
          errorCode: 'INTERNAL_SERVER_ERROR',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_error_banner')), findsOneWidget);
      expect(find.text('Không thể đồng bộ dữ liệu máy chủ'), findsOneWidget);
      expect(find.text('Thiết bị đang ngoại tuyến'), findsNothing);

      // 3. 401/403 Unauthorized / Forbidden banner
      syncNotifier.emitSyncState(
        const AccountSyncState(
          status: AccountSyncStatus.unauthorized,
          message: 'Phiên đăng nhập đã hết hạn (401). Vui lòng đăng nhập lại.',
          errorCode: 'UNAUTHORIZED',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_unauthorized_banner')),
          findsOneWidget);
      expect(find.byKey(const Key('settings_relogin_button')), findsOneWidget);
    });

    testWidgets(
        'renders real isVerified status and role menus for guest, new host, verified host, and admin',
        (tester) async {
      const unverifiedGuest = User(
        id: 'u-guest',
        email: 'guest@minhthanh.vn',
        firstName: 'Khách',
        lastName: 'Chưa Xác Minh',
        role: 'guest',
        isVerified: false,
      );
      final repo = FakeAuthRepository(currentUserResponse: unverifiedGuest);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(unverifiedGuest),
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Unverified guest
      expect(find.text('Khách lưu trú'), findsOneWidget);
      expect(find.textContaining('Chưa xác minh'), findsOneWidget);
      expect(find.byKey(const Key('menu_become_host')), findsOneWidget);
      expect(find.byKey(const Key('menu_admin_portal')), findsNothing);

      // Switch to New Host (pending host application) with isVerified: true
      const pendingHost = User(
        id: 'u-newhost',
        email: 'newhost@minhthanh.vn',
        firstName: 'Chủ Nhà',
        lastName: 'Mới',
        role: 'host new',
        roles: <String>['host new'],
        isVerified: true,
      );
      authNotifier.emitState(const AsyncValue.data(pendingHost));
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ Chủ nhà đang chờ duyệt'), findsOneWidget);
      expect(find.textContaining('Đã xác minh'), findsOneWidget);
      expect(find.byKey(const Key('menu_host_status')), findsOneWidget);

      // Switch to Approved Host
      const approvedHost = User(
        id: 'u-host',
        email: 'host@minhthanh.vn',
        firstName: 'Chủ Nhà',
        lastName: 'Chính Thức',
        role: 'host',
        roles: <String>['host'],
        isVerified: true,
      );
      authNotifier.emitState(const AsyncValue.data(approvedHost));
      await tester.pumpAndSettle();

      expect(find.text('Chủ nhà (Host)'), findsOneWidget);
      expect(find.byKey(const Key('menu_host_portal')), findsOneWidget);

      // Switch to Admin
      const adminUser = User(
        id: 'u-admin',
        email: 'admin@minhthanh.vn',
        firstName: 'Quản',
        lastName: 'Trị',
        role: 'admin',
        roles: <String>['admin'],
        isVerified: true,
      );
      authNotifier.emitState(const AsyncValue.data(adminUser));
      await tester.pumpAndSettle();

      expect(find.text('Quản trị viên (Admin)'), findsOneWidget);
      expect(find.byKey(const Key('menu_admin_portal')), findsOneWidget);
      expect(find.byKey(const Key('menu_become_host')), findsNothing);
      expect(find.text('Dành cho chủ nhà'), findsNothing);
    });
  });

  group('Profile Update, Draft Preservation, Double-Submit & PII Isolation',
      () {
    testWidgets(
        'preserves draft on 422/500/offline failure, does not write fake local profile, and prevents double-submit',
        (tester) async {
      const userA = User(
        id: 'user-a',
        email: 'usera@minhthanh.vn',
        firstName: 'Nguyễn',
        lastName: 'Văn A',
        location: 'TP.HCM',
      );
      final repo = FakeAuthRepository(currentUserResponse: userA);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(userA),
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Profile modal
      await tester.tap(find.byKey(const Key('settings_edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_profile_full_name_input')),
        'Nguyễn Văn A Updated',
      );
      await tester.enterText(
        find.byKey(const Key('edit_profile_location_input')),
        'Vũng Tàu',
      );

      // Simulate 422 ValidationFailure from backend
      repo.updateProfileError = const ValidationFailure(
        'Số điện thoại hoặc thông tin hồ sơ chưa hợp lệ (422).',
        code: 'VALIDATION_ERROR',
        fieldErrors: <ApiFieldError>[
          ApiFieldError(
            path: 'location',
            msg: 'Địa điểm không hợp lệ trên máy chủ.',
          ),
        ],
      );

      final saveBtn = find.byKey(const Key('edit_profile_save_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Error banner shown, modal stays open, SharedPreferences was NOT written
      expect(
          find.byKey(const Key('edit_profile_error_banner')), findsOneWidget);
      expect(
        find.text('Địa điểm không hợp lệ trên máy chủ.'),
        findsOneWidget,
      );
      expect(preferencesService.getAccountProfile('user-a'), isEmpty);

      // Close modal -> unsaved draft banner appears on profile card
      await tester.tap(find.byKey(const Key('edit_profile_close_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings_unsaved_draft_banner')),
        findsOneWidget,
      );

      // Re-open Edit Profile modal -> draft values are preserved!
      await tester.tap(find.byKey(const Key('settings_resume_draft_button')));
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('edit_profile_full_name_input')),
      );
      expect(nameField.controller?.text, 'Nguyễn Văn A Updated');

      // Test double-submit prevention with in-flight Completer
      repo.updateProfileError = null;
      final completer = Completer<User>();
      repo.updateProfileCompleter = completer;
      repo.updateProfileCallCount = 0;

      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump();
      // Attempt second tap while first request is still in-flight
      await tester.tap(saveBtn, warnIfMissed: false);
      await tester.pump();

      expect(repo.updateProfileCallCount, 1);

      completer.complete(
        userA.copyWith(
          firstName: 'Nguyễn Văn A',
          lastName: 'Updated',
          location: 'Vũng Tàu',
        ),
      );
      await tester.pumpAndSettle();

      // Modal closed, draft cleared, UI updated
      expect(
        find.byKey(const Key('settings_unsaved_draft_banner')),
        findsNothing,
      );
      expect(find.text('Nguyễn Văn A Updated'), findsOneWidget);
    });

    testWidgets(
        'clears User A unsaved draft when switching to User B (strict PII isolation)',
        (tester) async {
      const userA = User(
        id: 'user-a',
        email: 'usera@minhthanh.vn',
        firstName: 'User',
        lastName: 'Alpha',
        phone: '0911222333',
      );
      const userB = User(
        id: 'user-b',
        email: 'userb@minhthanh.vn',
        firstName: 'User',
        lastName: 'Beta',
        phone: '0999888777',
      );

      final repo = FakeAuthRepository(currentUserResponse: userA);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(userA),
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Create an unsaved draft for User A
      await tester.tap(find.byKey(const Key('settings_edit_profile_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit_profile_full_name_input')),
        'Secret Alpha Draft Name',
      );
      await tester.tap(find.byKey(const Key('edit_profile_close_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings_unsaved_draft_banner')),
        findsOneWidget,
      );

      // Switch active session to User B
      repo.currentUserResponse = userB;
      authNotifier.emitState(const AsyncValue.data(userB));
      await tester.pumpAndSettle();

      // User A's draft banner and PII must NOT be visible to User B
      expect(
        find.byKey(const Key('settings_unsaved_draft_banner')),
        findsNothing,
      );
      expect(find.text('User Beta'), findsOneWidget);
      expect(find.text('User Alpha'), findsNothing);

      // Opening Edit Profile for User B must show User B's data, never User A's draft
      await tester.tap(find.byKey(const Key('settings_edit_profile_button')));
      await tester.pumpAndSettle();

      final nameFieldB = tester.widget<TextField>(
        find.byKey(const Key('edit_profile_full_name_input')),
      );
      expect(nameFieldB.controller?.text, 'User Beta');
    });
  });

  group('Avatar Picker & Upload Modal Tests', () {
    testWidgets(
        'handles picker cancel, permission denied, >5MB file, and successful device upload',
        (tester) async {
      const user = User(
        id: 'user-avatar-1',
        email: 'avatar@minhthanh.vn',
        firstName: 'Minh',
        lastName: 'Thanh',
      );
      final repo = FakeAuthRepository(currentUserResponse: user);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(user),
      );
      final fakePicker = FakeAvatarPickerService();
      final fakeUploader = FakeAvatarUploadService();

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
            avatarPickerServiceProvider.overrideWithValue(fakePicker),
            avatarUploadServiceProvider.overrideWithValue(fakeUploader),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings_change_avatar_button')));
      await tester.pumpAndSettle();

      // 1. User cancels image picker -> returns null, no error shown
      fakePicker.fileToReturn = null;
      fakePicker.exceptionToThrow = null;
      await tester.tap(find.byKey(const Key('avatar_pick_device_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('avatar_modal_error_banner')), findsNothing);
      expect(fakeUploader.uploadCallCount, 0);

      // 2. Permission denied -> shows clear error banner
      fakePicker.exceptionToThrow = AvatarPickException.permissionDenied();
      await tester.tap(find.byKey(const Key('avatar_pick_device_button')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('avatar_modal_error_banner')), findsOneWidget);
      expect(
        find.textContaining('quyền truy cập thư viện ảnh'),
        findsOneWidget,
      );

      // 3. Large image (> 5MB) -> shows 5MB limit error banner
      fakePicker.exceptionToThrow =
          AvatarPickException.fileTooLarge(6 * 1024 * 1024);
      await tester.tap(find.byKey(const Key('avatar_pick_device_button')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('avatar_modal_error_banner')), findsOneWidget);
      expect(
          find.textContaining('vượt quá giới hạn tối đa 5MB'), findsOneWidget);

      // 4. Valid image -> uploads to R2 and calls PATCH /api/users/me/avatar
      fakePicker.exceptionToThrow = null;
      fakePicker.fileToReturn = AvatarPickedFile(
        name: 'my_avatar.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
        bytes: _validJpegBytes(length: 1024),
      );
      await tester.tap(find.byKey(const Key('avatar_pick_device_button')));
      await tester.pumpAndSettle();

      expect(fakeUploader.uploadCallCount, 1);
      expect(repo.updateAvatarCallCount, 1);
      expect(
        repo.lastUpdateAvatarPayload?['url'],
        'https://cdn.example.com/avatars/new-avatar.jpg',
      );
      expect(
        repo.lastUpdateAvatarPayload?['key'],
        'avatars/new-avatar.jpg',
      );
    });
  });

  group('Logout Confirmation Dialog & Responsive Layout', () {
    testWidgets('prompts confirmation before logout and cancels or confirms',
        (tester) async {
      const user = User(
        id: 'user-logout',
        email: 'logout@minhthanh.vn',
        firstName: 'Minh',
        lastName: 'Thanh',
      );
      final repo = FakeAuthRepository(currentUserResponse: user);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(user),
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          overrides: [
            preferencesServiceProvider.overrideWithValue(preferencesService),
            authRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith((ref) => authNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final logoutBtn = find.byKey(const Key('settings_bottom_logout_button'));
      await tester.ensureVisible(logoutBtn);
      expect(
        find.descendant(
          of: logoutBtn,
          matching: find.byIcon(AppSemanticIcons.logout),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: logoutBtn,
          matching: find.byIcon(LucideIcons.doorOpen),
        ),
        findsOneWidget,
      );
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.byKey(const Key('logout_confirm_dialog')), findsOneWidget);

      // Tap Cancel -> stays signed in
      await tester.tap(find.byKey(const Key('logout_cancel_btn')));
      await tester.pumpAndSettle();
      expect(repo.logoutCallCount, 0);
      expect(find.byKey(const Key('settings_signed_in_card')), findsOneWidget);

      // Tap Logout again and Confirm -> logs out and transitions to logged-out view
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout_confirm_btn')));
      await tester.pumpAndSettle();

      expect(repo.logoutCallCount, 1);
      expect(find.byKey(const Key('settings_logged_out_card')), findsOneWidget);
    });

    testWidgets(
        'renders cleanly without overflow across 320/360/390/430dp widths, text scale 1.0/1.3/1.6, and keyboard insets',
        (tester) async {
      const user = User(
        id: 'user-responsive',
        email: 'very.long.email.address.for.responsive.testing@minhthanh.vn',
        firstName: 'Nguyễn Hoàng Minh',
        lastName: 'Thành Villa Vũng Tàu',
        phone: '0912345678',
        role: 'admin',
        roles: <String>['admin', 'host'],
        isVerified: true,
        location: 'Thành phố Vũng Tàu, Tỉnh Bà Rịa - Vũng Tàu',
        job: 'Quản lý vận hành chuỗi biệt thự nghỉ dưỡng cao cấp',
        dreamDestination: 'Santorini, Hy Lạp & Kyoto, Nhật Bản',
        school: 'Đại học Bách Khoa TP. Hồ Chí Minh',
        languages: <String>['Tiếng Việt', 'English', '한국어'],
        bio:
            'Chào mừng bạn đến với hệ thống biệt thự nghỉ dưỡng Minh Thanh Villa.',
      );
      final repo = FakeAuthRepository(currentUserResponse: user);
      final authNotifier = ControlledAuthNotifier(
        repo,
        prefs: preferencesService,
        initialState: const AsyncValue.data(user),
      );

      const widths = <double>[320, 360, 390, 430];
      const textScales = <double>[1.0, 1.3, 1.6];

      for (final width in widths) {
        for (final scale in textScales) {
          await tester.pumpWidget(
            _buildTestRouterApp(
              surfaceSize: Size(width, 844),
              textScale: scale,
              viewInsets: const EdgeInsets.only(bottom: 280),
              overrides: [
                preferencesServiceProvider
                    .overrideWithValue(preferencesService),
                authRepositoryProvider.overrideWithValue(repo),
                authNotifierProvider.overrideWith((ref) => authNotifier),
              ],
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason:
                'Expected zero layout overflow at width=$width, textScale=$scale',
          );
        }
      }
    });
  });
}
