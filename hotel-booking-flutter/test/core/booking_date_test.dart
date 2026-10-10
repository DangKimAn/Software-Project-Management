import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';

void main() {
  group('BookingDate Unit Tests', () {
    test('parses YYYY-MM-DD correctly and serializes back', () {
      final date = BookingDate.parse('2026-10-15');
      expect(date.year, 2026);
      expect(date.month, 10);
      expect(date.day, 15);
      expect(date.toIsoDate(), '2026-10-15');
    });

    test(
        'calculates nights accurately under half-open interval [checkIn, checkOut)',
        () {
      final checkIn = BookingDate.parse('2026-10-15');
      final checkOut = BookingDate.parse('2026-10-17');

      final nights = BookingDate.getNightsBetween(checkIn, checkOut);
      expect(nights.length, 2);
      expect(nights[0].toIsoDate(), '2026-10-15');
      expect(nights[1].toIsoDate(), '2026-10-16');
      // Notice: check-out day (17th) is NOT an occupied stay night!
    });

    test('calculates differenceInNights correctly', () {
      final d1 = BookingDate.parse('2026-10-15');
      final d2 = BookingDate.parse('2026-10-20');
      expect(d1.differenceInNights(d2), 5);
    });

    test(
        'isRangeAvailable returns false when requested range crosses a booked night',
        () {
      final checkIn = BookingDate.parse('2026-10-14');
      final checkOut = BookingDate.parse('2026-10-18');
      final bookedNights = {
        BookingDate.parse('2026-10-16'),
      };

      final available = BookingDate.isRangeAvailable(
        checkIn: checkIn,
        checkOut: checkOut,
        bookedNights: bookedNights,
      );

      expect(available, isFalse);
    });

    test(
        'isRangeAvailable allows check-out day to coincide with a booked night',
        () {
      // If night 17 is booked, a guest checking in on 15 and checking out on 17 does NOT occupy night 17
      final checkIn = BookingDate.parse('2026-10-15');
      final checkOut = BookingDate.parse('2026-10-17');
      final bookedNights = {
        BookingDate.parse('2026-10-17'), // booked night is 17th onwards
      };

      final available = BookingDate.isRangeAvailable(
        checkIn: checkIn,
        checkOut: checkOut,
        bookedNights: bookedNights,
      );

      expect(available, isTrue);
    });

    test('comparison and ordering work predictably', () {
      final d1 = BookingDate.parse('2026-10-01');
      final d2 = BookingDate.parse('2026-10-02');
      final d3 = BookingDate.parse('2026-10-01');

      expect(d1.isBefore(d2), isTrue);
      expect(d2.isAfter(d1), isTrue);
      expect(d1.isAtSameMomentAs(d3), isTrue);
    });
  });
}
