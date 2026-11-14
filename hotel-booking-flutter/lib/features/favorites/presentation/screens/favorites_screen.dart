import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../villas/domain/entities/villa.dart';
import '../../../villas/presentation/widgets/property_card.dart';
export '../../../../app/di/providers.dart' show wishlistDetailProvider;

/// Màn hình danh sách biệt thự yêu thích (Wishlist) của người dùng và khách vãng lai.
///
/// Hợp nhất dữ liệu thời gian thực giữa trạng thái tim lạc quan (`favoritesProvider`),
/// danh sách tải từ máy chủ (`wishlistDetailProvider`) và bộ giải mã biệt thự ngoại trang
/// (`resolvedFavoriteVillasProvider`), đồng thời cảnh báo rõ các chỗ nghỉ ngừng hoạt động.
class FavoritesScreen extends ConsumerWidget {
  /// Khởi tạo màn hình danh sách yêu thích.
  const FavoritesScreen({super.key});

  /// Dựng giao diện danh sách biệt thự đã lưu theo lưới đáp ứng đa kích thước màn hình.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    final isAuthenticated =
        ref.watch(authNotifierProvider.select((s) => s.valueOrNull != null));
    final wishlistAsync = ref.watch(wishlistDetailProvider);
    final villasAsync = ref.watch(villaListProvider);
    final resolvedGuestVillasAsync = ref.watch(resolvedFavoriteVillasProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopHeader(currentPath: '/yeu-thich'),
            Expanded(
              child: villasAsync.when(
                data: (allVillas) {
                  // Giải thuật hợp nhất danh sách biệt thự yêu thích không trễ trạng thái (Zero-Stale Unheart Sync):
                  // 1. Khi đã đồng bộ backend hoặc người dùng vừa bấm bỏ tim, chỉ giữ các ID đang thuộc `validFavoriteIds`
                  //    (tuyệt đối không để `backendDetail.listingIds` cũ làm thẻ đã bỏ tim xuất hiện lại).
                  // 2. Với khách chưa đăng nhập, kết hợp thêm `resolvedFavoriteVillasProvider` để hiển thị cả các biệt thự ngoài trang 1.
                  final backendDetail = wishlistAsync.valueOrNull;
                  final invalidIds = PreferencesService.normalizeListingIds(
                    backendDetail?.invalidListingIds ?? const <String>[],
                  );
                  final invalidSet = invalidIds.toSet();
                  final validFavoriteIds = favorites
                      .where((id) =>
                          PreferencesService.isValidListingId(id) &&
                          !invalidSet.contains(id))
                      .toSet();

                  final extraResolved =
                      resolvedGuestVillasAsync.valueOrNull ?? const <Villa>[];

                  final byId = <String, Villa>{
                    for (final v in allVillas)
                      if (validFavoriteIds.contains(v.id)) v.id: v,
                    for (final v in extraResolved)
                      if (validFavoriteIds.contains(v.id)) v.id: v,
                    if (backendDetail != null)
                      for (final v in backendDetail.items)
                        if (!invalidSet.contains(v.id) &&
                            !favoritesNotifier.isRemovedInSession(v.id) &&
                            (validFavoriteIds.contains(v.id) ||
                                (!favoritesNotifier.hasSyncedBackend &&
                                    isAuthenticated &&
                                    backendDetail.listingIds.contains(v.id))))
                          v.id: v,
                  };
                  final savedVillas = byId.values.toList();

                  if (savedVillas.isEmpty &&
                      invalidIds.isEmpty &&
                      validFavoriteIds.isNotEmpty &&
                      resolvedGuestVillasAsync.isLoading) {
                    return const AppLoading(
                      message: 'Đang tải danh sách yêu thích...',
                    );
                  }

                  if (savedVillas.isEmpty && invalidIds.isEmpty) {
                    return AppEmptyView(
                      icon: LucideIcons.heart,
                      title: 'Chưa có biệt thự nào được lưu',
                      description:
                          'Bấm vào biểu tượng trái tim ở góc ảnh biệt thự để thêm vào danh sách yêu thích.',
                      actionText: 'Khám phá biệt thự',
                      onAction: () => context.go('/'),
                    );
                  }

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Danh sách yêu thích của bạn',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Đã lưu ${savedVillas.length} nơi lưu trú tại Vũng Tàu',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (wishlistAsync.hasError) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          AppSemanticIcons.errorAlert,
                                          size: 16,
                                          color: AppColors.iconMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Không đồng bộ được wishlist từ máy chủ. Dữ liệu lưu cục bộ vẫn được giữ.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(48, 48),
                                          ),
                                          onPressed: () => ref.invalidate(
                                              wishlistDetailProvider),
                                          child: const Text('Thử lại'),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (invalidIds.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          AppSemanticIcons.errorAlert,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Có ${invalidIds.length} nơi lưu trú đã lưu hiện không còn khả dụng hoặc đã ngừng hoạt động.',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  // Giải thuật chia lưới đáp ứng đa điểm ngắt (Responsive Breakpoint Grid):
                                  // Xác định số cột theo bề rộng khả dụng (>= 960px: 3 cột, >= 620px: 2 cột, < 620px: 1 cột)
                                  // và tính chiều rộng thẻ `cardW` trừ khoảng hở `gap` để dàn đều bằng `Wrap`.
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
                                        children: savedVillas.map((villa) {
                                          return SizedBox(
                                            width: cardW,
                                            child: PropertyCard(
                                              villa: villa,
                                              isFavorite: true,
                                              onFavoriteToggle: () {
                                                ref
                                                    .read(favoritesProvider
                                                        .notifier)
                                                    .toggleFavorite(villa.id);
                                              },
                                              onTap: () => context
                                                  .push('/villa/${villa.id}'),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => AppLoading(
                    message: context.l10n.loadingFavorites),
                error: (err, _) => AppErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(villaListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
