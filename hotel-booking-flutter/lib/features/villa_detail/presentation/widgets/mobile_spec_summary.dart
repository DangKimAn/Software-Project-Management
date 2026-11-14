import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../villas/domain/entities/villa_specs.dart';

/// Khối tóm tắt thông số kỹ thuật hai tầng thu gọn / mở rộng dành cho trang Chi tiết biệt thự.
///
/// 2-tier specification summary conforming to FLUTTER_RULES.md section 8.1:
/// - 4 core specs when collapsed: Sức chứa → Phòng ngủ → Giường → WC
/// - 4 supporting specs when expanded: Hồ bơi riêng → Bếp/BBQ → Đậu xe → Khoảng cách biển
class MobileSpecSummary extends StatefulWidget {
  /// Bộ thông số kỹ thuật của căn biệt thự cần trình bày.
  final VillaSpecs specs;

  /// Khởi tạo khối thông số hai tầng `MobileSpecSummary`.
  const MobileSpecSummary({super.key, required this.specs});

  @override
  State<MobileSpecSummary> createState() => _MobileSpecSummaryState();
}

class _MobileSpecSummaryState extends State<MobileSpecSummary> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final specs = widget.specs;
    final coreEntries = <({IconData icon, String value, String label})>[
      if (specs.maxGuests > 0)
        (
          icon: LucideIcons.users,
          value: '${specs.maxGuests} khách',
          label: 'Sức chứa',
        ),
      if (specs.bedrooms > 0)
        (
          icon: LucideIcons.bed,
          value: '${specs.bedrooms} phòng',
          label: 'Phòng ngủ',
        ),
      if (specs.beds > 0)
        (
          icon: LucideIcons.bedDouble,
          value: '${specs.beds} giường',
          label: 'Giường',
        ),
      if (specs.bathrooms > 0)
        (
          icon: LucideIcons.bath,
          value: '${specs.bathrooms} WC',
          label: 'Phòng tắm',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coreEntries.isNotEmpty)
            // Giải thuật bố cục thích ứng 4 thông số cốt lõi theo bề rộng & cỡ chữ (FLUTTER_RULES §8.1):
            // Khi `maxWidth < 380` hoặc `textScale > 1.25`, chuyển sang lưới `Wrap` 2 cột để xuống dòng an toàn;
            // ở chế độ 1 hàng tiêu chuẩn, bọc từng cột bằng `Expanded` và nhãn bằng `Flexible` (`maxLines: 1, ellipsis`).
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final useTwoColumnGrid =
                    constraints.maxWidth < 380 || textScale > 1.25;
                if (useTwoColumnGrid) {
                  const colSpacing = 12.0;
                  final itemWidth = math.max(
                    0.0,
                    (constraints.maxWidth - colSpacing) / 2,
                  );
                  return Wrap(
                    spacing: colSpacing,
                    runSpacing: 12.0,
                    children: [
                      for (final entry in coreEntries)
                        SizedBox(
                          width: itemWidth,
                          child: _buildCoreItem(
                            entry.icon,
                            entry.value,
                            entry.label,
                            isSingleRow: false,
                          ),
                        ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < coreEntries.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _buildCoreItem(
                          coreEntries[i].icon,
                          coreEntries[i].value,
                          coreEntries[i].label,
                          isSingleRow: true,
                        ),
                      ),
                    ],
                  ],
                );
              },
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
                              specs.beachDistanceMeters != null &&
                                      specs.beachDistanceMeters! > 0
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _isExpanded
                              ? 'Thu gọn thông số'
                              : 'Xem thêm thông số chi tiết',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildCoreItem(
    IconData icon,
    String value,
    String label, {
    required bool isSingleRow,
  }) {
    if (isSingleRow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.iconStrong),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: AppColors.iconStrong),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textStrong,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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
