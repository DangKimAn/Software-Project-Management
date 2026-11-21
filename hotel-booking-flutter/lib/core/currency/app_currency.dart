/// Supported display currencies for Guest screens.
///
/// Business & settlement source of truth ALWAYS remains [AppCurrency.vnd].
/// Danh mục các đơn vị tiền tệ hiển thị được hỗ trợ trên giao diện Khách (`VND`, `USD`, `KRW`).
///
/// Nguồn sự thật cho tính giá nghiệp vụ và thanh toán quyết toán luôn cố định là `AppCurrency.vnd`.
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

  /// Trả về `true` nếu đơn vị tiền tệ là ngoại tệ tham chiếu (`USD` hoặc `KRW`), khác với tiền gốc `VND`.
  bool get isForeign => this != AppCurrency.vnd;

  /// Maps UI language code (`vi`, `en`, `ko`) to its default display currency.
  /// Unknown or empty locale codes always default safely to [AppCurrency.vnd].
  /// Giải thuật ánh xạ mã ngôn ngữ giao diện (`vi`, `en`, `ko`) sang đơn vị tiền tệ hiển thị mặc định:
  /// Tách thành phần ngôn ngữ chính trước dấu `-` hoặc `_`, ánh xạ `en -> USD`, `ko -> KRW`, và mặc định an toàn về `VND` cho `vi` hoặc mã không xác định.
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
  /// Phân tích không phân biệt hoa thường mã tiền tệ chuẩn ISO 4217 (`VND`, `USD`, `KRW`), trả về `null` nếu không khớp.
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
