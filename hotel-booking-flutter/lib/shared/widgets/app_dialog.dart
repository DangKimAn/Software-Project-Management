import 'package:flutter/material.dart';
import 'app_button.dart';
export '../animations/source_animations.dart'
    show AppModal, AppToast, AppToastType;

/// Hộp thoại xác nhận chuẩn của ứng dụng hỗ trợ tự động tắt hiệu ứng khi bật giảm chuyển động
/// và xếp chồng dọc nút bấm an toàn trên màn hình hẹp hoặc chữ phóng lớn.
class AppDialog extends StatelessWidget {
  /// Tiêu đề chính của hộp thoại xác nhận.
  final String title;

  /// Nội dung giải thích chi tiết hành động cần người dùng xác nhận.
  final String message;

  /// Nhãn hiển thị trên nút xác nhận chính.
  final String confirmText;

  /// Hàm thực thi khi người dùng nhấn nút xác nhận.
  final VoidCallback onConfirm;

  /// Nhãn tùy chọn cho nút hủy bỏ; nếu `null` hộp thoại chỉ hiển thị một nút xác nhận.
  final String? cancelText;

  /// Hàm xử lý tùy chọn khi nhấn hủy; mặc định đóng hộp thoại và trả về `false`.
  final VoidCallback? onCancel;

  /// Khởi tạo hộp thoại xác nhận `AppDialog`.
  const AppDialog(
      {super.key,
      required this.title,
      required this.message,
      required this.confirmText,
      required this.onConfirm,
      this.cancelText,
      this.onCancel});

  /// Hiển thị hộp thoại xác nhận bất đồng bộ và trả về `true` nếu đồng ý, `false` nếu hủy.
  static Future<bool?> show(BuildContext context,
          {required String title,
          required String message,
          required String confirmText,
          String? cancelText}) =>
      showDialog<bool>(
        context: context,
        useSafeArea: true,
        animationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: Duration(milliseconds: 220),
                reverseDuration: Duration(milliseconds: 180)),
        builder: (ctx) => AppDialog(
            title: title,
            message: message,
            confirmText: confirmText,
            onConfirm: () => Navigator.of(ctx).pop(true),
            cancelText: cancelText,
            onCancel: () => Navigator.of(ctx).pop(false)),
      );

  /// Dựng `AlertDialog` có khả năng cuộn nội dung và tự xuống dòng các nút hành động khi thiếu chỗ.
  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(title),
        content: Text(message),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (cancelText != null)
            AppButton.secondary(
                width: 200,
                text: cancelText!,
                onPressed: onCancel ?? () => Navigator.of(context).pop(false)),
          AppButton(width: 200, text: confirmText, onPressed: onConfirm),
        ],
      );
}
