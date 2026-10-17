import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../villas/domain/entities/nightly_price.dart';

/// Price list component constrained in height to ensure sticky action bar is NEVER pushed off-screen.
///
/// Adheres strictly to FLUTTER_RULES.md section 10:
/// - Max height ~220 logical px on phone, ~248 on tablet.
/// - Uses ConstrainedBox + ListView.builder(shrinkWrap: true, primary: false).
/// - 1-4 nights shrinks naturally; 10-20 nights scrolls independently.
class DailyPriceBreakdown extends StatelessWidget {
  final List<NightlyPrice> nightlyPrices;
  final bool isTablet;

  const DailyPriceBreakdown({
    super.key,
    required this.nightlyPrices,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    if (nightlyPrices.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxHeight = isTablet
        ? AppConstants.maxPriceBreakdownHeightTablet
        : AppConstants.maxPriceBreakdownHeightPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bảng giá theo từng đêm',
              style: AppTypography.cardTitle.copyWith(fontSize: 15),
            ),
            Text(
              '${nightlyPrices.length} đêm',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Constrained scrolling list (Flat Minimal - no outer box)
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.separated(
            primary: false,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: nightlyPrices.length,
            separatorBuilder: (_, __) => const Divider(
              color: AppColors.borderSoft,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = nightlyPrices[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.date.toDisplayString(format: 'dd/MM (EEE)'),
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: item.isWeekend
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: item.isWeekend
                                ? AppColors.primary
                                : AppColors.textStrong,
                          ),
                        ),
                        if (item.note != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            item.note!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      item.isAvailable
                          ? CurrencyFormatter.formatVnd(item.priceVnd)
                          : 'Đã kín phòng',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: item.isAvailable
                            ? AppColors.textStrong
                            : AppColors.errorRed,
                        decoration: item.isAvailable
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
