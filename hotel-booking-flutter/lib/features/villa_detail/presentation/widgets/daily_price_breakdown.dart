import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/l10n.dart';
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

    final hasProviderScope =
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    if (!hasProviderScope) {
      return _buildWithFormatter(
        context,
        MoneyFormatter(localeCode: context.activeLanguageCode),
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final formatter = ref.watch(moneyFormatterProvider);
        return _buildWithFormatter(context, formatter);
      },
    );
  }

  Widget _buildWithFormatter(BuildContext context, MoneyFormatter formatter) {
    final l10n = formatter.l10n;
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
                l10n.dailyPriceBreakdownTitle,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.nightsCount(nightlyPrices.length),
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
              final dateLabel = LocaleFormatters.formatNightlyDateWithWeekday(
                item.date,
                localeCode: formatter.localeCode,
              );
              final priceText = item.isAvailable
                  ? formatter
                      .format(
                        item.priceVnd,
                        context: MoneyDisplayContext.priceDetail,
                      )
                      .formatted
                  : l10n.statusBooked;

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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      priceText,
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
