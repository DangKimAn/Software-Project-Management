import 'app_currency.dart';
import 'exchange_rate_snapshot.dart';

/// Arbitrary-precision base-10 decimal represented as `unscaledValue * 10^(-scale)`
/// using [BigInt] to eliminate IEEE-754 binary floating-point rounding drift.
/// Kiểu số thập phân cơ số 10 độ chính xác tùy ý biểu diễn dưới dạng dấu phẩy tĩnh `unscaledValue * 10^(-scale)` dựa trên `BigInt`.
///
/// Giải thuật số học dấu phẩy tĩnh cơ số 10 (`BigInt` Scaled Fixed-Point Arithmetic):
/// - Loại bỏ hoàn toàn sai số biểu diễn nhị phân IEEE-754 (`double`) khi nhân tiền nguyên `VND` với hệ số tỷ giá rất nhỏ (như `0.000038813`).
/// - Mọi phép nhân và làm tròn `HALF_UP` đều thực hiện thuần túy trên số nguyên lớn `BigInt`.
class ExactDecimal implements Comparable<ExactDecimal> {
  static final ExactDecimal zero = ExactDecimal._(BigInt.zero, 0);
  static final ExactDecimal one = ExactDecimal._(BigInt.one, 0);

  final BigInt unscaledValue;
  final int scale;

  const ExactDecimal._(this.unscaledValue, this.scale);

  /// Khởi tạo `ExactDecimal` từ số nguyên `value` với bậc thập phân `scale = 0`.
  factory ExactDecimal.fromInt(int value) =>
      ExactDecimal._(BigInt.from(value), 0);

  bool get isZero => unscaledValue == BigInt.zero;
  bool get isNegative => unscaledValue.isNegative;
  bool get isStrictlyPositive => unscaledValue > BigInt.zero;

