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

class _SpyFilePickerService implements HostFilePickerService {
  HostKycFileSource? lastSource;
  String? lastTitle;
  HostPickedFile? fileToReturn;

  @override
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu xác minh',
    HostKycFileSource source = HostKycFileSource.deviceFile,
  }) async {
    lastTitle = title;
    lastSource = source;
    return fileToReturn;
  }

  @override
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  }) async =>
      const [];

  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async =>
      null;

  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async =>
      fileToReturn!;
}

class _MockHostRepository extends HostRepository {
  _MockHostRepository() : super(Dio());
  @override
  Future<HostApplicationRecord?> getMyApplicationRecord() async => null;
}

class _MockOnboardingApiService extends HostOnboardingApiService {
  _MockOnboardingApiService() : super(dio: Dio());
  @override
  Future<HostApplicationRecord?> getMyApplicationRecord() async => null;
}

void main() {
  final sampleJpgBytes = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget buildHarness({
    required _SpyFilePickerService spyPicker,
    HostOnboardingPermissionService? permissionService,
  }) {
    return ProviderScope(
      overrides: [
        hostRepositoryProvider.overrideWithValue(_MockHostRepository()),
        hostOnboardingApiProvider.overrideWithValue(_MockOnboardingApiService()),
        hostFilePickerProvider.overrideWithValue(spyPicker),
        if (permissionService != null)
          hostOnboardingPermissionProvider.overrideWithValue(permissionService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: DangKyHostScreen(),
        ),
      ),
    );
  }

  group('Host KYC Camera & Gallery Flow Tests', () {
    testWidgets(
        'First time clicking Camera Scan shows permission request dialog, granting saves preference and calls picker with cameraScan',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final spyPicker = _SpyFilePickerService()
        ..fileToReturn = HostPickedFile(
          name: 'cccd_front_cam.jpg',
          bytes: sampleJpgBytes,
          sizeBytes: sampleJpgBytes.length,
          mimeType: 'image/jpeg',
        );

      await tester.pumpWidget(buildHarness(
        spyPicker: spyPicker,
        permissionService: const DefaultHostOnboardingPermissionService(),
      ));
      await tester.pumpAndSettle();

      // Open source selection sheet via scan button
      final scanBtn = find.byKey(const Key('kyc_scan_btn_identityFront'));
      await tester.ensureVisible(scanBtn);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      // Click "Chụp / Quét giấy tờ trực tiếp"
      final cameraOption =
          find.byKey(const Key('kyc_source_camera_identityFront'));
      expect(cameraOption, findsOneWidget);
      await tester.tap(cameraOption);
      await tester.pumpAndSettle();

      // First time -> Dialog "Yêu cầu mở Máy ảnh" must appear
      expect(find.text('Yêu cầu mở Máy ảnh'), findsOneWidget);
      expect(
        find.textContaining('The Palm cần sử dụng Máy ảnh của bạn'),
        findsOneWidget,
      );

      // Confirm dialog by tapping "Mở Máy ảnh"
      final grantBtn = find.byKey(const Key('kyc_camera_permission_grant_btn'));
      expect(grantBtn, findsOneWidget);
      await tester.tap(grantBtn);
      await tester.pumpAndSettle();

      // Verify permission is now saved in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
            DefaultHostOnboardingPermissionService.kCameraPermissionPrefKey),
        isTrue,
      );

      // Verify picker was invoked with source == HostKycFileSource.cameraScan
      expect(spyPicker.lastSource, HostKycFileSource.cameraScan);
    });

    testWidgets(
        'Subsequent times clicking Camera Scan automatically opens camera without asking again',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Simulate already granted in previous session
      SharedPreferences.setMockInitialValues(<String, Object>{
        DefaultHostOnboardingPermissionService.kCameraPermissionPrefKey: true,
      });

      final spyPicker = _SpyFilePickerService()
        ..fileToReturn = HostPickedFile(
          name: 'cccd_front_cam.jpg',
          bytes: sampleJpgBytes,
          sizeBytes: sampleJpgBytes.length,
          mimeType: 'image/jpeg',
        );

      await tester.pumpWidget(buildHarness(
        spyPicker: spyPicker,
        permissionService: const DefaultHostOnboardingPermissionService(),
      ));
      await tester.pumpAndSettle();

      // Open source selection sheet
      final scanBtn = find.byKey(const Key('kyc_scan_btn_identityFront'));
      await tester.ensureVisible(scanBtn);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      // Click "Chụp / Quét giấy tờ trực tiếp"
      final cameraOption =
          find.byKey(const Key('kyc_source_camera_identityFront'));
      await tester.tap(cameraOption);
      await tester.pumpAndSettle();

      // Dialog should NOT appear because permission was already granted
      expect(find.text('Yêu cầu mở Máy ảnh'), findsNothing);

      // Picker invoked directly with cameraScan
      expect(spyPicker.lastSource, HostKycFileSource.cameraScan);
    });

    testWidgets(
        'First time clicking Camera Scan and rejecting dialog shows error and does not call picker',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final spyPicker = _SpyFilePickerService();

      await tester.pumpWidget(buildHarness(
        spyPicker: spyPicker,
        permissionService: const DefaultHostOnboardingPermissionService(),
      ));
      await tester.pumpAndSettle();

      final scanBtn = find.byKey(const Key('kyc_scan_btn_identityFront'));
      await tester.ensureVisible(scanBtn);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      final cameraOption =
          find.byKey(const Key('kyc_source_camera_identityFront'));
      await tester.tap(cameraOption);
      await tester.pumpAndSettle();

      // Deny dialog
      final denyBtn = find.byKey(const Key('kyc_camera_permission_deny_btn'));
      expect(denyBtn, findsOneWidget);
      await tester.tap(denyBtn);
      await tester.pumpAndSettle();

      // Picker should not be called
      expect(spyPicker.lastSource, isNull);

      // Error message shown (in slot error and top banner)
      expect(
        find.textContaining('Ứng dụng cần quyền mở Máy ảnh'),
        findsWidgets,
      );
    });

    testWidgets(
        'Clicking "Chọn ảnh từ Thư viện" invokes picker with photoLibrary source',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final spyPicker = _SpyFilePickerService()
        ..fileToReturn = HostPickedFile(
          name: 'cccd_gallery.png',
          bytes: sampleJpgBytes,
          sizeBytes: sampleJpgBytes.length,
          mimeType: 'image/png',
        );

      await tester.pumpWidget(buildHarness(
        spyPicker: spyPicker,
        permissionService: const DefaultHostOnboardingPermissionService(),
      ));
      await tester.pumpAndSettle();

      // Open source selection sheet
      final scanBtn = find.byKey(const Key('kyc_scan_btn_identityFront'));
      await tester.ensureVisible(scanBtn);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      // Click "Chọn ảnh từ Thư viện"
      final galleryOption =
          find.byKey(const Key('kyc_source_gallery_identityFront'));
      expect(galleryOption, findsOneWidget);
      await tester.tap(galleryOption);
      await tester.pumpAndSettle();

      // Must be invoked with photoLibrary source, not deviceFile
      expect(spyPicker.lastSource, HostKycFileSource.photoLibrary);
    });
  });
}
