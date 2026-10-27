import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';

void main() {
  group('Booking Domain & State Machine Tests (BUG-07, BUG-20, BUG-32)', () {
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
          'title': 'The Palm Luxury Ocean Villa',
          'addressLine': '15 Thuy Van, Vung Tau',
          'coverImageUrl': 'https://example.com/cover.jpg',
        },
      };

      final booking = Booking.fromJson(json);

      expect(booking.id, '456');
      expect(booking.listingId, '12');
      expect(booking.propertyName, 'The Palm Luxury Ocean Villa');
      expect(booking.checkInDate, '2026-10-15');
      expect(booking.checkOutDate, '2026-10-18');
      expect(booking.nights, 3);
      expect(booking.totalAmount, 10500000);
      expect(booking.guestCount, 8);
      expect(booking.isActive, isTrue);
      expect(booking.isCompleted, isFalse);
      expect(booking.isCancelled, isFalse);
      expect(booking.canCancel, isTrue);
      expect(booking.canPayNow, isFalse);
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
      expect(booking.canCancel, isFalse);
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
      expect(booking.canCancel, isFalse);
      expect(booking.statusDisplay, 'Đã hoàn thành');
    });

    test(
        'Booking state machine preserves distinct backend statuses and business meanings',
        () {
      Booking makeBooking(String status, {int? remainingPaymentSeconds}) {
        return Booking.fromJson({
          'id': '100',
          'listingId': '1',
          'propertyName': 'Test Villa',
          'checkInDate': '2026-12-01',
          'checkOutDate': '2026-12-03',
          'totalAmount': 6000000,
          'status': status,
          if (remainingPaymentSeconds != null)
            'remainingPaymentSeconds': remainingPaymentSeconds,
        });
      }

      final pendingActive =
          makeBooking('pending_payment', remainingPaymentSeconds: 600);
      expect(pendingActive.status, 'pending_payment');
      expect(pendingActive.statusDisplay, 'Chờ thanh toán');
      expect(pendingActive.canPayNow, isTrue);
      expect(pendingActive.canCancel, isTrue);
      expect(pendingActive.isActive, isTrue);
      expect(pendingActive.isCancelled, isFalse);

      final pendingZeroHold =
          makeBooking('pending_payment', remainingPaymentSeconds: 0);
      expect(pendingZeroHold.computeRemainingPaymentSeconds(), 0);
      expect(pendingZeroHold.canPayNow, isFalse);
      expect(pendingZeroHold.isExpired, isTrue);
      expect(pendingZeroHold.statusDisplay, 'Quá hạn thanh toán');

      final cancelledGuest = makeBooking('cancelled_by_guest');
      expect(cancelledGuest.status, 'cancelled_by_guest');
      expect(cancelledGuest.statusDisplay, 'Khách đã hủy');
      expect(cancelledGuest.isCancelled, isTrue);
      expect(cancelledGuest.canCancel, isFalse);
      expect(cancelledGuest.canPayNow, isFalse);

      final cancelledHost = makeBooking('cancelled_by_host');
      expect(cancelledHost.status, 'cancelled_by_host');
      expect(cancelledHost.statusDisplay, 'Host đã hủy');
      expect(cancelledHost.isCancelled, isTrue);
      expect(cancelledHost.canCancel, isFalse);

      final cancelledAdmin = makeBooking('cancelled_by_admin');
      expect(cancelledAdmin.status, 'cancelled_by_admin');
      expect(cancelledAdmin.statusDisplay, 'Admin đã hủy');
      expect(cancelledAdmin.isCancelled, isTrue);
      expect(cancelledAdmin.canCancel, isFalse);

      final expired = makeBooking('expired');
      expect(expired.status, 'expired');
      expect(expired.statusDisplay, 'Quá hạn thanh toán');
      expect(expired.isExpired, isTrue);
      expect(expired.isCancelled, isTrue);
      expect(expired.canPayNow, isFalse);
      expect(expired.canCancel, isFalse);

      final paymentExpired = makeBooking('payment_expired');
      expect(paymentExpired.status, 'payment_expired');
      expect(paymentExpired.statusDisplay, 'Quá hạn thanh toán');
      expect(paymentExpired.isExpired, isTrue);
      expect(paymentExpired.isCancelled, isTrue);

      final checkedIn = makeBooking('checked_in');
      expect(checkedIn.statusDisplay, 'Đã nhận phòng');
      expect(checkedIn.isActive, isTrue);
      expect(checkedIn.canCancel, isFalse);

      final refundPending = makeBooking('refund_pending');
      expect(refundPending.statusDisplay, 'Đang chờ hoàn tiền');
      expect(refundPending.isCancelled, isTrue);
      expect(refundPending.isActive, isFalse);
      expect(refundPending.canCancel, isFalse);

      final refunded = makeBooking('refunded');
      expect(refunded.statusDisplay, 'Đã hoàn tiền');
      expect(refunded.isCancelled, isTrue);
      expect(refunded.canCancel, isFalse);
    });

    test(
        'Hold expiry never resets 0 seconds to 900 seconds and respects UTC expiresAt',
        () {
      final expiredByZeroSeconds = Booking.fromJson({
        'id': '201',
        'listingId': '10',
        'propertyName': 'Ocean Villa',
        'checkInDate': '2026-12-01',
        'checkOutDate': '2026-12-03',
        'totalAmount': 5000000,
        'status': 'pending_payment',
        'remainingPaymentSeconds': 0,
      });

      expect(expiredByZeroSeconds.computeRemainingPaymentSeconds(), 0);
      expect(expiredByZeroSeconds.canPayNow, isFalse);
      expect(expiredByZeroSeconds.isExpired, isTrue);

      final nowUtc = DateTime.utc(2026, 10, 15, 8, 0, 0);
      final futureExpiresBooking = Booking.fromJson({
        'id': '202',
        'listingId': '10',
        'propertyName': 'Ocean Villa',
        'checkInDate': '2026-12-01',
        'checkOutDate': '2026-12-03',
        'totalAmount': 5000000,
        'status': 'pending_payment',
        'paymentExpiresAt': '2026-10-15T08:05:30Z',
      });
      expect(
        futureExpiresBooking.computeRemainingPaymentSeconds(now: nowUtc),
        330,
      );

      final pastExpiresBooking = Booking.fromJson({
        'id': '203',
        'listingId': '10',
        'propertyName': 'Ocean Villa',
        'checkInDate': '2026-12-01',
        'checkOutDate': '2026-12-03',
        'totalAmount': 5000000,
        'status': 'pending_payment',
        'paymentExpiresAt': '2026-10-15T07:55:00Z',
      });
      expect(
        pastExpiresBooking.computeRemainingPaymentSeconds(now: nowUtc),
        0,
      );
    });

    test(
        'Price breakdown maps backend subtotalAmount so baseNightsAmount is never 0 and fixed surcharge is not multiplied by nights',
        () {
      final booking = Booking.fromJson({
        'bookingId': 301,
        'listingId': 15,
        'propertyName': 'Beachfront Villa',
        'checkInDate': '2026-10-16', // Friday
        'checkOutDate': '2026-10-19', // Monday (3 nights: Fri, Sat, Sun)
        'nights': 3,
        'guestCount': 10,
        'subtotalAmount': 14000000,
        'extraGuestFeeAmount': 1200000,
        'surchargeAmount': 500000,
        'cleaningFee': 300000,
        'serviceFee': 400000,
        'discountAmount': 1000000,
        'totalAmount': 15400000,
        'status': 'pending_payment',
      });

      final pb = booking.priceBreakdown!;
      expect(pb.baseNightsAmount, 14000000);
      expect(pb.subtotalAmount, 14000000);
      expect(pb.extraGuestFeeAmount, 1200000);
      expect(pb.surchargeAmount, 500000);
      expect(pb.cleaningFee, 300000);
      expect(pb.serviceFee, 400000);
      expect(pb.discountAmount, 1000000);
      expect(pb.totalAmount, 15400000);
    });

    test(
        'BookingQueueItem.calculatePriceEstimate computes weekday/weekend nights and fixed surcharge without double counting',
        () {
      const item = BookingQueueItem(
        listingId: '15',
        title: 'Sanctuary Villa',
        location: 'Bãi Sau, Vũng Tàu',
        imageUrl: 'https://example.com/v.jpg',
        pricePerNight: 4000000,
        weekendPrice: 5000000,
        weekendSurcharge: 1000000, // Should not be added on top of weekendPrice
        surchargeAmount: 500000, // Fixed surcharge, NOT multiplied by nights
        cleaningFee: 300000,
        serviceFee: 200000,
        extraGuestFee: 200000,
        includedGuests: 8,
        maxGuests: 14,
        checkIn: '2026-10-16', // Friday
        checkOut:
            '2026-10-19', // Monday (Fri, Sat, Sun -> 1 weekday + 2 weekend)
        guestsCount: 10, // 2 extra guests
      );

      final estimate = item.calculatePriceEstimate();
      expect(estimate.nights, 3);
      expect(estimate.weekdayNights, 1);
      expect(estimate.weekendNights, 2);
      // 1 * 4,000,000 + 2 * 5,000,000 = 14,000,000 (not 14M + 2M)
      expect(estimate.baseNightsAmount, 14000000);
      // 2 extra guests * 200,000 * 3 nights = 1,200,000
      expect(estimate.extraGuestFeeAmount, 1200000);
      // Fixed surcharge = 500,000 (not 500k * 3)
      expect(estimate.surchargeAmount, 500000);
      // Total = 14,000,000 + 1,200,000 + 500,000 + 300,000 + 200,000 = 16,200,000
      expect(estimate.estimatedTotal, 16200000);
    });
  });
}
