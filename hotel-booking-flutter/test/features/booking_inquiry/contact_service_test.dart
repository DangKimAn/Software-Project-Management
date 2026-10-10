import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/features/booking_inquiry/domain/services/contact_service.dart';

void main() {
  group('ContactService Tests', () {
    test(
        'buildZaloInquiryMessage constructs correct text including villa code and dates',
        () {
      final checkIn = BookingDate.parse('2026-10-15');
      final checkOut = BookingDate.parse('2026-10-17');

      final message = ContactService.buildZaloInquiryMessage(
        villaName: 'Minh Thanh Luxury Sea Villa 01',
        villaCode: 'MTV-01',
        checkIn: checkIn,
        checkOut: checkOut,
        guestCount: 16,
        additionalNotes: 'Cần phòng xông hơi',
      );

      expect(message.contains('Minh Thanh Luxury Sea Villa 01'), isTrue);
      expect(message.contains('MTV-01'), isTrue);
      expect(message.contains('15/10/2026'), isTrue);
      expect(message.contains('17/10/2026'), isTrue);
      expect(message.contains('2 đêm'), isTrue);
      expect(message.contains('16 người'), isTrue);
      expect(message.contains('Cần phòng xông hơi'), isTrue);
    });
  });
}
