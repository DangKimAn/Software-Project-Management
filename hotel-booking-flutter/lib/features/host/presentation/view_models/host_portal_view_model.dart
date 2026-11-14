// CONFLICT-RESOLVED: Bổ sung `HostPortalViewModel` cho cổng quản lý Chủ nhà (`host_portal_screens.dart`)
// theo chuẩn MVVM (FLUTTER_RULES.md Mục 2), loại bỏ việc Screen gọi trực tiếp `hostRepositoryProvider`,
// `hostFilePickerProvider`, `hostCurrentUserRoleProvider` và `package:dio/dio.dart`.
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';

export '../../services/host_file_picker_service.dart' show HostPickedFile;

/// Provider theo dõi vai trò hiện hành của người dùng trong cổng Chủ nhà thông qua tầng ViewModel.
final hostPortalUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(hostCurrentUserRoleProvider);
});

/// ViewModel điều phối danh sách chỗ nghỉ, đặt phòng, lịch 30 ngày, hội thoại, doanh thu và cài đặt tài khoản Chủ nhà.
class HostPortalViewModel {
  final Ref _ref;
  final HostRepository _repo;
  final HostFilePickerService _picker;

  /// Khởi tạo `HostPortalViewModel` với `Ref`, `HostRepository` và `HostFilePickerService`.
  const HostPortalViewModel(this._ref, this._repo, this._picker);

  /// Vai trò hiện tại của tài khoản đang thao tác trên cổng Chủ nhà.
  String? get currentUserRole => _ref.read(hostCurrentUserRoleProvider);

