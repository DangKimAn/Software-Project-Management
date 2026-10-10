import '../../../../core/network/dio_client.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final DioClient _client;

  const BookingRepositoryImpl(this._client);

  @override
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/bookings/mine',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page ?? 1,
          'limit': limit ?? 20,
        },
      );
      final body = response.data;
      final dataObj = body?['data'];
      List<dynamic> items = [];
      if (dataObj is Map<String, dynamic> && dataObj['items'] is List) {
        items = dataObj['items'] as List<dynamic>;
      } else if (dataObj is List) {
        items = dataObj;
      }

      return items
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final response = await _client.dio
          .get<Map<String, dynamic>>('/api/bookings/$bookingId');
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (data == null) return null;
      return Booking.fromJson(data);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    try {
      await _client.dio.post<Map<String, dynamic>>(
        '/api/bookings/$bookingId/cancel',
        data: {
          'cancellationReason': reason.trim(),
        },
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
