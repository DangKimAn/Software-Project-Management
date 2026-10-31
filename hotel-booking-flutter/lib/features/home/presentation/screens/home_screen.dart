import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../blog/data/blog_repository.dart';
import '../../../search/presentation/widgets/source_search_bar.dart';
import '../../../villas/domain/entities/villa.dart';

/// Dedicated provider for Popular Destinations on HomeScreen (`PopularDestinationsSection.tsx`)
/// independent of `villaFilterProvider` / `villaListProvider` so Search filters never pollute Home.
final popularDestinationsProvider = FutureProvider<List<Villa>>((ref) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getVillas(
    page: 1,
    limit: 36,
    sort: 'newest',
  );
});

/// Complete 1:1 port of `Source goc/frontend/src/views/pages/Home/HomePage.tsx`,
/// `Hero.tsx`, `SearchBar.tsx` (`variant="home"`), `RecentlyViewedSection.tsx`,
/// `PopularDestinationsSection.tsx`, `PopularDestinationCard.tsx`, and `BlogHighlightsSection.tsx`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _popularScrollController = ScrollController();
  final GlobalKey _bodySearchKey = GlobalKey();
  bool _isPinnedByScroll = false;
  bool _isScrolledPastHero = false;
  bool _isDestinationGridMode = false;
  int _destinationGridPage =
      0; // 0-indexed like `PopularDestinationsSection.tsx`
  static const int _destinationPageSize = 6;
  double _popularCardStepWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
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
    _popularScrollController.dispose();
    super.dispose();
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
                            'Chào buổi ${_greetingByHour()}!',
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
                            'Trân trọng được chào đón bạn tại thành phố biển Vũng Tàu',
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

  /// Matches `RecentlyViewedSection.tsx` & `ListingCard.tsx` (`bg-white py-12 sm:py-14`, `max-w-[74rem]`, `rounded-3xl`).
  Widget _buildRecentlyViewedSection(
    BuildContext context,
    List<RecentlyViewedItem> items,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1184),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LỊCH SỬ XEM',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Đã xem gần đây',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Color(0xFF18181B),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(recentlyViewedProvider.notifier).clear(),
                    child: const Text(
                      'Xóa lịch sử xem',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 1024
                      ? 4
                      : (constraints.maxWidth >= 720
                          ? 3
                          : (constraints.maxWidth >= 480 ? 2 : 1));
                  const gap = 16.0;
                  final cardWidth =
                      (constraints.maxWidth - (gap * (cols - 1))) / cols;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: items.take(8).map((item) {
                      return SizedBox(
                        width: cardWidth,
                        child: _ListingCardWidget(
                          id: item.id,
                          name: item.title,
                          address: item.location,
                          pricePerNight: item.pricePerNight,
                          rating: item.rating,
                          imageUrl: item.imageUrl,
                          onTap: () => context.push('/villa/${item.id}'),
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
    );
  }

  /// Popular Destinations section with visible top section header,
  /// "Xem tất cả >" toggle on the right, and compact cards.
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
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Đang tải chỗ nghỉ ...',
                    style: TextStyle(
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
                  // Section Header: Eyebrow + Title + Subtitle on left, "Xem tất cả >" on right
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ĐIỂM ĐẾN NỔI BẬT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Điểm đến được yêu thích',
                        style: TextStyle(
                          fontSize: isDesktop ? 26 : 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'Khám phá các căn biệt thự và chỗ nghỉ được yêu thích nhất tại Vũng Tàu',
                              style: TextStyle(
                                fontSize: isDesktop ? 14 : 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isDestinationGridMode =
                                    !_isDestinationGridMode;
                                _destinationGridPage = 0;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isDestinationGridMode
                                        ? 'Thu gọn'
                                        : 'Xem tất cả',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    _isDestinationGridMode
                                        ? LucideIcons.chevronUp
                                        : LucideIcons.chevronRight,
                                    size: 16,
                                    color: AppColors.iconStrong,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                                label: 'Quay lại',
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
                                label: 'Xem tiếp',
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
                                label: 'Thu gọn',
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BÀI VIẾT MỚI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Kinh nghiệm lưu trú nổi bật',
                        style: TextStyle(
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
                        const Text(
                          'Nội dung tập trung vào nhu cầu thực tế khi đặt villa tại Vũng Tàu, từ nhóm gia đình đến nhóm bạn đông người.',
                          style: TextStyle(
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Xem tất cả bài viết',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
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
                  child: const Center(
                    child: Text(
                      'Đang tải bài viết...',
                      style: TextStyle(
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
                  child: const Text(
                    'Không tải được bài viết mới.',
                    style: TextStyle(
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
                      child: const Center(
                        child: Text(
                          'Chưa có bài viết nổi bật.',
                          style: TextStyle(
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

/// Popular Destination Card styled after the reference card UI (rounded card, top image with circular heart icon, title + mapPin location + price/rating).
class _PopularDestinationCard extends ConsumerWidget {
  final Villa villa;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _PopularDestinationCard({
    required this.villa,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    final thumbUrl = villa.imageUrls.isNotEmpty
        ? villa.imageUrls.first
        : 'assets/images/19tranphu.jpg';

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
                      url: thumbUrl,
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
                    villa.name,
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
                          villa.address.isNotEmpty
                              ? villa.address
                              : (villa.tagline.isNotEmpty
                                  ? villa.tagline
                                  : 'Vũng Tàu'),
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
                            villa.basePriceVnd,
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
                        villa.rating.toStringAsFixed(1),
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

/// Exact port of `ListingCard.tsx` in Flat Minimal UI (no rating pill badge, no card border).
class _ListingCardWidget extends ConsumerWidget {
  final String id;
  final String name;
  final String address;
  final int pricePerNight;
  final double rating;
  final String imageUrl;
  final VoidCallback onTap;

  const _ListingCardWidget({
    required this.id,
    required this.name,
    required this.address,
    required this.pricePerNight,
    required this.rating,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AppImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.star,
                          size: 14,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: formatter.formatPriceOrContact(
                          pricePerNight,
                          context: MoneyDisplayContext.villaCard,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      TextSpan(
                        text: ' ${formatter.l10n.pricePerNightUnit}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: AppColors.iconMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF64748B),
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
    );
  }
}

/// Exact port of `BlogPostCard.tsx` in Flat Minimal UI (no category badge box, no card border).
class _BlogPostCardWidget extends StatelessWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const _BlogPostCardWidget({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                    Text(
                      post.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post.readTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: Color(0xFF020617),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: Text(
                    post.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 14,
                      color: AppColors.iconStrong,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      post.location,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