  // Giải thuật kiểm tra lỗi HTTP 404 (chưa có Quản trị viên trực tuyến hoặc không tìm thấy tài nguyên) mà không lộ `DioException` lên UI.
  /// Kiểm tra đối tượng `error` có phải ngoại lệ không tìm thấy tài nguyên (`HTTP 404`) hay không.
  static bool isNotFoundError(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  // Giải thuật truy vấn và cập nhật vòng đời trạng thái tin đăng chỗ nghỉ của Chủ nhà.
  /// Tải toàn bộ danh sách chỗ nghỉ của Chủ nhà qua các trang phân trang để phục vụ KPI, bộ lọc và danh mục quản lý.
  Future<List<Map<String, dynamic>>> getMyListings({
    String? status,
    int limit = 50,
    int maxPages = 20,
  }) {
    return _repo.getMyListings(
      status: status,
      limit: limit,
      maxPages: maxPages,
    );
  }

  Future<List<Map<String, dynamic>>> getHostListings({
    String? status,
    int page = 1,
    int limit = 50,
  }) {
    return _repo.getHostListings(status: status, page: page, limit: limit);
  }

  Future<Map<String, dynamic>> updateHostListing(
    String id,
    Map<String, dynamic> data, {
    String? userRole,
  }) {
    return _repo.updateHostListing(id, data, userRole: userRole);
  }

  Future<Map<String, dynamic>> submitListingForApproval(String listingId) {
    return _repo.submitListingForApproval(listingId);
  }

  Future<Map<String, dynamic>> hideHostListing(String listingId) {
    return _repo.hideHostListing(listingId);
  }

  Future<Map<String, dynamic>> publishHostListing(String listingId) {
    return _repo.publishHostListing(listingId);
  }

  Future<void> deleteHostListing(String id, {String? userRole}) {
    return _repo.deleteHostListing(id, userRole: userRole);
  }

  // Giải thuật quản lý danh sách đơn đặt phòng và chuyển đổi trạng thái xác nhận / check-in / check-out / hủy.
  Future<List<Map<String, dynamic>>> getAllHostBookings({
    String? status,
    int pageSize = 100,
    int maxPages = 10,
  }) {
    return _repo.getAllHostBookings(
      status: status,
      pageSize: pageSize,
      maxPages: maxPages,
    );
  }

  Future<Map<String, dynamic>> confirmHostBooking(
    String bookingId, {
    Map<String, dynamic>? currentBooking,
    String? userRole,
  }) {
    return _repo.confirmHostBooking(
      bookingId,
      currentBooking: currentBooking,
      userRole: userRole ?? currentUserRole,
    );
  }

  Future<Map<String, dynamic>> checkInHostBooking(
    String bookingId, {
    Map<String, dynamic>? currentBooking,
    String? userRole,
  }) {
    return _repo.checkInHostBooking(
      bookingId,
      currentBooking: currentBooking,
      userRole: userRole ?? currentUserRole,
    );
  }

  Future<Map<String, dynamic>> checkOutHostBooking(
    String bookingId, {
    Map<String, dynamic>? currentBooking,
    String? userRole,
  }) {
    return _repo.checkOutHostBooking(
      bookingId,
      currentBooking: currentBooking,
      userRole: userRole ?? currentUserRole,
    );
  }

  Future<Map<String, dynamic>> cancelHostBooking(
    String bookingId, {
    String? reason,
    Map<String, dynamic>? currentBooking,
    String? userRole,
  }) {
    return _repo.cancelHostBooking(
      bookingId,
      reason: reason,
      currentBooking: currentBooking,
      userRole: userRole ?? currentUserRole,
    );
  }

  // Giải thuật tải và cập nhật hàng loạt lịch trống / giá ghi đè theo tháng của biệt thự.
  Future<List<HostCalendarDay>> getListingCalendarDays(
    String listingId, {
    required int month,
    required int year,
  }) {
    return _repo.getListingCalendarDays(listingId, month: month, year: year);
  }

  Future<Map<String, dynamic>> bulkUpdateListingCalendar(
    String listingId, {
    required List<String> dates,
    bool? isAvailable,
    bool? isBlockedByHost,
    double? priceOverride,
    bool includeNullPriceOverride = false,
    int? minNightsOverride,
    bool includeNullMinNightsOverride = false,
    String? notes,
    List<HostCalendarDay>? currentCalendarDays,
    String? todayVietnam,
    String? userRole,
  }) {
    return _repo.bulkUpdateListingCalendar(
      listingId,
      dates: dates,
      isAvailable: isAvailable,
      isBlockedByHost: isBlockedByHost,
      priceOverride: priceOverride,
      includeNullPriceOverride: includeNullPriceOverride,
      minNightsOverride: minNightsOverride,
      includeNullMinNightsOverride: includeNullMinNightsOverride,
      notes: notes,
      currentCalendarDays: currentCalendarDays,
      todayVietnam: todayVietnam,
      userRole: userRole,
    );
  }

  // Giải thuật truy vấn hội thoại, khởi tạo kênh hỗ trợ Admin, đối soát thanh toán, đánh giá lưu trú và báo cáo doanh thu.
  Future<List<Map<String, dynamic>>> getHostConversations({
    int page = 1,
    int limit = 50,
    bool? unreadOnly,
  }) {
    return _repo.getHostConversations(
      page: page,
      limit: limit,
      unreadOnly: unreadOnly,
    );
  }

  Future<Map<String, dynamic>> openSupportConversation({
    String? firstMessage,
  }) {
    return _repo.openSupportConversation(firstMessage: firstMessage);
  }

  Future<void> markConversationRead(String conversationId) {
    return _repo.markConversationRead(conversationId);
  }

  Future<List<Map<String, dynamic>>> getConversationMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) {
    return _repo.getConversationMessages(
      conversationId,
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> sendConversationMessage(
    String conversationId,
    String content,
  ) {
    return _repo.sendConversationMessage(conversationId, content);
  }

  Future<List<Map<String, dynamic>>> getPayoutAccounts() {
    return _repo.getPayoutAccounts();
  }

  Future<List<Map<String, dynamic>>> getMyPayouts({
    String? status,
    String? from,
    String? to,
    int limit = 50,
    int maxPages = 20,
  }) {
    return _repo.getMyPayouts(
      status: status,
      from: from,
      to: to,
      limit: limit,
      maxPages: maxPages,
    );
  }

  Future<List<Map<String, dynamic>>> getPayouts({
    String? status,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) {
    return _repo.getPayouts(
      status: status,
      from: from,
      to: to,
      page: page,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getListingReviews(
    String listingId, {
    int page = 1,
    int limit = 50,
  }) {
    return _repo.getListingReviews(listingId, page: page, limit: limit);
  }

  Future<Map<String, dynamic>> replyToReview(String reviewId, String reply) {
    return _repo.replyToReview(reviewId, reply);
  }

  Future<HostRevenueReport> getTypedRevenueReport({
    String rangeKey = '30d',
    String? groupOverride,
    String? listingId,
    String? from,
    String? to,
    DateTime? now,
  }) {
    return _repo.getTypedRevenueReport(
      rangeKey: rangeKey,
      groupOverride: groupOverride,
      listingId: listingId,
      from: from,
      to: to,
      now: now,
    );
  }

  // Giải thuật quản lý hồ sơ cá nhân Chủ nhà, tải ảnh lên R2 và cấu hình tài khoản ngân hàng nhận thanh toán.
  Future<Map<String, dynamic>> getHostProfile() => _repo.getHostProfile();

  Future<Map<String, dynamic>> updateHostProfile({
    required String fullName,
    String? phone,
  }) {
    return _repo.updateHostProfile(fullName: fullName, phone: phone);
  }

  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) {
    return _picker.pickAvatarImage(context: context);
  }

  Future<HostR2UploadResult> uploadFileToR2(
    HostPickedFile file, {
    String folder = 'listings',
    String? listingId,
  }) {
    return _repo.uploadFileToR2(file, folder: folder, listingId: listingId);
  }

  Future<Map<String, dynamic>> updateHostAvatar({
    required String url,
    String? key,
  }) {
    return _repo.updateHostAvatar(url: url, key: key);
  }

  Future<List<VietnamBank>> getTypedVietnamBanks() {
    return _repo.getTypedVietnamBanks();
  }

  Future<Map<String, dynamic>?> getBankAccount() => _repo.getBankAccount();

  Future<Map<String, dynamic>> saveBankAccount(Map<String, dynamic> data) {
    return _repo.saveBankAccount(data);
  }

  /// Rút trích thông báo lỗi tiếng Việt thân thiện để hiển thị trên giao diện Host Portal.
  String extractErrorMessage(
    Object error, [
    String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.',
  ]) {
    return _repo.extractErrorMessage(error, fallback);
  }
}

/// Provider cung cấp `HostPortalViewModel` cho toàn bộ các tab chức năng của cổng quản lý Chủ nhà.
final hostPortalViewModelProvider = Provider<HostPortalViewModel>((ref) {
  final repo = ref.watch(hostRepositoryProvider);
  final picker = ref.watch(hostFilePickerProvider);
  return HostPortalViewModel(ref, repo, picker);
});
