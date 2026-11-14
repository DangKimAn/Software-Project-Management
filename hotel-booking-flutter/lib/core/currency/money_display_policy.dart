import 'app_currency.dart';

/// UI surfaces where monetary values are rendered, each with explicit rounding
/// and currency eligibility rules (Section IV.5 of `tiente.md`).
/// Phân loại các bề mặt giao diện hiển thị giá tiền với quy tắc làm tròn và phạm vi cho phép ngoại tệ riêng biệt.
enum MoneyDisplayContext {
  /// Villa cards on Home / Search / Favorites: integer for VND, USD, KRW.
  villaCard,

  /// Map pin / marker badges: compact for VND, USD, KRW.
  mapMarker,

  /// Small calendar cells: compact or integer.
  priceCalendar,

  /// Nightly price breakdown & quote rows: integer for VND/KRW, 2 decimals for USD.
  priceDetail,

  /// Subtotal, surcharges, cleaning/service fees, discounts: integer for VND/KRW, 2 decimals for USD.
  breakdown,

  /// Reference foreign total shown alongside authoritative VND at Checkout:
  /// 2 decimals for USD, integer for KRW.
  checkoutReference,

  /// Authoritative settlement total at Checkout / Payment CTA / Payment Receipt:
  /// STRICTLY exact VND only — never converts to USD or KRW.
  checkoutPayableVnd,

  /// Host & Admin portals (pricing editors, payouts, revenue reports):
  /// STRICTLY exact VND only — never converts to USD or KRW.
  hostOrAdmin,
}

/// Chính sách kiểm soát quyền quy đổi ngoại tệ, số chữ số thập phân và chế độ rút gọn theo từng `MoneyDisplayContext`.
abstract final class MoneyDisplayPolicy {
  /// Returns `true` if foreign currency conversion is permitted in [context].
  /// Trả về `true` nếu ngữ cảnh `context` cho phép hiển thị ngoại tệ tham chiếu (cấm tuyệt đối tại `checkoutPayableVnd` và `hostOrAdmin`).
  static bool allowsForeignCurrency(MoneyDisplayContext context) {
    return context != MoneyDisplayContext.hostOrAdmin &&
        context != MoneyDisplayContext.checkoutPayableVnd;
  }

  /// Returns the target decimal places for rounding once at the final display layer.
  /// Xác định số chữ số phần thập phân cần làm tròn ở bước hiển thị cuối cùng (`0` cho `VND`/`KRW`; `2` cho bảng chi tiết giá `USD` và `0` cho thẻ/bản đồ `USD`).
  static int decimalDigitsFor(
    AppCurrency currency,
    MoneyDisplayContext context,
  ) {
    switch (currency) {
      case AppCurrency.vnd:
        return 0;
      case AppCurrency.krw:
        return 0;
      case AppCurrency.usd:
        switch (context) {
          case MoneyDisplayContext.priceDetail:
          case MoneyDisplayContext.breakdown:
          case MoneyDisplayContext.checkoutReference:
            return 2;
          case MoneyDisplayContext.villaCard:
          case MoneyDisplayContext.mapMarker:
          case MoneyDisplayContext.priceCalendar:
          case MoneyDisplayContext.checkoutPayableVnd:
          case MoneyDisplayContext.hostOrAdmin:
            return 0;
        }
    }
  }

  /// Returns `true` when compact notation (`3.5M ₫`, `$1.2K`, `₩182K`) is preferred.
  /// Trả về `true` khi ngữ cảnh ưu tiên ký hiệu rút gọn (`3.5M ₫`, `$1.2K`, `₩182K`), áp dụng cho ghim bản đồ `mapMarker`.
  static bool usesCompactFormat(MoneyDisplayContext context) {
    return context == MoneyDisplayContext.mapMarker;
  }
}
