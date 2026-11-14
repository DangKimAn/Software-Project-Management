import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../villas/domain/entities/villa.dart';

/// Renders the villa description with international translation support
/// (English and Korean) and interactive "Show original / Show translation" toggle.
class VillaDescriptionSection extends StatefulWidget {
  final Villa villa;

  const VillaDescriptionSection({
    super.key,
    required this.villa,
  });

  @override
  State<VillaDescriptionSection> createState() => _VillaDescriptionSectionState();
}

class _VillaDescriptionSectionState extends State<VillaDescriptionSection> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.activeLanguageCode;
    final hasTranslation = widget.villa.hasTranslationFor(lang);
    final displayedText = (hasTranslation && !_showOriginal)
        ? widget.villa.descriptionDisplayFor(lang)
        : widget.villa.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.villaDetailAboutTitle,
          style: AppTypography.sectionHeading.copyWith(fontSize: 18),
        ),
        if (hasTranslation) ...[
          const SizedBox(height: 8),
          _buildTranslationPill(context, lang),
        ],
        const SizedBox(height: 10),
        Text(
          displayedText,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: 15,
            height: 1.55,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationPill(BuildContext context, String lang) {
    final l10n = context.l10n;
    final isShowingOriginal = _showOriginal;

    final badgeLabel = isShowingOriginal
        ? l10n.villaDetailOriginalBadge
        : l10n.villaDetailTranslatedBadge;
    final actionLabel = isShowingOriginal
        ? l10n.villaDetailShowTranslation
        : l10n.villaDetailShowOriginal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderSoft,
          width: 1,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          const Icon(
            LucideIcons.languages,
            size: 14,
            color: AppColors.textSecondary,
          ),
          Text(
            badgeLabel,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Text(
            '•',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _showOriginal = !_showOriginal;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
