import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/security/url_security_validator.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_sheet_sync_card.dart';

class _TestDioHolder {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
}

class _RecordedRequest {
  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final dynamic data;

  const _RecordedRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.data,
  });
}

class _FakeAdapter implements HttpClientAdapter {
  final List<_RecordedRequest> requests = [];
  final FutureOr<ResponseBody> Function(RequestOptions options) responder;

  _FakeAdapter({required this.responder});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _RecordedRequest(
        method: options.method.toUpperCase(),
        path: options.path,
        queryParameters: Map<String, dynamic>.from(options.queryParameters),
        data: options.data,
      ),
    );
    return await responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _connectedPayloadJson({
  String status = 'connected',
  int totalListings = 12,
  int pendingHoldsCount = 2,
  int syncErrorsCount = 0,
  bool autoSyncEnabled = true,
  String? lastErrorMessage,
  List<Map<String, dynamic>> openWarnings = const [],
  List<Map<String, dynamic>> recentLogs = const [],
}) {
  return {
    'success': true,
    'data': {
      'connected': true,
      'serviceAccountEmail':
          'villa-sync-bot@agency-sheets.iam.gserviceaccount.com',
      'defaultHostEditorEmail': 'athanhnee@gmail.com',
      'integration': {
        'integrationId': 10,
        'spreadsheetId': '1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA',
        'spreadsheetUrl':
            'https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit',
        'spreadsheetTitle': 'Lịch Villa Agency Nguyễn Văn A',
        'hostEditorEmail': 'athanhnee@gmail.com',
        'status': status,
        'autoSyncEnabled': autoSyncEnabled,
        'strictBookingPrecheck': true,
        'canWriteVerified': status == 'connected',
        'lastSyncedAt': '2026-10-31T05:00:00.000Z',
        'lastErrorMessage': lastErrorMessage,
        'consecutiveFailures': status == 'connected' ? 0 : 1,
      },
      'stats': {
        'totalListings': totalListings,
        'archivedListings': 1,
        'pendingHoldsCount': pendingHoldsCount,
        'openConflictsCount': openWarnings.length,
        'syncErrorsCount': syncErrorsCount,
        'pendingJobsCount': 0,
      },
      'listingsSummary': [
        {
          'listingId': 101,
          'title': 'Villa Bãi Sau 5PN',
          'status': 'active',
        },
      ],
      'openWarnings': openWarnings,
      'recentLogs': recentLogs,
    },
  };
}

