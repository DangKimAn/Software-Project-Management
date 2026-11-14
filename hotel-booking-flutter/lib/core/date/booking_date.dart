import 'package:intl/intl.dart';

/// Immutable value object representing a calendar booking date.
///
/// Complies with THE PALM VILLA BUSINESS RULES:
/// - Calendar dates are treated as pure dates (YYYY-MM-DD) in `Asia/Ho_Chi_Minh`.
/// - Avoids UTC conversion drift (`DateTime.toUtc().toIso8601String()` is forbidden for calendar days).
/// - The stay duration follows the half-open interval `[checkIn, checkOut)`.
///   Example: 15/10 - 17/10 covers night 15 and night 16 (2 nights).
///   Check-out on the 17th is NOT an occupied night and can be a check-in day for the next guest.
/// Đối tượng giá trị bất biến biểu diễn ngày lịch đặt phòng thuần túy (`YYYY-MM-DD`) theo múi giờ `Asia/Ho_Chi_Minh`.
///
/// Giải thuật mô hình hóa lịch lưu trú nửa mở `[checkIn, checkOut)`:
/// 1. Lưu trữ tách rời bộ ba số nguyên `(year, month, day)` để triệt tiêu hoàn toàn hiện tượng trôi ngày do lệch múi giờ thiết bị khi chuyển đổi UTC.
/// 2. Khoảng lưu trú tuân thủ tập nửa mở `[checkIn, checkOut)`: ví dụ nhận phòng `15/10` và trả phòng `17/10` bao gồm 2 đêm lưu trú (`15/10` và `16/10`);
///    ngày `17/10` là buổi sáng trả phòng nên vẫn hợp lệ để đoàn khách kế tiếp nhận phòng vào buổi chiều cùng ngày.
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
  /// Trích xuất trực tiếp bộ ba `(year, month, day)` từ `dateTime` mà không dịch chuyển múi giờ.
  factory BookingDate.fromDateTime(DateTime dateTime) {
    return BookingDate(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
    );
  }

  /// Parses an ISO string in `YYYY-MM-DD` format.
  /// Phân tích chuỗi ngày chuẩn ISO `YYYY-MM-DD` thành `BookingDate`, ném `FormatException` nếu sai cấu trúc 3 thành phần.
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
  /// Phân tích an toàn chuỗi `YYYY-MM-DD`, trả về `null` thay vì ném ngoại lệ nếu đầu vào rỗng hoặc sai định dạng.
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
  /// Trả về ngày hôm nay theo múi giờ Việt Nam (`Asia/Ho_Chi_Minh`, `UTC+7`).
  factory BookingDate.today() {
    // CONFLICT-RESOLVED: Chuẩn hóa BookingDate.today() ủy quyền về BookingDate.todayVn() (UTC+7) để tránh lệch ngày theo giờ máy thiết bị (FLUTTER_RULES 9.3).
    return BookingDate.todayVn();
  }

  /// Returns today's date in Vietnam timezone (`Asia/Ho_Chi_Minh`, UTC+7),
  /// matching `getTodayVN()` in `Source goc/frontend/src/views/components/search/searchState.ts`.
  /// Giải thuật xác định ngày hiện tại theo múi giờ Việt Nam (`UTC+7`):
  /// Chuẩn hóa thời điểm `nowUtc` (hoặc `DateTime.now()`) về gốc UTC rồi cộng bù đúng `+7` giờ trước khi đọc `(year, month, day)`.
  factory BookingDate.todayVn({DateTime? nowUtc}) {
    // CONFLICT-RESOLVED: Bổ sung tham số tùy chọn nowUtc phục vụ kiểm thử đơn vị mốc nửa đêm múi giờ Việt Nam (UTC+7) mà không phá vỡ các điểm gọi mặc định.
    // Thuật toán: Quy đổi mốc thời gian hiện tại (hoặc mốc UTC truyền vào) sang UTC rồi cộng độ lệch +7 giờ của múi giờ Asia/Ho_Chi_Minh trước khi trích xuất năm-tháng-ngày.
    final vnNow =
        (nowUtc ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
    return BookingDate(year: vnNow.year, month: vnNow.month, day: vnNow.day);
  }

  /// Converts to an internal UTC DateTime for date-only calendar arithmetic.
  /// Quy đổi sang `DateTime.utc(year, month, day)` chỉ phục vụ phép toán cộng trừ số ngày lịch không chịu ảnh hưởng của giờ mùa hè (DST).
  DateTime toDateTime() {
    return DateTime.utc(year, month, day);
  }

  /// Alias for `toDateTime()` returning UTC DateTime.
  DateTime toDateTimeUtc() => toDateTime();

  /// Serializes into the standard API date format `YYYY-MM-DD`.
  /// Tuần tự hóa ngày lịch thành chuỗi chuẩn `YYYY-MM-DD` (đệm số `0` cho tháng và ngày có 1 chữ số) để truyền lên REST API.
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
  /// Cộng thêm (hoặc lùi lại nếu âm) `days` ngày lịch dựa trên trục `DateTime.utc` không sai số múi giờ.
  BookingDate addDays(int days) {
    final dt = toDateTime().add(Duration(days: days));
    return BookingDate(year: dt.year, month: dt.month, day: dt.day);
  }

  /// Difference in nights between this date and another date (`other - this`).
  /// Positive when `other` is after `this` (e.g. `checkIn.differenceInNights(checkOut)`).
  /// Tính số đêm lưu trú giữa ngày hiện tại và ngày `other` theo công thức nửa mở `other - this` (trả về số dương khi `other` đứng sau `this`).
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
  /// Giải thuật liệt kê toàn bộ danh sách đêm lưu trú thuộc khoảng nửa mở `[checkIn, checkOut)`:
  /// Nếu `checkOut` không đứng sau `checkIn` thì trả về danh sách rỗng; ngược lại tịnh tiến từng ngày từ `checkIn`
  /// và dừng ngay trước `checkOut` (không bao gồm ngày trả phòng `checkOut`).
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
  /// Giải thuật kiểm tra tính khả dụng của khoảng lưu trú nửa mở `[checkIn, checkOut)` trước tập đêm đã kín `bookedNights`:
  /// 1. Từ chối ngay (`false`) nếu `checkOut <= checkIn`.
  /// 2. Sinh danh sách các đêm thực ở qua `getNightsBetween(checkIn, checkOut)` và kiểm tra giao cắt với `bookedNights`.
  /// 3. Vì `checkOut` nằm ngoài khoảng nửa mở nên ngày trả phòng được phép trùng với ngày nhận phòng của khách kế tiếp mà không bị chặn sai.
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
/// Bộ trợ giúp thuần nghiệp vụ chuyển đổi các chế độ chọn ngày tìm kiếm (`dates`, `months`, `flexible`) sang cặp `(checkIn, checkOut)` hợp lệ.
class SearchDateModeHelper {
  SearchDateModeHelper._();

  /// Giải thuật tính khoảng ngày lưu trú cho chế độ tìm kiếm theo tháng (`months`):
  /// 1. Chuẩn hóa danh sách tháng: Nếu `selectedMonths` rỗng thì lấy `[today.month]`, sau đó sao chép và sắp xếp tăng dần để lấy `firstMonth` và `lastMonth`.
  /// 2. Xác định năm bắt đầu và kẹp biên quá khứ: Nếu `firstMonth < today.month` thì đẩy sang năm kế tiếp (`today.year + 1`);
  ///    khởi tạo `checkIn` tại ngày mồng 1 của `firstMonth` rồi kẹp lên `today` nếu rơi vào quá khứ.
  /// 3. Tính ngày kết thúc theo tháng cuối: Nếu `lastMonth < firstMonth` thì tăng thêm 1 năm (`startYear + 1`), lấy ngày đầu tiên của tháng kế tiếp qua `DateTime.utc(endYear, lastMonth + 1, 1)`.
  /// 4. Kẹp ngưỡng số đêm trong đoạn `[1, 30]`: Đảm bảo tối thiểu 1 đêm và tối đa 30 đêm nhằm tương thích với giới hạn `maxNights = 30` mặc định của chỗ nghỉ trên máy chủ.
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

    // Giải thuật tính khoảng ngày lưu trú cho chế độ tìm kiếm theo 'Tháng':
    // Giới hạn khoảng đêm mặc định tối đa 30 đêm để tương thích với ngưỡng `maxNights = 30` mặc định của chỗ nghỉ,
    // tránh hiện tượng tháng có 31 ngày loại bỏ toàn bộ kết quả về 0.
    // CONFLICT-RESOLVED: Khắc phục lỗi sinh khoảng ngày 31+ đêm ở chế độ 'Tháng' vượt quá `maxNights = 30` mặc định trên backend.
    final endYear = lastMonth < firstMonth ? startYear + 1 : startYear;
    final firstOfNextMonth = DateTime.utc(endYear, lastMonth + 1, 1);
    var checkOut = BookingDate(
      year: firstOfNextMonth.year,
      month: firstOfNextMonth.month,
      day: firstOfNextMonth.day,
    );
    final rawNights = checkIn.differenceInNights(checkOut);
    if (rawNights <= 0) {
      checkOut = checkIn.addDays(1);
    } else if (rawNights > 30) {
      checkOut = checkIn.addDays(30);
    }

    return (
      checkIn: checkIn,
      checkOut: checkOut,
      months: effectiveMonths,
    );
  }

  /// Giải thuật tính khoảng ngày lưu trú cho chế độ tìm kiếm linh hoạt (`flexible`):
  /// 1. Xác định mốc ngày gốc `today` theo múi giờ Việt Nam (`BookingDate.todayVn()`).
  /// 2. Phân nhánh theo thời lượng `flexDuration`:
  ///    - `'week'`: Nhận phòng từ ngày mai (`today + 1`) và trả phòng sau `7` đêm (`checkIn + 7`).
  ///    - `'month'`: Nhận phòng từ ngày mai (`today + 1`) và trả phòng sau `30` đêm (`checkIn + 30`).
  ///    - `'weekend'` (mặc định): Tính độ lệch ngày tới Thứ Bảy gần nhất theo công thức đồng dư `(DateTime.saturday - weekday + 7) % 7`
  ///      (bằng `0` nếu hôm nay đã là Thứ Bảy) và thiết lập kỳ nghỉ 2 đêm cuối tuần `[checkIn, checkIn + 2)`.
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
