import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Các biến thể phân cấp thị giác của nút bấm chuẩn `AppButton`.
enum AppButtonVariant {
  /// Nút hành động chính có nền đặc nổi bật nhất trên màn hình.
  primary,

  /// Nút hành động phụ có viền mảnh trên nền sáng.
  secondary,

  /// Nút văn bản tối giản không viền dành cho tác vụ bổ trợ.
  ghost,
}

/// Nút bấm chuẩn toàn hệ thống đảm bảo chiều cao tối thiểu `48dp`, hỗ trợ trạng thái đang tải
/// giữ nguyên chiều rộng nhãn (chống nhảy bố cục) và tích hợp vùng thông báo trực tiếp `liveRegion`.
class AppButton extends StatelessWidget {
  /// Nhãn văn bản hiển thị bên trong nút.
  final String text;

  /// Hàm xử lý khi nhấn nút; tự động khóa tương tác khi `isLoading` đang bật.
  final VoidCallback? onPressed;

  /// Biến thể hiển thị (`primary`, `secondary`, `ghost`).
  final AppButtonVariant variant;

  /// Cờ hiển thị vòng quay tiến trình ngay tại tâm nút mà không làm đổi kích thước nút.
  final bool isLoading;

  /// Biểu tượng tùy chọn đặt phía trước nhãn văn bản.
  final Widget? icon;

  /// Chiều rộng cố định của nút; mặc định mở rộng toàn chiều ngang vùng chứa (`double.infinity`).
  final double? width;

  /// Chiều cao tối thiểu của nút; tự động giãn thêm khi cỡ chữ trợ năng phóng lớn.
  ///
  /// Minimum height; grows with text scaling and wrapped labels.
  final double height;

  /// Nhãn ngữ nghĩa ghi đè cho trình đọc màn hình (mặc định dùng `text`).
  final String? semanticLabel;

  /// Khởi tạo nút bấm biến thể chính (`AppButtonVariant.primary`).
  const AppButton(
      {super.key,
      required this.text,
      required this.onPressed,
      this.variant = AppButtonVariant.primary,
      this.isLoading = false,
      this.icon,
      this.width,
      this.height = 50,
      this.semanticLabel});

  /// Khởi tạo nhanh nút bấm biến thể viền phụ (`AppButtonVariant.secondary`).
  const AppButton.secondary(
      {super.key,
      required this.text,
      required this.onPressed,
      this.isLoading = false,
      this.icon,
      this.width,
      this.height = 50,
      this.semanticLabel})
      : variant = AppButtonVariant.secondary;

  /// Khởi tạo nhanh nút bấm văn bản tối giản (`AppButtonVariant.ghost`).
  const AppButton.ghost(
      {super.key,
      required this.text,
      required this.onPressed,
      this.isLoading = false,
      this.icon,
      this.width,
      this.height = 48,
      this.semanticLabel})
      : variant = AppButtonVariant.ghost;

  /// Dựng nút theo biến thể tương ứng với chiều cao sàn `>= 48dp` và lớp chồng `Stack` chống xê dịch khi tải.
  @override
  Widget build(BuildContext context) {
    // Giải thuật bảo toàn kích thước nút trong trạng thái tải (Zero-CLS Loading Stack):
    // Ẩn dòng nhãn bằng Opacity = 0 thay vì gỡ khỏi cây bố cục để giữ nguyên khung kích thước nội tại,
    // đồng thời đặt vòng quay tiến trình ở tâm và dùng giá trị tĩnh 0.75 khi bật giảm chuyển động.
    final callback = isLoading ? null : onPressed;
    final content = Semantics(
      label: semanticLabel ?? text,
      liveRegion: isLoading,
      child: ExcludeSemantics(
          child: Stack(
        alignment: Alignment.center,
        children: [
          // Preserve label dimensions while loading so surrounding content stays still.
          Opacity(
              opacity: isLoading ? 0 : 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Flexible(child: Text(text, textAlign: TextAlign.center)),
                ],
              )),
          if (isLoading)
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context) ? .75 : null,
                  strokeWidth: 2,
                )),
        ],
      )),
    );
    final button = switch (variant) {
      AppButtonVariant.primary =>
        FilledButton(onPressed: callback, child: content),
      AppButtonVariant.secondary =>
        OutlinedButton(onPressed: callback, child: content),
      AppButtonVariant.ghost => TextButton(onPressed: callback, child: content),
    };
    return SizedBox(
        width: width ?? double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(48, height)),
          child: button,
        ));
  }
}

/// Nút biểu tượng nền trong suốt hỗ trợ điều hướng bàn phím, `Tooltip` và vùng chạm tối thiểu `48x48dp`.
///
/// Bare icon with a transparent, keyboard accessible hit target of at least 48dp.
class AppIconButton extends StatelessWidget {
  /// Phần tử biểu tượng hiển thị ở tâm nút.
  final Widget icon;

  /// Hàm xử lý khi kích hoạt nút biểu tượng.
  final VoidCallback? onPressed;

  /// Chuỗi chú giải bắt buộc dùng đồng thời cho `Tooltip` và nhãn đọc màn hình `Semantics`.
  final String tooltip;

  /// Tham số giữ lại để tương thích ngược; nền nút biểu tượng luôn trong suốt theo quy chuẩn thiết kế.
  ///
  /// Retained for caller compatibility. Icon actions always have a transparent background.
  final Color? backgroundColor;

  /// Màu ghi đè tùy chọn cho biểu tượng bên trong.
  final Color? iconColor;

  /// Kích thước cạnh vùng chạm của nút (tự động nâng lên tối thiểu `48dp`).
  final double size;

  /// Khởi tạo nút biểu tượng trần có vùng chạm chuẩn trợ năng.
  const AppIconButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      required this.tooltip,
      this.backgroundColor,
      this.iconColor,
      this.size = 48});

  /// Dựng hộp chạm tối thiểu `48x48dp` kết hợp `Tooltip` và `Semantics` không lặp nhãn.
  @override
  Widget build(BuildContext context) => SizedBox(
        width: math.max(48, size),
        height: math.max(48, size),
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Semantics(
            label: tooltip,
            child: IconButton(
              onPressed: onPressed,
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.transparent)),
              color: iconColor,
              icon: icon,
            ),
          ),
        ),
      );
}
