/// Tập hợp hằng số cấu hình toàn cục về định danh thương hiệu, thời gian chờ mạng, khóa lưu trữ và quy chuẩn bố cục.
///
/// Đồng bộ các ngưỡng nghiệp vụ cốt lõi như múi giờ `Asia/Ho_Chi_Minh`, chiều cao tối đa vùng cuộn bảng giá theo đêm
/// (`220.0` trên điện thoại, `248.0` trên máy tính bảng) và diện tích vùng chạm trợ năng tối thiểu (`48.0` dp).
abstract final class AppConstants {
  static const appName = 'The Palm Villa';
  static const appTagline = 'Biệt thự nghỉ dưỡng Vũng Tàu';

  // Network timeouts in milliseconds
  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 15);
  static const sendTimeout = Duration(seconds: 15);

  // Storage Keys
  static const storageLocaleKey = 'app_user_locale';
  static const storageCurrencyPreferenceKey = 'app_user_currency_preference_v1';
  static const storageExchangeRateSnapshotKey = 'app_fx_rate_snapshot_v1';
  static const storageFavoritesKey = 'app_saved_favorites';
  static const storageAuthTokenKey = 'app_secure_auth_token';
  static const storageRefreshCookieKey = 'app_secure_refresh_cookie';
  static const storageRefreshTokenKey = 'app_secure_refresh_token';

  // Default Business Settings
  static const defaultTimeZone = 'Asia/Ho_Chi_Minh';
  static const minStayNights = 1;
  static const maxGuestsDefault = 30;

  // Max height for nightly price breakdown inside villa detail screen
  // (Prevents sticky CTA from being pushed off-screen on phones)
  static const maxPriceBreakdownHeightPhone = 220.0;
  static const maxPriceBreakdownHeightTablet = 248.0;

  // Touch Target Minimum Dimensions (Accessibility)
  static const minTouchTargetSize = 48.0;
}
