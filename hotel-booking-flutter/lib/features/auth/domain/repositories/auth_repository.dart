import '../entities/auth_session.dart';
import '../entities/user.dart';

/// Hợp đồng kho lưu trữ nghiệp vụ xác thực, khôi phục mật khẩu và cập nhật hồ sơ người dùng.
abstract class AuthRepository {
  /// Đăng nhập bằng định danh `identifier` (email, tên đăng nhập hoặc số điện thoại) và mật khẩu `password`.
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  /// Đăng nhập hoặc liên kết tài khoản thông qua chuỗi OpenID Connect `idToken` cấp bởi Google SDK.
  Future<AuthSession> loginWithGoogle({
    required String idToken,
  });

  /// Đăng ký tài khoản người dùng mới và khởi tạo phiên đăng nhập ngay sau khi tạo thành công.
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  });

  /// Yêu cầu máy chủ gửi mã xác thực OTP khôi phục mật khẩu tới `identifier` (email hoặc số điện thoại).
  Future<void> forgotPassword({
    required String identifier,
  });

  /// Xác nhận mã `otp` gồm 6 chữ số và đặt lại mật khẩu mới `newPassword` cho tài khoản `identifier`.
  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  });

  /// Khôi phục và truy vấn thông tin người dùng của phiên hiện hành; trả về `null` nếu chưa đăng nhập hoặc phiên đã hết hạn.
  Future<User?> getCurrentUser();

  /// Cập nhật các thông tin giới thiệu và liên hệ trên hồ sơ cá nhân của người dùng hiện tại.
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    String? avatarUrl,
  });

  /// Lưu đường dẫn ảnh đại diện mới `url` (kèm khóa lưu trữ đám mây `key` nếu có) vào hồ sơ người dùng.
  Future<User> updateAvatar({
    required String url,
    String? key,
  });

  /// Thu hồi phiên làm việc trên máy chủ và xóa sạch toàn bộ thông tin xác thực lưu trữ cục bộ.
  Future<void> logout();
}
