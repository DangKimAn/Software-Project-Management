import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.roundedCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row of 4 Core Specs: Sức chứa → Phòng ngủ → Giường → WC
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCoreItem(
                  LucideIcons.users, '${specs.maxGuests} khách', 'Sức chứa'),
              _buildCoreItem(
                  LucideIcons.bed, '${specs.bedrooms} phòng', 'Phòng ngủ'),
              _buildCoreItem(
                  LucideIcons.bedDouble, '${specs.beds} giường', 'Giường'),
              _buildCoreItem(
                  LucideIcons.bath, '${specs.bathrooms} WC', 'Phòng tắm'),
            ],
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
                        'Tiện ích nổi bật & Vị trí',
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
                                  ? 'Hồ bơi nước mặn'
                                  : (specs.hasPrivatePool
                                      ? 'Hồ bơi riêng'
                                      : 'Không có hồ bơi'),
                            ),
                          ),
                          Expanded(
                            child: _buildSupportingItem(
                              LucideIcons.utensils,
                              specs.hasBbqKitchen
                                  ? 'Bếp & Lò BBQ đầy đủ'
                                  : 'Bếp cơ bản',
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
                                  ? 'Chỗ đậu xe ô tô'
                                  : 'Đậu xe tự túc',
                            ),
                          ),
                          Expanded(
                            child: _buildSupportingItem(
                              LucideIcons.mapPin,
                              specs.beachDistanceMeters != null
                                  ? '${specs.beachDistanceMeters}m ra bãi tắm'
                                  : 'Gần trung tâm',
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
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isExpanded
                          ? 'Thu gọn thông số'
                          : 'Xem thêm thông số chi tiết',
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
                      color: AppColors.primary,
                    ),
                  ],
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
        Icon(icon, size: 22, color: AppColors.textStrong),
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
        Icon(icon, size: 16, color: AppColors.primary),
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
