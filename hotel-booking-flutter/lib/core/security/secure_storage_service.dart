import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  const SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: AppConstants.storageAuthTokenKey, value: token);
  }

  Future<String?> getAuthToken() async {
    return _storage.read(key: AppConstants.storageAuthTokenKey);
  }

  Future<void> deleteAuthToken() async {
    await _storage.delete(key: AppConstants.storageAuthTokenKey);
  }

  Future<bool> hasAuthToken() async {
    final token = await getAuthToken();
    return token != null && token.trim().isNotEmpty;
  }

  /// Stores the raw `refreshToken` cookie value received from `Set-Cookie` on Android/iOS.
  Future<void> saveRefreshCookie(String cookieValue) async {
    final trimmed = cookieValue.trim();
    if (trimmed.isEmpty) {
      await deleteRefreshCookie();
      return;
    }
    await _storage.write(
      key: AppConstants.storageRefreshCookieKey,
      value: trimmed,
    );
  }

  Future<String?> getRefreshCookie() async {
    return _storage.read(key: AppConstants.storageRefreshCookieKey);
  }

  Future<void> deleteRefreshCookie() async {
    await _storage.delete(key: AppConstants.storageRefreshCookieKey);
  }

  Future<bool> hasRefreshCookie() async {
    final cookie = await getRefreshCookie();
    return cookie != null && cookie.trim().isNotEmpty;
  }

  /// Stores an explicit refresh token when provided via body in supported flows.
  Future<void> saveRefreshToken(String refreshToken) async {
    final trimmed = refreshToken.trim();
    if (trimmed.isEmpty) {
      await deleteRefreshToken();
      return;
    }
    await _storage.write(
      key: AppConstants.storageRefreshTokenKey,
      value: trimmed,
    );
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: AppConstants.storageRefreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: AppConstants.storageRefreshTokenKey);
  }

  Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.trim().isNotEmpty;
  }

  /// Clears all authentication & refresh tokens/cookies on logout or session expiration.
  Future<void> clearAuthSession() async {
    await Future.wait([
      deleteAuthToken(),
      deleteRefreshCookie(),
      deleteRefreshToken(),
    ]);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Extracts and securely stores or clears the `refreshToken` cookie from `Set-Cookie`
  /// headers on non-Web platforms (Android/iOS/Desktop).
  ///
  /// On Flutter Web (`kIsWeb`), the browser manages `HttpOnly` cookies directly via
  /// `withCredentials: true`, and JavaScript must never attempt to read `HttpOnly` cookies.
  Future<void> syncRefreshCookieFromHeaders(
    List<String>? setCookieHeaders, {
    bool isWebOverride = kIsWeb,
  }) async {
    if (isWebOverride || setCookieHeaders == null || setCookieHeaders.isEmpty) {
      return;
    }

    for (final rawHeader in setCookieHeaders) {
      final segments = rawHeader
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;

      final nameValue = segments.first;
      final eqIndex = nameValue.indexOf('=');
      if (eqIndex <= 0) continue;

      final cookieName = nameValue.substring(0, eqIndex).trim();
      final cookieValue = nameValue.substring(eqIndex + 1).trim();

      if (cookieName != 'refreshToken' && cookieName != 'refresh_token') {
        continue;
      }

      var isExpired = cookieValue.isEmpty;
      for (final attr in segments.skip(1)) {
        final lower = attr.toLowerCase();
        if (lower.startsWith('max-age=')) {
          final maxAge =
              int.tryParse(lower.substring('max-age='.length).trim());
          if (maxAge != null && maxAge <= 0) {
            isExpired = true;
          }
        }
      }

      if (isExpired) {
        await deleteRefreshCookie();
        await deleteRefreshToken();
      } else {
        await saveRefreshCookie(cookieValue);
      }
    }
  }
}
