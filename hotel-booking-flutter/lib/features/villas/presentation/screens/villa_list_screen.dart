import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/animations/shimmer_loading.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../widgets/property_card.dart';

class VillaListScreen extends ConsumerWidget {
  const VillaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final villasAsync = ref.watch(villaListProvider);
    final filter = ref.watch(villaFilterProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách biệt thự'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
            tooltip: 'Bộ lọc tìm kiếm',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter indicator bar if active
          if (filter.searchQuery.isNotEmpty || filter.minGuests != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceMuted,
              child: Row(
                children: [
                  const Icon(LucideIcons.filter,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang lọc: ${filter.searchQuery.isNotEmpty ? '"${filter.searchQuery}"' : ''} ${filter.minGuests != null ? 'từ ${filter.minGuests} khách' : ''}',
                      style: AppTypography.caption
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(villaFilterProvider.notifier).state =
                          const VillaFilterState();
                    },
                    child: const Text('Xóa lọc',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ],

          // List Body
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(villaListProvider),
              child: villasAsync.when(
                data: (villas) {
                  if (villas.isEmpty) {
                    return AppEmptyView(
                      title: 'Không tìm thấy biệt thự phù hợp',
                      description:
                          'Hãy thử xóa bộ lọc hoặc tìm kiếm theo từ khóa khác.',
                      actionText: 'Đặt lại bộ lọc',
                      onAction: () {
                        ref.read(villaFilterProvider.notifier).state =
                            const VillaFilterState();
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: villas.length,
                    itemBuilder: (context, index) {
                      final villa = villas[index];
                      final isFav = favorites.contains(villa.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: FadeSlideIn(
                          delay: Duration(milliseconds: (index % 8) * 60),
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
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (_, __) => const ShimmerPropertyCard(),
                ),
                error: (err, stack) => AppErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(villaListProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
