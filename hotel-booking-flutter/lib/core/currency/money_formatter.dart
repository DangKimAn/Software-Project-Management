import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_formatters.dart';
import 'app_currency.dart';
import 'exchange_rate_snapshot.dart';
import 'money_converter.dart';
import 'money_display_policy.dart';

/// Rich formatted output for Guest UI rendering and accessibility semantics.
/// Kết quả định dạng tiền tệ giàu ngữ nghĩa phục vụ hiển thị giao diện Khách và trình đọc màn hình (Accessibility).
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
/// Bộ định dạng tiền tệ trung tâm bất biến gắn với ngôn ngữ hiện hành, đơn vị tiền tệ hiệu lực và bản chụp tỷ giá `ExchangeRateSnapshot`.
///
/// Tuân thủ nguyên tắc chỉ làm tròn đúng một lần duy nhất ở bước xuất chuỗi cuối cùng bằng số học `BigInt`.
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
  /// Tạo bản sao `MoneyFormatter` ghim cố định vào `frozenSnapshot` để giữ ổn định số tiền tham chiếu suốt phiên thanh toán Checkout (`FX-24`).
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
  /// Trả về `true` khi khách chọn ngoại tệ (`USD`/`KRW`) nhưng thiếu bản chụp tỷ giá hợp lệ hoặc bản chụp đã hết hạn quá 7 ngày nên phải quay về `VND`.
  bool get isFallingBackToVnd {
    if (!featureEnabled || effectiveCurrency == AppCurrency.vnd) {
      return false;
    }
    return snapshot == null || snapshot!.isExpiredAt(_now);
  }

  /// True when the active foreign rate is older than 48h (up to 7d) or flagged stale.
  /// Trả về `true` khi tỷ giá ngoại tệ đang dùng đã quá 48 giờ (nhưng chưa quá 7 ngày) hoặc bị máy chủ đánh dấu cũ.
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
  /// Định dạng số nguyên `amountVnd` sang chuỗi `VND` chính xác tuyệt đối (ví dụ `3.500.000 ₫` hoặc `3.500.000 VND` khi `withCode = true`).
  /// Bắt buộc sử dụng cho tổng tiền thanh toán thực tế tại Checkout, nút thanh toán, biên lai và cổng Chủ nhà/Quản trị.
  static String formatExactVndStatic(int amountVnd, {bool withCode = false}) {
    final isNeg = amountVnd < 0;
    final grouped = _groupDigits(BigInt.from(amountVnd).abs().toString(), '.');
    final sign = isNeg ? '-' : '';
    return withCode ? '$sign$grouped VND' : '$sign$grouped ₫';
  }

  // CONFLICT-RESOLVED: Hợp nhất CurrencyFormatter (từ core/formatters và core/utils) vào MoneyFormatter để xóa bỏ 2 tệp định dạng VND trùng vai trò.
  // Giải thuật định dạng tiền tệ nguyên dương (Positive Integer VND Grouping):
  // Kiểm tra biên null hoặc <= 0 để trả về chuỗi dự phòng `fallback`, sau đó phân nhóm hàng nghìn bằng dấu chấm dựa trên BigInt.
  /// Định dạng số nguyên dương `VND` hoặc trả về chuỗi `fallback` khi giá trị `null` hoặc `<= 0`.
  static String formatVnd(int? amount, {String fallback = 'Liên hệ báo giá'}) {
    if (amount == null || amount <= 0) {
      return fallback;
    }
    return formatExactVndStatic(amount);
  }

  /// Định dạng `VND` chính xác theo ngôn ngữ hiện hành, trả về nhãn liên hệ báo giá đã bản địa hóa nếu `amountVnd` là `null`.
  String formatExactVnd(int? amountVnd, {bool withCode = false}) {
    if (amountVnd == null) {
      return l10n.contactForPrice;
    }
    return formatExactVndStatic(amountVnd, withCode: withCode);
  }

  /// Core conversion + single-step rounding formatter.
  /// Giải thuật quy đổi và định dạng tiền tệ đa ngữ cảnh với một bước làm tròn duy nhất (`MoneyFormatter.format`):
  /// 1. Xác định đơn vị tiền đích `targetCurrency`: Nếu cờ tính năng tắt hoặc ngữ cảnh `context` cấm ngoại tệ (như `checkoutPayableVnd`, `hostOrAdmin`), cưỡng bức dùng `VND`; ngược lại dùng `effectiveCurrency`.
  /// 2. Gọi `MoneyConverter.convert` để nhận giá trị thập phân chính xác `ExactDecimal` (hoặc trạng thái quay lui về `VND` nếu tỷ giá thiếu/hết hạn).
  /// 3. Nhánh hiển thị `VND`: Chọn giữa định dạng rút gọn `_formatCompactVnd` (cho ghim bản đồ) hoặc định dạng phân nhóm dấu chấm đầy đủ `formatExactVndStatic`.
  /// 4. Nhánh hiển thị ngoại tệ rút gọn (`usesCompactFormat`): Làm tròn đến hàng đơn vị và rút gọn theo hậu tố `K`/`M` qua `_formatCompactForeign`.
  /// 5. Nhánh hiển thị ngoại tệ đầy đủ: Tra số chữ số thập phân đích `decimals` theo `MoneyDisplayPolicy` (`0` cho `KRW` và thẻ villa `USD`; `2` cho bảng chi tiết giá `USD`), sau đó làm tròn `HALF_UP` đúng một lần qua `roundHalfUpToScaledUnits(decimals)`.
  /// 6. Chốt chặn chống hiển thị miễn phí giả tạo (`FX-27`): Nếu `amountVnd != 0` nhưng kết quả sau làm tròn bằng `0`, trả về ngưỡng dưới tối thiểu (`< $0.01` hoặc `< ₩1`) với `isSubUnitMinimum = true`.
  /// 7. Phân nhóm hàng nghìn bằng dấu phẩy và ghép tiền tố xấp xỉ `≈ ` (khi `includeApproximatePrefix && converted.isApproximate`) để xuất chuỗi hoàn chỉnh.
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
  /// Định dạng mức giá nguyên dương theo ngữ cảnh `context`, hoặc trả về chuỗi liên hệ báo giá theo ngôn ngữ hiện hành nếu `null` hay `<= 0`.
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
  /// Định dạng dòng khấu trừ/giảm giá (luôn chuẩn hóa dấu âm `-` đứng trước tiền tố xấp xỉ khi giá trị khác `0`).
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
  /// Định dạng nhãn giá khởi điểm mỗi đêm đã bản địa hóa cho thẻ chỗ nghỉ (hoặc trả về nhãn liên hệ báo giá nếu `<= 0`).
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
  /// Định dạng nhãn phụ thu giá Thứ Bảy trên thẻ chỗ nghỉ, trả về `null` nếu chỗ nghỉ không áp dụng giá riêng ngày Thứ Bảy.
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
  /// Định dạng số tiền rút gọn phục vụ huy hiệu ghim trên bản đồ hoặc ô lịch nhỏ.
  String formatCompact(int? amountVnd) {
    if (amountVnd == null || amountVnd <= 0) {
      return format(0, context: MoneyDisplayContext.mapMarker).formatted;
    }
    return format(amountVnd, context: MoneyDisplayContext.mapMarker).formatted;
  }

  /// Giải thuật định dạng số nguyên không dấu đã nhân bậc thập phân `absScaled` sang chuỗi ngoại tệ có dấu phẩy phân cách hàng nghìn (ví dụ `$1,234.56` hoặc `₩181,552`).
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

  /// Giải thuật rút gọn số tiền `VND` theo bậc tỷ (`B`), triệu (`M`) và nghìn (`K`) cho nhãn ghim bản đồ.
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

  /// Giải thuật rút gọn ngoại tệ đã quy đổi theo bậc triệu (`M`) và nghìn (`K`), đồng thời bảo toàn chốt chặn dưới `< 1` đơn vị khi `originalAmountVnd != 0`.
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

  /// Giải thuật phân nhóm chuỗi chữ số hàng nghìn từ phải sang trái bằng ký tự phân tách `separator` (`.` cho `VND`, `,` cho `USD`/`KRW`).
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
