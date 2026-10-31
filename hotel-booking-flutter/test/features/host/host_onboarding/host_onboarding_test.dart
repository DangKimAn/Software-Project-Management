import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_onboarding_screens.dart';
import 'package:hotel_booking_flutter/features/host/services/host_file_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// TEST DOUBLES & FAKE NETWORK INFRASTRUCTURE
// =============================================================================

class _FakeHostFilePickerService implements HostFilePickerService {
  _FakeHostFilePickerService({
    List<HostPickedFile?>? queue,
  }) : _queue = List<HostPickedFile?>.from(queue ?? const <HostPickedFile?>[]);

  final List<HostPickedFile?> _queue;
  HostPickedFile? defaultFile;
  Object? errorToThrow;
  final List<String> requestedTitles = <String>[];

  void enqueue(HostPickedFile? file) {
    _queue.add(file);
  }

  @override
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu xác minh',
  }) async {
    requestedTitles.add(title);
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (_queue.isNotEmpty) {
      return _queue.removeAt(0);
    }
    return defaultFile;
  }

  @override
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  }) async =>
      const <HostPickedFile>[];

  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async =>
      defaultFile;

  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async =>
      defaultFile!;
}

class _FakePermissionService implements HostOnboardingPermissionService {
  _FakePermissionService({
    this.result = const HostKycPermissionResult(
      status: HostKycPermissionStatus.granted,
    ),
  });

  HostKycPermissionResult result;
  final List<HostKycFileSource> requestedSources = <HostKycFileSource>[];

  @override
  Future<HostKycPermissionResult> requestPermission(
    HostKycFileSource source,
  ) async {
    requestedSources.add(source);
    return result;
  }
}

class _FakeHostOnboardingRepository extends HostOnboardingApiService {
  _FakeHostOnboardingRepository({
    this.currentRecord,
    this.fetchError,
    this.submitError,
    this.submitReturnedStatus = HostApplicationStatus.pending,
    this.submitCompleter,
  }) : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')));

  HostApplicationRecord? currentRecord;
  Object? fetchError;
  Object? submitError;
  Object? cancelError;
  HostApplicationStatus submitReturnedStatus;
  Completer<void>? submitCompleter;
  bool simulateProgressSteps = true;

  int getMyApplicationCount = 0;
  int submitCount = 0;
  int cancelCount = 0;
  HostKycSubmissionDto? lastSubmittedDto;
  final List<double> recordedOverallProgress = <double>[];

  @override
  Future<bool> cancelApplication() async {
    cancelCount += 1;
    if (cancelError != null) {
      throw cancelError!;
    }
    currentRecord = null;
    return true;
  }

  @override
  Future<HostApplicationRecord?> getMyApplicationRecord() async {
    getMyApplicationCount += 1;
    if (fetchError != null) {
      throw fetchError!;
    }
    return currentRecord;
  }

  @override
  Future<Map<String, dynamic>?> getMyApplication() async {
    final rec = await getMyApplicationRecord();
    if (rec == null) return null;
    return <String, dynamic>{
      'id': rec.id,
      'status': rec.status.apiValue,
      'contactName': rec.contactName,
      'contactEmail': rec.contactEmail,
      'phone': rec.phone,
      'profileType': rec.profileType.value,
      'documentType': rec.documentType.value,
      'businessAddress': rec.businessAddress,
      'note': rec.note,
      'rejectReason': rec.rejectReason,
    };
  }

  @override
  Future<HostApplicationRecord> submitKycApplication(
    HostKycSubmissionDto dto, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    submitCount += 1;
    lastSubmittedDto = dto;

    final totalBytes = (dto.identityFront?.sizeBytes ?? 0) +
        (dto.identityBack?.sizeBytes ?? 0) +
        (dto.identitySingle?.sizeBytes ?? 0) +
        (dto.businessLicense?.sizeBytes ?? 0);
    final effectiveTotal = totalBytes > 0 ? totalBytes : 2048;

    if (simulateProgressSteps && onSendProgress != null) {
      final half = (effectiveTotal * 0.5).round();
      onSendProgress(half, effectiveTotal);
      recordedOverallProgress.add(half / effectiveTotal);
    }

    if (submitCompleter != null) {
      await submitCompleter!.future;
    }

    if (submitError != null) {
      throw submitError!;
    }

    if (simulateProgressSteps && onSendProgress != null) {
      onSendProgress(effectiveTotal, effectiveTotal);
      recordedOverallProgress.add(1.0);
    }

    final created = HostApplicationRecord(
      id: 2026,
      status: submitReturnedStatus,
      contactName: dto.contactName.trim(),
      contactEmail: dto.contactEmail.trim(),
      phone: dto.phone.trim(),
      profileType: dto.profileType,
      documentType: dto.documentType,
      businessAddress: dto.businessAddress.trim(),
      note: dto.note.trim(),
      createdAt: '2026-10-27T04:30:00.000Z',
      documents: <HostApplicationDocument>[
        if (dto.identityFront != null)
          HostApplicationDocument(
            documentType: 'identity_front',
            fileUrl: 'https://r2.private/kyc/${dto.identityFront!.name}',
            originalFilename: dto.identityFront!.name,
            mimeType: dto.identityFront!.mimeType,
            fileSize: dto.identityFront!.sizeBytes,
          ),
        if (dto.identityBack != null)
          HostApplicationDocument(
            documentType: 'identity_back',
            fileUrl: 'https://r2.private/kyc/${dto.identityBack!.name}',
            originalFilename: dto.identityBack!.name,
            mimeType: dto.identityBack!.mimeType,
            fileSize: dto.identityBack!.sizeBytes,
          ),
        if (dto.identitySingle != null)
          HostApplicationDocument(
            documentType: 'identity_single',
            fileUrl: 'https://r2.private/kyc/${dto.identitySingle!.name}',
            originalFilename: dto.identitySingle!.name,
            mimeType: dto.identitySingle!.mimeType,
            fileSize: dto.identitySingle!.sizeBytes,
          ),
        if (dto.businessLicense != null)
          HostApplicationDocument(
            documentType: 'business_license',
            fileUrl: 'https://r2.private/kyc/${dto.businessLicense!.name}',
            originalFilename: dto.businessLicense!.name,
            mimeType: dto.businessLicense!.mimeType,
            fileSize: dto.businessLicense!.sizeBytes,
          ),
      ],
    );
    currentRecord = created;
    return created;
  }
}

