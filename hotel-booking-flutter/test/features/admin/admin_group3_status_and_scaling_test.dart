import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
import 'package:hotel_booking_flutter/features/admin/domain/admin_status_helper.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/screens/admin_portal_screens.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/widgets/admin_studio_widgets.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  const defaultAdminActor = User(
    id: '999',
    email: 'admin@palm.vn',
    firstName: 'Admin',
    lastName: 'System',
    role: 'admin',
    roles: ['admin'],
  );
  final authRepo = _StubAuthRepository(actor ?? defaultAdminActor);
  return ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repository),
      authRepositoryProvider.overrideWithValue(authRepo),
      authNotifierProvider.overrideWith((ref) => AuthNotifier(authRepo)),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: surfaceSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: AdminPortalScreen(activeTab: activeTab),
    ),
  );
}

void main() {
  group('AdminStatusHelper — Unit tests', () {
    test(
      'classifies active, inactive, suspended/blocked/locked, and deleted user statuses accurately',
      () {
        final active = AdminStatusHelper.classifyUserStatus('active');
        expect(active.kind, AdminUserStatusKind.active);
        expect(active.badgeLabel, 'Đang hoạt động');
        expect(active.showsActiveDot, isTrue);
        expect(active.canToggleStatus, isTrue);
        expect(active.actionLabel, 'Khóa');
        expect(active.nextTargetStatus, 'suspended');

        final inactive = AdminStatusHelper.classifyUserStatus('inactive');
        expect(inactive.kind, AdminUserStatusKind.inactive);
        expect(inactive.badgeLabel, 'Ngừng hoạt động');
        expect(inactive.showsActiveDot, isFalse);
        expect(inactive.canToggleStatus, isTrue);
        expect(inactive.actionLabel, 'Kích hoạt');
        expect(inactive.nextTargetStatus, 'active');

        final unverified = AdminStatusHelper.classifyUserStatus('pending');
        expect(unverified.kind, AdminUserStatusKind.inactive);
        expect(unverified.badgeLabel, 'Chưa kích hoạt');
        expect(unverified.showsActiveDot, isFalse);
        expect(unverified.nextTargetStatus, 'active');

        for (final alias in const ['suspended', 'blocked', 'locked', 'LOCKED']) {
          final locked = AdminStatusHelper.classifyUserStatus(alias);
          expect(locked.kind, AdminUserStatusKind.suspended);
          expect(locked.badgeLabel, 'Tạm khóa');
          expect(locked.showsActiveDot, isFalse);
          expect(locked.canToggleStatus, isTrue);
          expect(locked.actionLabel, 'Mở khóa');
          expect(locked.nextTargetStatus, 'active');
          expect(
            AdminStatusHelper.normalizeOutboundUserStatus(alias),
            'suspended',
          );
        }

        final deleted = AdminStatusHelper.classifyUserStatus('deleted');
        expect(deleted.kind, AdminUserStatusKind.deleted);
        expect(deleted.badgeLabel, 'Đã xóa');
        expect(deleted.showsActiveDot, isFalse);
        expect(deleted.canToggleStatus, isFalse);
        expect(deleted.actionLabel, isNull);
        expect(deleted.nextTargetStatus, isNull);
      },
    );

    test(
      'allows verification/application approve & reject strictly when status is pending',
      () {
        expect(AdminStatusHelper.canReviewSubmission('pending'), isTrue);
        expect(AdminStatusHelper.canReviewSubmission('PENDING'), isTrue);
        expect(AdminStatusHelper.canReviewSubmission('approved'), isFalse);
        expect(AdminStatusHelper.canReviewSubmission('rejected'), isFalse);
        expect(AdminStatusHelper.canReviewSubmission('cancelled'), isFalse);

        expect(
          AdminStatusHelper.classifyReviewStatus('approved').badgeLabel,
          'Đã duyệt',
        );
        expect(
          AdminStatusHelper.classifyReviewStatus('rejected').badgeLabel,
          'Đã từ chối',
        );
      },
    );

    test(
      'slices the latest 14 revenue points in ascending chronological order without dropping newest days',
      () {
        final thirtyDays = List<AdminRevenuePoint>.generate(
          30,
          (i) => AdminRevenuePoint(
            period: '2026-10-${(i + 1).toString().padLeft(2, '0')}',
            grossRevenue: (i + 1) * 1000000,
            bookingCount: i + 1,
          ),
        );

        final window = AdminStatusHelper.sliceLatestRevenueWindow(
          thirtyDays,
          maxItems: 14,
        );
        expect(window.length, 14);
        expect(window.first.period, '2026-10-17');
        expect(window.last.period, '2026-10-30');

        final shortSeries = thirtyDays.sublist(0, 5);
        final shortWindow = AdminStatusHelper.sliceLatestRevenueWindow(
          shortSeries,
          maxItems: 14,
        );
        expect(shortWindow.length, 5);
        expect(shortWindow.first.period, '2026-10-01');
        expect(shortWindow.last.period, '2026-10-05');
      },
    );
  });

  group('Group 3 UI Fixes & 2.0x Font-Scaling — Widget tests', () {
    testWidgets(
      'Users tab renders distinct badges & actions for active, inactive, suspended/blocked/locked, and deleted accounts',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mutatedPayloads = <String, Map<String, dynamic>>{};
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/users' && options.method == 'GET') {
            return _jsonResponse({
              'data': {
                'users': [
                  {
                    'userId': '101',
                    'fullName': 'Khách Active',
                    'email': 'active@example.com',
                    'role': 'guest',
                    'status': 'active',
                  },
                  {
                    'userId': '102',
                    'fullName': 'Khách Inactive',
                    'email': 'inactive@example.com',
                    'role': 'guest',
                    'status': 'inactive',
                  },
                  {
                    'userId': '103',
                    'fullName': 'Khách Blocked',
                    'email': 'blocked@example.com',
                    'role': 'guest',
                    'status': 'blocked',
                  },
                  {
                    'userId': '104',
                    'fullName': 'Khách Locked',
                    'email': 'locked@example.com',
                    'role': 'guest',
                    'status': 'locked',
                  },
                  {
                    'userId': '105',
                    'fullName': 'Khách Deleted',
                    'email': 'deleted@example.com',
                    'role': 'guest',
                    'status': 'deleted',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 5,
                  'totalPages': 1,
                },
              },
            });
          }
          if (options.path.startsWith('/api/users/') &&
              options.path.endsWith('/status') &&
              options.method == 'PATCH') {
            mutatedPayloads[options.path] =
                Map<String, dynamic>.from(options.data as Map);
            return _jsonResponse({'data': <String, dynamic>{}});
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'nguoi-dung',
            repository: AdminRepository(dio),
            surfaceSize: const Size(1280, 1100),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Active user (#101): green active dot + 'Đang hoạt động' + lock icon
        final row101 = find.byKey(const ValueKey('admin-user-row-101'));
        expect(
          find.descendant(of: row101, matching: find.text('Đang hoạt động')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('admin-user-active-dot-101')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row101,
            matching: find.widgetWithIcon(OutlinedButton, LucideIcons.lock),
          ),
          findsOneWidget,
        );

        // 2. Inactive user (#102): 'Ngừng hoạt động', NO green active dot, 'Kích hoạt' action -> sends 'active'
        final row102 = find.byKey(const ValueKey('admin-user-row-102'));
        expect(
          find.descendant(of: row102, matching: find.text('Ngừng hoạt động')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('admin-user-active-dot-102')),
          findsNothing,
        );
        final activateBtn = find.byKey(const ValueKey('admin-user-lock-102'));
        expect(activateBtn, findsOneWidget);
        await tester.tap(activateBtn);
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận kích hoạt tài khoản'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Xác nhận kích hoạt'),
        );
        await tester.pumpAndSettle();
        expect(
          mutatedPayloads['/api/users/102/status'],
          equals({'status': 'active'}),
        );

        // 3. Blocked (#103) & Locked (#104): unified 'Tạm khóa' badge + 'Mở khóa' -> sends 'active'
        for (final id in const ['103', '104']) {
          final row = find.byKey(ValueKey('admin-user-row-$id'));
          expect(
            find.descendant(of: row, matching: find.text('Tạm khóa')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey('admin-user-active-dot-$id')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: row,
              matching:
                  find.widgetWithIcon(OutlinedButton, LucideIcons.lockOpen),
            ),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const ValueKey('admin-user-lock-104')));
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận mở khóa tài khoản'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Xác nhận mở khóa'),
        );
        await tester.pumpAndSettle();
        expect(
          mutatedPayloads['/api/users/104/status'],
          equals({'status': 'active'}),
        );

        // 4. Deleted (#105): 'Đã xóa' muted badge, NO lock toggle button, disabled edit button
        final row105 = find.byKey(const ValueKey('admin-user-row-105'));
        expect(
          find.descendant(of: row105, matching: find.text('Đã xóa')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('admin-user-lock-105')),
          findsNothing,
        );
        final editDeletedBtn = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('admin-user-edit-105')),
        );
        expect(editDeletedBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Legacy Verifications shows approve/reject buttons ONLY for pending items and read-only chips for approved/rejected',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/host-applications') {
            return _jsonResponse({
              'data': {
                'items': const <Map<String, dynamic>>[],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 0,
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
                    'fullName': 'Host Chờ Duyệt',
                    'verificationType': 'identity',
                    'status': 'pending',
                  },
                  {
                    'verificationId': '702',
                    'fullName': 'Host Đã Duyệt',
                    'verificationType': 'identity',
                    'status': 'approved',
                  },
                  {
                    'verificationId': '703',
                    'fullName': 'Host Bị Từ Chối',
                    'verificationType': 'identity',
                    'status': 'rejected',
                  },
                ],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 3,
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
            surfaceSize: const Size(1280, 1000),
          ),
        );
        await tester.pumpAndSettle();

        final row701 = find.byKey(
          const ValueKey('admin-verification-row-701'),
        );
        final row702 = find.byKey(
          const ValueKey('admin-verification-row-702'),
        );
        final row703 = find.byKey(
          const ValueKey('admin-verification-row-703'),
        );

        // Pending #701 has active approve & reject buttons
        expect(
          find.descendant(
            of: row701,
            matching: find.widgetWithText(ElevatedButton, 'Duyệt xác minh'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row701,
            matching: find.widgetWithText(OutlinedButton, 'Từ chối'),
          ),
          findsOneWidget,
        );

        // Approved #702 has NO approve/reject buttons, renders read-only 'Đã duyệt' chip
        expect(
          find.descendant(of: row702, matching: find.byType(ElevatedButton)),
          findsNothing,
        );
        expect(
          find.descendant(of: row702, matching: find.byType(OutlinedButton)),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('admin-verification-readonly-702')),
          findsOneWidget,
        );

        // Rejected #703 has NO approve/reject buttons, renders read-only 'Đã từ chối' chip
        expect(
          find.descendant(of: row703, matching: find.byType(ElevatedButton)),
          findsNothing,
        );
        expect(
          find.descendant(of: row703, matching: find.byType(OutlinedButton)),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('admin-verification-readonly-703')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Overview revenue chart displays the latest 14 chronological days instead of dropping newest days on 30-day series',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final seriesJson = List<Map<String, dynamic>>.generate(
          30,
          (i) => {
            'period': '2026-10-${(i + 1).toString().padLeft(2, '0')}',
            'grossRevenue': (i + 1) * 1000000,
            'bookingCount': 1,
          },
        );

        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/admin/reports/revenue') {
            return _jsonResponse({
              'data': {
                'totals': {'grossRevenue': 465000000},
                'series': seriesJson,
              },
            });
          }
          return _jsonResponse({
            'data': {
              'totals': {'totalBookings': 30},
              'pagination': {'total': 10},
            },
          });
        });

        await tester.pumpWidget(
          _buildTestPortal(
            activeTab: 'tong-quan',
            repository: AdminRepository(dio),
            surfaceSize: const Size(1280, 1400),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2026-10-01'), findsNothing);
        expect(find.text('2026-10-16'), findsNothing);
        expect(find.text('2026-10-17'), findsOneWidget);
        expect(find.text('2026-10-30'), findsOneWidget);

        final y17 = tester.getTopLeft(find.text('2026-10-17')).dy;
        final y30 = tester.getTopLeft(find.text('2026-10-30')).dy;
        expect(y17, lessThan(y30));
      },
    );

    testWidgets(
      'AdminStudioAvatar and all Admin tabs scale cleanly at 2.0x textScale without clipping or RenderFlex overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 840));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 1. Direct AdminStudioAvatar check at 2.0x
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 840),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AdminStudioAvatar(
                    name: 'Đặng Minh Thành',
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(AdminStudioAvatar),
            matching: find.byType(FittedBox),
          ),
          findsOneWidget,
        );
        final avatarRect = tester.getRect(find.byType(AdminStudioAvatar));
        final initialsRect = tester.getRect(find.text('ĐT'));
        expect(initialsRect.left, greaterThanOrEqualTo(avatarRect.left + 3.5));
        expect(initialsRect.right, lessThanOrEqualTo(avatarRect.right - 3.5));

        // 2. Full Admin tabs at 2.0x textScale (360dp width) including dropdowns, 'Chưa có ảnh', and 42x42 % circle
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/api/users') {
            return _jsonResponse({
              'data': {
                'users': [
                  {
                    'userId': '10',
                    'fullName': 'Nguyễn Minh Thành',
                    'email': 'thanh@vungtaustay.com',
                    'role': 'host',
                    'status': 'inactive',
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
                    'title': 'Villa Bãi Trước',
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
          if (options.path == '/api/admin/verifications') {
            return _jsonResponse({
              'data': {
                'verifications': [
                  {
                    'verificationId': '702',
                    'fullName': 'Lê Hoàng Host',
                    'verificationType': 'identity',
                    'status': 'approved',
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
          if (options.path == '/api/admin/fees/current') {
            return _jsonResponse({
              'data': {
                'activeFee': {'feePct': 12.5},
                'totalPlatformRevenue': 15000000,
                'history': [
                  {
                    'feePct': 12.5,
                    'status': 'active',
                    'effectiveAt': '2026-10-01T00:00:00Z',
                    'reason': 'Áp dụng mức phí mới',
                  },
                ],
              },
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });
        final repo = AdminRepository(dio);

        for (final tab in const [
          'tong-quan',
          'nguoi-dung',
          'kiem-duyet',
          'ho-so-host',
          'phan-quyen',
          'phi-nen-tang',
        ]) {
          await tester.pumpWidget(
            _buildTestPortal(
              activeTab: tab,
              repository: repo,
              surfaceSize: const Size(360, 840),
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Tab $tab overflowed at 2.0x textScale',
          );

          if (tab == 'nguoi-dung') {
            final dropdownFinder = find.byType(DropdownButton<String>).first;
            expect(tester.getSize(dropdownFinder).height, greaterThanOrEqualTo(28));
          }

          final scrollable = find.byType(SingleChildScrollView).first;
          await tester.drag(scrollable, const Offset(0, -320));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Tab $tab overflowed while scrolling at 2.0x textScale',
          );
        }
      },
    );
  });
}
