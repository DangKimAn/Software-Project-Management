import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/villas/domain/entities/villa.dart';

class VillaBadge extends StatelessWidget {
  final VillaBadgeType badgeType;

  const VillaBadge({super.key, required this.badgeType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label = badgeType.labelVi;

    switch (badgeType) {
      case VillaBadgeType.featured:
        icon = LucideIcons.sparkles;
        break;
      case VillaBadgeType.newVilla:
        icon = LucideIcons.sparkle;
        break;
      case VillaBadgeType.nearBeach:
        icon = LucideIcons.waves;
        break;
      case VillaBadgeType.saltwater:
        icon = LucideIcons.droplets;
        break;
      case VillaBadgeType.group:
        icon = LucideIcons.users;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.iconStrong),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