class _FakeHostRepositoryForOnboarding extends HostRepository {
  _FakeHostRepositoryForOnboarding() : super(Dio());
  int _callIndex = 0;

  @override
  Future<HostIdentityAiResult> analyzeIdentityCard({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    _callIndex++;
    final isBack =
        filename.toLowerCase().contains('back') || (_callIndex % 2 == 0);
    return HostIdentityAiResult(
      documentType: 'cccd',
      side: isBack ? 'back' : 'front',
      idNumber: '079090123456',
      fullName: isBack ? null : 'NGUYỄN VĂN AN',
      isDocumentValid: true,
      isClear: true,
      confidence: 0.99,
      warnings: const [],
      summaryVi: isBack ? 'CCCD mặt sau' : 'CCCD mặt trước - NGUYỄN VĂN AN',
    );
  }
}

// =============================================================================
// REAL FILE BYTES HELPERS (JPEG, PNG, WebP, PDF)
// =============================================================================

final Uint8List _kValidPng1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Uint8List _validJpegBytes([int length = 1024]) {
  final bytes = Uint8List(length);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  bytes[3] = 0xE0;
  return bytes;
}

Uint8List _validWebpBytes([int length = 1024]) {
  final bytes = Uint8List(length);
  const riff = <int>[0x52, 0x49, 0x46, 0x46];
  const webp = <int>[0x57, 0x45, 0x42, 0x50];
  for (var i = 0; i < 4; i++) {
    bytes[i] = riff[i];
    bytes[8 + i] = webp[i];
  }
  return bytes;
}

Uint8List _validPdfBytes([int length = 1024]) {
  final bytes = Uint8List(length);
  final header = ascii.encode('%PDF-1.7\n');
  for (var i = 0; i < header.length && i < bytes.length; i++) {
    bytes[i] = header[i];
  }
  return bytes;
}

HostPickedFile _makeJpegFile(String name, {int sizeBytes = 1024}) {
  return HostPickedFile(
    name: name,
    mimeType: 'image/jpeg',
    sizeBytes: sizeBytes,
    bytes: _validJpegBytes(sizeBytes < 16 ? 16 : sizeBytes),
  );
}

HostPickedFile _makePngFile(String name, {int? sizeBytes}) {
  return HostPickedFile(
    name: name,
    mimeType: 'image/png',
    sizeBytes: sizeBytes ?? _kValidPng1x1.length,
    bytes: _kValidPng1x1,
  );
}

HostPickedFile _makeWebpFile(String name, {int sizeBytes = 1024}) {
  return HostPickedFile(
    name: name,
    mimeType: 'image/webp',
    sizeBytes: sizeBytes,
    bytes: _validWebpBytes(sizeBytes < 16 ? 16 : sizeBytes),
  );
}

HostPickedFile _makePdfFile(String name, {int sizeBytes = 2048}) {
  return HostPickedFile(
    name: name,
    mimeType: 'application/pdf',
    sizeBytes: sizeBytes,
    bytes: _validPdfBytes(sizeBytes < 16 ? 16 : sizeBytes),
  );
}

HostApplicationRecord _sampleRecord({
  required HostApplicationStatus status,
  String? rejectReason,
  HostProfileType profileType = HostProfileType.individual,
  HostDocumentType documentType = HostDocumentType.cccd,
}) {
  return HostApplicationRecord(
    id: 108,
    status: status,
    contactName: 'Nguyễn Minh Thành',
    contactEmail: 'minhthanh@vungtau.vn',
    phone: '0901234567',
    profileType: profileType,
    documentType: documentType,
    businessAddress: '164B Phan Chu Trinh, Phường 2, TP. Vũng Tàu',
    note: 'Chuỗi 3 villa nghỉ dưỡng sát biển',
    rejectReason: rejectReason,
    createdAt: '2026-10-25T08:00:00.000Z',
    documents: const <HostApplicationDocument>[
      HostApplicationDocument(
        documentType: 'identity_front',
        fileUrl: 'https://r2.private/kyc/cccd_front.jpg',
        originalFilename: 'cccd_front.jpg',
      ),
      HostApplicationDocument(
        documentType: 'identity_back',
        fileUrl: 'https://r2.private/kyc/cccd_back.jpg',
        originalFilename: 'cccd_back.jpg',
      ),
    ],
  );
}

Widget _buildRouterApp({
  required String initialLocation,
  required _FakeHostOnboardingRepository repository,
  _FakeHostFilePickerService? pickerService,
  _FakePermissionService? permissionService,
  HostOnboardingDraftService? draftService,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('HOME_SCREEN'))),
      ),
      GoRoute(
        path: '/dang-nhap',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LOGIN_SCREEN'))),
      ),
      GoRoute(
        path: '/host',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('HOST_PORTAL_SCREEN'))),
      ),
      GoRoute(
        path: '/tro-thanh-host',
        builder: (context, state) => const TroThanhHostLandingScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'dang-ky',
            builder: (context, state) => const DangKyHostScreen(),
          ),
          GoRoute(
            path: 'trang-thai',
            builder: (context, state) => const TrangThaiHostScreen(),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      hostOnboardingApiProvider.overrideWithValue(repository),
      hostRepositoryProvider
          .overrideWithValue(_FakeHostRepositoryForOnboarding()),
      if (pickerService != null)
        hostFilePickerProvider.overrideWithValue(pickerService),
      if (permissionService != null)
        hostOnboardingPermissionProvider.overrideWithValue(permissionService),
      if (draftService != null)
        hostOnboardingDraftServiceProvider.overrideWithValue(draftService),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
    ),
  );
}

