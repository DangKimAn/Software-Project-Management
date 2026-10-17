import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/price_display.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';
import '../../../villas/domain/entities/villa.dart';

class BookingActionBar extends StatelessWidget {
  final Villa villa;
  final int? totalCalculatedVnd;
  final int? selectedNights;
  final VoidCallback? onBookNow;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onInquireZalo;
  final VoidCallback? onCallHotline;

  const BookingActionBar({
    super.key,
    required this.villa,
    this.totalCalculatedVnd,
    this.selectedNights,
    this.onBookNow,
    this.onAddToQueue,
    this.onInquireZalo,
    this.onCallHotline,
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
                          ? 'Tổng $selectedNights đêm • Đã gồm phí'
                          : (villa.instantBook
                              ? 'Đặt phòng xác nhận ngay'
                              : 'Tư vấn & Đặt phòng 24/7'),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Add to Queue (MultiBooking) button
              if (onAddToQueue != null)
                AppIconButton(
                  icon: const Icon(LucideIcons.shoppingBag, size: 18),
                  iconColor: AppColors.iconStrong,
                  tooltip: 'Thêm vào giỏ chờ đặt',
                  onPressed: onAddToQueue,
                ),

              // Hotline icon button (monochrome, no background circle)
              AppIconButton(
                icon: const Icon(LucideIcons.phone, size: 18),
                iconColor: AppColors.iconStrong,
                tooltip: 'Gọi hotline tư vấn',
                onPressed: onCallHotline ?? () => ContactService.callHotline(),
              ),

              const SizedBox(width: 8),

              // Primary CTA button: Book Now (if provided) or Zalo Inquiry
              Expanded(
                flex: 5,
                child: AppButton(
                  text: onBookNow != null
                      ? (villa.instantBook
                          ? 'Đặt phòng ngay'
                          : 'Gửi yêu cầu đặt')
                      : 'Tư vấn Zalo',
                  icon: Icon(
                    onBookNow != null
                        ? LucideIcons.calendarCheck
                        : LucideIcons.messageCircle,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: onBookNow ??
                      onInquireZalo ??
                      () {
                        final msg = ContactService.buildZaloInquiryMessage(
                          villaName: villa.name,
                          villaCode: villa.code,
                        );
                        ContactService.openZaloInquiry(messageText: msg);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Đã sao chép nội dung tư vấn và mở Zalo'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
