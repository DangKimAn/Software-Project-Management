import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_onboarding_screens.dart';
import 'package:hotel_booking_flutter/features/host/services/host_file_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// TEST DOUBLES & MOCKS
// =============================================================================

class _FakeHostRepository extends HostRepository {
  _FakeHostRepository(super.dio);

  HostIdentityAiResult? resultToReturn;
  Object? errorToThrow;
  int analyzeCallCount = 0;
  List<int>? lastBytes;
  String? lastFilename;
  String? lastMimeType;

  @override
  Future<HostIdentityAiResult> analyzeIdentityCard({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    analyzeCallCount += 1;
    lastBytes = bytes;
    lastFilename = filename;
    lastMimeType = mimeType;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    return resultToReturn ??
        const HostIdentityAiResult(
          documentType: 'cccd',
          side: 'front',
          idNumber: '079090123456',
          fullName: 'NGUYỄN VĂN AN',
          dateOfBirth: '15/08/1992',
          gender: 'Nam',
          placeOfResidence: '123 Thùy Vân, Phường Thắng Tam, TP. Vũng Tàu',
          confidence: 0.98,
          isClear: true,
          isDocumentValid: true,
          summaryVi: 'CCCD mặt trước - NGUYỄN VĂN AN - Số: 079090123456',
        );
  }
}

class _FakeFilePickerService implements HostFilePickerService {
  HostPickedFile? nextFile;

  @override
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu',
  }) async =>
      nextFile;

  @override
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = 30,
  }) async =>
      const [];

  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async =>
      nextFile;

  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async => nextFile!;
}

class _FakePermissionService implements HostOnboardingPermissionService {
  @override
  Future<HostKycPermissionResult> requestPermission(
          HostKycFileSource source) async =>
      const HostKycPermissionResult(status: HostKycPermissionStatus.granted);
}

class _FakeOnboardingApiService extends HostOnboardingApiService {
  _FakeOnboardingApiService() : super(dio: Dio());

  @override
  Future<HostApplicationRecord?> getMyApplicationRecord() async => null;

  @override
  Future<Map<String, dynamic>?> getMyApplication() async => null;
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HostIdentityAiResult Model Unit Tests', () {
    test('parses complete CCCD front JSON payload correctly', () {
      final json = <String, dynamic>{
        'documentType': 'cccd',
        'side': 'front',
        'idNumber': '079090123456',
        'fullName': 'NGUYỄN VĂN AN',
        'dateOfBirth': '15/08/1992',
        'gender': 'Nam',
        'nationality': 'Việt Nam',
        'placeOfOrigin': 'Vũng Tàu',
        'placeOfResidence': '123 Thùy Vân, Vũng Tàu',
        'expiryDate': '15/08/2032',
        'issueDate': null,
        'issuePlace': null,
        'mrz': null,
        'isClear': true,
        'isDocumentValid': true,
        'confidence': 0.98,
        'warnings': ['Ảnh chụp tốt'],
        'summaryVi': 'CCCD mặt trước - NGUYỄN VĂN AN',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'cccd');
      expect(result.side, 'front');
      expect(result.idNumber, '079090123456');
      expect(result.fullName, 'NGUYỄN VĂN AN');
      expect(result.dateOfBirth, '15/08/1992');
      expect(result.gender, 'Nam');
      expect(result.placeOfResidence, '123 Thùy Vân, Vũng Tàu');
      expect(result.confidence, 0.98);
      expect(result.isClear, isTrue);
      expect(result.isDocumentValid, isTrue);
      expect(result.warnings, contains('Ảnh chụp tốt'));
    });

