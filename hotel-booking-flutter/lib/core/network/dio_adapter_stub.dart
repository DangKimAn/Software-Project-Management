import 'package:dio/dio.dart';

/// Cấu hình bộ điều hợp HTTP mặc định trên nền tảng Native IO (Android, iOS, Desktop), nơi cookie `refreshToken` được quản lý qua `SecureStorageService`.
void configurePlatformDio(Dio dio) {
  // On native IO platforms (Android, iOS, Desktop), Dio uses IOHttpClientAdapter by default,
  // and SecureStorageService persists the refreshToken cookie securely in Keychain/Keystore.
}
