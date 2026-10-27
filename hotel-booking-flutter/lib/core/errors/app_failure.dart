class ApiFieldError {
  final String? path;
  final String? msg;

  const ApiFieldError({this.path, this.msg});

  String? get field => path;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    final resolvedPath =
        (json['path'] ?? json['field'] ?? json['param'])?.toString().trim();
    final resolvedMsg =
        (json['msg'] ?? json['message'] ?? json['error'])?.toString().trim();
    return ApiFieldError(
      path: (resolvedPath != null && resolvedPath.isNotEmpty)
          ? resolvedPath
          : null,
      msg: (resolvedMsg != null && resolvedMsg.isNotEmpty) ? resolvedMsg : null,
    );
  }
}

/// Sealed class hierarchy for typed application failures matching Backend envelope.
///
/// Explicitly separates device offline conditions from DNS lookup failures,
/// TCP connection refused, request timeouts, TLS/SSL certificate failures,
/// HTTP status errors (400/401/403/404/409/422/429/5xx), request cancellation,
/// and JSON/model serialization errors.
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

  bool get isOffline => this is OfflineFailure || code == 'NETWORK_OFFLINE';
  bool get isDnsError => this is DnsFailure || code == 'DNS_FAILURE';
  bool get isConnectionRefused =>
      this is ConnectionRefusedFailure || code == 'CONNECTION_REFUSED';
  bool get isTimeout => this is TimeoutFailure || code.contains('TIMEOUT');
  bool get isTlsError =>
      this is CertificateFailure || code == 'TLS_CERTIFICATE_ERROR';
  bool get isCancelled =>
      this is RequestCancelledFailure || code == 'REQUEST_CANCELLED';
  bool get isSerializationError =>
      this is SerializationFailure || code == 'SERIALIZATION_ERROR';
  bool get isForbidden =>
      this is ForbiddenFailure || statusCode == 403 || code == 'FORBIDDEN';
  bool get isUnauthorized => statusCode == 401 || code == 'UNAUTHORIZED';
  bool get isServerError =>
      this is ServerFailure || (statusCode != null && statusCode! >= 500);
  bool get isRateLimited =>
      this is RateLimitFailure || statusCode == 429 || code == 'RATE_LIMITED';

  bool get isRetryable {
    if (isCancelled || isDnsError || isTlsError || isSerializationError) {
      return false;
    }
    if (isTimeout || isOffline || isConnectionRefused || isRateLimited) {
      return true;
    }
    if (this is ServerFailure) {
      return statusCode == 502 || statusCode == 503 || statusCode == 504;
    }
    return false;
  }

  @override
  String toString() => message;
}

base class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Không có kết nối mạng hoặc mạng không ổn định.',
    String code = 'NETWORK_ERROR',
    dynamic cause,
  ]) : super(statusCode: null, code: code, cause: cause);
}

final class OfflineFailure extends NetworkFailure {
  const OfflineFailure([
    String message = 'Không có kết nối mạng hoặc mạng không ổn định.',
    dynamic cause,
  ]) : super(message, 'NETWORK_OFFLINE', cause);
}

final class DnsFailure extends NetworkFailure {
  final String? host;

  const DnsFailure([
    super.message =
        'Không thể phân giải tên miền máy chủ (lỗi DNS). Vui lòng kiểm tra cấu hình máy chủ.',
    super.code = 'DNS_FAILURE',
    super.cause,
    this.host,
  ]);
}

final class ConnectionRefusedFailure extends NetworkFailure {
  const ConnectionRefusedFailure([
    super.message =
        'Không thể kết nối tới máy chủ. Dịch vụ hiện chưa phản hồi.',
    super.code = 'CONNECTION_REFUSED',
    super.cause,
  ]);
}

final class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure([
    super.message =
        'Máy chủ phản hồi quá thời gian chờ (timeout). Vui lòng thử lại.',
    super.code = 'NETWORK_TIMEOUT',
    super.cause,
  ]);
}

final class CertificateFailure extends NetworkFailure {
  const CertificateFailure([
    super.message = 'Không thể xác minh chứng chỉ bảo mật TLS/SSL của máy chủ.',
    super.code = 'TLS_CERTIFICATE_ERROR',
    super.cause,
  ]);
}

typedef TlsFailure = CertificateFailure;

final class ServerFailure extends AppFailure {
  const ServerFailure(
    super.message, {
    super.statusCode = 500,
    super.code = 'SERVER_ERROR',
    super.details,
    super.fieldErrors,
    super.cause,
  });
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
    String code = 'NOT_FOUND',
  ]) : super(statusCode: 404, code: code);
}

base class AuthFailure extends AppFailure {
  const AuthFailure([
    super.message = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
    String code = 'UNAUTHORIZED',
    int statusCode = 401,
  ]) : super(statusCode: statusCode, code: code);
}

final class ForbiddenFailure extends AuthFailure {
  const ForbiddenFailure([
    String message = 'Bạn không có quyền truy cập chức năng này.',
    String code = 'FORBIDDEN',
  ]) : super(message, code, 403);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(
    super.message, {
    super.code = 'CONFLICT',
    super.details,
    super.fieldErrors,
    super.cause,
  }) : super(statusCode: 409);
}

final class RateLimitFailure extends AppFailure {
  final int? retryAfterSeconds;

  const RateLimitFailure([
    super.message = 'Bạn đã thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
    String code = 'RATE_LIMITED',
  ])  : retryAfterSeconds = null,
        super(statusCode: 429, code: code);

  const RateLimitFailure.withRetryAfter(
    super.message, {
    super.code = 'RATE_LIMITED',
    this.retryAfterSeconds,
    super.details,
    super.cause,
  }) : super(statusCode: 429);
}

base class ValidationFailure extends AppFailure {
  const ValidationFailure(
    super.message, {
    super.statusCode = 422,
    super.code = 'VALIDATION_ERROR',
    super.details,
    super.fieldErrors,
    super.cause,
  });
}

final class RequestCancelledFailure extends ValidationFailure {
  const RequestCancelledFailure([
    super.message = 'Yêu cầu đã bị hủy.',
    String code = 'REQUEST_CANCELLED',
    dynamic cause,
  ]) : super(statusCode: null, code: code, cause: cause);
}

final class SerializationFailure extends AppFailure {
  const SerializationFailure([
    super.message = 'Dữ liệu phản hồi từ máy chủ không đúng định dạng.',
    String code = 'SERIALIZATION_ERROR',
    dynamic details,
    dynamic cause,
  ]) : super(statusCode: null, code: code, details: details, cause: cause);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = 'Đã có lỗi không xác định xảy ra.',
    dynamic cause,
  ]) : super(code: 'UNKNOWN_ERROR', cause: cause);
}