  /// Phân tích chuỗi số thập phân `raw` thành `ExactDecimal`, ném `FormatException` nếu chuỗi không hợp lệ.
  static ExactDecimal parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid decimal string: "$raw"');
    }
    return parsed;
  }

  /// Parses plain decimal (`"0.000038813"`) or scientific notation (`"3.9e-5"`),
  /// rejecting `NaN`, `Infinity`, empty strings, or malformed input.
  /// Giải thuật phân tích chuỗi số thập phân thường (`"0.000038813"`) hoặc ký hiệu khoa học (`"3.9e-5"`) sang `ExactDecimal`:
  /// 1. Từ chối đầu vào rỗng, `NaN`, `Infinity` và kiểm tra khớp biểu thức chính quy tách dấu `([+-]?)`, phần nguyên, phần thập phân và số mũ `e/E` (giới hạn `|exp| <= 100` chống tràn bộ nhớ).
  /// 2. Ghép phần nguyên và phần thập phân thành chuỗi chữ số liền mạch rồi chuyển sang `BigInt` kèm dấu âm/dương.
  /// 3. Tính bậc thập phân hiệu dụng `effectiveScale = fracDigits.length - exp`; nếu `effectiveScale < 0` (số mũ dương lớn) thì nhân bù `10^(-effectiveScale)` vào `BigInt` và đưa `effectiveScale` về `0`.
  /// 4. Rút gọn các chữ số `0` dư ở đuôi phần thập phân qua `_normalize` để thu được dạng biểu diễn tối giản duy nhất.
  static ExactDecimal? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'nan' ||
        lower == 'infinity' ||
        lower == '+infinity' ||
        lower == '-infinity') {
      return null;
    }

    final sciMatch = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
    ).firstMatch(trimmed);
    if (sciMatch == null) return null;

    final sign = sciMatch.group(1) == '-' ? -1 : 1;
    final wholeDigits = sciMatch.group(2)!;
    final fracDigits = sciMatch.group(3) ?? '';
    final expStr = sciMatch.group(4);
    final exp = expStr != null ? int.tryParse(expStr) : 0;
    if (exp == null || exp.abs() > 100) return null;

    final combinedDigits = '$wholeDigits$fracDigits';
    var rawBig = BigInt.tryParse(combinedDigits);
    if (rawBig == null) return null;
    if (rawBig == BigInt.zero) {
      return zero;
    }
    if (sign < 0) {
      rawBig = -rawBig;
    }

    // Effective scale = fracDigits.length - exp
    var effectiveScale = fracDigits.length - exp;
    if (effectiveScale < 0) {
      rawBig = rawBig * _pow10(-effectiveScale);
      effectiveScale = 0;
    }

    return _normalize(rawBig, effectiveScale);
  }

  /// Giải thuật chuẩn hóa bậc thập phân: chia liên tiếp `value` cho `10` và giảm `scale` chừng nào `scale > 0` và chữ số tận cùng vẫn bằng `0`.
  static ExactDecimal _normalize(BigInt value, int scale) {
    if (value == BigInt.zero) return zero;
    var v = value;
    var s = scale;
    final ten = BigInt.from(10);
    while (s > 0 && v.remainder(ten) == BigInt.zero) {
      v = v ~/ ten;
      s--;
    }
    return ExactDecimal._(v, s);
  }

  static BigInt _pow10(int exponent) {
    if (exponent <= 0) return BigInt.one;
    return BigInt.from(10).pow(exponent);
  }

  /// Phép nhân chính xác hai số `ExactDecimal` theo công thức `(v1 * v2) * 10^(-(s1 + s2))` rồi chuẩn hóa bậc thập phân.
  ExactDecimal operator *(ExactDecimal other) {
    if (isZero || other.isZero) return zero;
    return _normalize(
      unscaledValue * other.unscaledValue,
      scale + other.scale,
    );
  }

  /// Rounds this decimal **once** to [fractionDigits] using symmetric half-up
  /// (`0.5 -> 1`, `-0.5 -> -1`) and returns the scaled integer at [fractionDigits].
  /// Giải thuật làm tròn đối xứng `HALF_UP` một bước duy nhất (`0.5 -> 1`, `-0.5 -> -1`) về số đơn vị nguyên ở bậc `fractionDigits`:
  /// 1. Nếu `scale <= fractionDigits`: nhân bù `10^(fractionDigits - scale)` để dịch sang đơn vị đích mà không mất độ chính xác.
  /// 2. Nếu `scale > fractionDigits`: đặt `divisor = 10^(scale - fractionDigits)`, tách thương nguyên `quotient = |unscaledValue| ~/ divisor` và phần dư `remainder = |unscaledValue| % divisor`.
  /// 3. Kiểm tra điều kiện nửa lên không dùng số thực: nếu `remainder * 2 >= divisor` thì cộng thêm `1` vào `quotient`, sau đó khôi phục dấu âm ban đầu.
  BigInt roundHalfUpToScaledUnits(int fractionDigits) {
    assert(fractionDigits >= 0);
    if (isZero) return BigInt.zero;

    if (scale <= fractionDigits) {
      return unscaledValue * _pow10(fractionDigits - scale);
    }

    final dropDigits = scale - fractionDigits;
    final divisor = _pow10(dropDigits);
    final absVal = unscaledValue.abs();
    var quotient = absVal ~/ divisor;
    final remainder = absVal.remainder(divisor);
    if (remainder * BigInt.two >= divisor) {
      quotient += BigInt.one;
    }
    return isNegative ? -quotient : quotient;
  }

  /// Renders canonical plain decimal string without scientific notation (e.g. `"0.000038813"`).
  /// Xuất chuỗi số thập phân thuần túy dạng chính tắc không dùng ký hiệu khoa học (ví dụ `"0.000038813"`), tự động đệm chữ số `0` ở đầu nếu `digits.length <= scale`.
  String toPlainDecimalString() {
    if (isZero) return '0';
    final signPrefix = isNegative ? '-' : '';
    final digits = unscaledValue.abs().toString();
    if (scale == 0) {
      return '$signPrefix$digits';
    }
    if (digits.length <= scale) {
      final padded = digits.padLeft(scale, '0');
      return '${signPrefix}0.$padded';
    }
    final splitAt = digits.length - scale;
    final whole = digits.substring(0, splitAt);
    final frac = digits.substring(splitAt);
    return '$signPrefix$whole.$frac';
  }

  /// So sánh thứ tự hai số `ExactDecimal` bằng cách quy đồng về bậc thập phân lớn hơn `max(scale, other.scale)` trên `BigInt`.
  @override
  int compareTo(ExactDecimal other) {
    final maxScale = scale > other.scale ? scale : other.scale;
    final left = unscaledValue * _pow10(maxScale - scale);
    final right = other.unscaledValue * _pow10(maxScale - other.scale);
    return left.compareTo(right);
  }

  @override
  bool operator ==(Object other) =>
      other is ExactDecimal && compareTo(other) == 0;

  @override
  int get hashCode => toPlainDecimalString().hashCode;
}

/// Output of converting an authoritative integer VND amount into a display currency.
/// Kết quả quy đổi từ số tiền nguyên chuẩn `VND` sang đơn vị tiền tệ hiển thị kèm siêu dữ liệu trạng thái tỷ giá.
class ConvertedMoney {
  final int originalAmountVnd;
  final AppCurrency displayedCurrency;
  final AppCurrency requestedCurrency;
  final ExactDecimal exactAmount;
  final String? rateSource;
  final DateTime? rateUpdatedAt;
  final bool isApproximate;
  final bool isUsingStaleRate;
  final bool didFallbackToVnd;

