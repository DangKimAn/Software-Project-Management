// CONFLICT-RESOLVED: Đổi tên app_header_footer.dart thành app_header.dart và gỡ bỏ export app_footer.dart nhằm tách biệt hoàn toàn thành phần Header và Footer, tránh trùng vai trò với app_footer.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
import '../../features/search/presentation/widgets/source_search_bar.dart';
import '../../features/trips/presentation/view_models/trips_view_model.dart';
import '../../features/trips/presentation/widgets/global_pending_booking_banner.dart';
// CONFLICT-RESOLVED: Tích hợp đa ngôn ngữ động (`context.l10n`) từ `origin/develop` (`cbb008a`) vào thanh điều hướng đầu trang `app_header.dart`.
import '../../l10n/l10n.dart';
import 'app_header_menu.dart';
import 'app_notification_bell.dart';
import 'app_semantic_icons.dart';

export 'app_notification_bell.dart';

/// Biến thể thanh đầu trang tích hợp sẵn thanh tìm kiếm dạng viên thuốc ("Bạn muốn đi đâu?"),
/// nút chuông thông báo và trình đơn tài khoản dùng chung cho các phân hệ chính.
///
/// Tự động chuyển đổi ưu tiên hiển thị biểu ngữ giữ chỗ chờ thanh toán (`GlobalPendingBookingBanner`)
/// thay cho thanh tìm kiếm và chuông thông báo khi người dùng đang có đơn giữ chỗ còn hiệu lực.
class AppSearchHeader extends ConsumerWidget {
  /// Đường dẫn định tuyến hiện tại dùng để đánh dấu mục điều hướng đang hoạt động.
  final String currentPath;

  /// Cho phép ẩn biểu ngữ nhắc đơn đặt phòng đang chờ thanh toán khi màn hình đã tự hiển thị riêng.
  final bool hidePendingBanner;

  /// Khởi tạo thanh đầu trang kèm ô kích hoạt tìm kiếm thu gọn.
  const AppSearchHeader({
    super.key,
    required this.currentPath,
    this.hidePendingBanner = false,
  });

  /// Dựng `GlobalPendingBookingBanner` khi có đơn giữ chỗ hoặc `AppTopHeader` với `SourceSearchBar` thu gọn.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CONFLICT-RESOLVED: Giữ cơ chế ưu tiên hiển thị biểu ngữ giữ chỗ `GlobalPendingBookingBanner` thay cho thanh tìm kiếm trên các tab chính từ develop.
    final activeBooking = ref.watch(activePendingBookingProvider);
    final isExcludedPath =
        currentPath.contains('/thanh-toan') || currentPath.contains('/pay');

    if (activeBooking != null && !hidePendingBanner && !isExcludedPath) {
      return Container(
        color: AppColors.surfaceBase,
        child: SafeArea(
          bottom: false,
          child: GlobalPendingBookingBanner(booking: activeBooking),
        ),
      );
    }

    return AppTopHeader(
      currentPath: currentPath,
      hidePendingBanner: true,
      centerSearchTrigger: SourceSearchBar(
        isCompact: true,
        isInHeader: true,
        onSearchSubmitted: () {
          try {
            context.push('/tim-kiem');
          } catch (_) {}
        },
      ),
    );
  }
}

/// Thanh điều hướng đầu trang đáp ứng đa kích thước màn hình, hỗ trợ chế độ phủ trong suốt trên ảnh bìa
/// (`isOverlayTop`) và chuyển cảnh mượt sang thanh tìm kiếm ghim khi cuộn trang.
///
/// Top Header / Navbar matching `Source goc/frontend/src/views/components/common/Header.tsx` & `Navbar.tsx`.
class AppTopHeader extends ConsumerWidget {
  /// Đường dẫn định tuyến hiện tại để làm nổi bật liên kết tương ứng trên màn hình lớn.
  final String currentPath;

  /// Thành phần tìm kiếm thu gọn hiển thị thay thế cụm thương hiệu/liên kết khi ghim đầu trang.
  final Widget? centerSearchTrigger;

  /// Khi bật `true`, nền thanh đầu trang trong suốt và chữ/biểu tượng chuyển sang màu trắng trên nền ảnh Hero.
  final bool isOverlayTop;

  /// Cờ ẩn biểu ngữ nhắc đơn đặt phòng đang chờ giữ chỗ ở ngay dưới thanh điều hướng.
  final bool hidePendingBanner;

  /// Khởi tạo thanh điều hướng đầu trang `AppTopHeader`.
  const AppTopHeader({
    super.key,
    this.currentPath = '/',
    this.centerSearchTrigger,
    this.isOverlayTop = false,
    this.hidePendingBanner = false,
  });