    test('parses 9-digit CMND JSON payload with null nationality and gender',
        () {
      final json = <String, dynamic>{
        'documentType': 'cmnd',
        'side': 'front',
        'idNumber': '241234567',
        'fullName': 'NGUYỄN VĂN A',
        'dateOfBirth': '15/05/1999',
        'gender': null,
        'nationality': null,
        'placeOfOrigin': 'Thọ Xuân, Thanh Hóa',
        'placeOfResidence': 'Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        'expiryDate': null,
        'issueDate': null,
        'issuePlace': null,
        'mrz': null,
        'isClear': true,
        'isDocumentValid': true,
        'confidence': 0.98,
        'warnings': <String>[],
        'summaryVi': 'CMND mặt trước - NGUYỄN VĂN A - Số: 241234567',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'cmnd');
      expect(result.side, 'front');
      expect(result.idNumber, '241234567');
      expect(result.fullName, 'NGUYỄN VĂN A');
      expect(result.dateOfBirth, '15/05/1999');
      expect(result.placeOfOrigin, 'Thọ Xuân, Thanh Hóa');
      expect(
          result.placeOfResidence, 'Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh');
      expect(result.confidence, 0.98);
      expect(result.isClear, isTrue);
    });

    test('parses Passport JSON payload correctly', () {
      final json = <String, dynamic>{
        'documentType': 'passport',
        'side': 'front',
        'idNumber': 'P01234567',
        'fullName': 'NGUYỄN VĂN A',
        'dateOfBirth': '15/05/1999',
        'gender': 'Nam',
        'nationality': 'VIỆT NAM',
        'placeOfOrigin': 'THỦ ĐÔ HÀ NỘI',
        'placeOfResidence': null,
        'expiryDate': '01/07/2034',
        'issueDate': '01/07/2024',
        'issuePlace': 'CỤC QUẢN LÝ XUẤT NHẬP CẢNH',
        'mrz': 'P<VNMN GUYEN<<VAN<A<<<<<<<<<<<<<<<<<<<<<<<<<<',
        'isClear': true,
        'isDocumentValid': true,
        'confidence': 0.98,
        'warnings': <String>[],
        'summaryVi': 'Hộ chiếu Việt Nam - NGUYỄN VĂN A - Số: P01234567',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'passport');
      expect(result.side, 'front');
      expect(result.idNumber, 'P01234567');
      expect(result.fullName, 'NGUYỄN VĂN A');
      expect(result.nationality, 'VIỆT NAM');
      expect(result.placeOfOrigin, 'THỦ ĐÔ HÀ NỘI');
      expect(result.expiryDate, '01/07/2034');
      expect(result.confidence, 0.98);
    });

    test('parses Driver\'s License (GPLX) JSON payload correctly', () {
      final json = <String, dynamic>{
        'documentType': 'driver_license',
        'side': 'front',
        'idNumber': '241234567890',
        'fullName': 'NGUYỄN VĂN A',
        'dateOfBirth': '15/05/1999',
        'gender': null,
        'nationality': 'VIỆT NAM',
        'placeOfOrigin': null,
        'placeOfResidence': 'Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        'expiryDate': '15/05/2034',
        'issueDate': '23/03/2024',
        'issuePlace': 'TRƯỞNG PHÒNG QLPT&NL',
        'mrz': null,
        'isClear': true,
        'isDocumentValid': true,
        'confidence': 0.98,
        'warnings': <String>[],
        'summaryVi':
            'Giấy phép lái xe mặt trước - NGUYỄN VĂN A - Số: 241234567890',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'driver_license');
      expect(result.side, 'front');
      expect(result.idNumber, '241234567890');
      expect(result.fullName, 'NGUYỄN VĂN A');
      expect(result.expiryDate, '15/05/2034');
      expect(result.confidence, 0.98);
    });

    test('parses invalid non-identity document (utility bill) JSON correctly',
        () {
      final json = <String, dynamic>{
        'documentType': 'unknown',
        'side': 'unknown',
        'idNumber': null,
        'fullName': null,
        'dateOfBirth': null,
        'gender': null,
        'nationality': null,
        'placeOfOrigin': null,
        'placeOfResidence': null,
        'expiryDate': null,
        'issueDate': null,
        'issuePlace': null,
        'mrz': null,
        'isClear': true,
        'isDocumentValid': false,
        'confidence': 0.95,
        'warnings': ['Không phải giấy tờ tùy thân, đây là hóa đơn tiền điện'],
        'summaryVi': 'Không phải giấy tờ tùy thân, đây là hóa đơn tiền điện',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'unknown');
      expect(result.side, 'unknown');
      expect(result.idNumber, isNull);
      expect(result.isDocumentValid, isFalse);
      expect(result.warnings.first, contains('hóa đơn tiền điện'));
    });

