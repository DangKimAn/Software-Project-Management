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

  String _formatWeekdayVi(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
      default:
        return 'CN';
    }
  }

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
            Expanded(
              child: Text(
                'Bảng giá theo từng đêm',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${nightlyPrices.length} đêm',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Constrained scrolling list (Flat Minimal - no outer box, no noisy row dividers)
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            primary: false,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: nightlyPrices.length,
            itemBuilder: (context, index) {
              final item = nightlyPrices[index];
              final weekdayVi =
                  _formatWeekdayVi(item.date.toDateTime().weekday);
              final dateLabel =
                  '${item.date.toDisplayString(format: 'dd/MM')} ($weekdayVi)';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              dateLabel,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14.5,
                                fontWeight: item.isWeekend
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (item.note != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.note!,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.isAvailable
                          ? CurrencyFormatter.formatVnd(item.priceVnd)
                          : 'Đã kín phòng',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
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
