// CONFLICT-RESOLVED: Bổ sung `AdminPortalViewModel` cho toàn bộ phân hệ Quản trị (`admin_portal_screens.dart`
// và `admin_kyc_document_viewer.dart`) theo chuẩn MVVM (FLUTTER_RULES.md Mục 2), loại bỏ 100% thao tác gọi trực tiếp
// `adminRepositoryProvider` và `conversationsRepositoryProvider` từ tầng Screen/Widget.
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../messages/data/conversations_repository.dart';
import '../../data/admin_repository.dart';

export '../../data/admin_api_client.dart'
    show
        AdminModerationPolicy,
        AdminOverviewStats,
        AdminPaginatedResult,
        AdminRevenuePoint;
export '../../../messages/data/conversations_repository.dart'
    show ConversationItem, conversationsListProvider;

/// ViewModel điều phối các nghiệp vụ quản trị hệ thống: thống kê, người dùng, kiểm duyệt chỗ nghỉ, KYC Host và phí nền tảng.
class AdminPortalViewModel {
  final Ref _ref;
  final AdminRepository _adminRepo;

  /// Khởi tạo `AdminPortalViewModel` với tham chiếu `Ref` và kho dữ liệu quản trị.
  const AdminPortalViewModel(this._ref, this._adminRepo);

  /// Số bản ghi người dùng tối đa trên mỗi trang phân trang.
  static const int maxUsersPageLimit = AdminRepository.maxUsersPageLimit;

  /// Số bản ghi chỗ nghỉ tối đa trên mỗi trang kiểm duyệt.
  static const int maxListingsPageLimit = AdminRepository.maxListingsPageLimit;

  // Giải thuật truy vấn số liệu tổng quan doanh thu và hoạt động hệ thống theo chu kỳ thời gian.
  /// Truy vấn thống kê tổng quan doanh thu, đơn đặt phòng và số liệu chờ duyệt theo khoảng thời gian.
  Future<AdminOverviewStats> getOverviewStats({
    int days = 30,
    String? from,
    String? to,
    String group = 'day',
  }) {
    return _adminRepo.getOverviewStats(
      days: days,
      from: from,
      to: to,
      group: group,
    );
  }

  // Giải thuật truy vấn phân trang danh sách người dùng kết hợp từ khóa, vai trò và trạng thái tài khoản.
  /// Truy vấn danh sách người dùng có phân trang kèm bộ lọc từ khóa `search`, vai trò `role` và trạng thái `status`.
  Future<AdminPaginatedResult<Map<String, dynamic>>> getAdminUsersPaginated({
    int page = 1,
    int limit = AdminRepository.maxUsersPageLimit,
    String? search,
    String? role,
    String? status,
  }) {
    return _adminRepo.getAdminUsersPaginated(
      page: page,
      limit: limit,
      search: search,
      role: role,
      status: status,
    );
  }

  /// Cập nhật trạng thái khóa/mở khóa hoặc kích hoạt cho tài khoản `userId`.
  Future<Map<String, dynamic>> updateAdminUserStatus(
    String userId,
    String status,
  ) {
    return _adminRepo.updateAdminUserStatus(userId, status);
  }

  /// Cập nhật thông tin hồ sơ hoặc vai trò của người dùng `userId` từ bảng quản trị.
  Future<Map<String, dynamic>> updateAdminUser(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return _adminRepo.updateAdminUser(userId, payload);
  }

  // Giải thuật truy vấn danh sách chỗ nghỉ chờ kiểm duyệt và thực thi phê duyệt / từ chối / phân tích ảnh AI.
  /// Lấy danh sách phân trang các chỗ nghỉ theo bộ lọc trạng thái `status`.
  Future<AdminPaginatedResult<Map<String, dynamic>>> getAdminListingsPaginated({
    String status = 'pending_approval',
    int page = 1,
    int limit = AdminRepository.maxListingsPageLimit,
  }) {
    return _adminRepo.getAdminListingsPaginated(
      status: status,
      page: page,
      limit: limit,
    );
  }

