import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/formatters/currency_formatter.dart';

class PriceDisplay extends StatelessWidget {
  final int? basePriceVnd;
  final int? saturdayPriceVnd;
  final bool showPerNightUnit;
  final TextStyle? priceStyle;

  const PriceDisplay({
    super.key,
    required this.basePriceVnd,
    this.saturdayPriceVnd,
    this.showPerNightUnit = true,
    this.priceStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (basePriceVnd == null || basePriceVnd! <= 0) {
      return Text(
        'Liên hệ báo giá',
        style: priceStyle ??
            AppTypography.cardTitle.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
      );
    }

    final priceStr = CurrencyFormatter.formatVnd(basePriceVnd);
    final satStr = CurrencyFormatter.formatSaturdayPrice(saturdayPriceVnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: priceStyle ?? AppTypography.priceHighlight,
            children: [
              const TextSpan(
                text: 'Từ ',
                style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.textMuted),
              ),
              TextSpan(text: priceStr),
              if (showPerNightUnit) ...[
                const TextSpan(
                  text: ' / đêm',
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
        if (satStr != null) ...[
          const SizedBox(height: 2),
          Text(
            satStr,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
