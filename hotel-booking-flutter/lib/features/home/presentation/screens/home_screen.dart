import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../blog/presentation/view_models/blog_view_model.dart';
import '../../../search/presentation/widgets/source_search_bar.dart';
import '../../../villas/domain/entities/villa.dart';
import '../view_models/home_view_model.dart';

export '../view_models/home_view_model.dart';

/// Màn hình Trang chủ kết hợp ảnh bìa lớn, thẻ tìm kiếm nổi, danh sách đã xem gần đây, điểm đến yêu thích và cẩm nang du lịch.
///
/// Tự động ghim thanh tìm kiếm thu gọn lên `AppTopHeader` khi người dùng cuộn qua vùng tìm kiếm chính ở đầu trang.
///
/// Complete 1:1 port of `Source goc/frontend/src/views/pages/Home/HomePage.tsx`,
/// `Hero.tsx`, `SearchBar.tsx` (`variant="home"`), `RecentlyViewedSection.tsx`,
/// `PopularDestinationsSection.tsx`, `PopularDestinationCard.tsx`, and `BlogHighlightsSection.tsx`.
class HomeScreen extends ConsumerStatefulWidget {
  /// Khởi tạo màn hình Trang chủ `HomeScreen`.
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _recentScrollController = ScrollController();
  final ScrollController _popularScrollController = ScrollController();
  final GlobalKey _bodySearchKey = GlobalKey();
  bool _isPinnedByScroll = false;
  bool _isScrolledPastHero = false;
  bool _isDestinationGridMode = false;
  int _destinationGridPage =
      0; // 0-indexed like `PopularDestinationsSection.tsx`
  static const int _destinationPageSize = 6;
  double _recentCardStepWidth = 220.0;
  double _popularCardStepWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // Giải thuật ghim thanh tìm kiếm theo ngưỡng cuộn dọc (Scroll-Threshold Header Pinning):
    // Phân biệt ngưỡng đổi nền thanh điều hướng (pastHero: 120px desktop / 80px mobile)
    // và ngưỡng ghim thanh tìm kiếm thu gọn lên đỉnh (searchTriggerOffset: 300px desktop / 200px mobile).
    final offset = _scrollController.offset;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 768;
    final pastHero = offset > (isDesktop ? 120.0 : 80.0);

    // Pin header search bar when scrolling past the hero search area (matches Airbnb / Header.tsx)
    final searchTriggerOffset = isDesktop ? 300.0 : 200.0;
    final isPinned = offset >= searchTriggerOffset;