  /// Lấy danh sách phân trang các chỗ nghỉ đang chờ quản trị viên kiểm duyệt.
  Future<AdminPaginatedResult<Map<String, dynamic>>>
      getPendingListingsPaginated({
    int page = 1,
    int limit = AdminRepository.maxListingsPageLimit,
  }) {
    return _adminRepo.getPendingListingsPaginated(page: page, limit: limit);
  }

  /// Tải dữ liệu chi tiết chỗ nghỉ `listingId` kèm danh sách ảnh và nhãn AI để kiểm duyệt.
  Future<Map<String, dynamic>> getAdminListingDetail(String listingId) {
    return _adminRepo.getAdminListingDetail(listingId);
  }

  /// Phê duyệt chỗ nghỉ `listingId` để xuất bản lên nền tảng tìm kiếm công khai.
  Future<void> approveListing(String listingId) {
    return _adminRepo.approveListing(listingId);
  }

  /// Từ chối chỗ nghỉ `listingId` kèm lý do cụ thể `reason` gửi về cho Chủ nhà.
  Future<void> rejectListing(String listingId, String reason) {
    return _adminRepo.rejectListing(listingId, reason);
  }

  /// Kích hoạt phân tích AI Vision hàng loạt cho toàn bộ ảnh của chỗ nghỉ `listingId`.
  Future<Map<String, dynamic>> analyzeAllListingImages(
    String listingId, {
    bool force = true,
  }) {
    return _adminRepo.analyzeAllListingImages(listingId, force: force);
  }

  /// Yêu cầu phân tích lại nhãn AI Vision cho một bức ảnh đơn lẻ `imageId`.
  Future<Map<String, dynamic>> reanalyzeListingImage(String imageId) {
    return _adminRepo.reanalyzeListingImage(imageId);
  }

  // Giải thuật truy vấn và xét duyệt hồ sơ đăng ký Chủ nhà & chứng từ định danh KYC bảo mật.
  /// Truy vấn phân trang danh sách hồ sơ đăng ký làm Chủ nhà theo trạng thái `status`.
  Future<AdminPaginatedResult<Map<String, dynamic>>>
      getAdminHostApplicationsPaginated({
    String status = 'pending',
    int page = 1,
    int limit = 50,
  }) {
    return _adminRepo.getAdminHostApplicationsPaginated(
      status: status,
      page: page,
      limit: limit,
    );
  }

  /// Tải thông tin chi tiết và danh sách chứng từ đính kèm của hồ sơ đăng ký Host `applicationId`.
  Future<Map<String, dynamic>> getAdminHostApplicationDetail(
    String applicationId,
  ) {
    return _adminRepo.getAdminHostApplicationDetail(applicationId);
  }

  /// Tải dữ liệu nhị phân của tệp chứng từ KYC `documentId` qua luồng bảo mật có kiểm tra `streamToken`.
  Future<Uint8List> fetchAdminHostDocumentBytes(
    String applicationId,
    String documentId, {
    String? streamToken,
  }) {
    return _adminRepo.fetchAdminHostDocumentBytes(
      applicationId,
      documentId,
      streamToken: streamToken,
    );
  }

  /// Phê duyệt hồ sơ đăng ký Host `applicationId` và nâng quyền tài khoản lên Chủ nhà.
  Future<void> approveHostApplication(String applicationId) {
    return _adminRepo.approveHostApplication(applicationId);
  }

  /// Từ chối hồ sơ đăng ký Host `applicationId` với lý do `reason`.
  Future<void> rejectHostApplication(String applicationId, String reason) {
    return _adminRepo.rejectHostApplication(applicationId, reason);
  }

  /// Yêu cầu ứng viên Chủ nhà `applicationId` bổ sung hoặc chụp lại chứng từ KYC với ghi chú `reason`.
  Future<void> requestMoreInfoHostApplication(
    String applicationId,
    String reason,
  ) {
    return _adminRepo.requestMoreInfoHostApplication(applicationId, reason);
  }

