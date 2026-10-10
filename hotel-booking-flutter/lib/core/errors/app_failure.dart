/// Sealed class hierarchy for typed application failures.
sealed class AppFailure {
  final String message;
  final int? statusCode;
  final dynamic cause;

  const AppFailure(this.message, {this.statusCode, this.cause});

  @override
  String toString() => '$runtimeType: $message (code: $statusCode)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(
      [super.message = 'Không có kết nối mạng hoặc mạng không ổn định.'])
      : super(statusCode: null);
}

final class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {super.statusCode, super.cause});
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Không tìm thấy dữ liệu yêu cầu.'])
      : super(statusCode: 404);
}

final class AuthFailure extends AppFailure {
  const AuthFailure(
      [super.message = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.'])
      : super(statusCode: 401);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause});
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(
      [super.message = 'Đã có lỗi không xác định xảy ra.', dynamic cause])
      : super(cause: cause);
}
