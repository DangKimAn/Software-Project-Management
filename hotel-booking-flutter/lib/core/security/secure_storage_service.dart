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

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
