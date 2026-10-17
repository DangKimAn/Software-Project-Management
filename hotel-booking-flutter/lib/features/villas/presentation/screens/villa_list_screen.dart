import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/animations/shimmer_loading.dart';
import '../../../../shared/animations/source_animations.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/vung_tau_map_picker.dart';
import '../../../search/presentation/widgets/source_search_bar.dart';
import '../widgets/property_card.dart';

/// Complete port of `Source goc/frontend/src/views/pages/Search/SearchPage.tsx`.
class VillaListScreen extends ConsumerStatefulWidget {
  const VillaListScreen({super.key});

  @override
  ConsumerState<VillaListScreen> createState() => _VillaListScreenState();
}

class _VillaListScreenState extends ConsumerState<VillaListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final ScrollVisibilityTracker _scrollTracker;
  bool _isHeaderVisible = true;
  bool _showInlineMap = false;

  @override
  void initState() {
    super.initState();
    _scrollTracker = ScrollVisibilityTracker(
      onChanged: (isVisible, _) {
        if (mounted && _isHeaderVisible != isVisible) {
          setState(() => _isHeaderVisible = isVisible);
        }
      },
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollTracker.onScroll(
      _scrollController.offset,
      MediaQuery.sizeOf(context).height,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(villaPaginatedProvider);
    final filter = ref.watch(villaFilterProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _isHeaderVisible
                ? const AppTopHeader(currentPath: '/search')
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(villaPaginatedProvider),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Search Bar & Filter Controls Header
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SourceSearchBar(
                                onSearchSubmitted: () =>
                                    ref.invalidate(villaPaginatedProvider),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        showStayFilterModal(context, ref),
                                    icon: const Icon(
                                      LucideIcons.slidersHorizontal,
                                      size: 16,
                                      color: AppColors.iconStrong,
                                    ),
                                    label: Text(
                                      filter.activeFilterCount > 0
                                          ? 'Bộ lọc (${filter.activeFilterCount})'
                                          : 'Bộ lọc',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(
                                      () => _showInlineMap = !_showInlineMap,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.map,
                                      size: 16,
                                      color: AppColors.iconStrong,
                                    ),
                                    label: Text(
                                      _showInlineMap
                                          ? 'Ẩn bản đồ Vũng Tàu'
                                          : 'Bản đồ Vũng Tàu',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => context.push('/ai-search'),
                                    icon: const Icon(
                                      LucideIcons.sparkles,
                                      size: 16,
                                      color: AppColors.iconStrong,
                                    ),
                                    label: const Text('Tìm bằng AI'),
                                  ),
                                  if (filter.searchQuery.isNotEmpty ||
                                      filter.locationGroup != null ||
                                      filter.lat != null ||
                                      filter.activeFilterCount > 0 ||
                                      filter.effectiveGuests > 0)
                                    TextButton(
                                      onPressed: () {
                                        ref
                                            .read(villaFilterProvider.notifier)
                                            .state = const VillaFilterState();
                                      },
                                      child: const Text(
                                        'Xóa toàn bộ lọc',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (_showInlineMap) ...[
                                const SizedBox(height: 14),
                                VungTauMapPicker(
                                  initialLat: filter.lat ??
                                      VungTauMapConstants.defaultLat,
                                  initialLng: filter.lng ??
                                      VungTauMapConstants.defaultLng,
                                  radiusMeters: filter.radius ??
                                      VungTauMapConstants.defaultRadiusMeters,
                                  height: 280,
                                  onLocationChanged: (lat, lng, label) {
                                    ref
                                        .read(villaFilterProvider.notifier)
                                        .update(
                                          (s) => s.copyWith(
                                            lat: lat,
                                            lng: lng,
                                            radius: VungTauMapConstants
                                                .defaultRadiusMeters,
                                            clearLocationGroup: true,
                                            page: 1,
                                          ),
                                        );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(height: 1, color: AppColors.border),
                  ),

                  // Results Grid + Pagination
                  paginatedAsync.when(
                    data: (result) {
                      final villas = result.items;
                      final pagination = result.pagination;

                      if (villas.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: AppEmptyView(
                              title: 'Không tìm thấy biệt thự phù hợp',
                              description:
                                  'Hãy thử xóa bộ lọc hoặc mở rộng khu vực tìm kiếm tại Vũng Tàu.',
                              actionText: 'Đặt lại bộ lọc',
                              onAction: () {
                                ref.read(villaFilterProvider.notifier).state =
                                    const VillaFilterState();
                              },
                            ),
                          ),
                        );
                      }

                      return SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tìm thấy ${pagination.totalItems} nơi lưu trú tại Vũng Tàu',
                                    style: AppTypography.cardTitle.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final cols = constraints.maxWidth >= 960
                                          ? 3
                                          : constraints.maxWidth >= 620
                                              ? 2
                                              : 1;
                                      const gap = 20.0;
                                      final cardW = (constraints.maxWidth -
                                              gap * (cols - 1)) /
                                          cols;
                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        children: List.generate(
                                          villas.length,
                                          (index) {
                                            final villa = villas[index];
                                            final isFav =
                                                favorites.contains(villa.id);
                                            return SizedBox(
                                              width: cardW,
                                              child: FadeSlideIn(
                                                delay: Duration(
                                                  milliseconds:
                                                      (index % 8) * 50,
                                                ),
                                                child: PropertyCard(
                                                  villa: villa,
                                                  isFavorite: isFav,
                                                  onFavoriteToggle: () {
                                                    ref
                                                        .read(
                                                          favoritesProvider
                                                              .notifier,
                                                        )
                                                        .toggleFavorite(
                                                          villa.id,
                                                        );
                                                  },
                                                  onTap: () => context.push(
                                                    '/villa/${villa.id}',
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  if (pagination.totalPages > 1) ...[
                                    const SizedBox(height: 28),
                                    Center(
                                      child: Wrap(
                                        spacing: 14,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          OutlinedButton(
                                            onPressed: pagination.hasPrev
                                                ? () {
                                                    ref
                                                        .read(
                                                          villaFilterProvider
                                                              .notifier,
                                                        )
                                                        .update(
                                                          (s) => s.copyWith(
                                                            page: s.page - 1,
                                                          ),
                                                        );
                                                  }
                                                : null,
                                            child: const Text('Trang trước'),
                                          ),
                                          Text(
                                            'Trang ${pagination.page} / ${pagination.totalPages}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: pagination.hasNext
                                                ? () {
                                                    ref
                                                        .read(
                                                          villaFilterProvider
                                                              .notifier,
                                                        )
                                                        .update(
                                                          (s) => s.copyWith(
                                                            page: s.page + 1,
                                                          ),
                                                        );
                                                  }
                                                : null,
                                            child: const Text('Trang sau'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, __) => const Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: ShimmerPropertyCard(),
                          ),
                          childCount: 3,
                        ),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(
                      child: AppErrorView(
                        message: err.toString(),
                        onRetry: () => ref.invalidate(villaPaginatedProvider),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: AppFooter()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
