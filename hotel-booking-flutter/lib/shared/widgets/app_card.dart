import 'package:flutter/material.dart';

/// Khung thẻ bề mặt dùng chung đồng bộ bo góc từ `CardTheme`, hỗ trợ viền mảnh và phản hồi chạm `InkWell`.
class AppCard extends StatelessWidget {
  /// Nội dung giao diện bên trong thẻ.
  final Widget child;

  /// Khoảng đệm bên trong thẻ (mặc định `EdgeInsets.all(16)`).
  final EdgeInsetsGeometry? padding;

  /// Khoảng cách lề bên ngoài thẻ.
  final EdgeInsetsGeometry? margin;

  /// Hàm xử lý khi người dùng chạm vào thẻ (`null` nếu thẻ chỉ hiển thị tĩnh).
  final VoidCallback? onTap;

  /// Màu nền tùy chỉnh ghi đè màu thẻ mặc định của chủ đề.
  final Color? backgroundColor;

  /// Viền khung tùy chọn khớp tự động với bán kính bo góc của `cardTheme`.
  final Border? border;

  /// Cho phép bật/tắt đổ bóng theo cấu hình `cardTheme` (`false` đặt `elevation = 0`).
  final bool showShadow;

  /// Khởi tạo khung thẻ bề mặt dùng chung `AppCard`.
  const AppCard(
      {super.key,
      required this.child,
      this.padding,
      this.margin,
      this.onTap,
      this.backgroundColor,
      this.border,
      this.showShadow = true});

  /// Dựng `Card` cắt khử răng cưa kèm lớp `Ink` và `InkWell` khớp bán kính bo góc chủ đề.
  @override
  Widget build(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    return Card(
      margin: margin,
      color: backgroundColor,
      elevation: showShadow ? null : 0,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: border == null
            ? null
            : BoxDecoration(
                border: border,
                borderRadius:
                    shape is RoundedRectangleBorder ? shape.borderRadius : null,
              ),
        child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Padding(
                padding: padding ?? const EdgeInsets.all(16), child: child)),
      ),
    );
  }
}
