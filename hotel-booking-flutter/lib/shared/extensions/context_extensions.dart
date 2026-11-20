import 'package:flutter/material.dart';

/// Tập tiện ích mở rộng trên `BuildContext` giúp truy xuất nhanh chủ đề giao diện,
/// kích thước màn hình, vùng đệm bàn phím ảo và phân loại điểm ngắt thiết bị.
extension BuildContextX on BuildContext {
  /// Dữ liệu chủ đề `ThemeData` hiện hành của nhánh giao diện.
  ThemeData get theme => Theme.of(this);

  /// Bảng màu ngữ nghĩa `ColorScheme` trích xuất từ chủ đề hiện hành.
  ColorScheme get colorScheme => theme.colorScheme;

  /// Hệ thống kiểu chữ `TextTheme` của chủ đề hiện hành.
  TextTheme get textTheme => theme.textTheme;

  /// Thông tin môi trường hiển thị `MediaQueryData` của cửa sổ hiện tại.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Kích thước khung nhìn logic `(width, height)` tính bằng dp.
  Size get screenSize => mediaQuery.size;

  /// Chiều rộng khung nhìn hiện tại tính bằng dp.
  double get screenWidth => screenSize.width;

  /// Chiều cao khung nhìn hiện tại tính bằng dp.
  double get screenHeight => screenSize.height;

  /// Phần diện tích khung nhìn bị che khuất bởi giao diện hệ thống (như bàn phím ảo).
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  /// Phần đệm an toàn của phần cứng màn hình (tai thỏ, thanh điều hướng đáy).
  EdgeInsets get viewPadding => mediaQuery.viewPadding;

  /// Trả về `true` khi bàn phím ảo đang mở (`viewInsets.bottom > 0`).
  bool get isKeyboardOpen => viewInsets.bottom > 0;

  /// Trả về `true` khi chiều rộng màn hình đạt điểm ngắt máy tính bảng trở lên (`>= 600dp`).
  bool get isTablet => screenWidth >= 600;
}
