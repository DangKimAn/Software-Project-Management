// CONFLICT-RESOLVED: Bổ sung `HostOnboardingViewModel` cho quy trình đăng ký & xác thực KYC Chủ nhà
// (`host_onboarding_screens.dart`) theo chuẩn MVVM (FLUTTER_RULES.md Mục 2), loại bỏ việc Screen phụ thuộc trực tiếp
// vào `package:dio/dio.dart`, `hostRepositoryProvider`, `hostOnboardingApiProvider`, `hostFilePickerProvider`,
// `hostOnboardingPermissionProvider` và `hostOnboardingDraftServiceProvider`.
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../onboarding/host_onboarding_services.dart';
import '../../services/host_file_picker_service.dart';

export '../../services/host_file_picker_service.dart' show HostPickedFile;

/// ViewModel điều phối lưu bản nháp an toàn, trích xuất CCCD bằng AI Vision, nộp hồ sơ KYC và tra cứu/hủy đơn đăng ký Host.
class HostOnboardingViewModel {
  final Ref _ref;
  final HostOnboardingApiService _api;
  final HostRepository _repo;
  final HostFilePickerService _picker;
  final HostOnboardingPermissionService _permissionService;

  /// Khởi tạo `HostOnboardingViewModel` kết nối dịch vụ API, kho lưu trữ, bộ chọn tệp và bộ kiểm quyền thiết bị.
  const HostOnboardingViewModel(
    this._ref,
    this._api,
    this._repo,
    this._picker,
    this._permissionService,
  );

  // Giải thuật truy vấn trạng thái hồ sơ đăng ký Chủ nhà từ máy chủ kèm bản ghi vừa nộp trong phiên.
  /// Truy vấn bản ghi hồ sơ đăng ký Chủ nhà hiện tại từ máy chủ.
  Future<HostApplicationRecord?> getMyApplicationRecord() {
    return _api.getMyApplicationRecord();
  }

  /// Hồ sơ đăng ký Chủ nhà vừa được nộp thành công trong phiên làm việc hiện tại.
  HostApplicationRecord? get lastSubmittedApplication =>
      _ref.read(hostLastSubmittedApplicationProvider);

  /// Ghi nhận hoặc xóa bản ghi hồ sơ `record` vừa nộp trong bộ nhớ phiên.
  void setLastSubmittedApplication(HostApplicationRecord? record) {
    _ref.read(hostLastSubmittedApplicationProvider.notifier).state = record;
  }

  // Giải thuật nạp, lưu có kiểm soát PII và xóa bản nháp đăng ký Chủ nhà theo phiên người dùng.
  /// Nạp lại bản nháp hồ sơ đăng ký Chủ nhà còn hạn lưu trữ cục bộ.
  Future<HostOnboardingDraftData?> loadDraft({DateTime? now}) {
    return _ref.read(hostOnboardingDraftServiceProvider).loadDraft(now: now);
  }

  /// Lưu bản nháp tiến độ đăng ký Chủ nhà (chỉ lưu thông tin định danh liên hệ khi người dùng đồng ý `consentToSaveContactPii`).
  Future<void> saveDraft({
    required HostProfileType profileType,
    required HostDocumentType documentType,
    required int stepIndex,
    required bool consentToSaveContactPii,
    String contactName = '',
    String contactEmail = '',
    String phone = '',
    String businessAddress = '',
    String note = '',
    DateTime? now,
  }) {
    return _ref.read(hostOnboardingDraftServiceProvider).saveDraft(
          profileType: profileType,
          documentType: documentType,
          stepIndex: stepIndex,
          consentToSaveContactPii: consentToSaveContactPii,
          contactName: contactName,
          contactEmail: contactEmail,
          phone: phone,
          businessAddress: businessAddress,
          note: note,
          now: now,
        );
  }

  /// Xóa sạch dữ liệu bản nháp đăng ký Chủ nhà khỏi thiết bị.
  Future<void> clearDraft() {
    return _ref.read(hostOnboardingDraftServiceProvider).clearDraft();
  }

  // Giải thuật xin quyền thiết bị, chọn tài liệu xác minh và bóc tách thông tin CCCD qua AI Vision có giới hạn thời gian.
  /// Yêu cầu cấp quyền truy cập máy ảnh hoặc thư viện tệp theo nguồn `source`.
  Future<HostKycPermissionResult> requestPermission(
    HostKycFileSource source, {
    BuildContext? context,
  }) {
    return _permissionService.requestPermission(source, context: context);
  }

