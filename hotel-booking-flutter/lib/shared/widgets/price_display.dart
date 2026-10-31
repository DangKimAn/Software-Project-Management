import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../l10n/l10n.dart';

class PriceDisplay extends StatelessWidget {
  final int? basePriceVnd;
  final int? saturdayPriceVnd;
  final bool showPerNightUnit;
  final TextStyle? priceStyle;
  final MoneyDisplayContext? displayContext;

  const PriceDisplay({
    super.key,
    required this.basePriceVnd,
    this.saturdayPriceVnd,
    this.showPerNightUnit = true,
    this.priceStyle,
    this.displayContext,
  });

  @override
  Widget build(BuildContext context) {
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
    if (basePriceVnd == null || basePriceVnd! <= 0) {
      return Text(
        l10n.contactForPrice,
        style: priceStyle ??
            AppTypography.cardTitle.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
      );
    }

    final resolvedContext = displayContext ??
        (showPerNightUnit
            ? MoneyDisplayContext.villaCard
            : MoneyDisplayContext.breakdown);
    final result = formatter.format(
      basePriceVnd!,
      context: resolvedContext,
    );
    final priceStr = result.formatted;
    final satStr = formatter.formatSaturdayRate(saturdayPriceVnd);

    const mutedAffixStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 13,
      color: AppColors.textMuted,
    );

    final List<InlineSpan> spans;
    if (showPerNightUnit) {
      final fullLabel = l10n.priceFrom(priceStr);
      final idx = fullLabel.indexOf(priceStr);
      if (idx >= 0) {
        final prefix = fullLabel.substring(0, idx);
        final suffix = fullLabel.substring(idx + priceStr.length);
        spans = <InlineSpan>[
          if (prefix.isNotEmpty) TextSpan(text: prefix, style: mutedAffixStyle),
          TextSpan(text: priceStr),
          if (suffix.isNotEmpty) TextSpan(text: suffix, style: mutedAffixStyle),
        ];
      } else {
        spans = <InlineSpan>[TextSpan(text: fullLabel)];
      }
    } else {
      spans = <InlineSpan>[TextSpan(text: priceStr)];
    }

    final semanticPrimary =
        showPerNightUnit ? l10n.priceFrom(priceStr) : priceStr;
    final semanticFull =
        satStr != null ? '$semanticPrimary, $satStr' : semanticPrimary;

    return Semantics(
      label: semanticFull,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              style: priceStyle ?? AppTypography.priceHighlight,
              children: spans,
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
      ),
    );
  }
}
