/// Supported display currencies for Guest screens.
///
/// Business & settlement source of truth ALWAYS remains [AppCurrency.vnd].
enum AppCurrency {
  vnd(code: 'VND', symbol: '₫'),
  usd(code: 'USD', symbol: r'$'),
  krw(code: 'KRW', symbol: '₩');

  final String code;
  final String symbol;

  const AppCurrency({
    required this.code,
    required this.symbol,
  });

  bool get isForeign => this != AppCurrency.vnd;

  /// Maps UI language code (`vi`, `en`, `ko`) to its default display currency.
  /// Unknown or empty locale codes always default safely to [AppCurrency.vnd].
  static AppCurrency defaultForLocale(String? rawLocaleCode) {
    if (rawLocaleCode == null || rawLocaleCode.trim().isEmpty) {
      return AppCurrency.vnd;
    }
    final primary =
        rawLocaleCode.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    switch (primary) {
      case 'en':
        return AppCurrency.usd;
      case 'ko':
        return AppCurrency.krw;
      case 'vi':
      default:
        return AppCurrency.vnd;
    }
  }

  /// Parses an ISO 4217 currency code (`VND`, `USD`, `KRW`) case-insensitively.
  static AppCurrency? fromCodeOrNull(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    switch (rawCode.trim().toUpperCase()) {
      case 'VND':
        return AppCurrency.vnd;
      case 'USD':
        return AppCurrency.usd;
      case 'KRW':
        return AppCurrency.krw;
      default:
        return null;
    }
  }
}
