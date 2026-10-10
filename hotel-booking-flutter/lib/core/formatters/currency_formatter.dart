import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final _vndFormat = NumberFormat('#,###', 'vi_VN');

  /// Formats an integer VND amount (e.g. 12000000 -> "12.000.000 ₫").
  static String formatVnd(int? amount, {String fallback = 'Liên hệ báo giá'}) {
    if (amount == null || amount <= 0) {
      return fallback;
    }
    return '${_vndFormat.format(amount)} ₫';
  }

  /// Formats price with per-night unit (e.g. "Từ 12.000.000 ₫ / đêm").
  static String formatPerNight(int? amount,
      {String fallback = 'Liên hệ báo giá'}) {
    if (amount == null || amount <= 0) {
      return fallback;
    }
    return 'Từ ${_vndFormat.format(amount)} ₫ / đêm';
  }

  /// Formats Saturday specific rate (e.g. "Thứ 7: 15.000.000 ₫").
  static String? formatSaturdayPrice(int? amount) {
    if (amount == null || amount <= 0) {
      return null;
    }
    return 'Thứ 7: ${_vndFormat.format(amount)} ₫';
  }
}
