import '../../../../core/errors/app_failure.dart';

/// Mirrors backend auth.validator.ts; the server remains authoritative.
abstract final class AuthValidation {
  static String? identifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Vui lòng nhập email, tên đăng nhập hoặc số điện thoại';
    }
    if (phone(text) == null && text.isNotEmpty) return null;
    if (email(text) == null ||
        RegExp(r'^[a-zA-Z0-9._-]{3,255}$').hasMatch(text)) {
      return null;
    }
    return 'Email, tên đăng nhập hoặc số điện thoại không hợp lệ';
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return RegExp(r'^(0|\+84)[0-9]{9}$').hasMatch(text)
        ? null
        : 'Số điện thoại cần có 10 số hoặc bắt đầu bằng +84';
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    return text.length <= 255 &&
            RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$').hasMatch(text)
        ? null
        : 'Email không hợp lệ';
  }

  static String? password(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 8 || text.length > 128) {
      return 'Mật khẩu cần từ 8 đến 128 ký tự';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(text) ||
        !RegExp(r'[0-9]').hasMatch(text)) {
      return 'Mật khẩu cần có chữ và số';
    }
    return null;
  }

  static Map<String, String> fieldErrors(Object error) => error is AppFailure
      ? {
          for (final field in error.fieldErrors)
            if (field.path != null && field.msg != null) field.path!: field.msg!
        }
      : {};
}
