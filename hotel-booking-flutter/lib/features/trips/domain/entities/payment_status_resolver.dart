import 'booking.dart';

/// Phân giải trạng thái kết quả thanh toán có thẩm quyền bằng cách đối chiếu chéo giữa
/// phiên thanh toán `payment`, đơn đặt phòng `booking` và gợi ý trạng thái gọi lại `initialStatusHint`.
///
/// Quy trình ưu tiên phân giải gồm 4 tầng:
/// 1. Ưu tiên cao nhất cho trạng thái hoàn tiền từ cả `payment` và `booking`: nếu `refundStatus` là
///    `'succeeded'`/`'refunded'` thì trả về `'refunded'`; nếu có cờ `requiresRefund` (giao dịch thanh toán muộn
///    sau khi hết hạn giữ chỗ) hoặc `refundStatus` đang `'pending'`/`'processing'` thì trả về `'refund_pending'`
///    trước khi xét `'paid'`, ngăn việc báo nhầm thanh toán thành công cho đơn đã bị thu hồi chỗ.
/// 2. Nếu có bản ghi `payment` xác định rõ kết quả cuối (`'paid'`, `'failed'`, `'cancelled'`, `'expired'`),
///    trả về trực tiếp kết quả đối soát từ cổng thanh toán.
/// 3. Nếu chưa có kết quả cuối từ `payment`, suy diễn dựa trên `booking` (`effectiveStatus`, đếm ngược giữ chỗ
///    `computeRemainingPaymentSeconds() <= 0` -> `'expired'`, trạng thái hủy -> `'cancelled'`).
/// 4. Khi đơn vẫn đang `'pending_payment'`, tận dụng `initialStatusHint` từ tham số URL callback nếu báo lỗi/hủy,
///    ngược lại giữ `'pending'` để luồng thăm dò tiếp tục xác minh hoặc trả về `'unverified'` khi thiếu dữ liệu.
// Giải thuật phân giải trạng thái giao dịch có thẩm quyền (Authoritative Payment Status):
// Ưu tiên kiểm tra trạng thái hoàn tiền thực tế từ cả bản ghi Payment và Booking
// (`refundStatus == 'succeeded'` -> `'refunded'`; `requiresRefund` hoặc `pending`/`processing` -> `'refund_pending'`)
// TRƯỚC KHI xét `paymentResultStatus == 'paid'` để tránh hiển thị nhầm "Thanh toán thành công"
// đối với giao dịch thanh toán muộn sau khi hết hạn giữ chỗ đã/đang được hoàn tiền.
// CONFLICT-RESOLVED: Đồng bộ với `payments.service.ts` trả về `paymentResultStatus: "refunded"` khi `refundStatus === "succeeded"` và xét đầy đủ `booking.refundStatus`.
String deriveAuthoritativePaymentStatus({
  PaymentSessionResult? payment,
  Booking? booking,
  String? initialStatusHint,
}) {
  final bookingRefund = booking?.refundStatus?.trim().toLowerCase();
  final bookingRawStatus = booking?.status.trim().toLowerCase();
  final bookingEffectiveStatus = booking?.effectiveStatus;

  if (payment != null) {
    final payRefund = payment.refundStatus?.trim().toLowerCase();
    final resultStatus = payment.paymentResultStatus.trim().toLowerCase();
    final payStatus = payment.paymentStatus.trim().toLowerCase();

    if (payRefund == 'succeeded' ||
        payRefund == 'refunded' ||
        resultStatus == 'refunded' ||
        payStatus == 'refunded' ||
        bookingRefund == 'succeeded' ||
        bookingRefund == 'refunded' ||
        bookingRawStatus == 'refunded' ||
        bookingEffectiveStatus == 'refunded') {
      return 'refunded';
    }

    if (payRefund == 'pending' ||
        payRefund == 'processing' ||
        resultStatus == 'refund_pending' ||
        payStatus == 'refund_pending' ||
        payment.requiresRefund ||
        bookingRefund == 'pending' ||
        bookingRefund == 'processing' ||
        bookingRawStatus == 'refund_pending' ||
        bookingEffectiveStatus == 'refund_pending') {
      return 'refund_pending';
    }

    if (resultStatus == 'paid' ||
        resultStatus == 'failed' ||
        resultStatus == 'cancelled' ||
        resultStatus == 'expired') {
      return resultStatus;
    }
  }

  if (booking != null) {
    if (bookingRefund == 'succeeded' ||
        bookingRefund == 'refunded' ||
        bookingRawStatus == 'refunded' ||
        bookingEffectiveStatus == 'refunded') {
      return 'refunded';
    }

    if (bookingRefund == 'pending' ||
        bookingRefund == 'processing' ||
        bookingRawStatus == 'refund_pending' ||
        bookingEffectiveStatus == 'refund_pending') {
      return 'refund_pending';
    }

    if (bookingRawStatus == 'paid' ||
        bookingRawStatus == 'confirmed' ||
        bookingRawStatus == 'checked_in' ||
        bookingRawStatus == 'checked_out' ||
        bookingRawStatus == 'completed' ||
        bookingEffectiveStatus == 'paid' ||
        bookingEffectiveStatus == 'checked_out' ||
        bookingEffectiveStatus == 'completed') {
      return 'paid';
    }

    if (booking.isExpired ||
        (bookingRawStatus == 'pending_payment' &&
            booking.computeRemainingPaymentSeconds() <= 0)) {
      return 'expired';
    }

    if (booking.isCancelled) {
      return 'cancelled';
    }

    if (bookingRawStatus == 'pending_payment' ||
        bookingEffectiveStatus == 'pending_payment') {
      if (payment != null) {
        return payment.paymentResultStatus.trim().toLowerCase();
      }
      final normalizedHint = initialStatusHint?.trim().toLowerCase() ?? '';
      if (normalizedHint == 'failed' || normalizedHint == 'cancelled') {
        return normalizedHint;
      }
      return 'pending';
    }
  }

  if (payment != null) {
    return payment.paymentResultStatus.trim().toLowerCase();
  }

  return 'unverified';
}
