import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/villa_specs.dart';

/// Renders villa specifications in the EXACT order required by FLUTTER_RULES.md section 7.3:
/// 1. Phòng ngủ (X phòng, icon bed)
/// 2. Giường (Y giường, icon bed-double)
/// 3. Sức chứa (Z khách, icon users)
/// 4. WC (W WC, icon bath)
/// 5. Khoảng cách biển (N m tới biển, icon map-pin)
class PropertySpecsRow extends StatelessWidget {
  final VillaSpecs specs;
  final bool showBeachDistance;

  const PropertySpecsRow({
    super.key,
    required this.specs,
    this.showBeachDistance = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (specs.bedrooms > 0)
        _buildSpecItem(LucideIcons.bed, '${specs.bedrooms} phòng'),
      if (specs.beds > 0)
        _buildSpecItem(LucideIcons.bedDouble, '${specs.beds} giường'),
      if (specs.maxGuests > 0)
        _buildSpecItem(LucideIcons.users, '${specs.maxGuests} khách'),
      if (specs.bathrooms > 0)
        _buildSpecItem(LucideIcons.bath, '${specs.bathrooms} WC'),
      if (showBeachDistance &&
          specs.beachDistanceMeters != null &&
          specs.beachDistanceMeters! > 0)
        _buildSpecItem(
          LucideIcons.mapPin,
          '${specs.beachDistanceMeters}m tới biển',
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Uses Wrap to prevent RenderFlex overflow on small screens and large text scaling
    return Wrap(
      spacing: 14.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }

  Widget _buildSpecItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.iconMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
