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
  final VoidCallback? onInquireZalo;
  final VoidCallback? onCallHotline;

  const BookingActionBar({
    super.key,
    required this.villa,
    this.onInquireZalo,
    this.onCallHotline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
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
                      basePriceVnd: villa.basePriceVnd,
                      priceStyle: AppTypography.cardTitle.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tư vấn trực tiếp 24/7',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Action buttons on right
              // Hotline icon button
              AppIconButton(
                icon: const Icon(LucideIcons.phone, size: 18),
                backgroundColor: AppColors.surfaceMuted,
                iconColor: AppColors.textStrong,
                tooltip: 'Gọi hotline tư vấn',
                onPressed: onCallHotline ?? () => ContactService.callHotline(),
              ),

              const SizedBox(width: 8),

              // Zalo primary CTA button
              Expanded(
                flex: 5,
                child: AppButton(
                  text: 'Tư vấn Zalo',
                  icon: const Icon(LucideIcons.messageCircle, size: 18),
                  onPressed: onInquireZalo ??
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
