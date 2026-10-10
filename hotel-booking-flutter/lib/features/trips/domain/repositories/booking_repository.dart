import '../entities/booking.dart';

abstract class BookingRepository {
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  });

  Future<Booking?> getBookingById(String bookingId);

  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  });
}
