import 'dart:developer' as developer;
import '../config/app_config.dart';

abstract final class AppLogger {
  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );
  static final RegExp _cookieTokenPattern = RegExp(
    r'(refreshToken|auth_token)\s*=\s*[^;\s,]+',
    caseSensitive: false,
  );
  static final RegExp _jsonSecretPattern = RegExp(
    r'"(accessToken|refreshToken|token|idToken|password|newPassword)"\s*:\s*"[^"]*"',
    caseSensitive: false,
  );

  /// Redacts any tokens, cookies, or secrets before writing to debug logs.
  static String sanitize(String message) {
    return message
        .replaceAll(_bearerPattern, 'Bearer [REDACTED]')
        .replaceAllMapped(
          _cookieTokenPattern,
          (m) => '${m.group(1)}=[REDACTED]',
        )
        .replaceAllMapped(
          _jsonSecretPattern,
          (m) => '"${m.group(1)}":"[REDACTED]"',
        );
  }

  static void d(String message, {String tag = 'MinhThanhVilla'}) {
    if (AppConfig.enableLogging) {
      developer.log('[DEBUG] ${sanitize(message)}', name: tag);
    }
  }

  static void i(String message, {String tag = 'MinhThanhVilla'}) {
    if (AppConfig.enableLogging) {
      developer.log('[INFO] ${sanitize(message)}', name: tag);
    }
  }

  static void w(String message, {String tag = 'MinhThanhVilla'}) {
    developer.log('[WARN] ${sanitize(message)}', name: tag);
  }

  static void e(
    String message, {
    String tag = 'MinhThanhVilla',
    Object? error,
    StackTrace? stackTrace,
  }) {
    final safeError = error != null ? sanitize(error.toString()) : null;
    developer.log(
      '[ERROR] ${sanitize(message)}',
      name: tag,
      error: safeError,
      stackTrace: stackTrace,
    );
  }
}
