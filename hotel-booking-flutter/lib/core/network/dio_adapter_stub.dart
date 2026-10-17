import 'package:dio/dio.dart';

void configurePlatformDio(Dio dio) {
  // On native IO platforms (Android, iOS, Desktop), Dio uses IOHttpClientAdapter by default,
  // and SecureStorageService persists the refreshToken cookie securely in Keychain/Keystore.
}
