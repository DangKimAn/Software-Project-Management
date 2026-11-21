import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_api_client.dart';
import 'package:hotel_booking_flutter/features/admin/domain/admin_status_helper.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/widgets/admin_studio_widgets.dart';

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

void main() {
  group('AdminStatusHelper — User status, verification guard & chart window',
      () {
    test(
      'distinguishes active, inactive, suspended/blocked/locked, and deleted statuses accurately',
      () {
        final active = AdminStatusHelper.classifyUserStatus('active');
        expect(active.kind, AdminUserStatusKind.active);
        expect(active.badgeLabel, 'Đang hoạt động');
        expect(active.showsActiveDot, isTrue);
        expect(active.canToggleStatus, isTrue);
        expect(active.actionLabel, 'Khóa');
        expect(active.nextTargetStatus, 'suspended');

        final defaultEmpty = AdminStatusHelper.classifyUserStatus(null);
        expect(defaultEmpty.kind, AdminUserStatusKind.active);
        expect(defaultEmpty.showsActiveDot, isTrue);

        final inactive = AdminStatusHelper.classifyUserStatus('inactive');
        expect(inactive.kind, AdminUserStatusKind.inactive);
        expect(inactive.badgeLabel, 'Ngừng hoạt động');
        expect(inactive.showsActiveDot, isFalse);
        expect(inactive.canToggleStatus, isTrue);
        expect(inactive.actionLabel, 'Kích hoạt');
        expect(inactive.nextTargetStatus, 'active');

        final pendingUser = AdminStatusHelper.classifyUserStatus('pending');
        expect(pendingUser.kind, AdminUserStatusKind.inactive);
        expect(pendingUser.badgeLabel, 'Chưa kích hoạt');
        expect(pendingUser.showsActiveDot, isFalse);
        expect(pendingUser.actionLabel, 'Kích hoạt');
        expect(pendingUser.nextTargetStatus, 'active');

        for (final raw in const ['suspended', 'blocked', 'locked', 'BLOCKED']) {
          final locked = AdminStatusHelper.classifyUserStatus(raw);
          expect(locked.kind, AdminUserStatusKind.suspended);
          expect(locked.badgeLabel, 'Tạm khóa');
          expect(locked.showsActiveDot, isFalse);
          expect(locked.canToggleStatus, isTrue);
          expect(locked.actionLabel, 'Mở khóa');
          expect(locked.nextTargetStatus, 'active');
          expect(
            AdminStatusHelper.normalizeOutboundUserStatus(raw),
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
      'AdminRepository.updateAdminUserStatus normalizes blocked & locked to suspended',
      () async {
        final sentPayloads = <Map<String, dynamic>>[];
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          sentPayloads.add(Map<String, dynamic>.from(options.data as Map));
          return ResponseBody.fromString(
            jsonEncode({
              'data': {'status': sentPayloads.last['status']},
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final repo = AdminRepository(dio);
        await repo.updateAdminUserStatus('10', 'locked');
        await repo.updateAdminUserStatus('11', 'blocked');
        await repo.updateAdminUserStatus('12', 'active');

        expect(
          sentPayloads,
          equals([
            {'status': 'suspended'},
            {'status': 'suspended'},
            {'status': 'active'},
          ]),
        );
      },
    );

    test(
      'enables verification/host-application approve & reject strictly for pending status',
      () {
        final pending = AdminStatusHelper.classifyReviewStatus('pending');
        expect(pending.kind, AdminReviewStatusKind.pending);
        expect(pending.canApproveOrReject, isTrue);
        expect(pending.badgeLabel, 'Chờ duyệt');
        expect(AdminStatusHelper.canReviewSubmission('pending'), isTrue);
        expect(AdminStatusHelper.canReviewSubmission('PENDING'), isTrue);

        final approved = AdminStatusHelper.classifyReviewStatus('approved');
        expect(approved.kind, AdminReviewStatusKind.approved);
        expect(approved.canApproveOrReject, isFalse);
        expect(approved.badgeLabel, 'Đã duyệt');
        expect(AdminStatusHelper.canReviewSubmission('approved'), isFalse);

        final rejected = AdminStatusHelper.classifyReviewStatus('rejected');
        expect(rejected.kind, AdminReviewStatusKind.rejected);
        expect(rejected.canApproveOrReject, isFalse);
        expect(rejected.badgeLabel, 'Đã từ chối');
        expect(AdminStatusHelper.canReviewSubmission('rejected'), isFalse);

        final cancelled = AdminStatusHelper.classifyReviewStatus('cancelled');
        expect(cancelled.kind, AdminReviewStatusKind.closed);
        expect(cancelled.canApproveOrReject, isFalse);
      },
    );

    test(
      'sliceLatestRevenueWindow keeps chronological ascending order of latest 14 items on 30-day and 90-day series',
      () {
        final series90 = List<AdminRevenuePoint>.generate(
          90,
          (index) => AdminRevenuePoint(
            period: 'day-${(index + 1).toString().padLeft(2, '0')}',
            grossRevenue: (index + 1) * 500000,
            bookingCount: 1,
          ),
        );

        final latest14 = AdminStatusHelper.sliceLatestRevenueWindow(
          series90,
          maxItems: 14,
        );
        expect(latest14.length, 14);
        expect(latest14.first.period, 'day-77');
        expect(latest14.last.period, 'day-90');

        final series7 = series90.sublist(0, 7);
        final window7 = AdminStatusHelper.sliceLatestRevenueWindow(
          series7,
          maxItems: 14,
        );
        expect(window7.length, 7);
        expect(window7.first.period, 'day-01');
        expect(window7.last.period, 'day-07');

        expect(
          AdminStatusHelper.sliceLatestRevenueWindow<AdminRevenuePoint>(
            const [],
          ),
          isEmpty,
        );
      },
    );
  });

  group('Admin Font-Scaling (1.3x–2.0x) — Isolated Widget tests', () {
    testWidgets(
      'AdminStudioAvatar scales initials cleanly inside circle with inner padding at 1.3x, 1.6x, and 2.0x',
      (tester) async {
        for (final scale in const [1.3, 1.6, 2.0]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: const MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: AdminStudioAvatar(
                      name: 'Đặng Minh Thành',
                      size: 38,
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
          final textRect = tester.getRect(find.text('ĐT'));
          expect(textRect.left, greaterThanOrEqualTo(avatarRect.left + 3.5));
          expect(textRect.right, lessThanOrEqualTo(avatarRect.right - 3.5));
          expect(textRect.top, greaterThanOrEqualTo(avatarRect.top + 3.5));
          expect(
            textRect.bottom,
            lessThanOrEqualTo(avatarRect.bottom - 3.5),
          );
        }
      },
    );

    testWidgets(
      'AdminStudioSegmentedBar and AdminStudioFilterPill scale cleanly at 2.0x on narrow 320dp viewport',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminStudioSegmentedBar<int>(
                        selectedValue: 30,
                        items: const [
                          AdminStudioSegmentItem(value: 7, label: '7 ngày'),
                          AdminStudioSegmentItem(value: 30, label: '30 ngày'),
                          AdminStudioSegmentItem(value: 90, label: '90 ngày'),
                        ],
                        onSelected: (_) {},
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AdminStudioFilterPill(
                            label: 'Chờ duyệt',
                            selected: true,
                            onTap: () {},
                          ),
                          AdminStudioFilterPill(
                            label: 'Đã duyệt',
                            selected: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AdminStudioPillDropdown expands vertically at 1.5x–2.0x textScale without clipping and truncates long labels with ellipsis',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        Widget buildDropdownHarness(double scale) {
          return MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminStudioPillDropdown<String>(
                        key: const ValueKey('status-filter-dropdown'),
                        value: 'inactive',
                        minHeight: 40,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              'Trạng thái: Tất cả',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text(
                              'Đang hoạt động',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'suspended',
                            child: Text(
                              'Tạm khóa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text(
                              'Ngừng hoạt động',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AdminStudioPillDropdown<String>(
                          key: const ValueKey('legacy-verification-dropdown'),
                          value: 'pending',
                          minHeight: 36,
                          maxWidth: 220,
                          isExpanded: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 6,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text(
                                'Chờ duyệt',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildDropdownHarness(1.0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final heightAt1x = tester
            .getSize(find.byKey(const ValueKey('status-filter-dropdown')))
            .height;
        expect(heightAt1x, greaterThanOrEqualTo(40));

        await tester.pumpWidget(buildDropdownHarness(2.0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final heightAt2x = tester
            .getSize(find.byKey(const ValueKey('status-filter-dropdown')))
            .height;
        expect(heightAt2x, greaterThanOrEqualTo(40));

        // Open dropdown popup at 2.0x to verify menu items do not overflow
        await tester.tap(find.byKey(const ValueKey('status-filter-dropdown')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Đang hoạt động'), findsWidgets);
        expect(find.text('Tạm khóa'), findsWidgets);
        expect(find.text('Ngừng hoạt động'), findsWidgets);
      },
    );
  });
}
