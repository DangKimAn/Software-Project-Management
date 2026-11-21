import 'user.dart';

/// Thực thể biểu diễn một phiên xác thực hợp lệ trả về từ máy chủ sau khi đăng nhập hoặc đăng ký.
class AuthSession {
  /// Chuỗi JWT Access Token dùng để xác thực các yêu cầu API bảo vệ.
  final String token;

  /// Chuỗi Refresh Token dùng để gia hạn phiên khi Access Token hết hạn (nếu không lưu qua Cookie HttpOnly).
  final String? refreshToken;

  /// Thực thể thông tin người dùng gắn với phiên đăng nhập hiện hành.
  final User user;

  /// Cho biết tài khoản vừa được khởi tạo lần đầu (ví dụ qua đăng nhập Google OAuth lần đầu) hay không.
  final bool isNewUser;

  /// Khởi tạo thực thể `AuthSession`.
  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
    this.isNewUser = false,
  });

  /// Giải mã đối tượng JSON từ phản hồi xác thực (`/api/auth/login`, `/api/auth/register`, `/api/auth/google`) thành `AuthSession`.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token']?.toString().trim().isNotEmpty == true
            ? json['token']?.toString().trim()
            : json['accessToken']?.toString().trim()) ??
        '';
    final rawRefresh = json['refreshToken']?.toString().trim();
    final userJson = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AuthSession(
      token: token,
      refreshToken:
          (rawRefresh != null && rawRefresh.isNotEmpty) ? rawRefresh : null,
      user: User.fromJson(userJson),
      isNewUser: json['isNewUser'] == true,
    );
  }
}
