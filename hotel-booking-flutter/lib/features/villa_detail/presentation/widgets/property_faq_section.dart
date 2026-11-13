import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';

class PropertyFaqSection extends StatelessWidget {
  const PropertyFaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final faqs = [
      (l10n.faqCheckInTitle, l10n.faqCheckInBody),
      (l10n.faqNoiseTitle, l10n.faqNoiseBody),
      (l10n.faqKitchenTitle, l10n.faqKitchenBody),
      (l10n.faqDepositTitle, l10n.faqDepositBody),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.rulesAndFaqTitle,
          style: AppTypography.sectionHeading.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Column(
          children: faqs.asMap().entries.map((entry) {
            final idx = entry.key;
            final faq = entry.value;
            final isLast = idx == faqs.length - 1;

            return Column(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(vertical: 6),
                    title: Text(
                      faq.$1,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textStrong,
                        height: 1.4,
                      ),
                    ),
                    iconColor: AppColors.iconStrong,
                    collapsedIconColor: AppColors.iconMuted,
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.$2,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(color: AppColors.borderSoft, height: 1),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
