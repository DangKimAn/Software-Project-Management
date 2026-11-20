import '../../../../core/errors/app_failure.dart';

/// Bộ quy tắc kiểm tra hợp lệ dữ liệu biểu mẫu xác thực đồng bộ với `auth.validator.ts` trên máy chủ.
///
/// Bao gồm thẩm định định danh đa năng (email / tên đăng nhập / số điện thoại), định dạng số điện thoại Việt Nam,
/// cấu trúc địa chỉ email, độ phức tạp mật khẩu và trích xuất lỗi theo từng trường dữ liệu từ `AppFailure`.
abstract final class AuthValidation {
  /// Kiểm tra định danh đăng nhập `value` (chấp nhận số điện thoại hợp lệ, email hợp lệ hoặc tên đăng nhập `3..255` ký tự).
  ///
  /// Trả về chuỗi thông báo lỗi tiếng Việt nếu không hợp lệ, hoặc `null` khi đạt yêu cầu.
  static String? identifier(String? value) {
    // Giải thuật xác thực định danh đa định dạng:
    // Chấp nhận nếu thỏa mãn biểu thức số điện thoại di động Việt Nam, biểu thức email tiêu chuẩn,
    // hoặc tên đăng nhập chữ-số kèm `._-` (từ chối chuỗi thuần số không đúng chuẩn SĐT Việt Nam).
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Vui lòng nhập email, tên đăng nhập hoặc số điện thoại';
    }
    if (phone(text) == null && text.isNotEmpty) return null;
    if (RegExp(r'^[0-9+]+$').hasMatch(text)) {
      return 'Số điện thoại không đúng định dạng di động Việt Nam (03, 05, 07, 08, 09)';
    }
    if (email(text) == null ||
        RegExp(r'^[a-zA-Z0-9._-]{3,255}$').hasMatch(text)) {
      return null;
    }
    return 'Email, tên đăng nhập hoặc số điện thoại không hợp lệ';
  }

  /// Kiểm tra định danh đăng nhập / khôi phục mật khẩu nghiêm ngặt (`TC-010`, `TC-016`):
  /// chỉ chấp nhận địa chỉ Email hợp lệ hoặc số điện thoại di động chuẩn Việt Nam (`03|05|07|08|09` / `+84...`).
  static String? loginIdentifier(String? value) {
    // Giải thuật phân nhánh kiểm tra định danh Đăng nhập:
    // Nếu chuỗi chỉ gồm chữ số và dấu `+`, kiểm tra nghiêm ngặt theo đầu số di động Việt Nam;
    // ngược lại kiểm tra theo cấu trúc địa chỉ Email tiêu chuẩn RFC.
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Vui lòng nhập email hoặc số điện thoại';
    }
    if (RegExp(r'^[0-9+]+$').hasMatch(text)) {
      return phone(text, required: true);
    }
    if (email(text) == null) {
      return null;
    }
    return 'Vui lòng nhập đúng định dạng Email hoặc số điện thoại Việt Nam';
  }

  /// Kiểm tra định dạng số điện thoại di động Việt Nam `value` (đầu số `03, 05, 07, 08, 09` hoặc `+843..+849`).
  ///
  /// Khi `required` là `false`, cho phép để trống và trả về `null`.
  static String? phone(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required ? 'Vui lòng nhập số điện thoại' : null;
    }
    return RegExp(r'^(0[35789][0-9]{8}|\+84[35789][0-9]{8})$').hasMatch(text)
        ? null
        : 'Số điện thoại cần đúng chuẩn Việt Nam (10 số đầu 03/05/07/08/09 hoặc +84)';
  }

  /// Kiểm tra tính hợp lệ của địa chỉ email `value` (tối đa 255 ký tự, đúng cấu trúc tên miền có dấu chấm).
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập email';
    return text.length <= 255 &&
            RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$').hasMatch(text)
        ? null
        : 'Email không hợp lệ';
  }

  /// Kiểm tra độ mạnh tối thiểu của mật khẩu `value`: độ dài `8..128` ký tự và bắt buộc chứa cả chữ cái lẫn chữ số.
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

  /// Trích xuất bản đồ lỗi chi tiết theo tên trường (`path` -> `msg`) từ ngoại lệ `AppFailure` do máy chủ trả về.
  static Map<String, String> fieldErrors(Object error) => error is AppFailure
      ? {
          for (final field in error.fieldErrors)
            if (field.path != null && field.msg != null) field.path!: field.msg!
        }
      : {};
}
