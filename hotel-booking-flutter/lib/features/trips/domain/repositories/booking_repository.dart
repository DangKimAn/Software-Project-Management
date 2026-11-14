import '../entities/booking.dart';

/// Hợp đồng kho lưu trữ nghiệp vụ đặt phòng, mã giảm giá và phiên thanh toán của phân hệ Chuyến đi.
abstract class BookingRepository {
  /// Truy vấn danh sách đơn đặt phòng của người dùng hiện tại, hỗ trợ lọc theo `status`, `page` và `limit`.
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  });

  /// Lấy thông tin chi tiết một đơn đặt phòng theo mã `bookingId`, trả về `null` nếu mã rỗng hoặc không hợp lệ.
  Future<Booking?> getBookingById(String bookingId);

  /// Khởi tạo đơn đặt phòng đơn lẻ cho chỗ nghỉ `listingId` trong khoảng ngày `checkInDate` đến `checkOutDate`,
  /// kèm số lượng khách `guestsCount`, ghi chú `specialRequests` và mã ưu đãi `couponCode` (nếu có).
  Future<Booking> createBooking({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    String? specialRequests,
    String? couponCode,
  });

  /// Khởi tạo đồng thời nhiều đơn đặt phòng trong một giao dịch lô từ danh sách cấu hình `items`.
  ///
  /// Ném `BulkBookingException` chứa danh sách lỗi theo từng chỉ mục dòng nếu một hoặc nhiều mục không hợp lệ.
  Future<List<Booking>> createBulkBookings({
    required List<Map<String, dynamic>> items,
  });

  /// Hủy đơn đặt phòng `bookingId` theo yêu cầu của khách hàng kèm lý do `reason`.
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  });

  /// Kiểm tra tính hợp lệ và tính trước mức giảm giá của mã khuyến mãi `code` đối với giá trị đơn `bookingAmount`
  /// và chỗ nghỉ `listingId` trước khi xác nhận đặt phòng.
  Future<CouponValidationResult> validateCoupon({
    required String code,
    int? bookingAmount,
    int? subtotalAmount,
    String? listingId,
    String? checkInDate,
    String? checkOutDate,
    int? guestsCount,
  });

  /// Truy vấn danh sách các cổng thanh toán trực tuyến (như VNPay, MoMo) và trạng thái sẵn sàng cấu hình trên máy chủ.
  Future<List<PaymentMethodAvailability>> getPaymentMethods();

  /// Khởi tạo phiên thanh toán mới cho đơn `bookingId` theo phương thức `method` (hỗ trợ `idempotencyKey` chống tạo trùng).
  Future<PaymentSessionResult> createPayment({
    required String bookingId,
    required String method,
    String? idempotencyKey,
  });

  /// Truy vấn kết quả và trạng thái đối soát hiện tại của phiên thanh toán theo `paymentId`.
  Future<PaymentSessionResult?> getPaymentById(String paymentId);
}
