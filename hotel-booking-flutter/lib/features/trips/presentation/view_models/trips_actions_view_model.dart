// CONFLICT-RESOLVED: Bổ sung `TripsActionsViewModel` cho các màn hình chuyến đi & thanh toán
// (`guest_payment_screen`, `multi_booking_screen`, `payment_result_screen`, `trips_screen`) theo chuẩn MVVM
// (FLUTTER_RULES.md Mục 2), loại bỏ việc Screen gọi trực tiếp `bookingRepositoryProvider` / `reviewRepositoryProvider`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../messages/data/conversations_repository.dart';
import '../../../reviews/presentation/view_models/review_view_model.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import 'trips_view_model.dart';

/// ViewModel điều phối các thao tác tạo thanh toán, đối soát trạng thái, đặt phòng hàng loạt, hủy đơn và gửi đánh giá.
///
/// Đóng gói toàn bộ tương tác ghi/cập nhật của phân hệ Chuyến đi và tự động vô hiệu hóa (`invalidate`)
/// các provider dữ liệu liên quan sau khi thao tác hoàn tất.
class TripsActionsViewModel {
  final Ref _ref;
  final BookingRepository _bookingRepository;

  /// Khởi tạo `TripsActionsViewModel` với `Ref` và kho lưu trữ `BookingRepository`.
  const TripsActionsViewModel(this._ref, this._bookingRepository);

  /// Truy vấn thông tin giao dịch thanh toán theo `paymentId` phục vụ đối chiếu kết quả trên màn hình biên lai.
  // Giải thuật truy vấn thông tin giao dịch thanh toán theo `paymentId` phục vụ đối chiếu kết quả.
  Future<PaymentSessionResult?> getPaymentById(String paymentId) {
    return _bookingRepository.getPaymentById(paymentId);
  }

  /// Truy vấn chi tiết đơn đặt phòng mới nhất theo `bookingId` từ máy chủ.
  // Giải thuật truy vấn chi tiết đơn đặt phòng theo `bookingId` từ máy chủ.
  Future<Booking?> getBookingById(String bookingId) {
    return _bookingRepository.getBookingById(bookingId);
  }

  /// Kiểm tra điều kiện áp dụng mã ưu đãi `code` cho giá trị đơn `bookingAmount` và chỗ nghỉ `listingId`.
  // Giải thuật kiểm tra điều kiện áp dụng mã ưu đãi cho đơn đặt phòng đang chờ thanh toán.
  Future<CouponValidationResult> validateCoupon({
    required String code,
    int? bookingAmount,
    String? listingId,
  }) {
    return _bookingRepository.validateCoupon(
      code: code,
      bookingAmount: bookingAmount,
      listingId: listingId,
    );
  }

  /// Khởi tạo phiên thanh toán trực tuyến theo phương thức `method` (`'vnpay'`, `'momo'`, ...) cho đơn `bookingId`.
  // Giải thuật khởi tạo phiên thanh toán trực tuyến (`vnpay` / `momo` / `vietqr`) cho đơn đặt phòng.
  Future<PaymentSessionResult> createPayment({
    required String bookingId,
    required String method,
  }) {
    return _bookingRepository.createPayment(
      bookingId: bookingId,
      method: method,
    );
  }

  /// Khởi tạo hàng loạt đơn đặt phòng từ danh sách cấu hình `items` cho đoàn khách thuê nhiều căn biệt thự.
  // Giải thuật khởi tạo hàng loạt đơn đặt phòng (`Bulk Bookings`) cho đoàn nhiều căn biệt thự.
  Future<List<Booking>> createBulkBookings({
    required List<Map<String, dynamic>> items,
  }) {
    return _bookingRepository.createBulkBookings(items: items);
  }

  /// Hủy đơn đặt phòng `bookingId` kèm lý do `reason` (và thông tin ngân hàng nhận hoàn tiền nếu đơn đã thanh toán),
  /// đồng thời làm mới tức thì danh sách chuyến đi cũng như chi tiết đơn.
  // Giải thuật hủy đơn đặt phòng kèm lý do/tài khoản hoàn tiền và làm mới ngay danh sách chuyến đi cá nhân.
  // CONFLICT-RESOLVED: Bổ sung tham số ngân hàng hoàn tiền (`bankName`, `accountNumber`, `accountName`) từ develop vào ViewModel để giữ kiến trúc MVVM.
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    await _bookingRepository.cancelBooking(
      bookingId: bookingId,
      reason: reason,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
    _ref.invalidate(myBookingsProvider);
    _ref.invalidate(bookingDetailProvider(bookingId));
  }

  /// Gửi đánh giá kỳ nghỉ (`rating` và `comment`) cho đơn `bookingId` sau khi hoàn thành chuyến đi,
  /// đồng thời làm mới danh sách chuyến đi và danh sách đánh giá của chỗ nghỉ `listingId`.
  // Giải thuật gửi đánh giá kỳ nghỉ sau khi hoàn tất chuyến đi và làm mới bộ đệm đánh giá của biệt thự.
  Future<void> submitStayReview({
    required String bookingId,
    required String listingId,
    required int rating,
    required String comment,
  }) async {
    await _ref.read(reviewRepositoryProvider).createReview(
          bookingId: bookingId,
          rating: rating,
          comment: comment,
        );
    _ref.invalidate(myBookingsProvider);
    if (listingId.isNotEmpty) {
      _ref.invalidate(listingReviewsProvider(listingId));
    }
  }

  /// Khởi tạo hoặc mở lại cuộc hội thoại trực tuyến với Chủ nhà gắn liền đơn đặt phòng `bookingId`.
  // Giải thuật mở luồng nhắn tin trực tiếp với Chủ nhà từ thẻ Chuyến đi sắp tới theo chuẩn MVVM.
  Future<String> openHostConversation({
    required String listingId,
    String? bookingId,
  }) async {
    final conv = await _ref
        .read(conversationsRepositoryProvider)
        .getOrCreateConversation(listingId, bookingId: bookingId);
    _ref.invalidate(conversationsListProvider);
    return conv.id;
  }
}

/// Provider cung cấp `TripsActionsViewModel` cho các màn hình thanh toán, đặt nhiều căn và quản lý chuyến đi.
final tripsActionsViewModelProvider = Provider<TripsActionsViewModel>((ref) {
  final bookingRepository = ref.watch(bookingRepositoryProvider);
  return TripsActionsViewModel(ref, bookingRepository);
});
