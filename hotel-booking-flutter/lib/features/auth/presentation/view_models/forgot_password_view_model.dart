// CONFLICT-RESOLVED: Bổ sung `ForgotPasswordViewModel` cho màn hình Quên mật khẩu theo chuẩn MVVM
// (FLUTTER_RULES.md Mục 2), loại bỏ việc `ForgotPasswordScreen` đọc trực tiếp `authRepositoryProvider`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_notifier.dart';

/// ViewModel điều phối quy trình yêu cầu mã OTP và đặt lại mật khẩu mới theo kiến trúc MVVM.
class ForgotPasswordViewModel {
  final AuthRepository _authRepository;

  /// Khởi tạo `ForgotPasswordViewModel` với kho xác thực `_authRepository`.
  const ForgotPasswordViewModel(this._authRepository);

  /// Gửi yêu cầu phát hành mã xác thực OTP khôi phục mật khẩu tới định danh `identifier` (Email hoặc Số điện thoại)
  /// và trả về thời gian đếm ngược gửi lại mã (giây).
  // Giải thuật gửi yêu cầu cấp mã xác thực OTP khôi phục mật khẩu và đồng bộ thời gian cooldown từ máy chủ (`TC-017`).
  Future<int> requestPasswordResetOtp({required String identifier}) async {
    final trimmed = identifier.trim();
    final repo = _authRepository;
    if (repo is AuthRepositoryImpl) {
      return repo.forgotPasswordWithCooldown(identifier: trimmed);
    }
    await repo.forgotPassword(identifier: trimmed);
    return 60;
  }

  /// Xác minh mã `otp` gồm 6 chữ số và lưu mật khẩu mới `newPassword` cho tài khoản `identifier`.
  // Giải thuật xác nhận mã OTP 6 chữ số và thiết lập mật khẩu mới lên máy chủ xác thực.
  Future<void> confirmPasswordReset({
    required String identifier,
    required String otp,
    required String newPassword,
  }) {
    return _authRepository.resetPassword(
      identifier: identifier.trim(),
      otp: otp.trim(),
      newPassword: newPassword,
    );
  }
}

/// Provider cung cấp `ForgotPasswordViewModel` cho màn hình Quên mật khẩu.
final forgotPasswordViewModelProvider = Provider<ForgotPasswordViewModel>((
  ref,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  return ForgotPasswordViewModel(authRepository);
});
