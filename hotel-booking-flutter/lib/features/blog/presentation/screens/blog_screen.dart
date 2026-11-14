import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_image.dart';
import '../view_models/blog_view_model.dart';

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
  String _debouncedQuery = '';
  int _currentPage = 1;
  Timer? _searchDebounce;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Giải thuật khử dấu tiếng Việt phục vụ tìm kiếm bài viết cẩm nang không phân biệt dấu và hoa thường.
  static String _foldAccents(String input) {
    const accented =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const plain =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      final idx = accented.indexOf(ch);
      buffer.write(idx >= 0 ? plain[idx] : ch);
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Giải thuật trì hoãn 300ms khi gõ từ khóa tìm kiếm để giảm tải truy vấn máy chủ mà vẫn lọc tức thời trên giao diện.
  void _onSearchChanged(String rawValue) {
    setState(() {});
    _searchDebounce?.cancel();
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      if (_debouncedQuery.isNotEmpty) {
        setState(() {
          _debouncedQuery = '';
          _currentPage = 1;
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final next = _searchCtrl.text.trim();
      if (_debouncedQuery != next) {
        setState(() {
          _debouncedQuery = next;
          _currentPage = 1;
        });
      }
    });
  }

  BlogQueryFilter get _activeFilter => BlogQueryFilter(
        category: _selectedCategory == 'Tất cả' ? null : _selectedCategory,
        query: _debouncedQuery.isEmpty ? null : _debouncedQuery,
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
    _searchDebounce?.cancel();
    setState(() {
      _selectedCategory = 'Tất cả';
      _debouncedQuery = '';
      _currentPage = 1;
      _searchCtrl.clear();
    });
  }

  void _retryFetch() {
    ref.invalidate(blogPaginatedProvider(_activeFilter));
    ref.invalidate(blogListProvider(_selectedCategory));
  }

  (String, String) _resolveErrorTitleAndMessage(
    Object err,
    BuildContext context,
    String localeCode,
  ) {
    final errorCopy = LocaleFormatters.localizeFailure(
      err,
      localeCode: localeCode,
      l10n: context.l10n,
    );
    if (err is AppFailure && err.message.trim().isNotEmpty) {
      return (errorCopy.title, err.message);
    }
    return (errorCopy.title, errorCopy.message);
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
    final localeCode = ref.watch(localeProvider);
    final loadedPosts = paginatedAsync.valueOrNull?.items ?? const <BlogPost>[];
    final categories = _buildCategoryList(loadedPosts);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 360 ? AppSpacing.md : 20.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
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
                                context.l10n.blogListBadge,
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                context.l10n.blogListHeroTitle,
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
                                  hintText: context.l10n.blogSearchHint,
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
                                          tooltip: context
                                              .l10n.blogClearSearchTooltip,
                                          icon: const Icon(
                                            LucideIcons.x,
                                            size: 18,
                                            color: AppColors.iconStrong,
                                          ),
                                          onPressed: () {
                                            _searchDebounce?.cancel();
                                            _searchCtrl.clear();
                                            setState(() {
                                              _debouncedQuery = '';
                                              _currentPage = 1;
                                            });
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
                                onChanged: _onSearchChanged,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              // Category Pill Chips (>=48dp touch height)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: categories.map((cat) {
                                    final selected = _selectedCategory == cat;
                                    final displayCat =
                                        LocaleFormatters.localizeBlogCategory(
                                      cat,
                                      localeCode: localeCode,
                                      l10n: context.l10n,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppSpacing.xs,
                                      ),
                                      child: Semantics(
                                        button: true,
                                        selected: selected,
                                        label: 'Chuyên mục $displayCat',
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
                                                    ? AppColors.primary
                                                    : AppColors.surfaceBase,
                                                borderRadius:
                                                    AppRadii.roundedPill,
                                                border: Border.all(
                                                  color: selected
                                                      ? AppColors.primary
                                                      : AppColors.borderSoft,
                                                ),
                                              ),
                                              child: Text(
                                                displayCat,
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
                      final query = _searchCtrl.text.trim();
                      final foldedQuery = _foldAccents(query);
                      final filtered = foldedQuery.isEmpty
                          ? posts
                          : posts
                              .where(
                                (p) =>
                                    _foldAccents(p.title)
                                        .contains(foldedQuery) ||
                                    _foldAccents(p.excerpt)
                                        .contains(foldedQuery) ||
                                    _foldAccents(p.category)
                                        .contains(foldedQuery) ||
                                    _foldAccents(p.location)
                                        .contains(foldedQuery),
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
                              title: context.l10n.blogEmptyTitle,
                              description: context.l10n.blogEmptyDescription,
                              actionText: hasActiveFilter
                                  ? context.l10n.blogClearFilters
                                  : null,
                              onAction: hasActiveFilter ? _resetFilters : null,
                            ),
                          ),
                        );
                      }

                      final showFeaturedHero = filtered.length >= 2 &&
                          _selectedCategory == 'Tất cả' &&
                          query.isEmpty &&
                          pagination.page == 1;

                      return SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: EdgeInsets.all(horizontalPad),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showFeaturedHero) ...[
                                    _FeaturedBlogBanner(
                                      post: filtered.first,
                                      onTap: () => context.push(
                                        '/blog/${filtered.first.slug}',
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                  ],
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
                            label: context.l10n.blogLoadingList,
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
                        context,
                        localeCode,
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
class BlogPostCard extends ConsumerWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const BlogPostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final localizedPost = LocaleFormatters.localizeBlogPost(
      post,
      localeCode: locale,
      l10n: context.l10n,
    );

    return Semantics(
      button: true,
      label: '${localizedPost.title}, ${localizedPost.category}',
      child: InkWell(
        key: ValueKey('blog-card-${localizedPost.slug}'),
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
                rawUrl: localizedPost.coverImage,
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
                            // CONFLICT-RESOLVED: Kết hợp dữ liệu đã bản địa hóa `localizedPost` từ `origin/develop` với ràng buộc `maxLines` chống tràn bố cục khi phóng chữ của nhánh refactor.
                            localizedPost.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ),
                        if (localizedPost.publishedAt.isNotEmpty)
                          Text(
                            localizedPost.publishedAt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (localizedPost.readTime.isNotEmpty)
                          Text(
                            localizedPost.readTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      localizedPost.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.38,
                        color: AppColors.textStrong,
                      ),
                    ),
                    if (localizedPost.excerpt.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        localizedPost.excerpt,
                        maxLines: 2,
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
                            localizedPost.location,
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
          label: context.l10n.blogPaginationPrev,
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
            label: context.l10n.blogPaginationPage(p),
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
                        ? AppColors.primary
                        : AppColors.surfaceBase,
                    borderRadius: AppRadii.roundedPill,
                    border: Border.all(
                      color: p == currentPage
                          ? AppColors.primary
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
          label: context.l10n.blogPaginationNext,
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

/// Khối bài viết nổi bật (Featured Hero) đầu trang Cẩm nang trên màn hình danh sách.
class _FeaturedBlogBanner extends ConsumerWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const _FeaturedBlogBanner({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final localizedPost = LocaleFormatters.localizeBlogPost(
      post,
      localeCode: locale,
      l10n: context.l10n,
    );
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    final imageBlock = BlogCoverImage(
      rawUrl: localizedPost.coverImage,
      aspectRatio: isWide ? 16 / 10 : 16 / 9,
      borderRadius: isWide
          ? const BorderRadius.horizontal(
              left: Radius.circular(AppRadii.card),
            )
          : const BorderRadius.vertical(
              top: Radius.circular(AppRadii.card),
            ),
    );

    final textBlock = Padding(
      padding: EdgeInsets.all(isWide ? AppSpacing.xxl : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadii.roundedPill,
                ),
                child: Text(
                  localizedPost.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (localizedPost.publishedAt.isNotEmpty)
                Text(
                  localizedPost.publishedAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              if (localizedPost.readTime.isNotEmpty)
                Text(
                  localizedPost.readTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizedPost.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayMedium.copyWith(
              fontSize: isWide ? 24 : 20,
              fontWeight: FontWeight.w800,
              height: 1.32,
              color: AppColors.textStrong,
            ),
          ),
          if (localizedPost.excerpt.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizedPost.excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMuted.copyWith(
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 16,
                color: AppColors.iconStrong,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  localizedPost.location,
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
                size: 18,
                color: AppColors.iconStrong,
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: localizedPost.title,
      child: InkWell(
        key: ValueKey('blog-featured-${localizedPost.slug}'),
        onTap: onTap,
        borderRadius: AppRadii.roundedCard,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadii.roundedCard,
            border: Border.all(color: AppColors.borderSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: isWide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: imageBlock),
                      Expanded(flex: 5, child: textBlock),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imageBlock,
                    textBlock,
                  ],
                ),
        ),
      ),
    );
  }
}
