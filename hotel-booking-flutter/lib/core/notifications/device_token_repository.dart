import '../network/dio_client.dart';

/// Giao diện kho dữ liệu quản lý đăng ký và thu hồi mã thông báo đẩy thiết bị (FCM/APNs) với máy chủ.
abstract class DeviceTokenRepository {
  /// Đăng ký mã thông báo đẩy `token` kèm nền tảng `platform` và cấu hình bản dựng `appFlavor`.
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appFlavor,
  });

  /// Hủy đăng ký mã thông báo đẩy `token` khi người dùng đăng xuất khỏi phiên làm việc.
  Future<void> unregisterToken({
    required String token,
  });
}

/// Triển khai `DeviceTokenRepository` giao tiếp với các điểm cuối `/api/notifications/devices`.
class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  final DioClient _client;

  const DeviceTokenRepositoryImpl(this._client);

  /// Giải thuật đăng ký thiết bị nhận thông báo đẩy:
  /// Cắt khoảng trắng `token`, bỏ qua an toàn nếu rỗng, và chỉ đính kèm `appFlavor` khi có giá trị hợp lệ.
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

  /// Giải thuật thu hồi mã thông báo đẩy trên máy chủ khi kết thúc phiên người dùng.
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
