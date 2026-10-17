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

  /// Formats compact VND amount for calendar cells and badges (e.g. 4500000 -> "4.5M ₫").
  static String formatCompact(num? amount) {
    if (amount == null || amount <= 0) return '0 ₫';
    final v = amount.toDouble();
    if (v >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1)}B ₫';
    }
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m == m.roundToDouble() ? m.toInt() : m.toStringAsFixed(1)}M ₫';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(0)}K ₫';
    }
    return '${v.toInt()} ₫';
  }
}
