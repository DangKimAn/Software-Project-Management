import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_formatters.dart';
import 'app_currency.dart';
import 'exchange_rate_snapshot.dart';
import 'money_converter.dart';
import 'money_display_policy.dart';

/// Rich formatted output for Guest UI rendering and accessibility semantics.
class MoneyDisplayResult {
  final String formatted;
  final AppCurrency displayedCurrency;
  final AppCurrency requestedCurrency;
  final bool isApproximate;
  final bool isUsingStaleRate;
  final bool didFallbackToVnd;
  final bool isSubUnitMinimum;

  const MoneyDisplayResult({
    required this.formatted,
    required this.displayedCurrency,
    required this.requestedCurrency,
    required this.isApproximate,
    required this.isUsingStaleRate,
    required this.didFallbackToVnd,
    this.isSubUnitMinimum = false,
  });

  bool get isForeignDisplayed => displayedCurrency != AppCurrency.vnd;
}

/// Centralized, immutable money formatter bound to active locale, effective currency,
/// and verified [ExchangeRateSnapshot].
///
/// Rounds **once** at the final string formatting step using exact [BigInt] decimal arithmetic.
class MoneyFormatter {
  final String localeCode;
  final AppCurrency effectiveCurrency;
  final ExchangeRateSnapshot? snapshot;
  final bool featureEnabled;
  final DateTime Function()? _clock;

  const MoneyFormatter({
    this.localeCode = 'vi',
    this.effectiveCurrency = AppCurrency.vnd,
    this.snapshot,
    this.featureEnabled = true,
    DateTime Function()? clock,
  }) : _clock = clock;

  DateTime get _now {
    final clock = _clock;
    return (clock != null ? clock() : DateTime.now()).toUtc();
  }

  AppLocalizations get l10n => LocaleFormatters.resolveL10n(localeCode);

  /// Returns a copy pinned to [frozenSnapshot] so Checkout displays stay stable
  /// throughout a guest's payment session (`FX-24`).
  MoneyFormatter withFrozenSnapshot(ExchangeRateSnapshot? frozenSnapshot) {
    return MoneyFormatter(
      localeCode: localeCode,
      effectiveCurrency: effectiveCurrency,
      snapshot: frozenSnapshot,
      featureEnabled: featureEnabled,
      clock: _clock,
    );
  }

  /// True when the user requested USD/KRW, feature flag is enabled, and no usable
  /// snapshot is available (missing or expired > 7 days).
  bool get isFallingBackToVnd {
    if (!featureEnabled || effectiveCurrency == AppCurrency.vnd) {
      return false;
    }
    return snapshot == null || snapshot!.isExpiredAt(_now);
  }

  /// True when the active foreign rate is older than 48h (up to 7d) or flagged stale.
  bool get isUsingStaleRate {
    if (!featureEnabled || effectiveCurrency == AppCurrency.vnd) {
      return false;
    }
    if (snapshot == null || snapshot!.isExpiredAt(_now)) {
      return false;
    }
    return snapshot!.isStaleAt(_now);
  }

  /// Formats an authoritative integer VND amount strictly in exact VND (`3.500.000 ₫`).
  /// Used for Checkout payable total, Payment CTA, Payment Result receipt, and Host/Admin.
  static String formatExactVndStatic(int amountVnd, {bool withCode = false}) {
    final isNeg = amountVnd < 0;
    final grouped = _groupDigits(BigInt.from(amountVnd).abs().toString(), '.');
    final sign = isNeg ? '-' : '';
    return withCode ? '$sign$grouped VND' : '$sign$grouped ₫';
  }

  String formatExactVnd(int? amountVnd, {bool withCode = false}) {
    if (amountVnd == null) {
      return l10n.contactForPrice;
    }
    return formatExactVndStatic(amountVnd, withCode: withCode);
  }

