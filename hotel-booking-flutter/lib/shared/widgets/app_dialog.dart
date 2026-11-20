import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
export '../animations/source_animations.dart'
    show AppModal, AppToast, AppToastType;

/// Hộp thoại xác nhận chuẩn của ứng dụng hỗ trợ tự động tắt hiệu ứng khi bật giảm chuyển động,
/// bố cục cân đối và hỗ trợ hai hình thức hiển thị: Hộp thoại căn giữa (Modal) hoặc Ngăn kéo dưới (Action Sheet).
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

  /// Biểu tượng tùy chọn hiển thị tại đỉnh hộp thoại.
  final Widget? icon;

  /// Cờ đánh dấu hành động mang tính hủy hoại/cảnh báo (đổi nút xác nhận sang màu đỏ nguy hiểm).
  final bool isDestructive;

  /// Khởi tạo hộp thoại xác nhận `AppDialog`.
  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.onConfirm,
    this.cancelText,
    this.onCancel,
    this.icon,
    this.isDestructive = false,
  });

  /// Hiển thị hộp thoại xác nhận bất đồng bộ (Center Modal) và trả về `true` nếu đồng ý, `false` nếu hủy.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    Widget? icon,
    bool isDestructive = false,
  }) =>
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
          onCancel: () => Navigator.of(ctx).pop(false),
          icon: icon,
          isDestructive: isDestructive,
        ),
      );

  /// Hiển thị hộp thoại xác nhận dạng Bottom Sheet (Action Sheet vuốt từ dưới lên).
  static Future<bool?> showActionSheet(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    Widget? icon,
    bool isDestructive = false,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _AppActionSheet(
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          icon: icon,
          isDestructive: isDestructive,
          onConfirm: () => Navigator.of(ctx).pop(true),
          onCancel: () => Navigator.of(ctx).pop(false),
        ),
      );

  /// Dựng `AlertDialog` có khả năng cuộn nội dung và bố cục nút cân đối, chống tràn.
  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isStacked = textScale > 1.45;

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            textAlign: icon != null ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Text(
        message,
        textAlign: icon != null ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.45),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (isStacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onConfirm,
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (cancelText != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                    child: Text(
                      cancelText!,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            ],
          )
        else
          Row(
            children: [
              if (cancelText != null) ...[
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          onCancel ?? () => Navigator.of(context).pop(false),
                      child: Text(
                        cancelText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onConfirm,
                    child: Text(
                      confirmText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Widget hiển thị Bottom Sheet xác nhận (Action Sheet) theo phong cách hiện đại.
class _AppActionSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final Widget? icon;
  final bool isDestructive;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _AppActionSheet({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.onConfirm,
    required this.onCancel,
    this.cancelText,
    this.icon,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh gạt vuốt xuống (Drag Handle)
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Hàng tiêu đề với Icon và nút đóng ✕
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: icon),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  splashRadius: 20,
                  tooltip: 'Đóng',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            // Dòng thông điệp xác nhận
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            // Nút xác nhận chính (Full-width, 48dp)
            SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const Key('logout_confirm_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onConfirm,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDestructive) ...[
                      const Icon(LucideIcons.logOut, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      confirmText,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            if (cancelText != null) ...[
              const SizedBox(height: 10),
              // Nút hủy bỏ phụ (Full-width, 48dp)
              SizedBox(
                height: 48,
                child: TextButton(
                  key: const Key('logout_cancel_btn'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onCancel,
                  child: Text(
                    cancelText!,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

