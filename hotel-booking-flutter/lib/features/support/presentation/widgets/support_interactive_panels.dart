import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../domain/entities/support_page_models.dart';

/// Lưới khám phá 4 phân khu nghỉ dưỡng thực tế tại TP. Vũng Tàu.
/// Khi chạm vào một phân khu, hệ thống gán `locationGroup` vào `villaFilterProvider` và điều hướng tới `/tim-kiem`.
class VungTauZoneExplorerGrid extends ConsumerWidget {
  final List<VungTauZoneItem> zones;

  const VungTauZoneExplorerGrid({
    super.key,
    required this.zones,
  });

  // Giải thuật đồng bộ bộ lọc tìm kiếm theo phân khu địa lý (`locationGroup`):
  // Khởi tạo lại trạng thái bộ lọc sạch với đúng mã `locationGroup` được chọn để tránh xung đột
  // với các điều kiện lọc cũ (tọa độ bán kính hoặc từ khóa cũ) trước khi mở màn hình Tìm kiếm.
  void _openZoneListings(
    BuildContext context,
    WidgetRef ref,
    VungTauZoneItem zone,
  ) {
    ref.read(villaFilterProvider.notifier).state = VillaFilterState(
      locationGroup: zone.locationGroup,
    );
    context.push('/tim-kiem');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoCols = constraints.maxWidth >= 720;
        final cardWidth = isTwoCols
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: zones.map((zone) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppImage(
                        url: zone.assetImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 17,
                              color: AppColors.textStrong,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  LucideIcons.mapPin,
                                  size: 15,
                                  color: AppColors.iconMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  zone.distanceHint,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            zone.highlight,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            key: ValueKey('zone-explore-${zone.locationGroup}'),
                            onPressed: () =>
                                _openZoneListings(context, ref, zone),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textStrong,
                              minimumSize: const Size(48, 46),
                              shape: const StadiumBorder(),
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(
                              LucideIcons.arrowRight,
                              size: 16,
                              color: AppColors.iconStrong,
                            ),
                            label: Text(l10n.supportExploreZoneAction),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Lưới danh mục Tiện ích & Dịch vụ đi kèm kết nối trực tiếp bộ lọc `amenities` của `/tim-kiem`.
class AddonServiceExplorerGrid extends ConsumerWidget {
  final List<VillaServiceCategoryItem> services;

  const AddonServiceExplorerGrid({
    super.key,
    required this.services,
  });

  // Giải thuật áp dụng bộ lọc tiện nghi đơn mục (`amenityCode`) và chuyển sang trang Tìm kiếm:
  // Gán mảng tiện nghi gồm đúng mã được chọn để truy vấn các chỗ nghỉ thực tế có trang bị tiện ích đó.
  void _filterByAmenity(
    BuildContext context,
    WidgetRef ref,
    VillaServiceCategoryItem item,
  ) {
    ref.read(villaFilterProvider.notifier).state = VillaFilterState(
      amenities: <String>[item.amenityCode],
    );
    context.push('/tim-kiem');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoCols = constraints.maxWidth >= 720;
        final cardWidth = isTwoCols
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: services.map((service) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            service.icon,
                            size: 20,
                            color: AppColors.iconStrong,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            service.title,
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 16,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      service.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.supportServiceNotePrefix(service.bookingNote),
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      key: ValueKey('amenity-filter-${service.amenityCode}'),
                      onPressed: () => _filterByAmenity(context, ref, service),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textStrong,
                        minimumSize: const Size(48, 44),
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(
                        LucideIcons.search,
                        size: 15,
                        color: AppColors.iconStrong,
                      ),
                      label: Text(l10n.supportFilterByAmenityAction),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
