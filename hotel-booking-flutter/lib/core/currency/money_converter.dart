import 'app_currency.dart';
import 'exchange_rate_snapshot.dart';

/// Arbitrary-precision base-10 decimal represented as `unscaledValue * 10^(-scale)`
/// using [BigInt] to eliminate IEEE-754 binary floating-point rounding drift.
class ExactDecimal implements Comparable<ExactDecimal> {
  static final ExactDecimal zero = ExactDecimal._(BigInt.zero, 0);
  static final ExactDecimal one = ExactDecimal._(BigInt.one, 0);

  final BigInt unscaledValue;
  final int scale;

  const ExactDecimal._(this.unscaledValue, this.scale);

  factory ExactDecimal.fromInt(int value) =>
      ExactDecimal._(BigInt.from(value), 0);

  bool get isZero => unscaledValue == BigInt.zero;
  bool get isNegative => unscaledValue.isNegative;
  bool get isStrictlyPositive => unscaledValue > BigInt.zero;

  static ExactDecimal parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid decimal string: "$raw"');
    }
    return parsed;
  }

  /// Parses plain decimal (`"0.000038813"`) or scientific notation (`"3.9e-5"`),
  /// rejecting `NaN`, `Infinity`, empty strings, or malformed input.
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

  ExactDecimal operator *(ExactDecimal other) {
    if (isZero || other.isZero) return zero;
    return _normalize(
      unscaledValue * other.unscaledValue,
      scale + other.scale,
    );
  }

  /// Rounds this decimal **once** to [fractionDigits] using symmetric half-up
  /// (`0.5 -> 1`, `-0.5 -> -1`) and returns the scaled integer at [fractionDigits].
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
abstract final class MoneyConverter {
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
