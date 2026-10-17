import '../entities/booking.dart';

abstract class BookingRepository {
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  });

  Future<Booking?> getBookingById(String bookingId);

  Future<Booking> createBooking({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    String? specialRequests,
    String? couponCode,
  });

  Future<List<Booking>> createBulkBookings({
    required List<Map<String, dynamic>> items,
  });

  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  });

  Future<CouponValidationResult> validateCoupon({
    required String code,
    int? bookingAmount,
    int? subtotalAmount,
    String? listingId,
    String? checkInDate,
    String? checkOutDate,
    int? guestsCount,
  });

  Future<List<PaymentMethodAvailability>> getPaymentMethods();

  Future<PaymentSessionResult> createPayment({
    required String bookingId,
    required String method,
    String? idempotencyKey,
  });

  Future<PaymentSessionResult?> getPaymentById(String paymentId);
}
