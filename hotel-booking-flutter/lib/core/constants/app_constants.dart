abstract final class AppConstants {
  static const appName = 'Minh Thanh Villa';
  static const appTagline = 'Biệt thự nghỉ dưỡng Vũng Tàu';

  // Network timeouts in milliseconds
  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 15);
  static const sendTimeout = Duration(seconds: 15);

  // Storage Keys
  static const storageLocaleKey = 'app_user_locale';
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
