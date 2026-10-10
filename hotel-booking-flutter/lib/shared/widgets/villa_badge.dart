import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase.withValues(alpha: 0.95),
        borderRadius: AppRadii.roundedPill,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.8), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // 8% opacity black
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textStrong),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
