import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../../shared/widgets/price_display.dart';
import '../../../support/domain/services/contact_service.dart';
import '../../../villas/domain/entities/villa.dart';

/// Thanh hành động cố định dưới đáy màn hình Chi tiết biệt thự, bọc trong `SafeArea` chuẩn thiết bị di động.
///
/// Hiển thị tổng chi phí dự tính (hoặc giá khởi điểm / trạng thái liên hệ báo giá khi chưa xác minh giá),
/// nút nhắn tin trực tiếp với chủ nhà và nút kêu gọi hành động chính (`Đặt phòng ngay` / `Tư vấn Zalo`).
class BookingActionBar extends StatelessWidget {
  /// Thực thể biệt thự đang xem chi tiết.
  final Villa villa;

  /// Tổng chi phí thanh toán tạm tính bằng VNĐ cho khoảng ngày đã chọn (`null` nếu hiển thị đơn giá cơ sở).
  final int? totalCalculatedVnd;

  /// Tổng số đêm lưu trú đã chọn để hiển thị nhãn giải thích đi kèm tổng giá.
  final int? selectedNights;

  /// Hàm gọi lại khi người dùng bấm nút đặt phòng trực tiếp.
  final VoidCallback? onBookNow;

  /// Hàm gọi lại tùy chọn để mở luồng tư vấn qua Zalo.
  final VoidCallback? onInquireZalo;

  /// Hàm gọi lại khi bấm nút nhắn tin trực tiếp cho chủ nhà.
  final VoidCallback? onMessageHost;

  /// Hàm gọi lại dự phòng khi liên hệ qua tổng đài điện thoại.
  final VoidCallback? onCallHotline;

  /// Vô hiệu hóa nút đặt phòng chính (ví dụ đang gửi đơn hoặc chủ nhà xem căn của chính mình).
  final bool isDisabled;

  /// Nhãn thay thế trên nút đặt phòng khi ở trạng thái `isDisabled`.
  final String? disabledLabel;

  /// Khởi tạo thanh hành động đặt phòng `BookingActionBar`.
  const BookingActionBar({
    super.key,
    required this.villa,
    this.totalCalculatedVnd,
    this.selectedNights,
    this.onBookNow,
    this.onInquireZalo,
    this.onMessageHost,
    this.onCallHotline,
    this.isDisabled = false,
    this.disabledLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Price block on left
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PriceDisplay(
                      basePriceVnd: totalCalculatedVnd ?? villa.basePriceVnd,
                      showPerNightUnit: totalCalculatedVnd == null,
                      priceStyle: AppTypography.cardTitle.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      selectedNights != null && selectedNights! > 0
                          ? context.l10n.totalNightsWithFee(selectedNights!)
                          : (villa.instantBook
                              ? context.l10n.bookingInstantConfirm
                              : context.l10n.bookingSupport247),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Message host icon button (replaces phone hotline icon)
              AppIconButton(
                icon: const Icon(AppSemanticIcons.messageHost, size: 18),
                iconColor: AppColors.iconStrong,
                tooltip: context.l10n.villaDetailMessageHostTooltip,
                onPressed: onMessageHost ??
                    onCallHotline ??
                    () => context.push('/villa/${villa.id}/nhan-tin-host'),
              ),

              const SizedBox(width: 8),

              // Primary CTA button: Book Now (if provided) or Zalo Inquiry
              Expanded(
                flex: 5,
                child: AppButton(
                  text: isDisabled
                      ? (disabledLabel ?? context.l10n.ctaBookNow)
                      : (onBookNow != null
                          ? (villa.instantBook
                              ? context.l10n.ctaBookInstant
                              : context.l10n.ctaRequestBooking)
                          : context.l10n.ctaBookNow),
                  onPressed: isDisabled
                      ? null
                      : (onBookNow ??
                          onInquireZalo ??
                          () {
                            final msg = ContactService.buildZaloInquiryMessage(
                              villaName: villa.name,
                              villaCode: villa.code,
                            );
                            ContactService.openZaloInquiry(messageText: msg);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.ctaZaloCopied),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
