import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/app_failure.dart';
import '../logging/app_logger.dart';

import '../security/secure_storage_service.dart';

class DioClient {
  final Dio _dio;
  final SecureStorageService? _secureStorage;

  DioClient({Dio? dio, SecureStorageService? secureStorage})
      : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConstants.connectTimeout,
                receiveTimeout: AppConstants.receiveTimeout,
                sendTimeout: AppConstants.sendTimeout,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_secureStorage != null) {
            try {
              final token = await _secureStorage.getAuthToken();
              if (token != null &&
                  token.isNotEmpty &&
                  !options.headers.containsKey('Authorization')) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (_) {
              // Ignore storage errors on request interceptor
            }
          }
          AppLogger.d('HTTP Request: ${options.method} ${options.uri.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.d(
              'HTTP Response [${response.statusCode}]: ${response.requestOptions.uri.path}');
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          AppLogger.w(
              'HTTP Error [${error.response?.statusCode}]: ${error.requestOptions.uri.path}');
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Translates DioException into clean typed AppFailure.
  static AppFailure handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure();
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401 || statusCode == 403) {
            return const AuthFailure();
          } else if (statusCode == 404) {
            return const NotFoundFailure();
          }
          final message = error.response?.data?['message']?.toString() ??
              'Lỗi máy chủ ($statusCode). Vui lòng thử lại sau.';
          return ServerFailure(message, statusCode: statusCode);
        case DioExceptionType.cancel:
          return const ValidationFailure('Yêu cầu đã bị hủy.');
        default:
          return UnknownFailure(
              error.message ?? 'Đã có lỗi mạng không mong muốn.');
      }
    }
    if (error is AppFailure) {
      return error;
    }
    return UnknownFailure(error.toString());
  }
}
