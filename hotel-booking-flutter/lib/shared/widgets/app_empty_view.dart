import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';

import 'app_button.dart';

/// Khung hiển thị trạng thái rỗng dùng chung khi danh sách hoặc kết quả tìm kiếm không có dữ liệu,
/// đi kèm biểu tượng đơn sắc, lời giải thích rõ ràng và nút kêu gọi hành động tùy chọn.
class AppEmptyView extends StatelessWidget {
  /// Tiêu đề ngắn gọn thông báo trạng thái trống.
  final String title;

  /// Mô tả chi tiết hướng dẫn người dùng cách điều chỉnh bộ lọc hoặc thao tác tiếp theo.
  final String description;

  /// Biểu tượng đơn sắc hiển thị phía trên tiêu đề (mặc định `LucideIcons.searchX`).
  final IconData icon;

  /// Hàm xử lý khi người dùng nhấn nút hành động khôi phục/tìm kiếm lại.
  final VoidCallback? onAction;

  /// Nhãn văn bản của nút hành động (chỉ hiển thị nút khi cả `onAction` và `actionText` khác `null`).
  final String? actionText;

  /// Khởi tạo giao diện trạng thái trống `AppEmptyView`.
  const AppEmptyView({
    super.key,
    required this.title,
    required this.description,
    this.icon = LucideIcons.searchX,
    this.onAction,
    this.actionText,
  });

  /// Dựng bố cục căn giữa có hỗ trợ cuộn dọc an toàn trên màn hình thấp.
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              AppButton.secondary(
                width: 180,
                text: actionText!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      )),
    );
  }
}
