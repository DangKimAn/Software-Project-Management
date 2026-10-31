import '../network/dio_client.dart';

abstract class DeviceTokenRepository {
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appFlavor,
  });

  Future<void> unregisterToken({
    required String token,
  });
}

class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  final DioClient _client;

  const DeviceTokenRepositoryImpl(this._client);

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appFlavor,
  }) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;

    await _client.dio.post<Map<String, dynamic>>(
      '/api/notifications/devices',
      data: <String, dynamic>{
        'token': trimmed,
        'platform': platform,
        if (appFlavor != null && appFlavor.trim().isNotEmpty)
          'appFlavor': appFlavor.trim(),
      },
    );
  }

  @override
  Future<void> unregisterToken({
    required String token,
  }) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;

    await _client.dio.post<Map<String, dynamic>>(
      '/api/notifications/devices/unregister',
      data: <String, dynamic>{
        'token': trimmed,
      },
    );
  }
}

