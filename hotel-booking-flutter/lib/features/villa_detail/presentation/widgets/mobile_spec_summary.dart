import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../villas/domain/entities/villa_specs.dart';

/// 2-tier specification summary conforming to FLUTTER_RULES.md section 8.1:
/// - 4 core specs when collapsed: Sức chứa → Phòng ngủ → Giường → WC
/// - 4 supporting specs when expanded: Hồ bơi riêng → Bếp/BBQ → Đậu xe → Khoảng cách biển
class MobileSpecSummary extends StatefulWidget {
  final VillaSpecs specs;

  const MobileSpecSummary({super.key, required this.specs});

  @override
  State<MobileSpecSummary> createState() => _MobileSpecSummaryState();
}

class _MobileSpecSummaryState extends State<MobileSpecSummary> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final specs = widget.specs;
    final l10n = context.l10n;
    final coreItems = <Widget>[
      if (specs.maxGuests > 0)
        _buildCoreItem(
          LucideIcons.users,
          l10n.specGuestsCount(specs.maxGuests),
          l10n.specCapacityLabel,
        ),
      if (specs.bedrooms > 0)
        _buildCoreItem(
          LucideIcons.bed,
          l10n.specBedroomsCount(specs.bedrooms),
          l10n.specBedroomsLabel,
        ),
      if (specs.beds > 0)
        _buildCoreItem(
          LucideIcons.bedDouble,
          l10n.specBedsCount(specs.beds),
          l10n.specBedsLabel,
        ),
      if (specs.bathrooms > 0)
        _buildCoreItem(
          LucideIcons.bath,
          l10n.specBathsCount(specs.bathrooms),
          l10n.specBathroomsLabel,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coreItems.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: coreItems,
            ),

          // Expandable Supporting Specs
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: AppColors.borderSoft),
                      ),
                      Text(
                        l10n.specHighlightsTitle,
                        style: AppTypography.cardTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      // 4 supporting specs in 2-column grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildSupportingItem(
                              LucideIcons.waves,
                              specs.hasSaltwaterPool
                                  ? l10n.specSaltwaterPool
                                  : (specs.hasPrivatePool
                                      ? l10n.specPrivatePool
                                      : l10n.specNoPool),
                            ),
                          ),
                          Expanded(
                            child: _buildSupportingItem(
                              LucideIcons.utensils,
                              specs.hasBbqKitchen
                                  ? l10n.specBbqKitchen
                                  : l10n.specBasicKitchen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSupportingItem(
                              LucideIcons.car,
                              specs.hasParking
                                  ? l10n.specParking
                                  : l10n.specSelfParking,
                            ),
                          ),
                          Expanded(
                            child: _buildSupportingItem(
                              LucideIcons.mapPin,
                              specs.beachDistanceMeters != null &&
                                      specs.beachDistanceMeters! > 0
                                  ? l10n.specBeachDistance(
                                      specs.beachDistanceMeters!)
                                  : l10n.specNearCenter,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),

          // Toggle Expand / Collapse button
          Center(
            child: InkWell(
              onTap: () {
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded
                            ? l10n.specCollapseAction
                            : l10n.specExpandAction,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 16,
                        color: AppColors.iconStrong,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: AppColors.iconStrong),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textStrong,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportingItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.iconStrong),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
