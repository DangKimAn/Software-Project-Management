import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/villas/domain/entities/villa.dart';

/// Huy hiệu phân loại nổi bật duy nhất trên góc thẻ biệt thự (`featured > new > near-beach > saltwater > group`).
///
/// Ánh xạ từng phân loại `VillaBadgeType` sang biểu tượng `LucideIcons` tương ứng và cắt gọn 1 dòng chống tràn bố cục trên màn hình hẹp.
class VillaBadge extends StatelessWidget {
  final VillaBadgeType badgeType;

  const VillaBadge({super.key, required this.badgeType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label = badgeType.labelVi;

    switch (badgeType) {
      case VillaBadgeType.featured:
        icon = LucideIcons.award;
        break;
      case VillaBadgeType.newVilla:
        icon = LucideIcons.badgeCheck;
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