  /// Core conversion + single-step rounding formatter.
  MoneyDisplayResult format(
    int amountVnd, {
    MoneyDisplayContext context = MoneyDisplayContext.villaCard,
    bool includeApproximatePrefix = true,
  }) {
    final targetCurrency =
        (!featureEnabled || !MoneyDisplayPolicy.allowsForeignCurrency(context))
            ? AppCurrency.vnd
            : effectiveCurrency;

    final converted = MoneyConverter.convert(
      amountVnd: amountVnd,
      targetCurrency: targetCurrency,
      snapshot: snapshot,
      now: _now,
    );

    if (converted.displayedCurrency == AppCurrency.vnd) {
      final text = MoneyDisplayPolicy.usesCompactFormat(context)
          ? _formatCompactVnd(amountVnd)
          : formatExactVndStatic(amountVnd);
      return MoneyDisplayResult(
        formatted: text,
        displayedCurrency: AppCurrency.vnd,
        requestedCurrency: targetCurrency,
        isApproximate: false,
        isUsingStaleRate: false,
        didFallbackToVnd: converted.didFallbackToVnd,
      );
    }

    if (MoneyDisplayPolicy.usesCompactFormat(context)) {
      final compactText = _formatCompactForeign(
        converted,
        includeApproximatePrefix: includeApproximatePrefix,
      );
      return MoneyDisplayResult(
        formatted: compactText.text,
        displayedCurrency: converted.displayedCurrency,
        requestedCurrency: targetCurrency,
        isApproximate: converted.isApproximate,
        isUsingStaleRate: converted.isUsingStaleRate,
        didFallbackToVnd: false,
        isSubUnitMinimum: compactText.isSubUnit,
      );
    }

    final decimals = MoneyDisplayPolicy.decimalDigitsFor(
      converted.displayedCurrency,
      context,
    );
    final scaled = converted.exactAmount.roundHalfUpToScaledUnits(decimals);

    // FX-27: Positive (or negative) non-zero VND that rounds to 0 in foreign currency
    // must NEVER render as "$0" / "₩0" / "Free".
    if (amountVnd != 0 && scaled == BigInt.zero) {
      final minUnit = decimals == 2 ? '0.01' : '1';
      final sign = amountVnd < 0 ? '-' : '';
      final sym = converted.displayedCurrency.symbol;
      return MoneyDisplayResult(
        formatted: '$sign< $sym$minUnit',
        displayedCurrency: converted.displayedCurrency,
        requestedCurrency: targetCurrency,
        isApproximate: true,
        isUsingStaleRate: converted.isUsingStaleRate,
        didFallbackToVnd: false,
        isSubUnitMinimum: true,
      );
    }

    final formattedUnsigned = _formatScaledForeignUnsigned(
      scaled.abs(),
      decimals: decimals,
      symbol: converted.displayedCurrency.symbol,
    );
    final sign = scaled.isNegative ? '-' : '';
    final approxPrefix =
        (includeApproximatePrefix && converted.isApproximate) ? '≈ ' : '';

    return MoneyDisplayResult(
      formatted: '$sign$approxPrefix$formattedUnsigned',
      displayedCurrency: converted.displayedCurrency,
      requestedCurrency: targetCurrency,
      isApproximate: converted.isApproximate,
      isUsingStaleRate: converted.isUsingStaleRate,
      didFallbackToVnd: false,
    );
  }

  /// Formats a positive price or returns localized `contactForPrice` when `null` or `<= 0`.
  String formatPriceOrContact(
    int? amountVnd, {
    MoneyDisplayContext context = MoneyDisplayContext.villaCard,
    bool includeApproximatePrefix = true,
  }) {
    if (amountVnd == null || amountVnd <= 0) {
      return l10n.contactForPrice;
    }
    return format(
      amountVnd,
      context: context,
      includeApproximatePrefix: includeApproximatePrefix,
    ).formatted;
  }

  /// Formats a discount/deduction line (always prefixed with `-` nicely).
  String formatDiscount(
    int positiveDiscountVnd, {
    MoneyDisplayContext context = MoneyDisplayContext.breakdown,
    bool includeApproximatePrefix = true,
  }) {
    final absVnd = positiveDiscountVnd.abs();
    if (absVnd == 0) {
      return format(0, context: context, includeApproximatePrefix: false)
          .formatted;
    }
    return format(
      -absVnd,
      context: context,
      includeApproximatePrefix: includeApproximatePrefix,
    ).formatted;
  }

