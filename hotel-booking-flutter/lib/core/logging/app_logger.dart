import 'dart:developer' as developer;
import '../config/app_config.dart';

abstract final class AppLogger {
  static void d(String message, {String tag = 'MinhThanhVilla'}) {
    if (AppConfig.enableLogging) {
      developer.log('[DEBUG] $message', name: tag);
    }
  }

  static void i(String message, {String tag = 'MinhThanhVilla'}) {
    if (AppConfig.enableLogging) {
      developer.log('[INFO] $message', name: tag);
    }
  }

  static void w(String message, {String tag = 'MinhThanhVilla'}) {
    developer.log('[WARN] $message', name: tag);
  }

  static void e(
    String message, {
    String tag = 'MinhThanhVilla',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[ERROR] $message',
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
