import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';

void main() {
  group('Booking Domain Tests', () {
    test(
        'Booking.fromJson correctly parses active booking payload from backend',
        () {
      final json = {
        'bookingId': 456,
        'listingId': 12,
        'checkInDate': '2026-10-15',
        'checkOutDate': '2026-10-18',
        'nights': 3,
        'totalAmount': 10500000,
        'guestCount': 8,
        'status': 'confirmed',
        'listing': {
          'title': 'Minh Thanh Luxury Ocean Villa',
          'addressLine': '15 Thuy Van, Vung Tau',
          'coverImageUrl': 'https://example.com/cover.jpg',
        },
      };

      final booking = Booking.fromJson(json);

      expect(booking.id, '456');
      expect(booking.listingId, '12');
      expect(booking.propertyName, 'Minh Thanh Luxury Ocean Villa');
      expect(booking.checkInDate, '2026-10-15');
      expect(booking.checkOutDate, '2026-10-18');
      expect(booking.nights, 3);
      expect(booking.totalAmount, 10500000);
      expect(booking.guestCount, 8);
      expect(booking.isActive, isTrue);
      expect(booking.isCompleted, isFalse);
      expect(booking.isCancelled, isFalse);
      expect(booking.statusDisplay, 'Đã xác nhận');
    });

    test('Booking.fromJson correctly identifies cancelled status', () {
      final json = {
        'id': 789,
        'listingId': 14,
        'propertyName': 'Villa Sunset',
        'checkInDate': '2026-11-01',
        'checkOutDate': '2026-11-03',
        'totalPrice': 5000000,
        'status': 'cancelled',
        'cancellationReason': 'Khách bận việc đột xuất',
      };

      final booking = Booking.fromJson(json);

      expect(booking.id, '789');
      expect(booking.isCancelled, isTrue);
      expect(booking.isActive, isFalse);
      expect(booking.statusDisplay, 'Đã hủy');
      expect(booking.cancellationReason, 'Khách bận việc đột xuất');
    });

    test('Booking.fromJson correctly identifies completed status', () {
      final json = {
        'id': 999,
        'listingId': 10,
        'propertyName': 'Villa Garden',
        'checkInDate': '2026-09-01',
        'checkOutDate': '2026-09-03',
        'totalPrice': 7000000,
        'status': 'completed',
      };

      final booking = Booking.fromJson(json);

      expect(booking.isCompleted, isTrue);
      expect(booking.isActive, isFalse);
      expect(booking.statusDisplay, 'Đã hoàn thành');
    });
  });
}