  const ConvertedMoney({
    required this.originalAmountVnd,
    required this.displayedCurrency,
    required this.requestedCurrency,
    required this.exactAmount,
    this.rateSource,
    this.rateUpdatedAt,
    required this.isApproximate,
    required this.isUsingStaleRate,
    required this.didFallbackToVnd,
  });
}

/// Pure conversion engine: `displayAmount = Decimal(amountVnd) * Decimal(rate[targetCurrency])`.
///
/// Never mutates source VND integers and never converts foreign currency back to VND.
/// Bộ máy quy đổi tiền tệ thuần hàm theo công thức `displayAmount = Decimal(amountVnd) * Decimal(rate[targetCurrency])`.
///
/// Đảm bảo nguyên tắc bất biến nguồn sự thật: không bao giờ biến đổi số nguyên `VND` gốc và không bao giờ quy đổi ngược ngoại tệ về `VND`.
abstract final class MoneyConverter {
  /// Giải thuật quy đổi tiền tệ hiển thị từ `VND` sang `targetCurrency`:
  /// 1. Đường đi trực tiếp cho `VND`: Nếu `targetCurrency == AppCurrency.vnd`, giữ nguyên giá trị `ExactDecimal.fromInt(amountVnd)` với `isApproximate = false` và `didFallbackToVnd = false`.
  /// 2. Kiểm tra tính khả dụng của bản chụp tỷ giá tại thời điểm `evalNow`: Nếu thiếu `snapshot` hoặc tỷ giá đã quá hạn 7 ngày (`isExpiredAt`), tự động quay lui an toàn về `VND` và bật cờ `didFallbackToVnd = true`.
  /// 3. Đọc hệ số tỷ giá đích từ `snapshot` qua `ExactDecimal.tryParse`; nếu không hợp lệ hoặc `<= 0` thì quay lui an toàn về `VND`.
  /// 4. Thực hiện phép nhân thập phân chính xác `ExactDecimal.fromInt(amountVnd) * rateDec`, đánh dấu giá trị xấp xỉ (`isApproximate = amountVnd != 0`) và ghi nhận trạng thái tỷ giá cũ (`isUsingStaleRate`).
  static ConvertedMoney convert({
    required int amountVnd,
    required AppCurrency targetCurrency,
    ExchangeRateSnapshot? snapshot,
    DateTime? now,
  }) {
    if (targetCurrency == AppCurrency.vnd) {
      return ConvertedMoney(
        originalAmountVnd: amountVnd,
        displayedCurrency: AppCurrency.vnd,
        requestedCurrency: AppCurrency.vnd,
        exactAmount: ExactDecimal.fromInt(amountVnd),
        isApproximate: false,
        isUsingStaleRate: false,
        didFallbackToVnd: false,
      );
    }

    final evalNow = (now ?? DateTime.now()).toUtc();
    if (snapshot == null || snapshot.isExpiredAt(evalNow)) {
      return ConvertedMoney(
        originalAmountVnd: amountVnd,
        displayedCurrency: AppCurrency.vnd,
        requestedCurrency: targetCurrency,
        exactAmount: ExactDecimal.fromInt(amountVnd),
        isApproximate: false,
        isUsingStaleRate: false,
        didFallbackToVnd: true,
      );
    }

    final rateDec = ExactDecimal.tryParse(
      snapshot.rateDecimalFor(targetCurrency),
    );
    if (rateDec == null || !rateDec.isStrictlyPositive) {
      return ConvertedMoney(
        originalAmountVnd: amountVnd,
        displayedCurrency: AppCurrency.vnd,
        requestedCurrency: targetCurrency,
        exactAmount: ExactDecimal.fromInt(amountVnd),
        isApproximate: false,
        isUsingStaleRate: false,
        didFallbackToVnd: true,
      );
    }

    final convertedExact = ExactDecimal.fromInt(amountVnd) * rateDec;
    return ConvertedMoney(
      originalAmountVnd: amountVnd,
      displayedCurrency: targetCurrency,
      requestedCurrency: targetCurrency,
      exactAmount: convertedExact,
      rateSource: snapshot.source,
      rateUpdatedAt: snapshot.sourceUpdatedAt,
      isApproximate: amountVnd != 0,
      isUsingStaleRate: snapshot.isStaleAt(evalNow),
      didFallbackToVnd: false,
    );
  }
}