    if ((pastHero != _isScrolledPastHero || isPinned != _isPinnedByScroll) &&
        mounted) {
      setState(() {
        _isScrolledPastHero = pastHero;
        _isPinnedByScroll = isPinned;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _recentScrollController.dispose();
    _popularScrollController.dispose();
    super.dispose();
  }

  void _scrollRecentlyViewed(int direction) {
    if (!_recentScrollController.hasClients) return;
    final position = _recentScrollController.position;
    final target = (position.pixels + (direction * _recentCardStepWidth))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _recentScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollPopularDestinations(int direction) {
    if (!_popularScrollController.hasClients) return;
    final position = _popularScrollController.position;
    final target = (position.pixels + (direction * _popularCardStepWidth))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _popularScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Exact greeting logic from `SearchBar.tsx` (`getGreetingByHour`).
  String _greetingByHour() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Sáng';
    if (hour >= 11 && hour < 13) return 'Trưa';
    if (hour >= 13 && hour < 18) return 'Chiều';
    return 'Tối';
  }

  String _greeting(String currentLocale) {
    if (currentLocale == 'vi') {
      return 'Chào buổi ${_greetingByHour()}!';
    }
    final l10n = lookupAppLocalizations(Locale(currentLocale));
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return l10n.greetingMorning;
    if (hour >= 12 && hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final popularVillasAsync = ref.watch(popularDestinationsProvider);
    final recentlyViewed = ref.watch(recentlyViewedProvider);
    final blogsAsync = ref.watch(blogHighlightsProvider);
    final shouldShowPinnedSearch = _isPinnedByScroll;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(popularDestinationsProvider);
              ref.invalidate(blogHighlightsProvider);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. Hero + Overlapping Floating Search Card (`Hero.tsx` + `SearchBar.tsx`)
                SliverToBoxAdapter(
                  child: _buildHeroAndSearchCard(context),
                ),

                // 2. Recently Viewed Section (`RecentlyViewedSection.tsx` + `ListingCard.tsx`)
                if (recentlyViewed.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildRecentlyViewedSection(context, recentlyViewed),
                  ),

                // 3. Popular Destinations Section (`PopularDestinationsSection.tsx` + `PopularDestinationCard.tsx`)
                SliverToBoxAdapter(
                  child: _buildPopularDestinationsSection(
                    context,
                    popularVillasAsync,
                  ),
                ),

                // 4. Blog Highlights Section (`BlogHighlightsSection.tsx` + `BlogPostCard.tsx`)
                SliverToBoxAdapter(
                  child: _buildBlogHighlightsSection(context, blogsAsync),
                ),

                // 5. Footer (`Footer.tsx`)
                const SliverToBoxAdapter(
                  child: AppFooter(),
                ),
              ],
            ),
          ),

          // Fixed / Overlay Top Header with Shrunk Center SearchBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppTopHeader(
              currentPath: '/',
              isOverlayTop: !_isScrolledPastHero && !shouldShowPinnedSearch,
              centerSearchTrigger: shouldShowPinnedSearch
                  ? SourceSearchBar(
                      isCompact: true,
                      isInHeader: true,
                      onSearchSubmitted: () => context.push('/tim-kiem'),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Matches `Hero.tsx` + `SearchBar.tsx` (`variant="home"`).
  Widget _buildHeroAndSearchCard(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 768;
    final heroHeight = isDesktop ? 390.0 : 215.0;
    final cardOverlap = isDesktop ? 84.0 : 56.0;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Hero Banner Image (`Hero.tsx`)
              SizedBox(
                height: heroHeight,
                width: double.infinity,
                child: const AppImage(
                  url: 'assets/images/NDT05929-HDR1.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment(0, 0.35),
                ),
              ),
              // Subtle top scrim for navbar legibility
              Container(
                height: heroHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      const Color(0xFF020617).withValues(alpha: 0.58),
                      const Color(0xFF020617).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating White Search Card (`SearchBar.tsx`)
          if (!_isDestinationGridMode)
            Transform.translate(
              offset: Offset(0, -cardOverlap),
              child: Padding(
                padding: EdgeInsets.only(
                  left: isDesktop ? 24 : 12,
                  right: isDesktop ? 24 : 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(isDesktop ? 32 : 28),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 32 : 12,
                        isDesktop ? 24 : 18,
                        isDesktop ? 32 : 12,
                        isDesktop ? 12 : 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _greeting(currentLocale),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isDesktop ? 34 : 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentLocale == 'vi'
                                ? 'Trân trọng được chào đón bạn tại thành phố biển Vũng Tàu'
                                : lookupAppLocalizations(Locale(currentLocale)).homeWelcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 13.5,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: isDesktop ? 18 : 14),
                          SourceSearchBar(
                            key: _bodySearchKey,
                            onSearchSubmitted: () => context.push('/tim-kiem'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Recently Viewed section styled consistently with Popular Destinations:
  /// single-row header (eyebrow + title on left, compact clear pill on right)
  /// and horizontal scrollable compact cards with `<` / `>` carousel buttons.
  Widget _buildRecentlyViewedSection(
    BuildContext context,
    List<RecentlyViewedItem> items,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 768;
    final favorites = ref.watch(favoritesProvider);
    final recentItems = items.take(8).toList();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 16,
        isDesktop ? 28 : 20,
        isDesktop ? 24 : 16,
        isDesktop ? 40 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1184),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // CONFLICT-RESOLVED: Kết hợp bố cục Expanded chống tràn chữ của HEAD với hỗ trợ đa ngôn ngữ động từ develop và giữ một nút xóa lịch sử duy nhất (_ClearRecentlyViewedButton).
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ref.watch(localeProvider) == 'vi'
                              ? 'LỊCH SỬ XEM'
                              : lookupAppLocalizations(
                                  Locale(ref.watch(localeProvider)),
                                ).homeRecentlyViewedTitle.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ref.watch(localeProvider) == 'vi'
                              ? 'Đã xem gần đây'
                              : lookupAppLocalizations(
                                  Locale(ref.watch(localeProvider)),
                                ).homeRecentlyViewedTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isDesktop ? 26 : 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ClearRecentlyViewedButton(
                    onTap: () =>
                        ref.read(recentlyViewedProvider.notifier).clear(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double cardW;
                  if (constraints.maxWidth >= 1100) {
                    cardW = (constraints.maxWidth - (16 * 3)) / 4;
                  } else if (constraints.maxWidth >= 820) {
                    cardW = (constraints.maxWidth - (16 * 2)) / 3;
                  } else if (constraints.maxWidth >= 540) {
                    cardW = (constraints.maxWidth - 14) / 2.4;
                  } else {
                    cardW = ((constraints.maxWidth - 12) / 2.15)
                        .clamp(150.0, 210.0);
                  }
                  _recentCardStepWidth = cardW + 12.0;

                  return SizedBox(
                    width: constraints.maxWidth,
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      clipBehavior: Clip.none,
                      children: [
                        SingleChildScrollView(
                          key: const ValueKey<String>(
                            'recently-viewed-horizontal-scroll',
                          ),
                          controller: _recentScrollController,
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < recentItems.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                SizedBox(
                                  width: cardW,
                                  child: _PopularDestinationCard
                                      .fromRecentlyViewed(
                                    item: recentItems[i],
                                    isFavorite:
                                        favorites.contains(recentItems[i].id),
                                    onFavoriteToggle: () {
                                      ref
                                          .read(favoritesProvider.notifier)
                                          .toggleFavorite(recentItems[i].id);
                                    },
                                    onTap: () => context
                                        .push('/villa/${recentItems[i].id}'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (recentItems.length > 2) ...[
                          Positioned(
                            left: -6,
                            child: _CarouselNavButton(
                              icon: LucideIcons.chevronLeft,
                              tooltip: 'Căn đã xem trước',
                              elevated: true,
                              onTap: () => _scrollRecentlyViewed(-1),
                            ),
                          ),
                          Positioned(
                            right: -6,
                            child: _CarouselNavButton(
                              icon: LucideIcons.chevronRight,
                              tooltip: 'Căn đã xem tiếp theo',
                              elevated: true,
                              onTap: () => _scrollRecentlyViewed(1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Popular Destinations section with visible top section header,
  /// arrow toggle on the right, and compact cards.
  Widget _buildPopularDestinationsSection(
    BuildContext context,
    AsyncValue<List<Villa>> villasAsync,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 768;
    final favorites = ref.watch(favoritesProvider);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 16,
        isDesktop ? 28 : 20,
        isDesktop ? 24 : 16,
        isDesktop ? 40 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1184),
          child: villasAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ref.watch(localeProvider) == 'vi'
                        ? 'Đang tải chỗ nghỉ ...'
                        : (ref.watch(localeProvider) == 'ko'
                            ? '숙소를 불러오는 중...'
                            : 'Loading stays...'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ),
            error: (err, _) => AppErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(popularDestinationsProvider),
            ),
            data: (villas) {
              final totalPages =
                  (villas.length / _destinationPageSize).ceil().clamp(1, 999);
              final safePageIndex =
                  _destinationGridPage.clamp(0, totalPages - 1);
              final featuredItems = villas.take(8).toList();
              final currentItems = villas
                  .skip(safePageIndex * _destinationPageSize)
                  .take(_destinationPageSize)
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header: Eyebrow + Title on left, arrow toggle on right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ref.watch(localeProvider) == 'vi'
                                  ? 'ĐIỂM ĐẾN NỔI BẬT'
                                  : (ref.watch(localeProvider) == 'ko'
                                      ? '주요 목적지'
                                      : 'FEATURED DESTINATIONS'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ref.watch(localeProvider) == 'vi'
                                  ? 'Điểm đến được yêu thích'
                                  : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homePopularDestinationsTitle,
                              style: TextStyle(
                                fontSize: isDesktop ? 26 : 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        label: _isDestinationGridMode
                            ? (ref.watch(localeProvider) == 'vi'
                                ? 'Thu gọn'
                                : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeShowLess)
                            : (ref.watch(localeProvider) == 'vi'
                                ? 'Xem tất cả'
                                : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeSeeMoreVillas),
                        child: Tooltip(
                          message: _isDestinationGridMode
                              ? (ref.watch(localeProvider) == 'vi'
                                  ? 'Thu gọn'
                                  : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeShowLess)
                              : (ref.watch(localeProvider) == 'vi'
                                  ? 'Xem tất cả'
                                  : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeSeeMoreVillas),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isDestinationGridMode =
                                    !_isDestinationGridMode;
                                _destinationGridPage = 0;
                              });
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  4,
                                  6,
                                ),
                                child: Icon(
                                  _isDestinationGridMode
                                      ? LucideIcons.chevronUp
                                      : LucideIcons.arrowRight,
                                  size: 20,
                                  color: AppColors.iconStrong,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (villas.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Chưa có chỗ nghỉ đã duyệt. Hãy đăng nhập host để tạo phòng, sau đó Admin duyệt để hiển thị tại đây.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    )
                  else if (!_isDestinationGridMode)
                    // Horizontal Scrollable Cards with side `<` and `>` navigation buttons
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double cardW;
                        if (constraints.maxWidth >= 1100) {
                          cardW = (constraints.maxWidth - (16 * 3)) / 4;
                        } else if (constraints.maxWidth >= 820) {
                          cardW = (constraints.maxWidth - (16 * 2)) / 3;
                        } else if (constraints.maxWidth >= 540) {
                          cardW = (constraints.maxWidth - 14) / 2.4;
                        } else {
                          cardW = ((constraints.maxWidth - 12) / 2.15)
                              .clamp(150.0, 210.0);
                        }
                        _popularCardStepWidth = cardW + 12.0;

                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            SingleChildScrollView(
                              controller: _popularScrollController,
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0;
                                      i < featuredItems.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(width: 12),
                                    SizedBox(
                                      width: cardW,
                                      child: _PopularDestinationCard(
                                        villa: featuredItems[i],
                                        isFavorite: favorites
                                            .contains(featuredItems[i].id),
                                        onFavoriteToggle: () {
                                          ref
                                              .read(favoritesProvider.notifier)
                                              .toggleFavorite(
                                                  featuredItems[i].id);
                                        },
                                        onTap: () => context.push(
                                            '/villa/${featuredItems[i].id}'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (featuredItems.length > 2) ...[
                              Positioned(
                                left: -6,
                                child: _CarouselNavButton(
                                  icon: LucideIcons.chevronLeft,
                                  tooltip: 'Căn trước',
                                  elevated: true,
                                  onTap: () => _scrollPopularDestinations(-1),
                                ),
                              ),
                              Positioned(
                                right: -6,
                                child: _CarouselNavButton(
                                  icon: LucideIcons.chevronRight,
                                  tooltip: 'Căn tiếp theo',
                                  elevated: true,
                                  onTap: () => _scrollPopularDestinations(1),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    )
                  else
                    // Expanded Grid View
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isDesktop ? 24 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Danh sách chỗ nghỉ đã duyệt',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF18181B),
                                ),
                              ),
                              Text(
                                'Trang ${safePageIndex + 1} / $totalPages',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cols = constraints.maxWidth >= 900
                                  ? 3
                                  : (constraints.maxWidth >= 480 ? 2 : 1);
                              const gap = 14.0;
                              final cardW =
                                  (constraints.maxWidth - (gap * (cols - 1))) /
                                      cols;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: currentItems.map((villa) {
                                  return SizedBox(
                                    width: cardW,
                                    child: _PopularDestinationCard(
                                      villa: villa,
                                      isFavorite: favorites.contains(villa.id),
                                      onFavoriteToggle: () {
                                        ref
                                            .read(favoritesProvider.notifier)
                                            .toggleFavorite(villa.id);
                                      },
                                      onTap: () =>
                                          context.push('/villa/${villa.id}'),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              _PillActionBtn(
                                label: ref.watch(localeProvider) == 'vi'
                                    ? 'Quay lại'
                                    : (ref.watch(localeProvider) == 'ko'
                                        ? '이전'
                                        : 'Back'),
                                leadingIcon: LucideIcons.arrowLeft,
                                enabled: safePageIndex > 0,
                                onTap: () {
                                  setState(() {
                                    _destinationGridPage = (safePageIndex - 1)
                                        .clamp(0, totalPages - 1);
                                  });
                                },
                              ),
                              _PillActionBtn(
                                label: ref.watch(localeProvider) == 'vi'
                                    ? 'Xem tiếp'
                                    : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeSeeNext,
                                trailingIcon: LucideIcons.arrowRight,
                                enabled: safePageIndex < totalPages - 1,
                                onTap: () {
                                  setState(() {
                                    _destinationGridPage = (safePageIndex + 1)
                                        .clamp(0, totalPages - 1);
                                  });
                                },
                              ),
                              _PillActionBtn(
                                label: ref.watch(localeProvider) == 'vi'
                                    ? 'Thu gọn'
                                    : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeShowLess,
                                enabled: true,
                                onTap: () {
                                  setState(() {
                                    _isDestinationGridMode = false;
                                    _destinationGridPage = 0;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Matches `BlogHighlightsSection.tsx` & `BlogPostCard.tsx` with solid white background and horizontal divider.
  Widget _buildBlogHighlightsSection(
    BuildContext context,
    AsyncValue<List<BlogPost>> blogsAsync,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 768;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2-Column Header (`BlogHighlightsSection.tsx`)
              Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.watch(localeProvider) == 'vi'
                            ? 'BÀI VIẾT MỚI'
                            : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeBlogBadge,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ref.watch(localeProvider) == 'vi'
                            ? 'Kinh nghiệm lưu trú nổi bật'
                            : lookupAppLocalizations(Locale(ref.watch(localeProvider))).homeBlogTitle,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: Color(0xFF020617),
                        ),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CONFLICT-RESOLVED: Giữ giới hạn dòng maxLines chống tràn của HEAD kết hợp chuỗi đa ngôn ngữ động từ develop.
                        Text(
                          ref.watch(localeProvider) == 'vi'
                              ? 'Nội dung tập trung vào nhu cầu thực tế khi đặt villa tại Vũng Tàu, từ nhóm gia đình đến nhóm bạn đông người.'
                              : lookupAppLocalizations(
                                  Locale(ref.watch(localeProvider)),
                                ).homeBlogSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => context.push('/cam-nang'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // CONFLICT-RESOLVED: Bọc Flexible chống tràn chữ trên màn hình nhỏ kết hợp bản dịch động từ develop.
                                Flexible(
                                  child: Text(
                                    ref.watch(localeProvider) == 'vi'
                                        ? 'Xem tất cả bài viết'
                                        : lookupAppLocalizations(
                                            Locale(ref.watch(localeProvider)),
                                          ).homeBlogSeeAll,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  LucideIcons.arrowRight,
                                  size: 14,
                                  color: AppColors.iconStrong,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              blogsAsync.when(
                loading: () => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      ref.watch(localeProvider) == 'vi'
                          ? 'Đang tải bài viết...'
                          : (ref.watch(localeProvider) == 'ko'
                              ? '글을 불러오는 중...'
                              : 'Loading articles...'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                error: (_, __) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    ref.watch(localeProvider) == 'vi'
                        ? 'Không tải được bài viết mới.'
                        : (ref.watch(localeProvider) == 'ko'
                            ? '새 글을 불러올 수 없습니다.'
                            : 'Unable to load new articles.'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          ref.watch(localeProvider) == 'vi'
                              ? 'Chưa có bài viết nổi bật.'
                              : (ref.watch(localeProvider) == 'ko'
                                  ? '추천 글이 아직 없습니다.'
                                  : 'No featured articles yet.'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 768 ? 3 : 1;
                      const gap = 20.0;
                      final cardW =
                          (constraints.maxWidth - (gap * (cols - 1))) / cols;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: posts.take(3).map((post) {
                          return SizedBox(
                            width: cardW,
                            child: _BlogPostCardWidget(
                              post: post,
                              onTap: () =>
                                  context.push('/cam-nang/${post.slug}'),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular `<` / `>` navigation button for horizontal villa carousels.
class _CarouselNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool elevated;

  const _CarouselNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFDDDDDD)),
                boxShadow: elevated
                    ? const [
                        BoxShadow(
                          color: Color(0x1F0F172A),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x0D0F172A),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.iconStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact right-aligned pill action for clearing recently viewed history
/// without wrapping below the section title.
class _ClearRecentlyViewedButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _ClearRecentlyViewedButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CONFLICT-RESOLVED: Chuyển _ClearRecentlyViewedButton sang ConsumerWidget để đồng bộ nhãn xóa lịch sử theo ngôn ngữ động từ develop.
    final currentLocale = ref.watch(localeProvider);
    final fullLabel = currentLocale == 'vi'
        ? 'Xóa lịch sử xem'
        : (currentLocale == 'ko' ? '기록 지우기' : 'Clear history');
    final shortLabel = currentLocale == 'vi' ? 'Xóa lịch sử' : fullLabel;
    return Semantics(
      button: true,
      label: fullLabel,
      child: Tooltip(
        message: fullLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
              maxWidth: 168,
            ),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Material(
                color: const Color(0xFFF8FAFC),
                shape: const StadiumBorder(
                  side: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey<String>('clear-recently-viewed-btn'),
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.trash2,
                          size: 13.5,
                          color: AppColors.iconMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            shortLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Popular Destination Card styled after the reference card UI (rounded card, top image with circular heart icon, title + mapPin location + price/rating).
class _PopularDestinationCard extends ConsumerWidget {
  final String title;
  final String location;
  final int? basePriceVnd;
  final double rating;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  _PopularDestinationCard({
    required Villa villa,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  })  : title = villa.name,
        location = villa.address.isNotEmpty
            ? villa.address
            : (villa.tagline.isNotEmpty ? villa.tagline : 'Vũng Tàu'),
        basePriceVnd = villa.basePriceVnd,
        rating = villa.rating,
        imageUrl = villa.imageUrls.isNotEmpty
            ? villa.imageUrls.first
            : 'assets/images/19tranphu.jpg';

  _PopularDestinationCard.fromRecentlyViewed({
    required RecentlyViewedItem item,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  })  : title = item.title,
        location = item.location.isNotEmpty ? item.location : 'Vũng Tàu',
        basePriceVnd = item.pricePerNight,
        rating = item.rating,
        imageUrl = item.imageUrl.isNotEmpty
            ? item.imageUrl
            : 'assets/images/19tranphu.jpg';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                    child: AppImage(
                      url: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Semantics(
                      button: true,
                      label: isFavorite ? 'Bỏ yêu thích' : 'Lưu yêu thích',
                      child: GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.heart,
                              size: 15,
                              color: isFavorite
                                  ? Colors.white
                                  : AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 13,
                        color: AppColors.iconMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatter.formatPriceOrContact(
                            basePriceVnd,
                            context: MoneyDisplayContext.villaCard,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.star,
                        size: 12,
                        color: AppColors.iconStrong,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

/// Exact port of `BlogPostCard.tsx` in Flat Minimal UI (no category badge box, no card border).
class _BlogPostCardWidget extends ConsumerWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const _BlogPostCardWidget({
    required this.post,
    required this.onTap,
  });

  @override
  // CONFLICT-RESOLVED: Kết hợp Semantics/ValueKey/Flexible chống tràn của HEAD với LocaleFormatters.localizeBlogPost đa ngôn ngữ động từ develop.
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final localizedPost = LocaleFormatters.localizeBlogPost(
      post,
      localeCode: currentLocale,
      l10n: context.l10n,
    );
    final displayReadTime = localizedPost.readTime;
    final displayCategory = localizedPost.category;
    final displayTitle = localizedPost.title;
    final displayExcerpt = localizedPost.excerpt;
    final displayLocation = localizedPost.location;

    return Semantics(
      button: true,
      label: '$displayTitle, $displayCategory',
      child: InkWell(
        key: ValueKey<String>('home-blog-card-${post.slug}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 192,
                width: double.infinity,
                child: AppImage(
                  url: post.coverImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayCategory,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (displayReadTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 132),
                          child: Text(
                            displayReadTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: Color(0xFF020617),
                    ),
                  ),
                  if (displayExcerpt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      displayExcerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: AppColors.iconStrong,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
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

class _PillActionBtn extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool enabled;
  final VoidCallback onTap;

  const _PillActionBtn({
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF18181B),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    trailingIcon,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