  /// Truy vấn danh sách yêu cầu xác minh danh tính thế hệ cũ theo `status` và `verificationType`.
  Future<AdminPaginatedResult<Map<String, dynamic>>>
      getAdminVerificationsPaginated({
    String status = 'all',
    String verificationType = 'all',
    int page = 1,
    int limit = 50,
  }) {
    return _adminRepo.getAdminVerificationsPaginated(
      status: status,
      verificationType: verificationType,
      page: page,
      limit: limit,
    );
  }

  /// Phê duyệt yêu cầu xác minh danh tính `verificationId` kèm ghi chú `notes`.
  Future<void> approveHostVerification(
    String verificationId, {
    String? notes,
  }) {
    return _adminRepo.approveHostVerification(verificationId, notes: notes);
  }

  /// Từ chối yêu cầu xác minh danh tính `verificationId` kèm lý do `reason`.
  Future<void> rejectHostVerification(String verificationId, String reason) {
    return _adminRepo.rejectHostVerification(verificationId, reason);
  }

  // Giải thuật quản lý cấu hình và lịch thay đổi phí nền tảng (`Platform Fee`).
  /// Truy vấn mức phí nền tảng hiện hành và lịch thay đổi phí sắp áp dụng (nếu có).
  Future<Map<String, dynamic>> getPlatformFeeStatus() {
    return _adminRepo.getPlatformFeeStatus();
  }

  /// Đặt lịch cập nhật tỷ lệ phần trăm phí nền tảng mới `feePct` kèm lý do điều chỉnh `reason`.
  Future<Map<String, dynamic>> schedulePlatformFeeChange({
    required double feePct,
    String? reason,
  }) {
    return _adminRepo.schedulePlatformFeeChange(feePct: feePct, reason: reason);
  }

  /// Hủy bỏ lịch thay đổi phí nền tảng đang chờ hiệu lực.
  Future<Map<String, dynamic>> cancelScheduledPlatformFee() {
    return _adminRepo.cancelScheduledPlatformFee();
  }

  // CONFLICT-RESOLVED: Bổ sung các nghiệp vụ xét duyệt rút tiền Host (Payout) và hoàn tiền Khách (Refund) từ nhánh develop vào AdminPortalViewModel để tuân thủ kiến trúc MVVM nghiêm ngặt.
  // Giải thuật truy vấn và điều phối phê duyệt / từ chối giải ngân rút tiền Chủ nhà & hoàn tiền Khách hàng qua Napas 24/7.
  /// Truy vấn danh sách yêu cầu rút tiền của Chủ nhà theo trạng thái `status` và giới hạn bản ghi `limit`.
  Future<List<Map<String, dynamic>>> getAdminHostPayouts({
    String? status,
    int page = 1,
    int limit = 50,
  }) {
    return _adminRepo.getAdminHostPayouts(
      status: status,
      page: page,
      limit: limit,
    );
  }

  /// Phê duyệt và kích hoạt lệnh giải ngân cho đơn rút tiền `payoutId` của Chủ nhà.
  Future<Map<String, dynamic>> disburseHostPayout(String payoutId) {
    return _adminRepo.disburseHostPayout(payoutId);
  }

  /// Lập lô chi trả mới (Bước 1 - Maker) cho Chủ nhà `hostId`.
  Future<Map<String, dynamic>> createAdminHostPayout({
    required int hostId,
    required List<int> bookingIds,
    required int payoutAccountId,
    required int amount,
    String? notes,
  }) {
    return _adminRepo.createAdminHostPayout(
      hostId: hostId,
      bookingIds: bookingIds,
      payoutAccountId: payoutAccountId,
      amount: amount,
      notes: notes,
    );
  }

  /// Phê duyệt độc lập lệnh chi trả `payoutId` (Bước 2 - Checker).
  Future<Map<String, dynamic>> approveHostPayout(String payoutId) {
    return _adminRepo.approveHostPayout(payoutId);
  }

  /// Xác nhận đã chuyển khoản cho lệnh chi trả `payoutId` kèm mã giao dịch `transferReference` (Bước 3).
  Future<Map<String, dynamic>> markHostPayoutPaid(
    String payoutId,
    String transferReference,
  ) {
    return _adminRepo.markHostPayoutPaid(payoutId, transferReference);
  }