  /// Dựng bố cục thanh đầu trang thích ứng điểm ngắt Desktop (`>= 900dp`) và Mobile nhỏ (`< 380dp`).
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Giải thuật chuyển cảnh hai chiều giữa thanh thương hiệu và thanh tìm kiếm ghim:
    // Sử dụng AnimatedSwitcher định danh bằng ValueKey ('pinned_search_content' so với 'top_header_content')
    // kết hợp trượt dọc đối xứng, mờ dần theo khoảng Interval(0.1, 1.0) và phóng nhẹ từ 0.94 -> 1.0.
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = screenWidth >= 900;
      final isCompactMobile = screenWidth < 380;

      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isOverlayTop ? Colors.transparent : Colors.white,
          border: isOverlayTop
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE4E4E7), width: 1),
                ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? (centerSearchTrigger != null ? 24 : 40)
              : (isCompactMobile ? 12.0 : 16.0),
          vertical: 10,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            final isSearch = (child.key as ValueKey?)?.value ==
                                'pinned_search_content';
                            if (isSearch) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.70),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: animation,
                                    curve: const Interval(0.1, 1.0,
                                        curve: Curves.easeOut),
                                  ),
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.94,
                                      end: 1.0,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    )),
                                    child: child,
                                  ),
                                ),
                              );
                            }
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, -0.2),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: centerSearchTrigger != null
                              ? KeyedSubtree(
                                  key: const ValueKey('pinned_search_content'),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: isDesktop ? 16 : 8,
                                    ),
                                    child: centerSearchTrigger!,
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('top_header_content'),
                                  child: _buildBrandAndDesktopNav(
                                    context,
                                    screenWidth: screenWidth,
                                    isDesktop: isDesktop,
                                    isCompactMobile: isCompactMobile,
                                  ),
                                ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: (centerSearchTrigger == null &&
                                (authUser == null || !authUser.isAdmin) &&
                                screenWidth >= 1260)
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (authUser != null && authUser.isHost) {
                                        context.push('/chu-nha/cho-nghi');
                                      } else {
                                        context.push('/tro-thanh-host');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOverlayTop
                                            ? Colors.transparent
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            authUser != null && authUser.isHost
                                                ? context.l10n.navHostPortal
                                                : context.l10n.navBecomeHost,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isOverlayTop
                                                  ? Colors.white
                                                  : const Color(0xFF18181B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      NotificationBell(isOverlayTop: isOverlayTop),
                      const SizedBox(width: 2),
                      AppHeaderMenuButton(
                        authUser: authUser,
                        isDesktop: isDesktop,
                        isOverlayTop: isOverlayTop,
                      ),
                    ],
                  ),
                ),
              ),
              if (!hidePendingBanner)
                const GlobalPendingBookingHeaderBanner(
                  margin: EdgeInsets.only(top: 8),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBrandAndDesktopNav(
    BuildContext context, {
    required double screenWidth,
    required bool isDesktop,
    required bool isCompactMobile,
  }) {
    final navSpacing =
        screenWidth >= 1280 ? 28.0 : (screenWidth >= 1080 ? 20.0 : 14.0);
    return Row(
      children: [
        Flexible(
          child: InkWell(
            onTap: () => context.go('/'),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBrandIcon.minhThanhLogo(
                    size: 26,
                    color: isOverlayTop ? Colors.white : AppColors.iconStrong,
                  ),
                  if (screenWidth >= 380) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'The Palm Villa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              isDesktop ? 19 : (isCompactMobile ? 16 : 19),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isOverlayTop
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isDesktop) ...[
          const Spacer(),
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CONFLICT-RESOLVED: Sử dụng khóa l10n (`navDiscover`, `navStays`, `navBlog`, `navContact`) từ `origin/develop` để thanh Header Desktop tự động đổi ngôn ngữ VI/EN/KO theo thời gian thực.
                  _NavTextLink(
                    label: context.l10n.navDiscover,
                    isActive: currentPath == '/',
                    isOverlayTop: isOverlayTop,
                    onTap: () => context.go('/'),
                  ),
                  SizedBox(width: navSpacing),
                  _NavTextLink(
                    label: context.l10n.navStays,
                    isActive: currentPath.startsWith('/search') ||
                        currentPath.startsWith('/tim-kiem') ||
                        currentPath.startsWith('/noi-luu-tru') ||
                        currentPath.startsWith('/villas'),
                    isOverlayTop: isOverlayTop,
                    onTap: () => context.push('/tim-kiem'),
                  ),
                  SizedBox(width: navSpacing),
                  _NavTextLink(
                    label: context.l10n.navBlog,
                    isActive: currentPath.startsWith('/blog') ||
                        currentPath.startsWith('/cam-nang'),
                    isOverlayTop: isOverlayTop,
                    onTap: () => context.push('/cam-nang'),
                  ),
                  SizedBox(width: navSpacing),
                  _NavTextLink(
                    label: context.l10n.navContact,
                    isActive: currentPath.startsWith('/lien-he'),
                    isOverlayTop: isOverlayTop,
                    onTap: () => context.push('/lien-he'),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _NavTextLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isOverlayTop;
  final VoidCallback onTap;

  const _NavTextLink({
    required this.label,
    required this.isActive,
    this.isOverlayTop = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isOverlayTop
        ? (isActive ? Colors.white : Colors.white.withValues(alpha: 0.85))
        : (isActive ? const Color(0xFF0F172A) : const Color(0xFF475569));

    final indicatorColor = isOverlayTop ? Colors.white : AppColors.primary;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 2,
              width: isActive ? 28 : 0,
              decoration: BoxDecoration(
                color: isActive ? indicatorColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