    test('parses elderly lifetime CCCD with "Không thời hạn" correctly', () {
      final json = <String, dynamic>{
        'documentType': 'cccd',
        'side': 'front',
        'idNumber': '012345678901',
        'fullName': 'NGUYỄN VĂN A',
        'dateOfBirth': '01/01/1950',
        'gender': 'Nam',
        'nationality': 'Việt Nam',
        'expiryDate': 'Không thời hạn',
        'isClear': true,
        'isDocumentValid': true,
        'confidence': 0.98,
        'warnings': <String>[],
        'summaryVi': 'CCCD mặt trước - NGUYỄN VĂN A - Số: 012345678901',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'cccd');
      expect(result.idNumber, '012345678901');
      expect(result.expiryDate, 'Không thời hạn');
      expect(result.isDocumentValid, isTrue);
    });

    test('parses expired CCCD with expiration warning correctly', () {
      final json = <String, dynamic>{
        'documentType': 'cccd',
        'side': 'front',
        'idNumber': '012345678901',
        'fullName': 'NGUYỄN VĂN A',
        'dateOfBirth': '15/05/1999',
        'gender': 'Nam',
        'nationality': 'Việt Nam',
        'expiryDate': '15/05/2021',
        'isClear': true,
        'isDocumentValid': true,
        'confidence': 0.99,
        'warnings': ['Giấy tờ đã hết hạn sử dụng'],
        'summaryVi': 'CCCD mặt trước - NGUYỄN VĂN A - Số: 012345678901',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'cccd');
      expect(result.expiryDate, '15/05/2021');
      expect(result.warnings.first, contains('hết hạn'));
    });

    test('parses CCCD with glare warning and reduced clarity correctly', () {
      final json = <String, dynamic>{
        'documentType': 'cccd',
        'side': 'front',
        'idNumber': '012345678901',
        'fullName': 'NGUYỄN VĂN A',
        'dateOfBirth': '15/05/1999',
        'gender': 'Nam',
        'nationality': 'Việt Nam',
        'placeOfOrigin': 'Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        'placeOfResidence':
            '123 Đường Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        'expiryDate': '15/05/2039',
        'isClear': false,
        'isDocumentValid': true,
        'confidence': 0.85,
        'warnings': ['Ảnh bị lóa sáng che khuất một phần vùng họ tên'],
        'summaryVi': 'CCCD mặt trước - NGUYỄN VĂN A - Số: 012345678901',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'cccd');
      expect(result.isClear, isFalse);
      expect(result.confidence, 0.85);
      expect(result.warnings.first, contains('lóa sáng'));
    });

    test('verifies all CI/CD mock fixtures exist', () {
      final fixtures = [
        'test/fixtures/identity/mock_cccd_front.jpg',
        'test/fixtures/identity/mock_cccd_back.jpg',
        'test/fixtures/identity/mock_cmnd_front.jpg',
        'test/fixtures/identity/mock_cmnd_back.jpg',
        'test/fixtures/identity/mock_passport.jpg',
        'test/fixtures/identity/mock_gplx_front.jpg',
        'test/fixtures/identity/mock_gplx_back.jpg',
        'test/fixtures/identity/mock_invalid_utility_bill.jpg',
        'test/fixtures/identity/mock_cccd_lifetime_elderly.jpg',
        'test/fixtures/identity/mock_cccd_back_held.jpg',
        'test/fixtures/identity/mock_cccd_photocopy_bw.jpg',
        'test/fixtures/identity/mock_cccd_expired.jpg',
        'test/fixtures/identity/mock_cccd_upside_down.jpg',
        'test/fixtures/identity/mock_cccd_glare.jpg',
        'test/fixtures/identity/mock_cccd_front_held.jpg',
      ];

      for (final fixture in fixtures) {
        final file = File(fixture);
        expect(file.existsSync(), isTrue,
            reason: '$fixture must exist for CI/CD');
      }
    });

    test('handles fallback defaults when nullable fields are absent', () {
      final json = <String, dynamic>{
        'documentType': 'cccd',
        'side': 'back',
      };

      final result = HostIdentityAiResult.fromJson(json);

      expect(result.documentType, 'cccd');
      expect(result.side, 'back');
      expect(result.idNumber, isNull);
      expect(result.fullName, isNull);
      expect(result.confidence, 1.0);
      expect(result.warnings, isEmpty);
      expect(result.isClear, isFalse);
    });