  /// Mở trình chọn chứng từ xác minh KYC từ thiết bị.
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu xác minh',
    bool imageOnly = false,
    HostKycFileSource source = HostKycFileSource.deviceFile,
  }) {
    return _picker.pickKycDocument(
      context: context,
      title: title,
      imageOnly: imageOnly,
      source: source,
    );
  }

  /// Gửi ảnh giấy tờ tùy thân lên bộ nhận diện AI OCR với giới hạn thời gian chờ `timeout`.
  Future<HostIdentityAiResult> analyzeIdentityCard({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    Duration timeout = const Duration(seconds: 25),
  }) {
    return _repo
        .analyzeIdentityCard(
          bytes: bytes,
          filename: filename,
          mimeType: mimeType,
        )
        .timeout(timeout);
  }

  // Giải thuật gửi hồ sơ KYC đa phần (`multipart/form-data`), cập nhật trạng thái sau nộp và dọn bản nháp.
  /// Nộp bộ hồ sơ KYC `dto` lên máy chủ kèm callback theo dõi tiến trình tải `onSendProgress`.
  Future<HostApplicationRecord> submitKycApplication(
    HostKycSubmissionDto dto, {
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _api.submitKycApplication(dto, onSendProgress: onSendProgress);
  }

  // Giải thuật làm mới phiên JWT ngầm khi hồ sơ KYC đã được Admin phê duyệt để nâng quyền Guest -> Host tức thì mà không làm gián đoạn phiên hiện tại nếu mạng lỗi.
  /// Làm mới Access Token và đồng bộ vai trò `host` vào `AuthNotifier` ngay khi phát hiện hồ sơ KYC đạt trạng thái `approved`.
  Future<void> refreshApprovedHostSession() async {
    final currentUser = _ref.read(authNotifierProvider).valueOrNull;
    if (currentUser == null ||
        currentUser.isHost ||
        currentUser.roles.contains('host')) {
      return;
    }
    try {
      final client = _ref.read(dioClientProvider);
      final response = await client.dio
          .post<Map<String, dynamic>>(
            '/api/auth/refresh',
            data: const <String, dynamic>{},
            options: Options(
              extra: const <String, dynamic>{
                'skipAuthRefresh': true,
                'skipAuthToken': true,
                'skipSessionCancel': true,
                'disableRetry': true,
              },
            ),
          )
          .timeout(const Duration(seconds: 4));
      final unwrapped = DioClient.unwrapEnvelope(response.data);
      final Map<String, dynamic>? payload = unwrapped is Map<String, dynamic>
          ? unwrapped
          : (response.data?['data'] is Map<String, dynamic>
              ? response.data!['data'] as Map<String, dynamic>
              : response.data);
      final newToken =
          (payload?['accessToken'] ?? payload?['token'])?.toString().trim() ??
              '';
      if (newToken.isNotEmpty) {
        await _ref.read(secureStorageProvider).saveAuthToken(newToken);
      }
      final rawUser = payload?['user'];
      if (rawUser is Map) {
        _ref
            .read(authNotifierProvider.notifier)
            .handleSessionRefreshed(Map<String, dynamic>.from(rawUser));
      }
    } catch (_) {
      // Giữ nguyên phiên hiện tại nếu môi trường kiểm thử cô lập hoặc mạng tạm thời gián đoạn.
    }
  }

  // Giải thuật hủy hồ sơ đăng ký Host đang chờ duyệt và xóa bản ghi tạm trong bộ nhớ phiên.
  /// Hủy hồ sơ đăng ký Chủ nhà đang chờ duyệt trên máy chủ và đặt lại bộ nhớ phiên.
  Future<void> cancelApplication() async {
    await _api.cancelApplication();
    _ref.read(hostLastSubmittedApplicationProvider.notifier).state = null;
  }

  // Giải thuật trích xuất thông báo lỗi thân thiện khi hủy hồ sơ thất bại mà không lộ chi tiết tầng mạng ra UI.
  /// Rút trích thông báo lỗi tiếng Việt khi thao tác hủy đơn đăng ký Chủ nhà gặp sự cố.
  String extractCancelErrorMessage(
    Object error, [
    String fallback = 'Không thể hủy đơn đăng ký. Vui lòng thử lại sau.',
  ]) {
    if (error is DioException &&
        error.response?.data is Map &&
        (error.response!.data as Map)['message'] != null) {
      return (error.response!.data as Map)['message'].toString();
    }
    return fallback;
  }
}

/// Provider cung cấp `HostOnboardingViewModel` cho các màn hình đăng ký và theo dõi KYC Chủ nhà.
final hostOnboardingViewModelProvider =
    Provider<HostOnboardingViewModel>((ref) {
  final api = ref.watch(hostOnboardingApiProvider);
  final repo = ref.watch(hostRepositoryProvider);
  final picker = ref.watch(hostFilePickerProvider);
  final permissionService = ref.watch(hostOnboardingPermissionProvider);
  return HostOnboardingViewModel(ref, api, repo, picker, permissionService);
});