void main() {
  group('UrlSecurityValidator — Google Sheets Anti-SSRF & Open-Redirect Guard',
      () {
    const validId = '1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA';

    test('accepts canonical https://docs.google.com/spreadsheets/d/<id> URLs',
        () {
      const editUrl =
          'https://docs.google.com/spreadsheets/d/$validId/edit#gid=0';
      expect(UrlSecurityValidator.extractGoogleSpreadsheetId(editUrl), validId);
      expect(UrlSecurityValidator.extractGoogleSpreadsheetId(validId), validId);
      expect(
        UrlSecurityValidator.isValidGoogleSpreadsheetUrl(
          editUrl,
          expectedSpreadsheetId: validId,
        ),
        isTrue,
      );
      expect(validateGoogleSheetInput(editUrl), isNull);
    });

    test(
        'rejects http, non-docs.google.com, credentials, custom ports, path traversal & mismatched IDs',
        () {
      const badInputs = <String>[
        'http://docs.google.com/spreadsheets/d/$validId/edit',
        'http://169.254.169.254/latest/meta-data/',
        'https://evil.com/spreadsheets/d/$validId/edit',
        'https://docs.google.com.evil.com/spreadsheets/d/$validId/edit',
        'https://sub.docs.google.com/spreadsheets/d/$validId/edit',
        'https://user:pass@docs.google.com/spreadsheets/d/$validId/edit',
        'https://docs.google.com:8443/spreadsheets/d/$validId/edit',
        'https://docs.google.com/spreadsheets/d/$validId/../other',
        'https://docs.google.com/document/d/$validId/edit',
        'short_id',
      ];

      for (final bad in badInputs) {
        expect(
          UrlSecurityValidator.extractGoogleSpreadsheetId(bad),
          isNull,
          reason: 'Expected null extraction for $bad',
        );
        expect(
          UrlSecurityValidator.isValidGoogleSpreadsheetUrl(bad),
          isFalse,
          reason: 'Expected false URL validation for $bad',
        );
        expect(validateGoogleSheetInput(bad), isNotNull);
      }

      expect(
        UrlSecurityValidator.isValidGoogleSpreadsheetUrl(
          'https://docs.google.com/spreadsheets/d/$validId/edit',
          expectedSpreadsheetId: '1DifferentSpreadsheetId9999999999999',
        ),
        isFalse,
      );

      // Ensure docs.google.com remains blocked for KYC admin docs and media rendering
      expect(
        UrlSecurityValidator.isTrustedAdminDocumentUrl(
          'https://docs.google.com/spreadsheets/d/$validId/edit',
        ),
        isFalse,
      );
      expect(
        UrlSecurityValidator.isSafeUploadOrMediaUrl(
          'https://docs.google.com/spreadsheets/d/$validId/edit',
        ),
        isFalse,
      );
    });
  });

  group('HostRepository — Google Sheets Agency Mode RBAC & Endpoints', () {
    test(
        'enforces strict Host-only role (401 unauthenticated, 403 guest/admin)',
        () async {
      final adapter = _FakeAdapter(
        responder: (_) => _json(_connectedPayloadJson()),
      );
      final holder = _TestDioHolder()..dio.httpClientAdapter = adapter;

      final unauthRepo = HostRepository(holder, roleResolver: () => null);
      await expectLater(
        () => unauthRepo.getHostSheetSyncStatus(),
        throwsA(
          isA<HostAuthorizationException>()
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );

      for (final role in ['guest', 'admin']) {
        final forbiddenRepo = HostRepository(holder, roleResolver: () => role);
        await expectLater(
          () => forbiddenRepo.syncHostSheetNow(),
          throwsA(
            isA<HostAuthorizationException>()
                .having((e) => e.statusCode, 'statusCode', 403),
          ),
        );
      }
      expect(adapter.requests, isEmpty);
    });

    test(
        'calls connect, sync-now, init-calendar, settings, resolve conflict, logs, disconnect & restoreListing',
        () async {
      final adapter = _FakeAdapter(
        responder: (options) {
          if (options.path == '/api/host/sheet-sync/logs') {
            return _json({
              'success': true,
              'data': {
                'items': [
                  {
                    'logId': 11,
                    'listingId': 101,
                    'listingTitle': 'Villa Bãi Sau 5PN',
                    'targetDate': '2026-11-20',
                    'direction': 'sheet_to_app',
                    'action': 'host_manual_block',
                    'detectedAt': '2026-10-31T05:10:00.000Z',
                  },
                ],
              },
            });
          }
          if (options.path == '/api/host/listings/101/restore') {
            return _json({
              'success': true,
              'data': {
                'listingId': 101,
                'title': 'Villa Bãi Sau 5PN',
                'status': 'hidden',
              },
            });
          }
          return _json(_connectedPayloadJson());
        },
      );
      final holder = _TestDioHolder()..dio.httpClientAdapter = adapter;
      final repo = HostRepository(holder, roleResolver: () => 'host');

      final connected = await repo.connectHostSheet(
        spreadsheetUrlOrId:
            'https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit',
        hostEditorEmail: 'athanhnee@gmail.com',
      );
      expect(connected.connected, isTrue);
      expect(connected.stats.totalListings, 12);

      await repo.syncHostSheetNow();
      await repo.initializeHostSheetCalendar();
      await repo.updateHostSheetSettings(autoSyncEnabled: false);
      await repo.resolveHostSheetConflict(
        conflictId: 501,
        action: 'undo_bulk_change',
      );
      final logs = await repo.getHostSheetChangeLogs(search: '101');
      expect(logs.single.listingId, 101);

      final restored = await repo.restoreHostListing('101');
      expect(restored['listingId'], 101);

      await repo.disconnectHostSheet();

      final paths =
          adapter.requests.map((r) => '${r.method} ${r.path}').toList();
      expect(
        paths,
        containsAll(<String>[
          'POST /api/host/sheet-sync/connect',
          'POST /api/host/sheet-sync/sync-now',
          'POST /api/host/sheet-sync/init-calendar',
          'PATCH /api/host/sheet-sync/settings',
          'POST /api/host/sheet-sync/conflicts/501/resolve',
          'GET /api/host/sheet-sync/logs',
          'POST /api/host/listings/101/restore',
          'DELETE /api/host/sheet-sync/disconnect',
        ]),
      );
    });
  });

  group('HostSheetSyncCard — Widget UX, Anti-Double-Submit, Undo & Responsive',
      () {
    testWidgets(
        'disconnected flow validates SSRF URLs locally and connects with prefilled athanhnee@gmail.com',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var isConnected = false;
      final adapter = _FakeAdapter(
        responder: (options) {
          if (options.method == 'POST' &&
              options.path == '/api/host/sheet-sync/connect') {
            isConnected = true;
            return _json(_connectedPayloadJson());
          }
          if (!isConnected) {
            return _json({
              'success': true,
              'data': {
                'connected': false,
                'serviceAccountEmail':
                    'villa-sync-bot@agency-sheets.iam.gserviceaccount.com',
                'defaultHostEditorEmail': 'athanhnee@gmail.com',
                'stats': {'totalListings': 5},
              },
            });
          }
          return _json(_connectedPayloadJson());
        },
      );
      final holder = _TestDioHolder()..dio.httpClientAdapter = adapter;
      final repo = HostRepository(holder, roleResolver: () => 'host');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: HostSheetSyncCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa kết nối'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sheet_sync_open_connect_btn')));
      await tester.pumpAndSettle();

      // Default host editor email is pre-filled with athanhnee@gmail.com
      final editorField = tester.widget<TextFormField>(
        find.byKey(const Key('sheet_sync_editor_email_input')),
      );
      expect(editorField.controller?.text, 'athanhnee@gmail.com');

      // Enter malicious URL -> blocked by form validator with 0 POST calls
      await tester.enterText(
        find.byKey(const Key('sheet_sync_url_input')),
        'https://evil.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA',
      );
      final submitBtn = find.byKey(const Key('sheet_sync_submit_connect_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        adapter.requests.where((r) => r.method == 'POST'),
        isEmpty,
      );

      // Enter valid Google Sheets URL -> connects & renders connected dashboard
      await tester.enterText(
        find.byKey(const Key('sheet_sync_url_input')),
        'https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789HostA/edit',
      );
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Đã kết nối · 12 căn'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets(
        'connected dashboard prevents sync-now double submit, handles bulk undo, logs filter & external URL validation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final syncCompleter = Completer<ResponseBody>();
      var undoResolved = false;
      Uri? launchedUri;
      var calendarRefreshCallbacks = 0;

      final adapter = _FakeAdapter(
        responder: (options) {
          if (options.method == 'POST' &&
              options.path == '/api/host/sheet-sync/sync-now') {
            return syncCompleter.future;
          }
          if (options.method == 'POST' &&
              options.path == '/api/host/sheet-sync/conflicts/501/resolve') {
            undoResolved = true;
            return _json(_connectedPayloadJson());
          }
          if (options.path == '/api/host/sheet-sync/logs') {
            return _json({
              'success': true,
              'data': {
                'items': [
                  {
                    'logId': 99,
                    'listingId': 101,
                    'listingTitle': 'Villa Bãi Sau 5PN',
                    'targetDate': '2026-11-25',
                    'direction': 'sheet_to_app',
                    'action': 'host_manual_block',
                    'detectedAt': '2026-10-31T06:00:00.000Z',
                  },
                ],
              },
            });
          }
          return _json(
            _connectedPayloadJson(
              openWarnings: undoResolved
                  ? const []
                  : [
                      {
                        'conflictId': 501,
                        'listingId': 101,
                        'listingTitle': 'Villa Bãi Sau 5PN',
                        'conflictType': 'bulk_row_block_warning',
                        'severity': 'high',
                        'status': 'open',
                        'description':
                            'Cảnh báo: 18 ngày trong tháng 11-2026 vừa bị tô khóa cùng lúc.',
                        'canUndoBulkChange': true,
                      },
                    ],
            ),
          );
        },
      );

      final holder = _TestDioHolder()..dio.httpClientAdapter = adapter;
      final repo = HostRepository(holder, roleResolver: () => 'host');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: HostSheetSyncCard(
                  onCalendarChanged: () => calendarRefreshCallbacks += 1,
                  externalLauncher: (uri) async {
                    launchedUri = uri;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Bulk warning banner & 1-click Undo ("Hoàn tác")
      expect(find.byKey(const Key('sheet_sync_warning_501')), findsOneWidget);
      final undoBtn = find.byKey(const Key('sheet_sync_undo_bulk_501'));
      await tester.ensureVisible(undoBtn);
      await tester.pumpAndSettle();
      await tester.tap(undoBtn);
      await tester.pumpAndSettle();

      expect(undoResolved, isTrue);
      expect(calendarRefreshCallbacks, 1);
      expect(find.byKey(const Key('sheet_sync_warning_501')), findsNothing);

      // 2. Anti-double-submit on "Đồng bộ ngay"
      final syncBtn = find.byKey(const Key('sheet_sync_now_btn'));
      await tester.ensureVisible(syncBtn);
      await tester.pumpAndSettle();
      await tester.tap(syncBtn);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(
        syncBtn,
        warnIfMissed: false,
      ); // Second rapid tap while busy -> ignored!
      await tester.pump(const Duration(milliseconds: 20));

      final syncRequests = adapter.requests
          .where((r) => r.path == '/api/host/sheet-sync/sync-now')
          .length;
      expect(syncRequests, 1);

      syncCompleter.complete(_json(_connectedPayloadJson()));
      await tester.pumpAndSettle();

      // 3. Open validated Google Spreadsheet URL externally
      final openUrlBtn = find.byKey(const Key('sheet_sync_open_url_btn'));
      await tester.ensureVisible(openUrlBtn);
      await tester.pumpAndSettle();
      await tester.tap(openUrlBtn);
      await tester.pumpAndSettle();
      expect(launchedUri?.host, 'docs.google.com');

      // 4. Open Change Logs sheet & filter by #101
      final logsBtn = find.byKey(const Key('sheet_sync_logs_btn'));
      await tester.ensureVisible(logsBtn);
      await tester.pumpAndSettle();
      await tester.tap(logsBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('sheet_sync_logs_search_input')),
        '101',
      );
      await tester.tap(find.byKey(const Key('sheet_sync_logs_search_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Villa Bãi Sau 5PN (#101)'), findsOneWidget);
    });

    testWidgets(
        'renders inside Calendar 20dp container across 320dp..768dp and textScale 1.0..1.6 with zero overflow',
        (tester) async {
      final adapter = _FakeAdapter(
        responder: (options) {
          return _json(
            _connectedPayloadJson(
              status: 'permission_error',
              syncErrorsCount: 1,
              lastErrorMessage:
                  'Chưa cấp quyền Editor cho email hệ thống trên Google Sheets.',
              openWarnings: [
                {
                  'conflictId': 701,
                  'listingId': 101,
                  'listingTitle': 'Villa Bãi Sau 5PN',
                  'conflictType': 'missing_listing_row',
                  'severity': 'critical',
                  'status': 'open',
                  'description':
                      'Phát hiện thiếu dòng mã căn 101 trên tab tháng 11-2026.',
                  'canUndoBulkChange': false,
                },
              ],
            ),
          );
        },
      );

      final holder = _TestDioHolder()..dio.httpClientAdapter = adapter;
      final repo = HostRepository(holder, roleResolver: () => 'host');

      for (final width in [320.0, 390.0, 768.0]) {
        for (final scale in [1.0, 1.6]) {
          await tester.binding.setSurfaceSize(Size(width, 920));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostRepositoryProvider.overrideWithValue(repo),
                hostCurrentUserRoleProvider.overrideWithValue('host'),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 920),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const MaterialApp(
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: HostSheetSyncCard(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('host_sheet_sync_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('sheet_sync_permission_error_banner')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('sheet_sync_repair_structure_701')),
            findsOneWidget,
          );
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