  /// Từ chối đơn rút tiền `payoutId` của Chủ nhà kèm lý do `reason`.
  Future<Map<String, dynamic>> rejectHostPayout(
    String payoutId,
    String reason,
  ) {
    return _adminRepo.rejectHostPayout(payoutId, reason);
  }

  /// Truy vấn danh sách yêu cầu hoàn tiền của Khách hàng theo trạng thái `status` và giới hạn bản ghi `limit`.
  Future<List<Map<String, dynamic>>> getAdminRefunds({
    String? status,
    int page = 1,
    int limit = 50,
  }) {
    return _adminRepo.getAdminRefunds(
      status: status,
      page: page,
      limit: limit,
    );
  }

  /// Phê duyệt và thực thi chuyển khoản hoàn tiền cho yêu cầu `refundId` của Khách hàng.
  Future<Map<String, dynamic>> approveRefund(String refundId) {
    return _adminRepo.approveRefund(refundId);
  }

  /// Từ chối yêu cầu hoàn tiền `refundId` kèm lý do `reason`.
  Future<Map<String, dynamic>> rejectRefund(
    String refundId,
    String reason,
  ) {
    return _adminRepo.rejectRefund(refundId, reason);
  }

  // Giải thuật truy vấn phân trang và xử lý báo cáo vi phạm cho Admin.
  /// Truy vấn danh sách báo cáo vi phạm theo `status` và `targetType`.
  Future<AdminPaginatedResult<Map<String, dynamic>>> getAdminReportsPaginated({
    String status = 'all',
    String targetType = 'all',
    int page = 1,
    int limit = 20,
  }) {
    return _adminRepo.getAdminReportsPaginated(
      status: status,
      targetType: targetType,
      page: page,
      limit: limit,
    );
  }

  /// Đánh dấu đã xử lý báo cáo vi phạm `reportId` với ghi chú `resolution`.
  Future<Map<String, dynamic>> resolveAdminReport(
    String reportId,
    String resolution,
  ) {
    return _adminRepo.resolveAdminReport(reportId, resolution);
  }

  /// Bác bỏ báo cáo vi phạm `reportId` kèm lý do `reason`.
  Future<Map<String, dynamic>> rejectAdminReport(
    String reportId,
    String reason,
  ) {
    return _adminRepo.rejectAdminReport(reportId, reason);
  }

  // Giải thuật khởi tạo kênh trò chuyện hỗ trợ trực tiếp với người dùng và làm mới danh sách hội thoại.
  /// Mở hoặc tạo mới hội thoại hỗ trợ trực tiếp với người dùng `participantUserId`.
  Future<ConversationItem> openDirectSupportConversation(
    String participantUserId,
  ) async {
    final conv = await _ref
        .read(conversationsRepositoryProvider)
        .getOrCreateDirectConversation(participantUserId);
    _ref.invalidate(conversationsListProvider);
    return conv;
  }

  /// Kiểm tra xem ngoại lệ `error` có phải là lỗi mất kết nối mạng hoặc ngoại tuyến hay không.
  static bool isOfflineError(Object error) =>
      AdminRepository.isOfflineError(error);

  /// Trích xuất mã trạng thái HTTP từ đối tượng lỗi `error` nếu có.
  static int? extractStatusCode(Object error) =>
      AdminRepository.extractStatusCode(error);

  /// Che bớt chuỗi số giấy tờ định danh nhạy cảm `raw` trước khi hiển thị trên giao diện quản trị.
  static String maskKycIdentifier(String raw) =>
      AdminRepository.maskKycIdentifier(raw);

  /// Trích xuất thông điệp lỗi tiếng Việt thân thiện từ `error` hoặc trả về `fallback`.
  static String extractErrorMessage(
    Object error, [
    String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.',
  ]) {
    return AdminRepository.extractErrorMessage(error, fallback);
  }
}

/// Riverpod provider cung cấp `AdminPortalViewModel` cho toàn bộ màn hình cổng Quản trị.
final adminPortalViewModelProvider = Provider<AdminPortalViewModel>((ref) {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return AdminPortalViewModel(ref, adminRepo);
});
