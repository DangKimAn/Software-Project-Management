import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/screens/admin_portal_screens.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';

typedef _AdapterHandler = ResponseBody Function(RequestOptions options);

class _MockDioAdapter implements HttpClientAdapter {
  _MockDioAdapter(this._handler);

  final _AdapterHandler _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Object body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository(this._user);

  final User? _user;

  @override
  Future<User?> getCurrentUser() async => _user;

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

Widget _buildTestPortal({
  required String activeTab,
  required AdminRepository repository,
  User? actor,
  Size surfaceSize = const Size(1280, 900),
  double textScale = 1.0,
}) {
  final authRepo = _StubAuthRepository(actor);
  return ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repository),
      authRepositoryProvider.overrideWithValue(authRepo),
      authNotifierProvider.overrideWith((ref) => AuthNotifier(authRepo)),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: AdminPortalScreen(activeTab: activeTab),
      ),
    ),
  );
}

void main() {
  group('AdminRepository — Error classification, KYC masking & pagination', () {
    test(
      'distinguishes offline network error from HTTP 500/403/409/422 and redacts sensitive tokens',
      () {
        final req = RequestOptions(path: '/api/admin/reports/revenue');

        final offlineErr = DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
          message: 'SocketException: Failed host lookup',
        );
        expect(AdminRepository.isOfflineError(offlineErr), isTrue);
        expect(
          AdminRepository.extractErrorMessage(offlineErr),
          contains('Không thể kết nối máy chủ'),
        );

        final server500 = DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 500,
            data: {'message': 'Internal database failure'},
          ),
        );
        expect(AdminRepository.isOfflineError(server500), isFalse);
        expect(AdminRepository.extractStatusCode(server500), 500);
        expect(
          AdminRepository.extractErrorMessage(server500),
          'Internal database failure',
        );

        final conflict409 = DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 409,
            data: {'message': 'Listing is not pending approval'},
          ),
        );
        expect(AdminRepository.isOfflineError(conflict409), isFalse);
        expect(AdminRepository.extractStatusCode(conflict409), 409);
        expect(
          AdminRepository.extractErrorMessage(conflict409),
          'Listing is not pending approval',
        );

        final validation422 = DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 422,
            data: {
              'details': [
                {'message': 'Reason must not be empty'},
                {'msg': 'Invalid status transition'},
              ],
            },
          ),
        );
        expect(AdminRepository.extractStatusCode(validation422), 422);
        expect(
          AdminRepository.extractErrorMessage(validation422),
          'Reason must not be empty; Invalid status transition',
        );

        final leakedTokenError = DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 400,
            data: {
              'message':
                  'Failed for Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret and https://r2.example.com/doc.jpg?X-Amz-Signature=abcdef123456',
            },
          ),
        );
        final sanitized = AdminRepository.extractErrorMessage(leakedTokenError);
        expect(
          sanitized,
          isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
        );
        expect(sanitized, isNot(contains('abcdef123456')));
        expect(sanitized, contains('[REDACTED]'));

        expect(AdminRepository.maskKycIdentifier('079099001234'), '***1234');
        expect(AdminRepository.maskKycIdentifier('***1234'), '***1234');
        expect(AdminRepository.maskKycIdentifier(''), '—');
      },
    );

    test(
      'supports paginated pending listings, host applications, and verifications',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/listings/pending') {
            return _jsonResponse({
              'success': true,
              'data': {
                'listings': [
                  {'listingId': '101', 'title': 'Villa A'},
                ],
                'pagination': {
                  'page': 2,
                  'limit': 10,
                  'total': 25,
                  'totalPages': 3,
                },
              },
            });
          }
          if (options.path == '/api/admin/host-applications') {
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {'applicationId': '201', 'status': 'pending'},
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 42,
                  'totalPages': 3,
                },
              },
            });
          }
          if (options.path == '/api/admin/verifications') {
            return _jsonResponse({
              'success': true,
              'data': {
                'verifications': [
                  {'verificationId': '301', 'status': 'pending'},
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        final repo = AdminRepository(dio);
        final listingsPage =
            await repo.getPendingListingsPaginated(page: 2, limit: 10);
        expect(listingsPage.page, 2);
        expect(listingsPage.total, 25);
        expect(listingsPage.totalPages, 3);
        expect(listingsPage.items.single['listingId'], '101');

        final appsPage =
            await repo.getAdminHostApplicationsPaginated(page: 1, limit: 20);
        expect(appsPage.total, 42);
        expect(appsPage.totalPages, 3);

        final verificationsPage =
            await repo.getAdminVerificationsPaginated(page: 1, limit: 20);
        expect(verificationsPage.total, 1);
        expect(verificationsPage.items.single['verificationId'], '301');
      },
    );
  });

  group('1. Dashboard Overview Tab (tong-quan)', () {
    testWidgets(
      'supports 7/30/90 day filters, empty state, offline/server error and retry recovery',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        int callBatch = 0;
        final requestedGroups = <String>[];
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/reports/revenue') {
            callBatch += 1;
            requestedGroups.add('${options.queryParameters['group']}');
          }
          // First batch: simulate offline network error
          if (callBatch == 1) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'Network unreachable',
            );
          }
          // Second batch (after retry): return empty 0-activity report
          if (callBatch == 2) {
            return _jsonResponse({
              'success': true,
              'data': {
                'totals': {
                  'grossRevenue': 0,
                  'platformRevenue': 0,
                  'hostRevenue': 0,
                  'totalBookings': 0,
                  'activeListings': 0,
                  'listingsCreated': 0,
                  'totalHosts': 0,
                },
                'series': const <Map<String, dynamic>>[],
                'pagination': {'total': 0},
              },
            });
          }
          // Third batch (90 days filter): return populated report
          if (options.path == '/api/users') {
            return _jsonResponse({
              'data': {
                'users': const <Map<String, dynamic>>[],
                'pagination': {'total': 64},
              },
            });
          }
          if (options.path == '/api/admin/listings/pending') {
            return _jsonResponse({
              'data': {
                'listings': const <Map<String, dynamic>>[],
                'pagination': {'total': 5},
              },
            });
          }
          if (options.path == '/api/admin/reports/revenue') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'grossRevenue': 45000000,
                  'platformRevenue': 6750000,
                  'hostRevenue': 38250000,
                },
                'series': [
                  {
                    'period': '2026-08',
                    'grossRevenue': 20000000,
                    'bookingCount': 4,
                  },
                  {
                    'period': '2026-09',
                    'grossRevenue': 25000000,
                    'bookingCount': 6,
                  },
                ],
              },
            });
          }
          if (options.path == '/api/admin/reports/bookings') {
            return _jsonResponse({
              'data': {
                'totals': {'totalBookings': 10},
              },
            });
          }
          if (options.path == '/api/admin/reports/listings') {
            return _jsonResponse({
              'data': {
                'totals': {'activeListings': 18, 'listingsCreated': 4},
              },
            });
          }
          if (options.path == '/api/admin/reports/hosts') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'hostsCreated': 3,
                  'activeHosts': 12,
                  'verifiedHosts': 9,
                },
              },
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'tong-quan',
            repository: AdminRepository(dio),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Offline error banner shown with retry button
        expect(find.text('Mất kết nối tới máy chủ'), findsOneWidget);
        expect(find.text('Thử lại'), findsOneWidget);

        // 2. Tap 'Thử lại' -> loads empty stats
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        expect(
          find.text('Chưa có phát sinh dữ liệu trong kỳ báo cáo này.'),
          findsOneWidget,
        );

        // 3. Switch filter to '90 ngày' -> auto switches group to 'month' and loads real series
        await tester.tap(find.text('90 ngày'));
        await tester.pumpAndSettle();
        expect(requestedGroups.last, 'month');
        expect(find.text('64'), findsOneWidget);
        expect(find.text('2026-08'), findsOneWidget);
        expect(find.text('2026-09'), findsOneWidget);
      },
    );
  });

  group('2. Users Management Tab (nguoi-dung)', () {
    testWidgets(
      'debounces search (350ms), requires confirmation to lock user, blocks self-lock, and enforces admin role guard',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final searchQueries = <String>[];
        final statusUpdates = <Map<String, dynamic>>[];

        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/users' && options.method == 'GET') {
            searchQueries.add('${options.queryParameters['search'] ?? ''}');
            return _jsonResponse({
              'success': true,
              'data': {
                'users': [
                  {
                    'userId': '1',
                    'fullName': 'Admin Chính',
                    'email': 'admin@vungtaustay.com',
                    'role': 'admin',
                    'status': 'active',
                  },
                  {
                    'userId': '42',
                    'fullName': 'Khách Hàng A',
                    'email': 'khach@example.com',
                    'role': 'guest',
                    'status': 'active',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 2,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/users/42/status' &&
              options.method == 'PATCH') {
            statusUpdates.add(
              Map<String, dynamic>.from(options.data as Map),
            );
            return _jsonResponse({
              'success': true,
              'data': {'userId': '42', 'status': 'suspended'},
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        const adminActor = User(
          id: '1',
          email: 'admin@vungtaustay.com',
          firstName: 'Admin',
          lastName: 'Chính',
          role: 'admin',
          roles: ['admin'],
        );

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'nguoi-dung',
            repository: AdminRepository(dio),
            actor: adminActor,
          ),
        );
        await tester.pumpAndSettle();
        expect(searchQueries.length, 1);

        // Rapid typing should debounce and only fire once after 350ms
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'kh');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.enterText(searchField, 'khach');
        await tester.pump(const Duration(milliseconds: 200));
        // Still only initial query before 350ms elapses from last keystroke
        expect(searchQueries.length, 1);

        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(searchQueries.length, 2);
        expect(searchQueries.last, 'khach');

        // Self-lock attempt on user #1 ('Admin Chính') is blocked immediately
        final adminRow = find.byKey(const ValueKey('admin-user-row-1'));
        final selfLockBtn = find.descendant(
          of: adminRow,
          matching: find.widgetWithText(OutlinedButton, 'Khóa'),
        );
        await tester.tap(selfLockBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Bạn không thể tự khóa tài khoản của chính mình.'),
          findsOneWidget,
        );
        expect(statusUpdates, isEmpty);

        // Locking user #42 opens confirmation modal first
        final guestRow = find.byKey(const ValueKey('admin-user-row-42'));
        final lockGuestBtn = find.descendant(
          of: guestRow,
          matching: find.widgetWithText(OutlinedButton, 'Khóa'),
        );
        await tester.tap(lockGuestBtn);
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận khóa tài khoản'), findsOneWidget);
        expect(statusUpdates, isEmpty);

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Xác nhận khóa'),
        );
        await tester.pumpAndSettle();
        expect(statusUpdates.single, {'status': 'suspended'});
      },
    );

    testWidgets(
      'disables user mutations when actor is non-admin (moderator/host/guest)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          return _jsonResponse({
            'data': {
              'users': [
                {
                  'userId': '42',
                  'fullName': 'Khách Hàng A',
                  'email': 'khach@example.com',
                  'role': 'guest',
                  'status': 'active',
                },
              ],
              'pagination': {
                'page': 1,
                'limit': 20,
                'total': 1,
                'totalPages': 1,
              },
            },
          });
        });

        const moderatorActor = User(
          id: '9',
          email: 'mod@vungtaustay.com',
          firstName: 'Kiểm Duyệt',
          lastName: 'Viên',
          role: 'guest',
          roles: ['moderator'],
        );

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'nguoi-dung',
            repository: AdminRepository(dio),
            actor: moderatorActor,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Chỉ Quản trị viên (Admin) mới có quyền chỉnh sửa',
          ),
          findsOneWidget,
        );
        final lockBtn = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Khóa'),
        );
        expect(lockBtn.onPressed, isNull);
      },
    );
  });

  group('3. Listing Moderation & AI Image Analysis Tab (kiem-duyet)', () {
    testWidgets(
      'requires viewing detail before approve OR reject, handles AI unavailable, and refreshes stale list on 409 conflict',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        bool listingAlreadyModerated = false;
        int pendingFetchCount = 0;
        int approveCalls = 0;

        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/listings/pending') {
            pendingFetchCount += 1;
            return _jsonResponse({
              'data': {
                'listings': listingAlreadyModerated
                    ? const <Map<String, dynamic>>[]
                    : [
                        {
                          'listingId': '888',
                          'title': 'Biệt thự Đồi Sứ',
                          'propertyType': 'villa',
                          'city': 'Vũng Tàu',
                          'basePrice': 5500000,
                        },
                      ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': listingAlreadyModerated ? 0 : 1,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/admin/listings/888' &&
              options.method == 'GET') {
            return _jsonResponse({
              'data': {
                'listingId': '888',
                'title': 'Biệt thự Đồi Sứ',
                'description': 'View biển trực diện',
                'basePrice': 5500000,
                'host': {
                  'fullName': 'Chủ Nhà Đồi Sứ',
                  'email': 'host@example.com',
                  'isHostVerified': true,
                },
                'images': [
                  {
                    'imageId': '501',
                    'url': '',
                    'aiAnalysisStatus': 'completed',
                    'aiImageType': 'exterior',
                    'aiConfidence': 0.94,
                    'aiSceneTags': ['sea_view', 'pool'],
                    'aiAmenityTags': ['infinity_pool'],
                    'aiQualityWarnings': const <String>[],
                  },
                ],
              },
            });
          }
          if (options.path == '/api/ai/listings/888/analyze-images') {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 503,
                data: {
                  'message':
                      'OpenAI Vision service is temporarily unavailable (503).',
                },
              ),
            );
          }
          if (options.path == '/api/admin/listings/888/approve') {
            approveCalls += 1;
            listingAlreadyModerated = true;
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'message': 'Listing is not pending approval (409).',
                },
              ),
            );
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'kiem-duyet',
            repository: AdminRepository(dio),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Clicking 'Duyệt' before viewing detail is blocked
        await tester.tap(find.widgetWithText(ElevatedButton, 'Duyệt'));
        await tester.pumpAndSettle();
        expect(
          find.text('Vui lòng xem chi tiết căn trước khi duyệt.'),
          findsOneWidget,
        );
        expect(approveCalls, 0);

        // 2. Clicking 'Từ chối' before viewing detail is ALSO blocked
        await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
        await tester.pumpAndSettle();
        expect(
          find.text('Vui lòng xem chi tiết căn trước khi từ chối.'),
          findsOneWidget,
        );

        // 3. View detail modal -> inspect AI tags -> test AI unavailable (503)
        await tester.tap(find.widgetWithText(OutlinedButton, 'Xem chi tiết'));
        await tester.pumpAndSettle();
        expect(find.text('Ảnh căn & AI Image Analysis'), findsOneWidget);
        expect(find.text('Độ tin cậy: 94%'), findsOneWidget);
        expect(find.text('sea_view'), findsOneWidget);

        await tester.tap(find.text('Phân tích lại AI toàn bộ ảnh'));
        await tester.pumpAndSettle();
        expect(
          find.text('OpenAI Vision service is temporarily unavailable (503).'),
          findsOneWidget,
        );

        // 4. Approve from detail modal -> backend returns 409 conflict -> UI shows 409 error AND refreshes stale list
        await tester.tap(find.widgetWithText(ElevatedButton, 'Duyệt căn này'));
        await tester.pumpAndSettle();

        expect(approveCalls, 1);
        expect(pendingFetchCount, 2);
        expect(
          find.text('Listing is not pending approval (409).'),
          findsOneWidget,
        );
        expect(find.text('Không có listing chờ duyệt.'), findsOneWidget);
      },
    );
  });

  group('4. Host Applications & Legacy Verifications Tab (ho-so-host)', () {
    testWidgets(
      'surfaces Legacy Verifications error with retry (no error swallowing) and masks KYC ID numbers',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        int verificationCalls = 0;
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/host-applications') {
            return _jsonResponse({
              'data': {
                'items': [
                  {
                    'applicationId': '501',
                    'contactName': 'Trần Thị Chủ Nhà',
                    'phone': '0909123456',
                    'status': 'pending',
                    'documentCount': 1,
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/admin/host-applications/501') {
            return _jsonResponse({
              'data': {
                'applicationId': '501',
                'contactName': 'Trần Thị Chủ Nhà',
                'phone': '0909123456',
                'idNumber': '079188006789',
                'businessAddress': '12 Thùy Vân, Vũng Tàu',
                'status': 'pending',
                'documents': [
                  {
                    'documentType': 'cccd',
                    'side': 'front',
                    'mimeType': 'application/pdf',
                    'objectKey': 'private/kyc/079188006789-front.pdf',
                    'signedUrl':
                        'https://r2.example.com/private/kyc.pdf?X-Amz-Signature=supersecret999',
                  },
                ],
              },
            });
          }
          if (options.path == '/api/admin/verifications') {
            verificationCalls += 1;
            if (verificationCalls == 1) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 500,
                  data: {
                    'message': 'Lỗi truy vấn bảng host_verifications (500).',
                  },
                ),
              );
            }
            return _jsonResponse({
              'data': {
                'verifications': [
                  {
                    'verificationId': '701',
                    'fullName': 'Nguyễn Văn Host',
                    'verificationType': 'cccd',
                    'idNumber': '079099001234',
                    'status': 'pending',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'ho-so-host',
            repository: AdminRepository(dio),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Legacy Verifications 500 error is NOT swallowed!
        expect(
          find.text('Lỗi truy vấn bảng host_verifications (500).'),
          findsOneWidget,
        );
        expect(
          find.text('Không có bản ghi Legacy Verification nào.'),
          findsNothing,
        );

        // 2. Tap 'Thử lại' on Legacy Verifications error banner -> recovers and masks KYC ID
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        expect(find.text('Nguyễn Văn Host (#701)'), findsOneWidget);
        expect(find.textContaining('***1234'), findsOneWidget);
        expect(find.textContaining('079099001234'), findsNothing);

        // 3. View Host Application #501 detail -> masks KYC ID and does not leak raw objectKey or signature
        await tester.tap(find.text('Chi tiết'));
        await tester.pumpAndSettle();
        expect(find.text('Số định danh (KYC): ***6789'), findsOneWidget);
        expect(find.textContaining('079188006789'), findsNothing);
        expect(find.textContaining('supersecret999'), findsNothing);
      },
    );
  });

  group('5. Role Editor Tab (phan-quyen)', () {
    testWidgets(
      'handles 409 conflict / 403 forbidden accurately without fake success and guards self-demotion',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/users' && options.method == 'GET') {
            return _jsonResponse({
              'data': {
                'users': [
                  {
                    'userId': '55',
                    'fullName': 'Host Đang Có Phòng',
                    'email': 'host55@example.com',
                    'role': 'host',
                  },
                  {
                    'userId': '1',
                    'fullName': 'Admin Duy Nhất',
                    'email': 'admin1@example.com',
                    'role': 'admin',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 50,
                  'total': 2,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/users/55' && options.method == 'PATCH') {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'message':
                      'Cannot change host role while user has active listings (409).',
                },
              ),
            );
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        const adminActor = User(
          id: '1',
          email: 'admin1@example.com',
          firstName: 'Admin',
          lastName: 'Duy Nhất',
          role: 'admin',
          roles: ['admin'],
        );

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'phan-quyen',
            repository: AdminRepository(dio),
            actor: adminActor,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Change user #55 from host -> guest -> backend returns 409 conflict
        final row55 = find.byKey(const ValueKey('admin-role-row-55'));
        await tester.tap(
          find.descendant(
            of: row55,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guest').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: row55,
            matching: find.widgetWithText(ElevatedButton, 'Lưu'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Cannot change host role while user has active listings (409).',
          ),
          findsOneWidget,
        );

        // 2. Admin #1 tries to demote themselves -> blocked by self-demotion guard
        final row1 = find.byKey(const ValueKey('admin-role-row-1'));
        await tester.tap(
          find.descendant(
            of: row1,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Moderator').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: row1,
            matching: find.widgetWithText(ElevatedButton, 'Lưu'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Bạn không thể tự hạ quyền Admin của chính mình.'),
          findsOneWidget,
        );
      },
    );
  });

  group(
    '6. Mobile Responsiveness (320/360/390/430dp) & Text Scaling (1.0/1.3/1.6)',
    () {
      AdminRepository buildPopulatedRepo() {
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/reports/revenue') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'grossRevenue': 18500000,
                  'platformRevenue': 2775000,
                  'hostRevenue': 15725000,
                },
                'series': [
                  {
                    'period': '2026-10-25',
                    'grossRevenue': 9500000,
                    'bookingCount': 2,
                  },
                  {
                    'period': '2026-10-26',
                    'grossRevenue': 9000000,
                    'bookingCount': 3,
                  },
                ],
              },
            });
          }
          if (options.path == '/api/users') {
            return _jsonResponse({
              'data': {
                'users': [
                  {
                    'userId': '10',
                    'fullName': 'Nguyễn Minh Thành',
                    'email': 'thanh@vungtaustay.com',
                    'phone': '0909111222',
                    'role': 'host',
                    'status': 'active',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/admin/listings/pending') {
            return _jsonResponse({
              'data': {
                'listings': [
                  {
                    'listingId': '99',
                    'title': 'Villa Bãi Trước Luxury',
                    'propertyType': 'villa',
                    'city': 'Vũng Tàu',
                    'basePrice': 4200000,
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/admin/host-applications') {
            return _jsonResponse({
              'data': {
                'items': [
                  {
                    'applicationId': '300',
                    'contactName': 'Lê Hoàng Host',
                    'phone': '0912333444',
                    'status': 'pending',
                    'documentCount': 2,
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path == '/api/admin/verifications') {
            return _jsonResponse({
              'data': {
                'verifications': [
                  {
                    'verificationId': '701',
                    'fullName': 'Lê Hoàng Host',
                    'verificationType': 'cccd',
                    'idNumber': '079099887766',
                    'status': 'pending',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });
        return AdminRepository(dio);
      }

      for (final width in const [320.0, 360.0, 390.0, 430.0]) {
        testWidgets(
          'renders and scrolls all 5 Admin tabs at ${width.toInt()}dp width with textScale 1.0, 1.3 & 1.6 without overflow',
          (tester) async {
            final repo = buildPopulatedRepo();
            await tester.binding.setSurfaceSize(Size(width, 780));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            for (final scale in const [1.0, 1.3, 1.6]) {
              for (final tab in const [
                'tong-quan',
                'nguoi-dung',
                'kiem-duyet',
                'ho-so-host',
                'phan-quyen',
              ]) {
                await tester.pumpWidget(
                  _buildTestPortal(
                    activeTab: tab,
                    repository: repo,
                    surfaceSize: Size(width, 780),
                    textScale: scale,
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);

                final scrollable = find.byType(SingleChildScrollView).first;
                await tester.drag(scrollable, const Offset(0, -300));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            }
          },
        );
      }
    },
  );
}
