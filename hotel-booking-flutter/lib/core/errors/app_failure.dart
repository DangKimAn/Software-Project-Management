class ApiFieldError {
  final String? path;
  final String? msg;

  const ApiFieldError({this.path, this.msg});

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      path: json['path']?.toString(),
      msg: json['msg']?.toString() ?? json['message']?.toString(),
    );
  }
}

/// Sealed class hierarchy for typed application failures matching Backend envelope.
sealed class AppFailure {
  final String message;
  final int? statusCode;
  final String code;
  final dynamic details;
  final List<ApiFieldError> fieldErrors;
  final dynamic cause;

  const AppFailure(
    this.message, {
    this.statusCode,
    this.code = 'INTERNAL_ERROR',
    this.details,
    this.fieldErrors = const [],
    this.cause,
  });

  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Không có kết nối mạng hoặc mạng không ổn định.',
  ]) : super(statusCode: null, code: 'NETWORK_ERROR');
}

final class ServerFailure extends AppFailure {
  const ServerFailure(
    super.message, {
    super.statusCode,
    super.code = 'SERVER_ERROR',
    super.details,
    super.fieldErrors,
    super.cause,
  });
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
  ]) : super(statusCode: 404, code: 'NOT_FOUND');
}

final class AuthFailure extends AppFailure {
  const AuthFailure([
    super.message = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
    String code = 'UNAUTHORIZED',
    int statusCode = 401,
  ]) : super(statusCode: statusCode, code: code);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(
    super.message, {
    super.code = 'CONFLICT',
    super.details,
    super.fieldErrors,
  }) : super(statusCode: 409);
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure([
    super.message = 'Bạn đã thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
  ]) : super(statusCode: 429, code: 'RATE_LIMITED');
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(
    super.message, {
    super.statusCode = 422,
    super.code = 'VALIDATION_ERROR',
    super.details,
    super.fieldErrors,
    super.cause,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = 'Đã có lỗi không xác định xảy ra.',
    dynamic cause,
  ]) : super(cause: cause);
}
