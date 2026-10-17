import 'package:intl/intl.dart';

/// Immutable value object representing a calendar booking date.
///
/// Complies with MINH THANH VILLA BUSINESS RULES:
/// - Calendar dates are treated as pure dates (YYYY-MM-DD) in `Asia/Ho_Chi_Minh`.
/// - Avoids UTC conversion drift (`DateTime.toUtc().toIso8601String()` is forbidden for calendar days).
/// - The stay duration follows the half-open interval `[checkIn, checkOut)`.
///   Example: 15/10 - 17/10 covers night 15 and night 16 (2 nights).
///   Check-out on the 17th is NOT an occupied night and can be a check-in day for the next guest.
class BookingDate implements Comparable<BookingDate> {
  final int year;
  final int month;
  final int day;

  const BookingDate({
    required this.year,
    required this.month,
    required this.day,
  });

  /// Factory constructor from DateTime (extracting only year, month, day).
  factory BookingDate.fromDateTime(DateTime dateTime) {
    return BookingDate(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
    );
  }

  /// Parses an ISO string in `YYYY-MM-DD` format.
  factory BookingDate.parse(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) {
      throw FormatException(
          'Invalid booking date format (expected YYYY-MM-DD): "$isoDate"');
    }
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return BookingDate(year: y, month: m, day: d);
  }

  /// Safe parse returning null on format error.
  static BookingDate? tryParse(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    try {
      return BookingDate.parse(isoDate);
    } catch (_) {
      return null;
    }
  }

  /// Alias for [tryParse] used across calendar pickers.
  static BookingDate? tryParseIso(String? isoDate) => tryParse(isoDate);

  /// Returns today's date in local time.
  factory BookingDate.today() {
    return BookingDate.fromDateTime(DateTime.now());
  }

  /// Returns today's date in Vietnam timezone (`Asia/Ho_Chi_Minh`, UTC+7),
  /// matching `getTodayVN()` in `Source goc/frontend/src/views/components/search/searchState.ts`.
  factory BookingDate.todayVn() {
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return BookingDate(year: vnNow.year, month: vnNow.month, day: vnNow.day);
  }

  /// Converts to an internal UTC DateTime for date-only calendar arithmetic.
  DateTime toDateTime() {
    return DateTime.utc(year, month, day);
  }

  /// Alias for `toDateTime()` returning UTC DateTime.
  DateTime toDateTimeUtc() => toDateTime();

  /// Serializes into the standard API date format `YYYY-MM-DD`.
  String toIsoDate() {
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$year-$mm-$dd';
  }

  /// Formats date for Vietnamese display (e.g. `15/10/2026`).
  String toDisplayString({String format = 'dd/MM/yyyy'}) {
    final dt = DateTime(year, month, day);
    return DateFormat(format).format(dt);
  }

  /// Short Vietnamese display helper (`dd/MM/yyyy`).
  String toDisplayVi() => toDisplayString();

  /// Adds a number of days to this date.
  BookingDate addDays(int days) {
    final dt = toDateTime().add(Duration(days: days));
    return BookingDate(year: dt.year, month: dt.month, day: dt.day);
  }

  /// Difference in nights between this date and another date (`other - this`).
  /// Positive when `other` is after `this` (e.g. `checkIn.differenceInNights(checkOut)`).
  int differenceInNights(BookingDate other) {
    final d1 = toDateTime();
    final d2 = other.toDateTime();
    return d2.difference(d1).inDays;
  }

  bool isBefore(BookingDate other) => compareTo(other) < 0;
  bool isAfter(BookingDate other) => compareTo(other) > 0;
  bool isAtSameMomentAs(BookingDate other) => compareTo(other) == 0;
  bool get isSaturday => toDateTime().weekday == DateTime.saturday;

  /// Whether this date falls on a weekend (Saturday or Sunday) per `booking-pricing.service.ts`.
  bool get isWeekend {
    final wd = toDateTime().weekday;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  @override
  int compareTo(BookingDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ day.hashCode;

  @override
  String toString() => toIsoDate();

  /// Computes all stay nights in the half-open interval `[checkIn, checkOut)`.
  ///
  /// For instance, if checkIn is 2026-10-15 and checkOut is 2026-10-17,
  /// this returns `[2026-10-15, 2026-10-16]`.
  static List<BookingDate> getNightsBetween(
      BookingDate checkIn, BookingDate checkOut) {
    if (!checkOut.isAfter(checkIn)) {
      return const [];
    }
    final nights = <BookingDate>[];
    var current = checkIn;
    while (current.isBefore(checkOut)) {
      nights.add(current);
      current = current.addDays(1);
    }
    return nights;
  }

  /// Validates whether a candidate date interval `[checkIn, checkOut)` is completely available
  /// given a set of booked nights.
  ///
  /// CRITICAL BUSINESS RULE:
  /// - A range CANNOT pass through any already booked night.
  /// - Check-out date is allowed to coincide with another reservation's check-in date
  ///   because check-out morning happens before 12:00 PM and check-in afternoon is after 2:00 PM.
  static bool isRangeAvailable({
    required BookingDate checkIn,
    required BookingDate checkOut,
    required Set<BookingDate> bookedNights,
  }) {
    if (!checkOut.isAfter(checkIn)) return false;

    final requestedNights = getNightsBetween(checkIn, checkOut);
    for (final night in requestedNights) {
      if (bookedNights.contains(night)) {
        return false;
      }
    }
    return true;
  }
}

/// Pure business logic helper for date mode conversions (`dates` | `months` | `flexible`)
/// matching `DatePickerPanel.tsx` and `searchState.ts` so `checkIn` and `checkOut` are always
/// valid, conflict-free ISO dates.
class SearchDateModeHelper {
  SearchDateModeHelper._();

  static ({
    BookingDate checkIn,
    BookingDate checkOut,
    List<int> months
  }) computeForMonths(List<int> selectedMonths, {BookingDate? referenceToday}) {
    final today = referenceToday ?? BookingDate.todayVn();
    final effectiveMonths =
        selectedMonths.isEmpty ? <int>[today.month] : [...selectedMonths]
          ..sort();
    final firstMonth = effectiveMonths.first;
    final lastMonth = effectiveMonths.last;

    final startYear = firstMonth < today.month ? today.year + 1 : today.year;
    var checkIn = BookingDate(year: startYear, month: firstMonth, day: 1);
    if (checkIn.isBefore(today)) {
      checkIn = today;
    }

    final endYear = lastMonth < firstMonth ? startYear + 1 : startYear;
    final firstOfNextMonth = DateTime.utc(endYear, lastMonth + 1, 1);
    var checkOut = BookingDate(
      year: firstOfNextMonth.year,
      month: firstOfNextMonth.month,
      day: firstOfNextMonth.day,
    );
    if (!checkOut.isAfter(checkIn)) {
      checkOut = checkIn.addDays(1);
    }

    return (
      checkIn: checkIn,
      checkOut: checkOut,
      months: effectiveMonths,
    );
  }

  static ({BookingDate checkIn, BookingDate checkOut}) computeForFlexible(
    String flexDuration, {
    BookingDate? referenceToday,
  }) {
    final today = referenceToday ?? BookingDate.todayVn();
    switch (flexDuration) {
      case 'week':
        final checkIn = today.addDays(1);
        return (checkIn: checkIn, checkOut: checkIn.addDays(7));
      case 'month':
        final checkIn = today.addDays(1);
        return (checkIn: checkIn, checkOut: checkIn.addDays(30));
      case 'weekend':
      default:
        final weekday = today.toDateTime().weekday;
        final daysUntilSaturday = (DateTime.saturday - weekday + 7) % 7;
        final checkIn = today.addDays(daysUntilSaturday);
        return (checkIn: checkIn, checkOut: checkIn.addDays(2));
    }
  }
}
