import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/entities/support_page_models.dart';

/// Giao diện kho dữ liệu gửi báo cáo / khiếu nại và tra cứu lịch sử phản ánh của người dùng.
abstract class SupportRepository {
  Future<UserSupportReport> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  });

  Future<List<UserSupportReport>> getMyReports();
}

class SupportRepositoryImpl implements SupportRepository {
  final DioClient _client;

  const SupportRepositoryImpl(this._client);

  static const Set<String> allowedTargetTypes = {
    'booking',
    'listing',
    'user',
    'review',
  };

  // Giải thuật kiểm tra hợp lệ đầu vào và gửi báo cáo phản ánh lên `/api/reports`:
  // 1. Xác thực `targetType` thuộc tập hợp cho phép của Backend (`booking`, `listing`, `user`, `review`),
  //    `targetId >= 1` và lý do phản ánh nằm trong giới hạn `1..255` ký tự.
  // 2. Gửi yêu cầu POST chuẩn hóa và bóc tách phong bì phản hồi (`unwrapEnvelope`) để trả về bản ghi đã lưu.
  @override
  Future<UserSupportReport> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    final cleanType = targetType.trim().toLowerCase();
    final cleanReason = reason.trim();
    final cleanDesc = description?.trim();

    if (!allowedTargetTypes.contains(cleanType)) {
      throw const ValidationFailure('Loại đối tượng phản ánh không hợp lệ.');
    }
    if (targetId < 1) {
      throw const ValidationFailure(
        'Mã đối tượng (mã đơn hoặc mã chỗ nghỉ) phải là số nguyên dương.',
      );
    }
    if (cleanReason.isEmpty || cleanReason.length > 255) {
      throw const ValidationFailure(
        'Tiêu đề phản ánh cần từ 1 đến 255 ký tự.',
      );
    }
    if (cleanDesc != null && cleanDesc.length > 2000) {
      throw const ValidationFailure(
        'Nội dung mô tả chi tiết tối đa 2000 ký tự.',
      );
    }

    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/reports',
        data: <String, dynamic>{
          'targetType': cleanType,
          'targetId': targetId,
          'reason': cleanReason,
          if (cleanDesc != null && cleanDesc.isNotEmpty)
            'description': cleanDesc,
        },
      );

      final unwrapped = DioClient.unwrapEnvelope(response.data);
      if (unwrapped is Map<String, dynamic>) {
        final reportMap = unwrapped['report'] is Map
            ? Map<String, dynamic>.from(unwrapped['report'] as Map)
            : unwrapped;
        return UserSupportReport.fromJson(reportMap);
      }
      return UserSupportReport(
        id: '',
        targetType: cleanType,
        targetId: targetId,
        reason: cleanReason,
        description: cleanDesc,
        status: 'open',
        createdAt: DateTime.now().toIso8601String(),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // Giải thuật tải danh sách phản ánh cá nhân từ `/api/reports/mine`:
  // Bóc tách cấu trúc phân trang (`items` hoặc mảng trực tiếp) và chuyển đổi an toàn từng phần tử JSON.
  @override
  Future<List<UserSupportReport>> getMyReports() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/reports/mine',
        queryParameters: const <String, dynamic>{'page': 1, 'limit': 10},
      );
      final unwrapped = DioClient.unwrapEnvelope(response.data);
      List<dynamic> rawItems = const [];
      if (unwrapped is Map<String, dynamic> && unwrapped['items'] is List) {
        rawItems = unwrapped['items'] as List<dynamic>;
      } else if (unwrapped is List) {
        rawItems = unwrapped;
      }
      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(UserSupportReport.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  AppFailure _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String serverMessage = 'Không thể thực hiện yêu cầu lúc này.';
    if (data is Map && data['message'] != null) {
      serverMessage = data['message'].toString();
    }
    if (statusCode == 401) {
      return AuthFailure(serverMessage);
    }
    if (statusCode == 403) {
      return ForbiddenFailure(serverMessage);
    }
    if (statusCode == 429) {
      return RateLimitFailure(serverMessage);
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return ValidationFailure(serverMessage, statusCode: statusCode);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkFailure(
        'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
    return ServerFailure(
      serverMessage,
      statusCode: statusCode ?? 500,
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return SupportRepositoryImpl(client);
});
