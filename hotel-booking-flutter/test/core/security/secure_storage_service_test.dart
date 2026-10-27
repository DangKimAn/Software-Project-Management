import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecureStorageService storage;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const SecureStorageService();
  });

  test(
      'secure session survives service recreation and logout clears all credentials',
      () async {
    await storage.saveAuthToken('test-access');
    await storage.saveRefreshCookie('test-cookie');
    await storage.saveRefreshToken('test-refresh');
    const restarted = SecureStorageService();
    expect(await restarted.getAuthToken(), 'test-access');
    expect(await restarted.getRefreshCookie(), 'test-cookie');
    await restarted.clearAuthSession();
    expect(await storage.getAuthToken(), isNull);
    expect(await storage.getRefreshCookie(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('Expires deletion clears both refresh credentials', () async {
    await storage.saveRefreshCookie('old');
    await storage.saveRefreshToken('old');
    await storage.syncRefreshCookieFromHeaders([
      'refreshToken=obsolete; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly',
    ], now: DateTime.utc(2026, 10, 27));
    expect(await storage.getRefreshCookie(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('Max-Age takes precedence over old Expires', () async {
    await storage.syncRefreshCookieFromHeaders([
      'refreshToken=valid; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=60',
    ], now: DateTime.utc(2026, 10, 27));
    expect(await storage.getRefreshCookie(), 'valid');
  });

  test('Web HttpOnly cookie is managed by browser, never copied to storage',
      () async {
    await storage.syncRefreshCookieFromHeaders([
      'refreshToken=browser-only; HttpOnly',
    ], isWebOverride: true);
    expect(await storage.getRefreshCookie(), isNull);
  });
}
