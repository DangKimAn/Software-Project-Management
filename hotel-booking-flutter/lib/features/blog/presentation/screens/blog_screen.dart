import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../data/blog_repository.dart';

/// Port of `Source goc/frontend/src/views/pages/Blog/BlogPage.tsx`
/// adhering to The Palm Light Luxury Design System (FLUTTER_RULES.md).
class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  static const List<String> _defaultCategories = [
    'Tất cả',
    'Cẩm nang du lịch',
    'Review Villa & Homestay',
    'Cẩm nang chuyến đi',
    'Kinh nghiệm đặt phòng',
    'Khám phá địa phương',
    'Mẹo lưu trú',
    'Villa gần biển',
    'Checklist đặt phòng',
  ];

  static const int _pageSize = 12;

  String _selectedCategory = 'Tất cả';
  int _currentPage = 1;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  BlogQueryFilter get _activeFilter => BlogQueryFilter(
        category: _selectedCategory == 'Tất cả' ? null : _selectedCategory,
        query: null,
        page: _currentPage,
        limit: _pageSize,
      );

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _currentPage = 1;
    });
  }

  void _goToPage(int page) {
    if (page == _currentPage || page < 1) return;
    setState(() {
      _currentPage = page;
    });
    if (_scrollController.hasClients && _scrollController.offset > 280) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'Tất cả';
      _currentPage = 1;
      _searchCtrl.clear();
    });
  }

  void _retryFetch() {
    ref.invalidate(blogPaginatedProvider(_activeFilter));
    ref.invalidate(blogListProvider(_selectedCategory));
  }

  (String, String) _resolveErrorTitleAndMessage(Object err) {
    if (err is NetworkFailure) {
      return ('Không có kết nối mạng', err.message);
    }
    if (err is ServerFailure) {
      return ('Lỗi máy chủ', err.message);
    }
    if (err is RateLimitFailure) {
      return ('Tạm thời quá tải', err.message);
    }
    if (err is AppFailure) {
      return ('Không thể tải danh sách bài viết', err.message);
    }
    return ('Không thể tải danh sách bài viết', err.toString());
  }

  List<String> _buildCategoryList(List<BlogPost> loadedPosts) {
    final seen = <String>{};
    final result = <String>[];
    for (final cat in _defaultCategories) {
      if (seen.add(cat)) {
        result.add(cat);
      }
    }
    for (final post in loadedPosts) {
      final c = post.category.trim();
      if (c.isNotEmpty && seen.add(c)) {
        result.add(c);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(blogPaginatedProvider(_activeFilter));
    final loadedPosts = paginatedAsync.valueOrNull?.items ?? const <BlogPost>[];
    final categories = _buildCategoryList(loadedPosts);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 360 ? AppSpacing.md : 20.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopHeader(currentPath: '/cam-nang'),
            Expanded(
              child: CustomScrollView(
                key: const PageStorageKey<String>('blog_list_scroll_view'),
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceBase,
                        border: Border(
                          bottom: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPad,
                        vertical: AppSpacing.xxl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CẨM NANG LƯU TRÚ VŨNG TÀU',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Kinh nghiệm lưu trú, lịch trình & bí quyết đặt Villa biển Vũng Tàu',
                                style: AppTypography.displayMedium.copyWith(
                                  fontSize: screenWidth < 360 ? 22 : 28,
                                  color: AppColors.textStrong,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              // Pill Search Field
                              TextField(
                                key: const ValueKey('blog-search-input'),
                                controller: _searchCtrl,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Tìm bài viết cẩm nang Vũng Tàu...',
                                  filled: true,
                                  fillColor: AppColors.surfaceBase,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 14,
                                  ),
                                  prefixIcon: const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: Icon(
                                        LucideIcons.search,
                                        size: 18,
                                        color: AppColors.iconMuted,
                                      ),
                                    ),
                                  ),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? AppIconButton(
                                          tooltip: 'Xóa từ khóa tìm kiếm',
                                          icon: const Icon(
                                            LucideIcons.x,
                                            size: 18,
                                            color: AppColors.iconStrong,
                                          ),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  border: const OutlineInputBorder(
                                    borderRadius: AppRadii.roundedPill,
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: AppRadii.roundedPill,
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: AppRadii.roundedPill,
                                    borderSide: BorderSide(
                                      color: AppColors.borderFocus,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              // Category Pill Chips (>=48dp touch height)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: categories.map((cat) {
                                    final selected = _selectedCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppSpacing.xs,
                                      ),
                                      child: Semantics(
                                        button: true,
                                        selected: selected,
                                        label: 'Chuyên mục $cat',
                                        child: InkWell(
                                          key: ValueKey('blog-category-$cat'),
                                          onTap: () => _selectCategory(cat),
                                          borderRadius: AppRadii.roundedPill,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight: 48,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.md,
                                                vertical: 10,
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? AppColors.textStrong
                                                    : AppColors.surfaceBase,
                                                borderRadius:
                                                    AppRadii.roundedPill,
                                                border: Border.all(
                                                  color: selected
                                                      ? AppColors.textStrong
                                                      : AppColors.borderSoft,
                                                ),
                                              ),
                                              child: Text(
                                                cat,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                  fontSize: 13,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: selected
                                                      ? AppColors.textInverse
                                                      : AppColors.textStrong,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  paginatedAsync.when(
                    data: (result) {
                      final posts = result.items;
                      final pagination = result.pagination;
                      final query = _searchCtrl.text.trim().toLowerCase();
                      final filtered = query.isEmpty
                          ? posts
                          : posts
                              .where(
                                (p) =>
                                    p.title.toLowerCase().contains(query) ||
                                    p.excerpt.toLowerCase().contains(query) ||
                                    p.category.toLowerCase().contains(query) ||
                                    p.location.toLowerCase().contains(query),
                              )
                              .toList();

                      if (filtered.isEmpty) {
                        final hasActiveFilter =
                            _selectedCategory != 'Tất cả' || query.isNotEmpty;
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxl,
                            ),
                            child: AppEmptyView(
                              title: 'Chưa có bài viết phù hợp',
                              description:
                                  'Hãy thử chọn chuyên mục khác hoặc từ khóa khác.',
                              actionText: hasActiveFilter ? 'Xóa bộ lọc' : null,
                              onAction: hasActiveFilter ? _resetFilters : null,
                            ),
                          ),
                        );
                      }

                      return SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: EdgeInsets.all(horizontalPad),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final cols = constraints.maxWidth >= 900
                                          ? 3
                                          : constraints.maxWidth >= 600
                                              ? 2
                                              : 1;
                                      const spacing = AppSpacing.lg;
                                      final cardWidth = (constraints.maxWidth -
                                              spacing * (cols - 1)) /
                                          cols;
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        children: filtered.map((post) {
                                          return SizedBox(
                                            width: cardWidth,
                                            child: BlogPostCard(
                                              post: post,
                                              onTap: () => context.push(
                                                '/blog/${post.slug}',
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                  if (pagination.totalPages > 1) ...[
                                    const SizedBox(height: AppSpacing.xxl),
                                    _BlogPaginationBar(
                                      pagination: pagination,
                                      onPageSelected: _goToPage,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Semantics(
                            label: 'Đang tải danh sách bài viết',
                            child: const CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (err, _) {
                      final (title, message) = _resolveErrorTitleAndMessage(
                        err,
                      );
                      return SliverToBoxAdapter(
                        child: AppErrorView(
                          title: title,
                          message: message,
                          onRetry: _retryFetch,
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: AppFooter()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stable aspect-ratio blog cover image that validates URLs and displays a clean
/// placeholder when the image URL is missing, invalid, or fails to load,
/// preventing layout shift (CLS / giật khối).
class BlogCoverImage extends StatelessWidget {
  final String rawUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;

  const BlogCoverImage({
    super.key,
    required this.rawUrl,
    this.aspectRatio = 16 / 10,
    this.borderRadius = AppRadii.roundedCard,
  });

  @override
  Widget build(BuildContext context) {
    final safeUrl = BlogContentSanitizer.sanitizeImageUrl(rawUrl);
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: safeUrl.isEmpty
            ? Container(
                key: const ValueKey('blog-cover-placeholder'),
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.image,
                  size: 28,
                  color: AppColors.iconMuted,
                ),
              )
            : AppImage(
                url: safeUrl,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

/// Blog post card adhering to Rule 4:
/// - Card radius 24dp (`AppRadii.roundedCard`), no heavy shadow.
/// - Fixed aspect ratio image (16:10) with placeholder fallback (zero layout jump).
/// - Flexible text layout supporting 320dp width and text scaling 1.0/1.3/1.6 without overflow.
class BlogPostCard extends StatelessWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const BlogPostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${post.title}, chuyên mục ${post.category}',
      child: InkWell(
        key: ValueKey('blog-card-${post.slug}'),
        onTap: onTap,
        borderRadius: AppRadii.roundedCard,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: AppRadii.roundedCard,
            border: Border.all(color: AppColors.borderSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlogCoverImage(
                rawUrl: post.coverImage,
                aspectRatio: 16 / 10,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.card),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceBase,
                            borderRadius: AppRadii.roundedPill,
                          ),
                          child: Text(
                            post.category,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ),
                        if (post.readTime.isNotEmpty)
                          Text(
                            post.readTime,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.38,
                        color: AppColors.textStrong,
                      ),
                    ),
                    if (post.excerpt.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        post.excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMuted.copyWith(
                          height: 1.55,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 15,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          LucideIcons.arrowUpRight,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlogPaginationBar extends StatelessWidget {
  final BlogPagination pagination;
  final ValueChanged<int> onPageSelected;

  const _BlogPaginationBar({
    required this.pagination,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentPage = pagination.page;
    final totalPages = pagination.totalPages;
    if (totalPages <= 1) return const SizedBox.shrink();
    final pages = <int>[];
    final start = (currentPage - 2).clamp(1, totalPages);
    final end = (currentPage + 2).clamp(1, totalPages);
    for (var p = start; p <= end; p++) {
      pages.add(p);
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: pagination.hasPreviousPage,
          label: 'Trang trước',
          child: OutlinedButton(
            key: const ValueKey('blog-page-prev'),
            onPressed: pagination.hasPreviousPage
                ? () => onPageSelected(currentPage - 1)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              side: BorderSide(
                color: pagination.hasPreviousPage
                    ? AppColors.border
                    : AppColors.borderSoft,
              ),
            ),
            child: const Text('<'),
          ),
        ),
        for (final p in pages)
          Semantics(
            button: true,
            selected: p == currentPage,
            label: 'Trang $p',
            child: InkWell(
              key: ValueKey('blog-page-$p'),
              onTap: p == currentPage ? null : () => onPageSelected(p),
              borderRadius: AppRadii.roundedPill,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == currentPage
                        ? AppColors.textStrong
                        : AppColors.surfaceBase,
                    borderRadius: AppRadii.roundedPill,
                    border: Border.all(
                      color: p == currentPage
                          ? AppColors.textStrong
                          : AppColors.borderSoft,
                    ),
                  ),
                  child: Text(
                    '$p',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p == currentPage
                          ? AppColors.textInverse
                          : AppColors.textStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Semantics(
          button: true,
          enabled: pagination.hasNextPage,
          label: 'Trang sau',
          child: OutlinedButton(
            key: const ValueKey('blog-page-next'),
            onPressed: pagination.hasNextPage
                ? () => onPageSelected(currentPage + 1)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              side: BorderSide(
                color: pagination.hasNextPage
                    ? AppColors.border
                    : AppColors.borderSoft,
              ),
            ),
            child: const Text('>'),
          ),
        ),
      ],
    );
  }
}
