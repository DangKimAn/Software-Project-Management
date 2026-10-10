import '../../../../core/date/booking_date.dart';

class NightlyPrice {
  final BookingDate date;
  final int priceVnd;
  final bool isWeekend;
  final bool isAvailable;
  final String? note;

  const NightlyPrice({
    required this.date,
    required this.priceVnd,
    this.isWeekend = false,
    this.isAvailable = true,
    this.note,
  });
}