  /// Formats `"Từ 3.500.000 ₫ / đêm"` / `"From ≈ $136 / night"` / `"1박당 ≈ ₩181,552부터"`.
  String formatPerNightFrom(int? amountVnd) {
    if (amountVnd == null || amountVnd <= 0) {
      return l10n.contactForPrice;
    }
    final priceStr = format(
      amountVnd,
      context: MoneyDisplayContext.villaCard,
    ).formatted;
    return l10n.priceFrom(priceStr);
  }

  /// Formats Saturday rate label (`"Thứ 7: ..."` / `"Sat: ..."` / `"토요일: ..."`).
  String? formatSaturdayRate(int? amountVnd) {
    if (amountVnd == null || amountVnd <= 0) {
      return null;
    }
    final priceStr = format(
      amountVnd,
      context: MoneyDisplayContext.villaCard,
    ).formatted;
    return l10n.saturdayPrice(priceStr);
  }

  /// Formats compact amount for map markers or compact calendar badges.
  String formatCompact(int? amountVnd) {
    if (amountVnd == null || amountVnd <= 0) {
      return format(0, context: MoneyDisplayContext.mapMarker).formatted;
    }
    return format(amountVnd, context: MoneyDisplayContext.mapMarker).formatted;
  }

  static String _formatScaledForeignUnsigned(
    BigInt absScaled, {
    required int decimals,
    required String symbol,
  }) {
    if (decimals == 0) {
      final grouped = _groupDigits(absScaled.toString(), ',');
      return '$symbol$grouped';
    }

    final rawDigits = absScaled.toString().padLeft(decimals + 1, '0');
    final splitAt = rawDigits.length - decimals;
    final wholeGrouped = _groupDigits(rawDigits.substring(0, splitAt), ',');
    final fraction = rawDigits.substring(splitAt);
    return '$symbol$wholeGrouped.$fraction';
  }

  static String _formatCompactVnd(int amountVnd) {
    if (amountVnd == 0) return '0 ₫';
    final sign = amountVnd < 0 ? '-' : '';
    final v = amountVnd.abs().toDouble();
    if (v >= 1000000000) {
      return '$sign${_trimTrailingZero((v / 1000000000).toStringAsFixed(1))}B ₫';
    }
    if (v >= 1000000) {
      return '$sign${_trimTrailingZero((v / 1000000).toStringAsFixed(1))}M ₫';
    }
    if (v >= 1000) {
      return '$sign${(v / 1000).round()}K ₫';
    }
    return '$sign${amountVnd.abs()} ₫';
  }

  static ({String text, bool isSubUnit}) _formatCompactForeign(
    ConvertedMoney converted, {
    required bool includeApproximatePrefix,
  }) {
    final roundedInt = converted.exactAmount.roundHalfUpToScaledUnits(0);
    final sym = converted.displayedCurrency.symbol;
    if (converted.originalAmountVnd != 0 && roundedInt == BigInt.zero) {
      final sign = converted.originalAmountVnd < 0 ? '-' : '';
      return (text: '$sign< ${sym}1', isSubUnit: true);
    }

    final sign = roundedInt.isNegative ? '-' : '';
    final absInt = roundedInt.abs().toInt();
    final approx =
        (includeApproximatePrefix && converted.isApproximate) ? '≈ ' : '';

    if (absInt >= 1000000) {
      final m = _trimTrailingZero((absInt / 1000000).toStringAsFixed(1));
      return (text: '$sign$approx$sym${m}M', isSubUnit: false);
    }
    if (absInt >= 1000) {
      final k = _trimTrailingZero((absInt / 1000).toStringAsFixed(1));
      return (text: '$sign$approx$sym${k}K', isSubUnit: false);
    }
    return (text: '$sign$approx$sym$absInt', isSubUnit: false);
  }

  static String _trimTrailingZero(String decimalText) {
    if (decimalText.endsWith('.0')) {
      return decimalText.substring(0, decimalText.length - 2);
    }
    return decimalText;
  }

  static String _groupDigits(String digits, String separator) {
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final firstGroupLen = digits.length % 3;
    if (firstGroupLen > 0) {
      buffer.write(digits.substring(0, firstGroupLen));
    }
    for (var i = firstGroupLen; i < digits.length; i += 3) {
      if (buffer.isNotEmpty) buffer.write(separator);
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