    test('normalizes Vietnamese names ignoring accents and letter case', () {
      expect(HostOnboardingValidator.normalizeVietnameseName('NGUYỄN VĂN A'),
          'nguyen van a');
      expect(HostOnboardingValidator.normalizeVietnameseName('Đào Duy Phong'),
          'dao duy phong');
      expect(
          HostOnboardingValidator.normalizeVietnameseName(
              '  vũ   thị   bình  '),
          'vu thi binh');
    });

    test('isNameMatching returns true for exact or diacritic/case variations',
        () {
      expect(
        HostOnboardingValidator.isNameMatching(
          enteredName: 'nguyen van a',
          aiExtractedName: 'NGUYỄN VĂN A',
        ),
        isTrue,
      );
      expect(
        HostOnboardingValidator.isNameMatching(
          enteredName: 'Đào Duy Phong',
          aiExtractedName: 'DAO DUY PHONG',
        ),
        isTrue,
      );
    });

    test('isNameMatching returns false for completely different names', () {
      expect(
        HostOnboardingValidator.isNameMatching(
          enteredName: 'Trần Thị B',
          aiExtractedName: 'NGUYỄN VĂN A',
        ),
        isFalse,
      );
      expect(
        HostOnboardingValidator.isNameMatching(
          enteredName: 'Lê Văn C',
          aiExtractedName: 'Đào Duy Phong',
        ),
        isFalse,
      );
    });
  });

  group('Host Onboarding AI CCCD Extraction Widget Tests', () {
    // Load mock CCCD front image from CI/CD test fixtures with in-memory fallback
    final mockFixtureFile = File('test/fixtures/identity/mock_cccd_front.jpg');
    final sampleImageBytes = mockFixtureFile.existsSync()
        ? mockFixtureFile.readAsBytesSync()
        : Uint8List.fromList(<int>[
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
            0x00,
            0x00,
            0x00,
            0x0D,
            0x49,
            0x48,
            0x44,
            0x52,
            0x00,
            0x00,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            0x01,
            0x08,
            0x06,
            0x00,
            0x00,
            0x00,
            0x1F,
            0x15,
            0xC4,
            0x89,
            0x00,
            0x00,
            0x00,
            0x0A,
            0x49,
            0x44,
            0x41,
            0x54,
            0x78,
            0x9C,
            0x63,
            0x00,
            0x01,
            0x00,
            0x00,
            0x05,
            0x00,
            0x01,
            0x0D,
            0x0A,
            0x2D,
            0xB4,
            0x00,
            0x00,
            0x00,
            0x00,
            0x49,
            0x45,
            0x4E,
            0x44,
            0xAE,
            0x42,
            0x60,
            0x82,
          ]);

    Widget buildTestHarness({
      required _FakeHostRepository fakeRepository,
      required _FakeFilePickerService fakePicker,
    }) {
      return ProviderScope(
        overrides: [
          hostRepositoryProvider.overrideWithValue(fakeRepository),
          hostFilePickerProvider.overrideWithValue(fakePicker),
          hostOnboardingPermissionProvider
              .overrideWithValue(_FakePermissionService()),
          hostOnboardingApiProvider
              .overrideWithValue(_FakeOnboardingApiService()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: DangKyHostScreen(),
          ),
        ),
      );
    }

    testWidgets('shows AI scan button after picking CCCD front image',
        (tester) async {
      final fakeRepo = _FakeHostRepository(Dio());
      final fakePicker = _FakeFilePickerService()
        ..nextFile = HostPickedFile(
          name: 'cccd_front.png',
          bytes: sampleImageBytes,
          sizeBytes: sampleImageBytes.length,
          mimeType: 'image/png',
        );

      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestHarness(
        fakeRepository: fakeRepo,
        fakePicker: fakePicker,
      ));
      await tester.pumpAndSettle();

      // Scroll to pick button and tap
      final pickBtn = find.byKey(const Key('kyc_pick_btn_identityFront'));
      await tester.ensureVisible(pickBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      // Verify "Quét AI CCCD" button appears
      final aiScanBtn = find.byKey(const Key('kyc_ai_scan_btn_identityFront'));
      expect(aiScanBtn, findsOneWidget);
      expect(find.text('Quét AI CCCD'), findsOneWidget);
    });

    testWidgets(
        'triggers AI scan, displays result card and autofills name and address',
        (tester) async {
      final fakeRepo = _FakeHostRepository(Dio())
        ..resultToReturn = const HostIdentityAiResult(
          documentType: 'cccd',
          side: 'front',
          idNumber: '079090123456',
          fullName: 'TRẦN VĂN BÌNH',
          dateOfBirth: '20/11/1990',
          gender: 'Nam',
          placeOfResidence: '456 Lê Hồng Phong, Vũng Tàu',
          confidence: 0.99,
          isClear: true,
          isDocumentValid: true,
          warnings: [],
          summaryVi: 'CCCD mặt trước - TRẦN VĂN BÌNH',
        );

      final fakePicker = _FakeFilePickerService()
        ..nextFile = HostPickedFile(
          name: 'cccd_front.png',
          bytes: sampleImageBytes,
          sizeBytes: sampleImageBytes.length,
          mimeType: 'image/png',
        );

      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestHarness(
        fakeRepository: fakeRepo,
        fakePicker: fakePicker,
      ));
      await tester.pumpAndSettle();

      // 1. Pick file
      final pickBtn = find.byKey(const Key('kyc_pick_btn_identityFront'));
      await tester.ensureVisible(pickBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      // 2. Click AI scan button
      final aiScanBtn = find.byKey(const Key('kyc_ai_scan_btn_identityFront'));
      await tester.ensureVisible(aiScanBtn);
      await tester.pumpAndSettle();
      await tester.tap(aiScanBtn);
      await tester.pumpAndSettle();

      // 3. Verify repository was called
      expect(fakeRepo.analyzeCallCount, 1);
      expect(fakeRepo.lastFilename, 'cccd_front.png');

      // 4. Verify AI Result Card is rendered
      expect(find.byKey(const Key('kyc_ai_result_card')), findsOneWidget);
      expect(find.text('Kết quả AI phân tích CCCD'), findsOneWidget);
      expect(find.text('TRẦN VĂN BÌNH'), findsWidgets);
      expect(find.text('079090123456'), findsOneWidget);
      expect(find.text('456 Lê Hồng Phong, Vũng Tàu'), findsOneWidget);
      expect(find.text('Độ tin cậy: 99%'), findsOneWidget);

      // 5. Verify contact name is autofilled, while business address is NOT overwritten by CCCD
      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('kyc_contact_name_input')),
      );
      expect(nameField.controller?.text, 'TRẦN VĂN BÌNH');

      final addressField = tester.widget<TextFormField>(
        find.byKey(const Key('kyc_business_address_input')),
      );
      expect(addressField.controller?.text, '');
    });

    testWidgets('handles AI scan error gracefully and shows error banner',
        (tester) async {
      final fakeRepo = _FakeHostRepository(Dio())
        ..errorToThrow = DioException(
          requestOptions:
              RequestOptions(path: '/api/ai/id-card-vision/extract'),
          message: 'Network connection failed',
        );

      final fakePicker = _FakeFilePickerService()
        ..nextFile = HostPickedFile(
          name: 'blurry_id.png',
          bytes: sampleImageBytes,
          sizeBytes: sampleImageBytes.length,
          mimeType: 'image/png',
        );

      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestHarness(
        fakeRepository: fakeRepo,
        fakePicker: fakePicker,
      ));
      await tester.pumpAndSettle();

      // 1. Pick file
      final pickBtn = find.byKey(const Key('kyc_pick_btn_identityFront'));
      await tester.ensureVisible(pickBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      // 2. Click AI scan button
      final aiScanBtn = find.byKey(const Key('kyc_ai_scan_btn_identityFront'));
      await tester.ensureVisible(aiScanBtn);
      await tester.pumpAndSettle();
      await tester.tap(aiScanBtn);
      await tester.pumpAndSettle();

      // 3. Verify error message appears
      expect(
        find.text(
            'Không thể phân tích AI từ ảnh này. Vui lòng thử lại với ảnh rõ nét hơn.'),
        findsOneWidget,
      );
      // AI result card should NOT be shown
      expect(find.byKey(const Key('kyc_ai_result_card')), findsNothing);
    });

    testWidgets(
        'shows name mismatch warning when entered name differs from CCCD and fixes it on tap',
        (tester) async {
      final fakeRepo = _FakeHostRepository(Dio())
        ..resultToReturn = const HostIdentityAiResult(
          documentType: 'cccd',
          side: 'front',
          idNumber: '012345678901',
          fullName: 'NGUYỄN VĂN A',
          dateOfBirth: '15/05/1999',
          gender: 'Nam',
          placeOfResidence:
              '123 Đường Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
          confidence: 0.98,
          isClear: true,
          isDocumentValid: true,
          summaryVi: 'CCCD mặt trước - NGUYỄN VĂN A',
        );

      final fakePicker = _FakeFilePickerService()
        ..nextFile = HostPickedFile(
          name: 'cccd_front.jpg',
          bytes: sampleImageBytes,
          sizeBytes: sampleImageBytes.length,
          mimeType: 'image/jpeg',
        );

      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestHarness(
        fakeRepository: fakeRepo,
        fakePicker: fakePicker,
      ));
      await tester.pumpAndSettle();

      // 1. Pick file and scan AI
      final pickBtn = find.byKey(const Key('kyc_pick_btn_identityFront'));
      await tester.ensureVisible(pickBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      final aiScanBtn = find.byKey(const Key('kyc_ai_scan_btn_identityFront'));
      await tester.ensureVisible(aiScanBtn);
      await tester.pumpAndSettle();
      await tester.tap(aiScanBtn);
      await tester.pumpAndSettle();

      // 2. Change name in input field to a completely different name
      final nameField = find.byKey(const Key('kyc_contact_name_input'));
      await tester.ensureVisible(nameField);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Trần Thị B');
      await tester.pumpAndSettle();

      // 3. Verify mismatch warning banner appears
      expect(
          find.byKey(const Key('kyc_name_mismatch_warning')), findsOneWidget);
      expect(find.text('Họ tên không khớp giấy tờ tùy thân'), findsOneWidget);

      // 4. Tap the quick-fix button "Dùng tên CCCD"
      final fixBtn = find.byKey(const Key('kyc_fix_name_mismatch_btn'));
      await tester.ensureVisible(fixBtn);
      await tester.pumpAndSettle();
      await tester.tap(fixBtn);
      await tester.pumpAndSettle();

      // 5. Verify the name input is restored to CCCD name and warning disappears
      final inputWidget = tester.widget<TextFormField>(nameField);
      expect(inputWidget.controller?.text, 'NGUYỄN VĂN A');
      expect(find.byKey(const Key('kyc_name_mismatch_warning')), findsNothing);
    });

    testWidgets(
        'shows AI guard banner and blocks submission when document is invalid or not scanned',
        (tester) async {
      final fakeRepo = _FakeHostRepository(Dio())
        ..resultToReturn = const HostIdentityAiResult(
          documentType: 'unknown',
          side: 'unknown',
          idNumber: null,
          fullName: null,
          isClear: true,
          isDocumentValid: false,
          confidence: 0.99,
          warnings: ['Không phải giấy tờ tùy thân, đây là CV xin việc'],
          summaryVi: 'Không phải giấy tờ tùy thân',
        );

      final fakePicker = _FakeFilePickerService()
        ..nextFile = HostPickedFile(
          name: 'cv_data_engineer.jpg',
          bytes: sampleImageBytes,
          sizeBytes: sampleImageBytes.length,
          mimeType: 'image/jpeg',
        );

      await tester.binding.setSurfaceSize(const Size(600, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestHarness(
        fakeRepository: fakeRepo,
        fakePicker: fakePicker,
      ));
      await tester.pumpAndSettle();

      // 1. Pick file
      final pickBtn = find.byKey(const Key('kyc_pick_btn_identityFront'));
      await tester.ensureVisible(pickBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      // 2. Banner warns that AI scan is needed before submission
      expect(
          find.byKey(const Key('kyc_submit_ai_guard_banner')), findsOneWidget);

      // 3. Tap AI scan button (which returns invalid doc)
      final aiScanBtn = find.byKey(const Key('kyc_ai_scan_btn_identityFront'));
      await tester.ensureVisible(aiScanBtn);
      await tester.pumpAndSettle();
      await tester.tap(aiScanBtn);
      await tester.pumpAndSettle();

      // 4. Verify rejection message appears
      expect(
          find.textContaining('Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ'),
          findsWidgets);

      // 5. Try to tap submit button and verify it still blocks
      final submitBtn = find.byKey(const Key('kyc_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ'),
          findsWidgets);
    });

    test('effectiveIdNumber extracts idNumber from field or MRZ line correctly',
        () {
      const front = HostIdentityAiResult(
        documentType: 'cccd',
        side: 'front',
        idNumber: '044205000083',
      );
      expect(front.effectiveIdNumber, '044205000083');

      const backWithMrz = HostIdentityAiResult(
        documentType: 'cccd',
        side: 'back',
        mrz: 'IDVNM012345678901<<<<<<<<<<<<<\n9905152M3905158VNM<<<<<<<<<<<5',
      );
      expect(backWithMrz.effectiveIdNumber, '012345678901');

      const backWithBoth = HostIdentityAiResult(
        documentType: 'cccd',
        side: 'back',
        idNumber: '012345678901',
        mrz: 'IDVNM012345678901<<<<<<<<<<<<<',
      );
      expect(backWithBoth.effectiveIdNumber, '012345678901');
    });

    testWidgets(
        'shows mismatch error and blocks submission when front and back CCCD numbers differ',
        (tester) async {
      final fakeRepo = _FakeHostRepository(Dio());
      final fakePicker = _FakeFilePickerService()
        ..nextFile = HostPickedFile(
          name: 'cccd_back.jpg',
          bytes: sampleImageBytes,
          sizeBytes: sampleImageBytes.length,
          mimeType: 'image/jpeg',
        );

      await tester.binding.setSurfaceSize(const Size(600, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestHarness(
        fakeRepository: fakeRepo,
        fakePicker: fakePicker,
      ));
      await tester.pumpAndSettle();

      // Pick front file
      fakeRepo.resultToReturn = const HostIdentityAiResult(
        documentType: 'cccd',
        side: 'front',
        idNumber: '044205000083',
        fullName: 'ĐẶNG KIM AN',
        isClear: true,
        isDocumentValid: true,
        confidence: 0.98,
      );

      final pickFrontBtn = find.byKey(const Key('kyc_pick_btn_identityFront'));
      await tester.ensureVisible(pickFrontBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickFrontBtn);
      await tester.pumpAndSettle();

      final aiScanFrontBtn =
          find.byKey(const Key('kyc_ai_scan_btn_identityFront'));
      await tester.ensureVisible(aiScanFrontBtn);
      await tester.pumpAndSettle();
      await tester.tap(aiScanFrontBtn);
      await tester.pumpAndSettle();

      // Pick back file with different idNumber
      fakeRepo.resultToReturn = const HostIdentityAiResult(
        documentType: 'cccd',
        side: 'back',
        idNumber: '012345678901',
        isClear: true,
        isDocumentValid: true,
        confidence: 0.98,
        mrz: 'IDVNM012345678901<<<<<<<<<<<<<',
      );

      final pickBackBtn = find.byKey(const Key('kyc_pick_btn_identityBack'));
      await tester.ensureVisible(pickBackBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBackBtn);
      await tester.pumpAndSettle();

      final aiScanBackBtn =
          find.byKey(const Key('kyc_ai_scan_btn_identityBack'));
      await tester.ensureVisible(aiScanBackBtn);
      await tester.pumpAndSettle();
      await tester.tap(aiScanBackBtn);
      await tester.pumpAndSettle();

      // Verify mismatch warning card appears
      expect(find.textContaining('Không trùng khớp số CCCD với mặt trước'),
          findsOneWidget);
      expect(find.textContaining('012345678901'), findsWidgets);
      expect(find.textContaining('044205000083'), findsWidgets);

      // Verify submit button is blocked
      final submitBtn = find.byKey(const Key('kyc_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.textContaining('Không trùng khớp'), findsWidgets);
    });
  });
}
