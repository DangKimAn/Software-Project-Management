import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Thẻ biên lai dùng chung hiển thị kết quả giao dịch thanh toán trên cả thiết bị di động và máy tính để bàn.
///
/// Tự động chuyển đổi bố cục cặp khóa - giá trị sang dạng xếp chồng dọc khi màn hình hẹp hoặc cỡ chữ trợ năng lớn.
class PaymentResultCard extends StatelessWidget {
  /// Biểu tượng minh họa trạng thái kết quả thanh toán.
  final IconData icon;

  /// Tiêu đề chính thông báo kết quả giao dịch.
  final String title;

  /// Nội dung giải thích chi tiết trạng thái đơn và hướng dẫn tiếp theo.
  final String subtitle;

  /// Cho biết hệ thống có đang trong quá trình đối soát trạng thái với máy chủ hay không.
  final bool isVerifying;

  /// Danh sách các dòng thông tin biên lai (như Mã đặt phòng, Mã giao dịch, Phương thức, Số tiền).
  final Map<String, String> details;

  /// Thao tác kích hoạt kiểm tra lại trạng thái giao dịch thủ công.
  final VoidCallback? onRecheck;

  /// Thao tác quay lại trang thanh toán để thử giao dịch mới.
  final VoidCallback? onRetry;

  /// Thao tác mở trang danh sách chuyến đi của tôi.
  final VoidCallback? onViewTrips;

  /// Thao tác điều hướng về Trang chủ.
  final VoidCallback? onGoHome;

  /// Khởi tạo `PaymentResultCard`.
  const PaymentResultCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.isVerifying,
      required this.details,
      this.onRecheck,
      this.onRetry,
      this.onViewTrips,
      this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSoft)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 28, color: AppColors.iconStrong)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
        ]),
        const SizedBox(height: 12),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary)),
        if (isVerifying) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          const SizedBox(height: 6),
          const Text('Đang kiểm tra trạng thái…',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary)),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
                children: details.entries
                    .map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: LayoutBuilder(builder: (context, constraints) {
                            final label = Text(entry.key,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary));
                            final amount = entry.key == 'Số tiền';
                            final valueStyle = TextStyle(
                                fontSize: amount ? 16 : 13,
                                fontWeight:
                                    amount ? FontWeight.w700 : FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.4);
                            if (constraints.maxWidth < 250 ||
                                MediaQuery.textScalerOf(context).scale(13) >
                                    18) {
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label,
                                    const SizedBox(height: 4),
                                    Text(entry.value, style: valueStyle)
                                  ]);
                            }
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 4, child: label),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      flex: 5,
                                      child: Text(entry.value,
                                          textAlign: TextAlign.right,
                                          style: valueStyle)),
                                ]);
                          }),
                        ))
                    .toList()),
          ),
        ],
        const SizedBox(height: 20),
        if (onRecheck != null) ...[
          _action(OutlinedButton(
              onPressed: isVerifying ? null : onRecheck,
              child: const Text('Kiểm tra lại trạng thái',
                  textAlign: TextAlign.center))),
          const SizedBox(height: 10),
        ],
        if (onRetry != null) ...[
          _action(FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Thử thanh toán lại',
                  textAlign: TextAlign.center))),
          const SizedBox(height: 10),
        ],
        if (onViewTrips != null)
          _action(FilledButton(
              onPressed: onViewTrips,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Xem chuyến đi của tôi',
                  textAlign: TextAlign.center))),
        if (onGoHome != null) ...[
          const SizedBox(height: 4),
          _action(TextButton(
              onPressed: onGoHome, child: const Text('Về Trang chủ'))),
        ],
      ]),
    );
  }

  Widget _action(Widget child) => ConstrainedBox(
        constraints:
            const BoxConstraints(minHeight: 48, minWidth: double.infinity),
        child: child,
      );
}
