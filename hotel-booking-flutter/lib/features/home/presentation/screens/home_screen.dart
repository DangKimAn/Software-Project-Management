import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/animations/pressable_scale.dart';
import '../../../../shared/animations/shimmer_loading.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';
import '../../../villas/domain/entities/villa.dart';
import '../../../villas/presentation/widgets/property_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final villasAsync = ref.watch(villaListProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minh Thanh Villa',
              style: AppTypography.sectionHeading.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Biệt thự nghỉ dưỡng cao cấp Vũng Tàu',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          AppIconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            tooltip: 'Cài đặt & Ngôn ngữ',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(villaListProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Search Prompt Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildSearchBar(context),
              ),
            ),

            // Quick Category Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildQuickCategories(context, ref),
              ),
            ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Biệt thự nổi bật',
                      style:
                          AppTypography.sectionHeading.copyWith(fontSize: 19),
                    ),
                    TextButton(
                      onPressed: () => context.push('/villas'),
                      child: Text(
                        'Xem tất cả',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Villa List Content
            villasAsync.when(
              data: (villas) {
                if (villas.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyView(
                      title: 'Chưa có biệt thự nào',
                      description: 'Vui lòng thử lại với bộ lọc khác.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final villa = villas[index];
                        final isFav = favorites.contains(villa.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: (index % 6) * 60),
                            child: PropertyCard(
                              villa: villa,
                              isFavorite: isFav,
                              onFavoriteToggle: () {
                                ref
                                    .read(favoritesProvider.notifier)
                                    .toggleFavorite(villa.id);
                              },
                              onTap: () => context.push('/villas/${villa.id}'),
                            ),
                          ),
                        );
                      },
                      childCount: villas.length,
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 20.0),
                      child: ShimmerPropertyCard(),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (err, stack) => SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(villaListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Quick Contact Actions (Zalo & Hotline)
      floatingActionButton: _buildFloatingActions(context),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/search'),
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: AppRadii.roundedPill,
          border: Border.all(color: AppColors.borderStrong),
          boxShadow: const [AppColors.shadowGlass],
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bắt đầu tìm kiếm...',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textStrong,
                    ),
                  ),
                  Text(
                    'Vũng Tàu • Bãi Sau, Bãi Trước • Chọn ngày',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.slidersHorizontal,
                  size: 16, color: AppColors.textStrong),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCategories(BuildContext context, WidgetRef ref) {
    final categories = [
      ('Tất cả', null, null),
      ('Gần biển', VillaBadgeType.nearBeach, null),
      ('Nước mặn', VillaBadgeType.saltwater, null),
      ('Đoàn đông', VillaBadgeType.group, 20),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(cat.$1),
              backgroundColor: AppColors.surfaceBase,
              side: const BorderSide(color: AppColors.borderSoft),
              labelStyle: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
              onPressed: () {
                ref.read(villaFilterProvider.notifier).state =
                    VillaFilterState(minGuests: cat.$3);
                context.push('/villas');
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hotline Button
        FloatingActionButton.extended(
          heroTag: 'fab_hotline',
          backgroundColor: AppColors.surfaceBase,
          foregroundColor: AppColors.textStrong,
          elevation: 3,
          onPressed: () => ContactService.callHotline(),
          icon: const Icon(LucideIcons.phone, size: 18),
          label: const Text('Hotline',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        // Zalo Button
        FloatingActionButton.extended(
          heroTag: 'fab_zalo',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          onPressed: () {
            const msg =
                'Xin chào Minh Thanh Villa, tôi muốn tìm hiểu thông tin biệt thự nghỉ dưỡng tại Vũng Tàu.';
            ContactService.openZaloInquiry(messageText: msg);
          },
          icon: const Icon(LucideIcons.messageCircle, size: 18),
          label:
              const Text('Zalo', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
