import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_api_client.dart';

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

void main() {
  group('AdminModerationPolicy — Role guard & moderation business rules', () {
    test(
      'distinguishes guest, host, and admin permissions accurately',
      () {
        expect(
          AdminModerationPolicy.supportedRoles,
          equals(const ['guest', 'host', 'admin']),
        );
        expect(
          AdminModerationPolicy.isAdminRole(
            primaryRole: 'admin',
            roles: const ['admin'],
          ),
          isTrue,
        );
        expect(
          AdminModerationPolicy.isAdminRole(
            primaryRole: 'guest',
            roles: const ['guest'],
          ),
          isFalse,
        );
        expect(
          AdminModerationPolicy.isAdminRole(
            primaryRole: 'host',
            roles: const ['host'],
          ),
          isFalse,
        );
      },
    );

    test(
      'requires viewing listing detail before BOTH approve and reject, and requires non-empty reject reason',
      () {
        final viewed = <String>{};
        expect(
          AdminModerationPolicy.validateListingApprove(
            viewedListingIds: viewed,
            listingId: '888',
            canModerate: true,
          ),
          'Vui lòng xem chi tiết căn trước khi duyệt.',
        );
        expect(
          AdminModerationPolicy.validateListingReject(
            viewedListingIds: viewed,
            listingId: '888',
            canModerate: true,
            reason: 'Ảnh bị mờ',
          ),
          'Vui lòng xem chi tiết căn trước khi từ chối.',
        );

        viewed.add('888');
        expect(
          AdminModerationPolicy.validateListingApprove(
            viewedListingIds: viewed,
            listingId: '888',
            canModerate: true,
          ),
          isNull,
        );
        expect(
          AdminModerationPolicy.validateListingReject(
            viewedListingIds: viewed,
            listingId: '888',
            canModerate: true,
            reason: '   ',
          ),
          'Vui lòng nhập lý do từ chối.',
        );
        expect(
          AdminModerationPolicy.validateListingReject(
            viewedListingIds: viewed,
            listingId: '888',
            canModerate: true,
            reason: 'Thiếu ảnh phòng tắm',
          ),
          isNull,
        );
      },
    );

    test(
      'prevents self-lock and self-demotion and blocks non-admin role/status mutations',
      () {
        expect(
          AdminModerationPolicy.validateUserStatusMutation(
            isActorAdmin: false,
            actorId: '9',
            targetUserId: '42',
          ),
          contains('Chỉ Quản trị viên (Admin)'),
        );
        expect(
          AdminModerationPolicy.validateUserStatusMutation(
            isActorAdmin: true,
            actorId: '1',
            targetUserId: '1',
          ),
          'Bạn không thể tự khóa tài khoản của chính mình.',
        );
        expect(
          AdminModerationPolicy.validateRoleMutation(
            isActorAdmin: true,
            actorId: '1',
            targetUserId: '1',
            nextRole: 'host',
          ),
          'Bạn không thể tự hạ quyền Admin của chính mình.',
        );
        expect(
          AdminModerationPolicy.validateRoleMutation(
            isActorAdmin: true,
            actorId: '1',
            targetUserId: '55',
            nextRole: 'host',
          ),
          isNull,
        );
        expect(
          AdminModerationPolicy.validateRoleMutation(
            isActorAdmin: true,
            actorId: '1',
            targetUserId: '55',
            nextRole: 'moderator',
          ),
          'Vai trò không hợp lệ.',
        );
      },
    );

    test(
      'sorts admin users strictly by guest -> host -> admin and then Vietnamese alphabetical name order',
      () {
        final unsorted = <Map<String, dynamic>>[
          {
            'userId': '1',
            'fullName': 'Quản trị viên The Palm Villa',
            'email': 'admin@minhthanhvilla.com',
            'role': 'admin',
          },
          {
            'userId': '11',
            'fullName': 'Đặng Kim An',
            'email': 'n23dccn001@student.ptithcm.edu.vn',
            'role': 'guest',
          },
          {
            'userId': '12',
            'fullName': 'NGUYỄN VĂN A',
            'email': 'dangkiman41005@gmail.com',
            'role': 'host',
          },
          {
            'userId': '4',
            'fullName': 'ĐẶNG KIM AN',
            'email': 'guest@gmail.com',
            'role': 'guest',
          },
          {
            'userId': '2',
            'fullName': 'Nguyễn Minh Thành',
            'email': 'host.thanh@minhthanhvilla.com',
            'roles': ['guest', 'host'],
          },
          {
            'userId': '8',
            'fullName': 'An Bình',
            'email': 'anbinh@example.com',
            'role': 'guest',
          },
          {
            'userId': '9',
            'fullName': 'Ăn Khang',
            'email': 'ankhang@example.com',
            'role': 'guest',
          },
          {
            'userId': '10',
            'fullName': 'Dũng Lê',
            'email': 'dungle@example.com',
            'role': 'guest',
          },
          {
            'userId': '15',
            'fullName': 'Lê Hoàng Long',
            'email': 'long@example.com',
            'role': 'guest',
          },
        ];

        final sorted = AdminModerationPolicy.sortAdminUsers(unsorted);
        expect(
          sorted.map((u) => '${u['userId']}').toList(),
          equals([
            // Guests: An Bình < Ăn Khang < Dũng Lê < ĐẶNG KIM AN (guest@...) < Đặng Kim An (n23...) < Lê Hoàng Long
            '8',
            '9',
            '10',
            '4',
            '11',
            '15',
            // Hosts: Nguyễn Minh Thành < NGUYỄN VĂN A
            '2',
            '12',
            // Admins: Quản trị viên The Palm Villa
            '1',
          ]),
        );

        // Also handles NFD combining diacritics identically to precomposed NFC
        expect(
          AdminModerationPolicy.compareVietnameseNames(
            'Đa\u0306\u0323ng Kim An',
            'ĐẶNG KIM AN',
          ),
          0,
        );
      },
    );
  });

  group('AdminRepository — Error classification, KYC masking & API contracts',
      () {
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

        final forbidden403 = DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 403,
            data: const <String, dynamic>{},
          ),
        );
        expect(AdminRepository.isOfflineError(forbidden403), isFalse);
        expect(AdminRepository.extractStatusCode(forbidden403), 403);
        expect(
          AdminRepository.extractErrorMessage(forbidden403),
          'Bạn không có quyền thực hiện thao tác này (403).',
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
      'getOverviewStats supports 7/30/90 day ranges, day/month group, and parses booking & listing breakdown',
      () async {
        final capturedQueries = <String, Map<String, dynamic>>{};
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          capturedQueries[options.path] =
              Map<String, dynamic>.from(options.queryParameters);
          if (options.path == '/api/users') {
            return _jsonResponse({
              'data': {
                'users': const <Map<String, dynamic>>[],
                'pagination': {'total': 120},
              },
            });
          }
          if (options.path == '/api/admin/listings/pending') {
            return _jsonResponse({
              'data': {
                'listings': const <Map<String, dynamic>>[],
                'pagination': {'total': 7},
              },
            });
          }
          if (options.path == '/api/admin/reports/revenue') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'grossRevenue': 82000000,
                  'platformRevenue': 12300000,
                  'hostRevenue': 69700000,
                  'pendingStayRevenue': 8300000,
                  'pendingStayPlatformRevenue': 800000,
                  'pendingStayHostRevenue': 7500000,
                  'pendingStayBookingCount': 1,
                  'refundedAmount': 1500000,
                },
                'series': [
                  {
                    'period': '2026-09',
                    'grossRevenue': 40000000,
                    'bookingCount': 8,
                  },
                  {
                    'period': '2026-10',
                    'grossRevenue': 42000000,
                    'bookingCount': 9,
                  },
                ],
              },
            });
          }
          if (options.path == '/api/admin/reports/bookings') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'totalBookings': 17,
                  'pendingBookings': 2,
                  'paidBookings': 5,
                  'completedBookings': 9,
                  'cancelledBookings': 1,
                },
              },
            });
          }
          if (options.path == '/api/admin/reports/listings') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'listingsCreated': 6,
                  'activeListings': 34,
                  'inactiveListings': 4,
                },
              },
            });
          }
          if (options.path == '/api/admin/reports/hosts') {
            return _jsonResponse({
              'data': {
                'totals': {
                  'hostsCreated': 5,
                  'activeHosts': 21,
                  'verifiedHosts': 18,
                },
              },
            });
          }
          return _jsonResponse({'data': <String, dynamic>{}});
        });

        final repo = AdminRepository(dio);
        final stats = await repo.getOverviewStats(days: 90, group: 'month');

        expect(
            capturedQueries['/api/admin/reports/revenue']?['group'], 'month');
        expect(stats.users, 120);
        expect(stats.pendingListings, 7);
        expect(stats.grossRevenue, 82000000);
        expect(stats.platformRevenue, 12300000);
        expect(stats.hostRevenue, 69700000);
        expect(stats.pendingStayRevenue, 8300000);
        expect(stats.pendingStayHostRevenue, 7500000);
        expect(stats.pendingStayBookingCount, 1);
        expect(stats.refundedAmount, 1500000);
        expect(stats.bookings, 17);
        expect(stats.successfulBookings, 14);
        expect(stats.pendingBookings, 2);
        expect(stats.paidBookings, 5);
        expect(stats.completedBookings, 9);
        expect(stats.cancelledBookings, 1);
        expect(stats.activeListings, 34);
        expect(stats.inactiveListings, 4);
        expect(stats.activeHosts, 21);
        expect(stats.verifiedHosts, 18);
        expect(stats.revenueSeries.length, 2);
        expect(stats.hasAnyActivity, isTrue);
      },
    );

    test(
      'supports paginated users, pending listings, host applications, verifications, and AI reanalysis endpoints',
      () async {
        final calls = <String>[];
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          calls.add('${options.method} ${options.path}');
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
          if (options.path == '/api/admin/images/501/reanalyze') {
            return _jsonResponse({
              'data': {
                'imageId': '501',
                'aiAnalysisStatus': 'completed',
                'aiConfidence': 0.96,
              },
            });
          }
          if (options.path == '/api/ai/listings/101/analyze-images') {
            return _jsonResponse({
              'data': {'analyzedCount': 4},
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

        final reanalyzed = await repo.reanalyzeListingImage('501');
        expect(reanalyzed['aiAnalysisStatus'], 'completed');

        final batchAnalyzed =
            await repo.analyzeAllListingImages('101', force: true);
        expect(batchAnalyzed['analyzedCount'], 4);
        expect(
          calls,
          containsAll(<String>[
            'GET /api/admin/listings/pending',
            'GET /api/admin/host-applications',
            'GET /api/admin/verifications',
            'POST /api/admin/images/501/reanalyze',
            'POST /api/ai/listings/101/analyze-images',
          ]),
        );
      },
    );
  });
}
