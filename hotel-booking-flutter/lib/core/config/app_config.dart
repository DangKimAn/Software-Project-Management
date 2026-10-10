/// Application configuration loaded securely at build time via `--dart-define-from-file`.
///
/// NOTE: Dart define flags are compiled into the binary and can be inspected.
/// Do NOT store sensitive private keys, database passwords, or secret tokens here.
final class AppConfig {
  AppConfig._();

  static const environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev-api.minhthanhvilla.com',
  );
  static const hotlineNumber = String.fromEnvironment(
    'HOTLINE_NUMBER',
    defaultValue: '0901234567',
  );
  static const zaloOaUrl = String.fromEnvironment(
    'ZALO_OA_URL',
    defaultValue: 'https://zalo.me/0901234567',
  );
  static const enableLogging =
      bool.fromEnvironment('ENABLE_LOGGING', defaultValue: true);

  /// Validates environment consistency and security at startup.
  static void validate({required String expectedEnvironment}) {
    if (environment != expectedEnvironment) {
      throw StateError(
        'Build environment mismatch: Expected "$expectedEnvironment" but received "$environment".',
      );
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('Invalid API_BASE_URL "$apiBaseUrl".');
    }
    // Mobile development requires http for 10.0.2.2 and localhost; Staging & Prod must use HTTPS
    if (!isDevelopment && uri.scheme != 'https') {
      throw StateError(
        'Invalid API_BASE_URL "$apiBaseUrl": Production and Staging environments MUST use secure HTTPS.',
      );
    }
  }

  static bool get isProduction => environment == 'prod';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'dev';
}