Future<void> _fillValidContactForm(
  WidgetTester tester, {
  HostProfileType profileType = HostProfileType.individual,
  HostDocumentType documentType = HostDocumentType.cccd,
}) async {
  await tester.enterText(
    find.byKey(const Key('kyc_contact_name_input')),
    'Nguyễn Minh Thành',
  );
  await tester.enterText(
    find.byKey(const Key('kyc_contact_email_input')),
    'minhthanh@vungtau.vn',
  );
  await tester.enterText(
    find.byKey(const Key('kyc_phone_input')),
    '0901234567',
  );

  if (profileType != HostProfileType.individual) {
    final profileDropdown = find.byKey(const Key('kyc_profile_type_dropdown'));
    await tester.ensureVisible(profileDropdown);
    await tester.tap(profileDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(profileType.labelVi).last);
    await tester.pumpAndSettle();
  }

  await tester.enterText(
    find.byKey(const Key('kyc_business_address_input')),
    '164B Phan Chu Trinh, Phường 2, TP. Vũng Tàu',
  );
  await tester.enterText(
    find.byKey(const Key('kyc_note_input')),
    'Biệt thự nghỉ dưỡng gần biển Bãi Sau',
  );

  if (documentType != HostDocumentType.cccd) {
    final docDropdown = find.byKey(const Key('kyc_document_type_dropdown'));
    await tester.ensureVisible(docDropdown);
    await tester.tap(docDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(documentType.labelVi).last);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapPickButton(WidgetTester tester, String slotKey) async {
  final btn = find.byKey(Key('kyc_pick_btn_$slotKey'));
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ===========================================================================
  // 1. STATUS AUDIT: /tro-thanh-host -> /tro-thanh-host/dang-ky -> /tro-thanh-host/trang-thai
  // ===========================================================================
  group('1. Status Audit: Strict 6 API Statuses & Non-Promotion Guard', () {
    testWidgets(
      'TrangThaiHostScreen displays exact 6 API statuses (none, pending, approved, rejected, supplement_required, revoked)',
      (tester) async {
        final testCases = <({
          HostApplicationRecord? record,
          String statusApiValue,
          String badgeLabel,
          String headline,
        })>[
          (
            record: null,
            statusApiValue: 'none',
            badgeLabel: 'Chưa đăng ký (none)',
            headline: 'Chưa có hồ sơ đăng ký Host',
          ),
          (
            record: _sampleRecord(status: HostApplicationStatus.pending),
            statusApiValue: 'pending',
            badgeLabel: 'Đang chờ duyệt (pending)',
            headline: 'Hồ sơ đang chờ xét duyệt',
          ),
          (
            record: _sampleRecord(status: HostApplicationStatus.approved),
            statusApiValue: 'approved',
            badgeLabel: 'Đã phê duyệt (approved)',
            headline: 'Hồ sơ đã được phê duyệt',
          ),
          (
            record: _sampleRecord(
              status: HostApplicationStatus.rejected,
              rejectReason: 'Ảnh mặt sau CCCD bị mờ góc phải.',
            ),
            statusApiValue: 'rejected',
            badgeLabel: 'Bị từ chối (rejected)',
            headline: 'Hồ sơ bị từ chối',
          ),
          (
            record: _sampleRecord(
              status: HostApplicationStatus.supplementRequired,
              rejectReason: 'Vui lòng bổ sung bản chụp Giấy phép kinh doanh.',
            ),
            statusApiValue: 'supplement_required',
            badgeLabel: 'Yêu cầu bổ sung hồ sơ (supplement_required)',
            headline: 'Yêu cầu bổ sung thông tin',
          ),
          (
            record: _sampleRecord(
              status: HostApplicationStatus.revoked,
              rejectReason: 'Tài khoản vi phạm quy định vận hành chỗ nghỉ.',
            ),
            statusApiValue: 'revoked',
            badgeLabel: 'Đã thu hồi quyền Host (revoked)',
            headline: 'Quyền Host đã bị thu hồi',
          ),
        ];

        for (final tc in testCases) {
          final repo = _FakeHostOnboardingRepository(currentRecord: tc.record);
          await tester.pumpWidget(
            _buildRouterApp(
              initialLocation: '/tro-thanh-host/trang-thai',
              repository: repo,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(Key('kyc_status_card_${tc.statusApiValue}')),
            findsOneWidget,
          );
          expect(
            find.byKey(Key('kyc_status_badge_${tc.statusApiValue}')),
            findsOneWidget,
          );
          expect(find.text(tc.badgeLabel), findsOneWidget);
          expect(find.text(tc.headline), findsOneWidget);

          if (tc.record?.rejectReason != null) {
            expect(
              find.byKey(const Key('status_reject_reason_box')),
              findsOneWidget,
            );
            expect(
              find.textContaining(tc.record!.rejectReason!),
              findsOneWidget,
            );
          }

          if (tc.statusApiValue == 'approved') {
            expect(
              find.byKey(const Key('status_open_host_portal_btn')),
              findsOneWidget,
            );
          } else {
            expect(
              find.byKey(const Key('status_open_host_portal_btn')),
              findsNothing,
            );
          }

          if (tc.statusApiValue == 'revoked' ||
              tc.statusApiValue == 'pending') {
            expect(
              find.byKey(const Key('status_resubmit_btn')),
              findsNothing,
            );
          }

          if (tc.statusApiValue == 'pending') {
            expect(
              find.byKey(const Key('status_cancel_application_btn')),
              findsOneWidget,
            );
          } else {
            expect(
              find.byKey(const Key('status_cancel_application_btn')),
              findsNothing,
            );
          }
        }
      },
    );

    testWidgets(
      'TrangThaiHostScreen handles cancel host application flow with confirmation and reset to none',
      (tester) async {
        final pendingRecord =
            _sampleRecord(status: HostApplicationStatus.pending);
        final repo =
            _FakeHostOnboardingRepository(currentRecord: pendingRecord);

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/trang-thai',
            repository: repo,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Cancel button exists for pending application
        final cancelBtn =
            find.byKey(const Key('status_cancel_application_btn'));
        expect(cancelBtn, findsOneWidget);

        // 2. Tapping opens confirmation dialog
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('confirm_cancel_application_dialog')),
          findsOneWidget,
        );
        expect(find.text('Hủy nộp đơn làm Host?'), findsOneWidget);

        // 3. User cancels dialog -> application stays intact
        await tester.tap(find.byKey(const Key('cancel_dialog_back_btn')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('confirm_cancel_application_dialog')),
          findsNothing,
        );
        expect(repo.cancelCount, 0);
        expect(
          find.byKey(const Key('status_cancel_application_btn')),
          findsOneWidget,
        );

        // 4. User opens dialog again and confirms cancellation
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('confirm_cancel_application_btn')));
        await tester.pumpAndSettle();

        expect(repo.cancelCount, 1);
        expect(
          find.text('Đã hủy đơn đăng ký làm Host thành công.'),
          findsOneWidget,
        );

        // 5. Screen reloads to status none (Chưa có hồ sơ đăng ký Host)
        expect(find.byKey(const Key('kyc_status_card_none')), findsOneWidget);
        expect(find.byKey(const Key('status_resubmit_btn')), findsOneWidget);
        expect(find.text('Đăng ký làm Host'), findsOneWidget);
      },
    );

    testWidgets(
      'TrangThaiHostScreen handles cancellation error by displaying error SnackBar',
      (tester) async {
        final pendingRecord =
            _sampleRecord(status: HostApplicationStatus.pending);
        final repo = _FakeHostOnboardingRepository(
          currentRecord: pendingRecord,
        )..cancelError = DioException(
            requestOptions:
                RequestOptions(path: '/api/host/applications/cancel'),
            response: Response(
              requestOptions:
                  RequestOptions(path: '/api/host/applications/cancel'),
              statusCode: 400,
              data: {'message': 'Không thể hủy hồ sơ vào lúc này.'},
            ),
          );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/trang-thai',
            repository: repo,
          ),
        );
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('status_cancel_application_btn')));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('confirm_cancel_application_btn')));
        await tester.pumpAndSettle();

        expect(repo.cancelCount, 1);
        expect(
          find.byKey(const Key('cancel_application_error_snackbar')),
          findsOneWidget,
        );
        expect(find.text('Không thể hủy hồ sơ vào lúc này.'), findsOneWidget);
      },
    );

    testWidgets(
      'TroThanhHostLandingScreen renders dedicated CTA & banner for pending, revoked, approved, rejected, supplement_required, and none',
      (tester) async {
        // 1. Revoked status on landing screen
        final revokedRepo = _FakeHostOnboardingRepository(
          currentRecord: _sampleRecord(
            status: HostApplicationStatus.revoked,
            rejectReason: 'Thu hồi quyền do vi phạm chính sách.',
          ),
        );
        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host',
            repository: revokedRepo,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('host_landing_revoked_status_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('host_landing_status_banner_revoked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('host_landing_register_btn')),
          findsNothing,
        );

        // 2. Pending status on landing screen
        final pendingRepo = _FakeHostOnboardingRepository(
          currentRecord: _sampleRecord(status: HostApplicationStatus.pending),
        );
        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host',
            repository: pendingRepo,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('host_landing_pending_status_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('host_landing_status_banner_pending')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Never auto-transitions to approved upon form submission even if backend POST payload unexpectedly returns approved',
      (tester) async {
        final repo = _FakeHostOnboardingRepository(
          currentRecord: null,
          // Simulate a faulty backend response returning approved on POST submit:
          submitReturnedStatus: HostApplicationStatus.approved,
        );
        final picker = _FakeHostFilePickerService(
          queue: <HostPickedFile?>[
            _makePngFile('cccd_front.png'),
            _makePngFile('cccd_back.png'),
          ],
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            pickerService: picker,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidContactForm(tester);
        await _tapPickButton(tester, 'identityFront');
        await _tapPickButton(tester, 'identityBack');

        // Ensure the GET /me call after navigation also reflects the safe pending record
        // by clearing currentRecord so TrangThaiHostScreen uses the guarded post-submit state,
        // or even if resolvePostSubmitStatus is checked directly:
        expect(
          HostOnboardingErrorClassifier.resolvePostSubmitStatus(
            _sampleRecord(status: HostApplicationStatus.approved),
          ),
          HostApplicationStatus.pending,
        );

        // Make repo return null on subsequent GET so TrangThaiHostScreen uses hostLastSubmittedApplicationProvider,
        // AND verify that even if repo returns pending, it never shows approved.
        repo.currentRecord = null;

        final submitBtn = find.byKey(const Key('kyc_submit_btn'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(repo.submitCount, 1);
        // Must navigate to /tro-thanh-host/trang-thai and show PENDING, never APPROVED
        expect(
          find.byKey(const Key('kyc_status_card_pending')),
          findsOneWidget,
        );
        expect(find.text('Đang chờ duyệt (pending)'), findsOneWidget);
        expect(
          find.byKey(const Key('kyc_status_card_approved')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('status_open_host_portal_btn')),
          findsNothing,
        );
      },
    );
  });

  // ===========================================================================
  // 2. VALIDATION, FILE FORMATS (JPG/PNG/WebP/PDF <= 5MB), PERMISSIONS & PREVIEW
  // ===========================================================================
  group('2. KYC Document & Backend Validator Parity', () {
    test(
      'HostOnboardingValidator validates JPG, PNG, WebP, PDF <= 5MB, magic bytes, CCCD 2-side, Passport, and Business License',
      () {
        expect(
          HostOnboardingValidator.validatePickedFile(
            _makeJpegFile('front.jpg'),
          ),
          isNull,
        );
        expect(
          HostOnboardingValidator.validatePickedFile(
            _makePngFile('back.png'),
          ),
          isNull,
        );
        expect(
          HostOnboardingValidator.validatePickedFile(
            _makeWebpFile('id.webp'),
          ),
          isNull,
        );
        expect(
          HostOnboardingValidator.validatePickedFile(
            _makePdfFile('business_license.pdf'),
          ),
          isNull,
        );

        // Oversized (> 5MB) rejected
        final oversized = _makeJpegFile(
          'huge_photo.jpg',
          sizeBytes: kMaxHostUploadBytes + 1024,
        );
        expect(
          HostOnboardingValidator.validatePickedFile(oversized),
          contains('5MB'),
        );

        // Disallowed extension rejected
        final badExt = HostPickedFile(
          name: 'payload.exe',
          mimeType: 'image/jpeg',
          sizeBytes: 512,
          bytes: _validJpegBytes(512),
        );
        expect(
          HostOnboardingValidator.validatePickedFile(badExt),
          contains('Phần mở rộng tệp'),
        );

        // Spoofed magic bytes rejected
        final spoofedPdf = HostPickedFile(
          name: 'fake_document.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 64,
          bytes: Uint8List.fromList(
            ascii.encode('<html><body>Not a real PDF file</body></html>'),
          ),
        );
        expect(
          HostOnboardingValidator.validatePickedFile(spoofedPdf),
          contains('Nội dung tệp'),
        );

        // Submission validation: Business + CCCD missing identityBack & businessLicense
        final missingResult = HostOnboardingValidator.validateSubmission(
          contactName: 'Công ty TNHH Villa Vũng Tàu',
          contactEmail: 'contact@villavungtau.vn',
          phone: '0901234567',
          profileType: HostProfileType.business,
          documentType: HostDocumentType.cccd,
          businessAddress: '100 Thùy Vân, Vũng Tàu',
          note: '',
          identityFront: _makePngFile('front.png'),
          identityBack: null,
          identitySingle: null,
          businessLicense: null,
        );
        expect(missingResult.isValid, isFalse);
        expect(missingResult.slotErrors.containsKey('identityBack'), isTrue);
        expect(missingResult.slotErrors.containsKey('businessLicense'), isTrue);
      },
    );

    testWidgets(
      'blocks KYC submission when required fields or CCCD back / businessLicense slots are missing',
      (tester) async {
        final repo = _FakeHostOnboardingRepository();
        final picker = _FakeHostFilePickerService(
          queue: <HostPickedFile?>[
            _makePngFile('cccd_front.png'),
          ],
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            pickerService: picker,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidContactForm(
          tester,
          profileType: HostProfileType.business,
          documentType: HostDocumentType.cccd,
        );
        await _tapPickButton(tester, 'identityFront');

        final submitBtn = find.byKey(const Key('kyc_submit_btn'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(repo.submitCount, 0);
        expect(find.byKey(const Key('kyc_error_banner')), findsOneWidget);
        expect(
          find.byKey(const Key('kyc_slot_error_identityBack')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('kyc_slot_error_businessLicense')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'requests permission via 36dp source sheet, handles denied permission, renders real PDF & Image previews, and supports delete & reselect',
      (tester) async {
        final repo = _FakeHostOnboardingRepository();
        final picker = _FakeHostFilePickerService(
          queue: <HostPickedFile?>[
            _makePdfFile('passport_scan.pdf'),
            _makePngFile('passport_reselected.png'),
          ],
        );
        final permission = _FakePermissionService(
          result: const HostKycPermissionResult(
            status: HostKycPermissionStatus.denied,
            messageVi:
                'Quyền truy cập máy ảnh đã bị từ chối. Vui lòng cấp quyền để chụp giấy tờ.',
          ),
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            pickerService: picker,
            permissionService: permission,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidContactForm(
          tester,
          documentType: HostDocumentType.passport,
        );

        // Tap scan icon button to open 36dp source bottom sheet
        final scanBtn = find.byKey(const Key('kyc_scan_btn_identitySingle'));
        await tester.ensureVisible(scanBtn);
        await tester.tap(scanBtn);
        await tester.pumpAndSettle();

        final cameraOption = find.byKey(
          const Key('kyc_source_camera_identitySingle'),
        );
        expect(cameraOption, findsOneWidget);
        await tester.tap(cameraOption);
        await tester.pumpAndSettle();

        // Permission was denied -> slot error displayed, picker not called
        expect(permission.requestedSources,
            contains(HostKycFileSource.cameraScan));
        expect(picker.requestedTitles, isEmpty);
        expect(
          find.byKey(const Key('kyc_slot_error_identitySingle')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Quyền truy cập máy ảnh đã bị từ chối'),
          findsWidgets,
        );

        // Grant permission and pick PDF file
        permission.result = const HostKycPermissionResult(
          status: HostKycPermissionStatus.granted,
        );
        await _tapPickButton(tester, 'identitySingle');
        expect(
          find.byKey(const Key('kyc_pdf_preview_identitySingle')),
          findsOneWidget,
        );
        expect(find.textContaining('passport_scan.pdf'), findsWidgets);

        // Open 36dp modal preview sheet
        final previewBtn = find.byKey(
          const Key('kyc_preview_btn_identitySingle'),
        );
        await tester.ensureVisible(previewBtn);
        await tester.tap(previewBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('kyc_preview_sheet_identitySingle')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Đóng xem trước'));
        await tester.pumpAndSettle();

        // Reselect with PNG image
        final reselectBtn = find.byKey(
          const Key('kyc_reselect_btn_identitySingle'),
        );
        await tester.ensureVisible(reselectBtn);
        await tester.tap(reselectBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('passport_reselected.png'), findsWidgets);

        // Delete file from slot
        final removeBtn = find.byKey(
          const Key('kyc_remove_btn_identitySingle'),
        );
        await tester.ensureVisible(removeBtn);
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('passport_reselected.png'), findsNothing);
        expect(
          find.byKey(const Key('kyc_pick_btn_identitySingle')),
          findsOneWidget,
        );
      },
    );
  });

  // ===========================================================================
  // 3. FAKE NETWORK ERRORS: 413, 422, TIMEOUT, OFFLINE VS 500, PROGRESS & RETRY
  // ===========================================================================
  group(
      '3. Fake Network Errors: 413, 422, Timeout, Offline vs 500 & Per-File Retry',
      () {
    testWidgets(
      'handles HTTP 413 Payload Too Large, preserves form & selected files, and allows per-file retry',
      (tester) async {
        final repo = _FakeHostOnboardingRepository(
          submitError: DioException(
            requestOptions: RequestOptions(path: '/api/host/applications'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/api/host/applications'),
              statusCode: 413,
              data: <String, dynamic>{
                'message': 'Payload Too Large: File exceeds 5MB limit.',
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        final picker = _FakeHostFilePickerService(
          queue: <HostPickedFile?>[
            _makePngFile('passport_highres.png', sizeBytes: 1024 * 500),
          ],
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            pickerService: picker,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidContactForm(
          tester,
          documentType: HostDocumentType.passport,
        );
        await _tapPickButton(tester, 'identitySingle');

        final submitBtn = find.byKey(const Key('kyc_submit_btn'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Error banner & per-slot error shown, form & file preserved
        expect(find.byKey(const Key('kyc_error_banner')), findsOneWidget);
        expect(find.textContaining('413'), findsWidgets);
        expect(find.textContaining('passport_highres.png'), findsWidgets);
        expect(find.text('Nguyễn Minh Thành'), findsOneWidget);

        // Per-file retry button is available on the affected slot
        final slotRetryBtn = find.byKey(
          const Key('kyc_retry_btn_identitySingle'),
        );
        expect(slotRetryBtn, findsOneWidget);

        // Clear simulated 413 error and tap per-file retry -> auto-submits when valid
        repo.submitError = null;
        repo.currentRecord = null;
        await tester.ensureVisible(slotRetryBtn);
        await tester.tap(slotRetryBtn);
        await tester.pumpAndSettle();

        expect(repo.submitCount, 2);
        expect(
          find.byKey(const Key('kyc_status_card_pending')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'maps HTTP 422 backend field & slot errors to UI without losing form data',
      (tester) async {
        final repo = _FakeHostOnboardingRepository(
          submitError: DioException(
            requestOptions: RequestOptions(path: '/api/host/applications'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/api/host/applications'),
              statusCode: 422,
              data: <String, dynamic>{
                'message': 'Dữ liệu hồ sơ không hợp lệ.',
                'errors': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'phone',
                    'msg': 'Số điện thoại này đã được đăng ký ở hồ sơ khác.',
                  },
                  <String, dynamic>{
                    'path': 'identityBack',
                    'msg': 'Ảnh mặt sau CCCD bị lóa sáng không đọc được.',
                  },
                ],
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        final picker = _FakeHostFilePickerService(
          queue: <HostPickedFile?>[
            _makePngFile('cccd_front.png'),
            _makePngFile('cccd_back.png'),
          ],
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            pickerService: picker,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidContactForm(tester);
        await _tapPickButton(tester, 'identityFront');
        await _tapPickButton(tester, 'identityBack');

        final submitBtn = find.byKey(const Key('kyc_submit_btn'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kyc_error_banner')), findsOneWidget);
        expect(
          find.textContaining('Số điện thoại này đã được đăng ký'),
          findsWidgets,
        );
        expect(
          find.byKey(const Key('kyc_slot_error_identityBack')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Ảnh mặt sau CCCD bị lóa sáng'),
          findsWidgets,
        );
        // Form text & picked files remain intact
        expect(find.text('Nguyễn Minh Thành'), findsOneWidget);
        expect(find.textContaining('cccd_front.png'), findsWidgets);
        expect(find.textContaining('cccd_back.png'), findsWidgets);
      },
    );

    testWidgets(
      'displays spinner & real upload progress during submission and handles network timeout with retry',
      (tester) async {
        final completer = Completer<void>();
        final repo = _FakeHostOnboardingRepository(
          submitCompleter: completer,
          submitError: DioException(
            requestOptions: RequestOptions(path: '/api/host/applications'),
            type: DioExceptionType.sendTimeout,
            message: 'Send timeout after 30000ms',
          ),
        );
        final picker = _FakeHostFilePickerService(
          queue: <HostPickedFile?>[
            _makePngFile('passport.png', sizeBytes: 4096),
          ],
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            pickerService: picker,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidContactForm(
          tester,
          documentType: HostDocumentType.passport,
        );
        await _tapPickButton(tester, 'identitySingle');

        final submitBtn = find.byKey(const Key('kyc_submit_btn'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pump();

        // While in-flight: spinner, overall progress bar, and per-slot progress bar are visible
        expect(find.text('Đang gửi hồ sơ...'), findsOneWidget);
        expect(
          find.byKey(const Key('kyc_upload_progress_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('kyc_upload_progress_bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('kyc_slot_progress_identitySingle')),
          findsOneWidget,
        );

        // Complete the in-flight request with timeout
        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kyc_error_banner')), findsOneWidget);
        expect(find.textContaining('quá thời gian (timeout)'), findsWidgets);

        // Retry after network recovers
        repo.submitCompleter = null;
        repo.submitError = null;
        repo.currentRecord = null;

        final retryBtn = find.byKey(const Key('kyc_submit_retry_btn'));
        await tester.ensureVisible(retryBtn);
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(repo.submitCount, 2);
        expect(
          find.byKey(const Key('kyc_status_card_pending')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'distinguishes offline error from HTTP 500 server error (never mislabels 500 as offline) and executes real retry',
      (tester) async {
        final repo = _FakeHostOnboardingRepository(
          fetchError: DioException(
            requestOptions: RequestOptions(path: '/api/host/applications/me'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/api/host/applications/me'),
              statusCode: 500,
              data: <String, dynamic>{'message': 'Database query failed'},
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/trang-thai',
            repository: repo,
          ),
        );
        await tester.pumpAndSettle();

        // Must show server error banner, NOT offline banner
        expect(find.byKey(const Key('status_error_banner')), findsOneWidget);
        expect(find.byKey(const Key('status_offline_banner')), findsNothing);
        expect(find.textContaining('mất kết nối mạng'), findsNothing);

        // Now simulate offline connectionError
        repo.fetchError = DioException(
          requestOptions: RequestOptions(path: '/api/host/applications/me'),
          type: DioExceptionType.connectionError,
          message: 'Failed host lookup',
        );
        await tester.tap(find.byKey(const Key('status_retry_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('status_offline_banner')), findsOneWidget);

        // Recover and retry -> loads pending record
        repo.fetchError = null;
        repo.currentRecord = _sampleRecord(
          status: HostApplicationStatus.pending,
        );
        await tester.tap(find.byKey(const Key('status_retry_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('kyc_status_card_pending')),
          findsOneWidget,
        );
      },
    );
  });

  // ===========================================================================
  // 4. PRIVACY, CONSENT-GATED DRAFT RESTORE & PII LOG SANITIZER
  // ===========================================================================
  group('4. Privacy, Consent-Gated Draft Restore & PII Log Sanitizer', () {
    test(
      'DefaultHostOnboardingDraftService strips sensitive PII when consent is false and expires drafts > 24h',
      () async {
        final memory = <String, String>{};
        final draftService = DefaultHostOnboardingDraftService(
          memoryStore: memory,
        );
        final now = DateTime.utc(2026, 10, 27, 10, 0);

        // Save with consent = false even when caller passes contact PII
        await draftService.saveDraft(
          profileType: HostProfileType.business,
          documentType: HostDocumentType.passport,
          stepIndex: 1,
          consentToSaveContactPii: false,
          contactName: 'Sensitive Name',
          contactEmail: 'sensitive@example.com',
          phone: '0912345678',
          businessAddress: 'Sensitive Address 123',
          note: 'Call me at 0912345678 or sensitive@example.com',
          now: now,
        );

        final loadedUnconsented = await draftService.loadDraft(now: now);
        expect(loadedUnconsented, isNotNull);
        expect(loadedUnconsented!.profileType, HostProfileType.business);
        expect(loadedUnconsented.documentType, HostDocumentType.passport);
        expect(loadedUnconsented.consentToSaveContactPii, isFalse);
        expect(loadedUnconsented.contactName, isEmpty);
        expect(loadedUnconsented.contactEmail, isEmpty);
        expect(loadedUnconsented.phone, isEmpty);
        expect(loadedUnconsented.businessAddress, isEmpty);
        expect(loadedUnconsented.note, isNot(contains('0912345678')));
        expect(
            loadedUnconsented.note, isNot(contains('sensitive@example.com')));

        // Save with consent = true and verify 24h TTL expiration
        await draftService.saveDraft(
          profileType: HostProfileType.individual,
          documentType: HostDocumentType.cccd,
          stepIndex: 0,
          consentToSaveContactPii: true,
          contactName: 'Consented Host',
          contactEmail: 'consented@example.com',
          phone: '0987654321',
          businessAddress: '88 Thùy Vân, Vũng Tàu',
          now: now,
        );

        final withinTtl = await draftService.loadDraft(
          now: now.add(const Duration(hours: 2)),
        );
        expect(withinTtl, isNotNull);
        expect(withinTtl!.contactName, 'Consented Host');

        final expired = await draftService.loadDraft(
          now: now.add(const Duration(hours: 25)),
        );
        expect(expired, isNull);
        expect(memory, isEmpty);
      },
    );

    testWidgets(
      'DangKyHostScreen restores non-sensitive draft structure while excluding unconsented sensitive PII',
      (tester) async {
        final draftService = DefaultHostOnboardingDraftService();
        await draftService.writeRawJsonForTest(<String, dynamic>{
          'profileType': 'business',
          'documentType': 'passport',
          'stepIndex': 1,
          'consentToSaveContactPii': false,
          'contactName': 'Leaked Unconsented Name',
          'contactEmail': 'leaked@example.com',
          'phone': '0999888777',
          'businessAddress': 'Leaked Secret Address',
          'idNumber': '079123456789',
          'updatedAt': DateTime.now().toIso8601String(),
        });

        final repo = _FakeHostOnboardingRepository();
        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repo,
            draftService: draftService,
          ),
        );
        await tester.pumpAndSettle();

        // Restores non-sensitive structure (business + passport) and shows draft banner
        expect(
          find.byKey(const Key('kyc_draft_restored_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('kyc_slot_identitySingle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('kyc_slot_businessLicense')),
          findsOneWidget,
        );

        // Sensitive PII fields were NOT restored because consentToSaveContactPii == false
        expect(find.text('Leaked Unconsented Name'), findsNothing);
        expect(find.text('leaked@example.com'), findsNothing);
        expect(find.text('0999888777'), findsNothing);
        expect(find.text('Leaked Secret Address'), findsNothing);
      },
    );

    test(
      'HostOnboardingLogSanitizer redacts emails, phone numbers, CCCD/Passport IDs, file paths, and tokens',
      () {
        const rawLog =
            'Upload failed for file C:\\Users\\lenovo\\Documents\\cccd_079123456789.jpg '
            'email=minhthanh@vungtau.vn phone=0901234567 '
            '"contactName":"Nguyễn Minh Thành" Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig';

        final sanitized = HostOnboardingLogSanitizer.sanitize(rawLog);
        expect(sanitized, isNot(contains('minhthanh@vungtau.vn')));
        expect(sanitized, isNot(contains('0901234567')));
        expect(sanitized, isNot(contains('079123456789')));
        expect(sanitized, isNot(contains('Nguyễn Minh Thành')));
        expect(sanitized, isNot(contains('C:\\Users\\lenovo')));
        expect(sanitized, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      },
    );
  });

  // ===========================================================================
  // 5. DESIGN RULES, ACCESSIBILITY & RESPONSIVE WIDTHS (320/360/390/430dp @ 1.0/1.3/1.6x)
  // ===========================================================================
  group(
      '5. Light Luxury Design, Accessibility & Responsive Matrix (320/360/390/430dp @ 1.0/1.3/1.6x)',
      () {
    testWidgets(
      'TroThanhHostLandingScreen, DangKyHostScreen, and TrangThaiHostScreen render without overflow across 320/360/390/430dp and text scales 1.0/1.3/1.6',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const widths = <double>[320, 360, 390, 430];
        const scales = <double>[1.0, 1.3, 1.6];

        final repoWithLongReason = _FakeHostOnboardingRepository(
          currentRecord: _sampleRecord(
            status: HostApplicationStatus.supplementRequired,
            rejectReason:
                'Ảnh chụp mặt sau Căn cước công dân gắn chip bị lóa sáng ở góc phải và thiếu bản sao Giấy chứng nhận đăng ký hộ kinh doanh có dấu mộc đỏ hợp lệ.',
          ),
        );

        for (final width in widths) {
          for (final scale in scales) {
            await tester.binding.setSurfaceSize(Size(width, 844));

            // 1. Status screen with long rejection/supplement reason
            await tester.pumpWidget(
              _buildRouterApp(
                initialLocation: '/tro-thanh-host/trang-thai',
                repository: repoWithLongReason,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'TrangThaiHostScreen overflowed at width=$width, scale=$scale',
            );

            // 2. Landing screen
            await tester.pumpWidget(
              _buildRouterApp(
                initialLocation: '/tro-thanh-host',
                repository: repoWithLongReason,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'TroThanhHostLandingScreen overflowed at width=$width, scale=$scale',
            );
          }
        }

        // 3. KYC Registration screen at 320dp and 1.6x text scale with long error banner
        await tester.binding.setSurfaceSize(const Size(320, 844));
        await tester.pumpWidget(
          _buildRouterApp(
            initialLocation: '/tro-thanh-host/dang-ky',
            repository: repoWithLongReason,
            textScale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify pill CTA shape (StadiumBorder), Coral #FF385C background, and >= 48x48dp hit target
        final submitElevatedBtn = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(const Key('kyc_submit_btn')),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(
          submitElevatedBtn.style?.shape?.resolve(<WidgetState>{}),
          isA<StadiumBorder>(),
        );
        expect(
          submitElevatedBtn.style?.backgroundColor?.resolve(<WidgetState>{}),
          AppColors.primary,
        );

        final scanBtnSize = tester.getSize(
          find.byKey(const Key('kyc_scan_btn_identityFront')),
        );
        expect(scanBtnSize.width, greaterThanOrEqualTo(48));
        expect(scanBtnSize.height, greaterThanOrEqualTo(48));
      },
    );

    test(
      'HostOnboardingApiService executes real Dio GET /api/host/applications/me and POST /api/host/applications multipart FormData with non-promotion guard',
      () async {
        final recordedRequests = <RequestOptions>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
        dio.httpClientAdapter = _CallbackHttpClientAdapter((options) async {
          recordedRequests.add(options);
          if (options.method == 'GET' &&
              options.path == '/api/host/applications/me') {
            return ResponseBody.fromString(
              jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'status': 'supplement_required',
                  'application': <String, dynamic>{
                    'id': 77,
                    'status': 'supplement_required',
                    'contactName': 'Nguyễn Minh Thành',
                    'contactEmail': 'minhthanh@vungtau.vn',
                    'phone': '0901234567',
                    'profileType': 'business',
                    'documentType': 'cccd',
                    'businessAddress': '164B Phan Chu Trinh, Vũng Tàu',
                    'rejectReason': 'Vui lòng bổ sung GPKD rõ nét.',
                  },
                },
              }),
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
            );
          }
          if (options.method == 'POST' &&
              options.path == '/api/host/applications') {
            return ResponseBody.fromString(
              jsonEncode(<String, dynamic>{
                // Even if backend erroneously returns approved on POST creation,
                // HostOnboardingApiService must coerce it to pending:
                'status': 'approved',
                'application': <String, dynamic>{
                  'id': 78,
                  'status': 'approved',
                  'contactName': 'Nguyễn Minh Thành',
                  'contactEmail': 'minhthanh@vungtau.vn',
                  'phone': '0901234567',
                  'profileType': 'business',
                  'documentType': 'cccd',
                  'businessAddress': '164B Phan Chu Trinh, Vũng Tàu',
                },
              }),
              201,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('{}', 404);
        });

        final service = HostOnboardingApiService(dio: dio);
        final current = await service.getMyApplicationRecord();
        expect(current, isNotNull);
        expect(current!.id, 77);
        expect(current.status, HostApplicationStatus.supplementRequired);
        expect(current.rejectReason, 'Vui lòng bổ sung GPKD rõ nét.');

        final dto = HostKycSubmissionDto(
          contactName: 'Nguyễn Minh Thành',
          contactEmail: 'minhthanh@vungtau.vn',
          phone: '0901234567',
          profileType: HostProfileType.business,
          documentType: HostDocumentType.cccd,
          businessAddress: '164B Phan Chu Trinh, Vũng Tàu',
          identityFront: _makeJpegFile('front.jpg'),
          identityBack: _makeJpegFile('back.jpg'),
          businessLicense: _makePdfFile('gpkd.pdf'),
        );
        final submitted = await service.submitKycApplication(dto);
        expect(submitted.id, 78);
        // Guarded: never approved on POST submission
        expect(submitted.status, HostApplicationStatus.pending);
        expect(recordedRequests.last.data, isA<FormData>());
      },
    );

    test(
      'HostOnboardingApiService.cancelApplication sends POST /api/host/applications/cancel',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
        final recordedRequests = <RequestOptions>[];
        dio.httpClientAdapter = _CallbackHttpClientAdapter((options) async {
          recordedRequests.add(options);
          if (options.method == 'POST' &&
              options.path == '/api/host/applications/cancel') {
            return ResponseBody.fromString(
              jsonEncode(<String, dynamic>{
                'success': true,
                'message': 'Đã hủy đơn đăng ký Host thành công.',
                'data': {'status': null},
              }),
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('{}', 404);
        });

        final service = HostOnboardingApiService(dio: dio);
        final success = await service.cancelApplication();
        expect(success, isTrue);
        expect(recordedRequests.length, 1);
        expect(recordedRequests.first.path, '/api/host/applications/cancel');
        expect(recordedRequests.first.method, 'POST');
      },
    );
  });
}

class _CallbackHttpClientAdapter implements HttpClientAdapter {
  _CallbackHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
