import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/core/formatters/currency_formatter.dart';
import 'package:hotel_booking_flutter/core/security/url_security_validator.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/theme/admin_studio_tokens.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/widgets/admin_studio_widgets.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/shared/animations/fade_slide_in.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_dialog.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_image.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_semantic_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminNavItem {
  const AdminNavItem({
    required this.id,
    required this.label,
    required this.route,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String label;
  final String route;
  final IconData icon;
  final String title;
  final String subtitle;
}

const List<AdminNavItem> kAdminNavItems = [
  AdminNavItem(
    id: 'tong-quan',
    label: 'Tổng quan',
    route: '/admin',
    icon: AppSemanticIcons.dashboard,
    title: 'Tổng quan Admin',
    subtitle: 'Dữ liệu tổng quan hệ thống và biểu đồ doanh thu.',
  ),
  AdminNavItem(
    id: 'nguoi-dung',
    label: 'Người dùng',
    route: '/admin/nguoi-dung',
    icon: LucideIcons.users,
    title: 'Quản lý người dùng',
    subtitle: 'Tìm kiếm, khóa/mở khóa và cập nhật vai trò người dùng.',
  ),
  AdminNavItem(
    id: 'kiem-duyet',
    label: 'Kiểm duyệt',
    route: '/admin/kiem-duyet',
    icon: LucideIcons.clipboardCheck,
    title: 'Kiểm duyệt bài đăng',
    subtitle: 'Duyệt hoặc từ chối listing đang chờ duyệt kèm phân tích ảnh AI.',
  ),
  AdminNavItem(
    id: 'ho-so-host',
    label: 'Hồ sơ đăng ký host',
    route: '/admin/ho-so-host',
    icon: AppSemanticIcons.hostApplications,
    title: 'Hồ sơ host',
    subtitle: 'Duyệt hồ sơ đăng ký chủ nhà và xác minh danh tính.',
  ),
  AdminNavItem(
    id: 'phan-quyen',
    label: 'Phân quyền',
    route: '/admin/phan-quyen',
    icon: LucideIcons.shield,
    title: 'Phân quyền hệ thống',
    subtitle: 'Cập nhật vai trò người dùng (Guest, Host, Admin).',
  ),
];

bool _isActorAdmin(User? actor) {
  if (actor == null) return false;
  if (actor.role.toLowerCase() == 'admin') return true;
  return actor.roles.any((r) => r.toLowerCase() == 'admin');
}

double _responsivePagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 380) return 12;
  if (width < 640) return 16;
  return 24;
}

EdgeInsets _studioScrollPadding(BuildContext context) {
  final pad = _responsivePagePadding(context);
  final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
  return EdgeInsets.fromLTRB(pad, 10, pad, isDesktop ? pad + 24 : pad + 98);
}

final ButtonStyle _kPillOutlinedStyle = AdminStudioTokens.secondaryPillButton;
final ButtonStyle _kCirclePagerOutlinedStyle =
    AdminStudioTokens.circlePagerButton;
final ButtonStyle _kCompactPillOutlinedStyle =
    AdminStudioTokens.compactSecondaryPillButton;
final ButtonStyle _kCompactIconActionStyle =
    AdminStudioTokens.compactIconActionButton;
final ButtonStyle _kPillElevatedStyle = AdminStudioTokens.primaryPillButton;
final ButtonStyle _kCompactPillElevatedStyle =
    AdminStudioTokens.compactPrimaryPillButton;

InputDecoration _multilineInputDecoration({
  String? hintText,
  String? labelText,
  String? errorText,
}) {
  return AdminStudioTokens.multilineDecoration(
    hintText: hintText,
    labelText: labelText,
    errorText: errorText,
  );
}

class _AdminErrorBanner extends StatelessWidget {
  const _AdminErrorBanner({
    required this.message,
    this.isOffline = false,
    this.onRetry,
  });

  final String message;
  final bool isOffline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isOffline
              ? AdminStudioTokens.cardSurface
              : AdminStudioTokens.dangerTint,
          borderRadius: BorderRadius.circular(AdminStudioTokens.cardRadius),
          border: Border.all(
            color: isOffline
                ? AdminStudioTokens.warningInk.withValues(alpha: 0.45)
                : AdminStudioTokens.dangerInk.withValues(alpha: 0.35),
          ),
          boxShadow: AdminStudioTokens.cardShadow,
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isOffline
                        ? AdminStudioTokens.warningTint
                        : Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isOffline
                          ? LucideIcons.wifiOff
                          : AppSemanticIcons.errorAlert,
                      size: 15.5,
                      color: isOffline
                          ? AdminStudioTokens.warningInk
                          : AdminStudioTokens.dangerInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOffline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            'Mất kết nối tới máy chủ',
                            style: AdminStudioTokens.cardTitle.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      Text(
                        message,
                        style: AdminStudioTokens.bodyRegular.copyWith(
                          fontSize: 13,
                          color: isOffline
                              ? AdminStudioTokens.inkSecondary
                              : AdminStudioTokens.dangerInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              OutlinedButton.icon(
                style: _kPillOutlinedStyle,
                onPressed: onRetry,
                icon: const Icon(
                  AppSemanticIcons.retry,
                  size: 14,
                  color: AdminStudioTokens.iconInk,
                ),
                label: const Text('Thử lại'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminPaginationBar extends StatelessWidget {
  const _AdminPaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.unitLabel,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final String unitLabel;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (total <= 0 && totalPages <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            totalPages > 1
                ? 'Trang $page/$totalPages · $total $unitLabel'
                : 'Tổng $total $unitLabel',
            style: AdminStudioTokens.metaCaption.copyWith(
              fontWeight: FontWeight.w500,
              color: AdminStudioTokens.inkSecondary,
            ),
          ),
          if (totalPages > 1)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Semantics(
                  button: true,
                  enabled: !loading && page > 1,
                  label: 'Trang trước',
                  child: Tooltip(
                    message: 'Trang trước',
                    child: OutlinedButton(
                      style: _kCirclePagerOutlinedStyle,
                      onPressed: loading || page <= 1 ? null : onPrev,
                      child: const Icon(
                        LucideIcons.chevronLeft,
                        size: 16,
                        color: AdminStudioTokens.iconInk,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: !loading && page < totalPages,
                  label: 'Trang sau',
                  child: Tooltip(
                    message: 'Trang sau',
                    child: OutlinedButton(
                      style: _kCirclePagerOutlinedStyle,
                      onPressed: loading || page >= totalPages ? null : onNext,
                      child: const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: AdminStudioTokens.iconInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AdminBottomNavItem {
  const AdminBottomNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.route,
    this.isMenuTrigger = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? route;
  final bool isMenuTrigger;
}

const List<AdminBottomNavItem> kAdminBottomNavItems = [
  AdminBottomNavItem(
    id: 'tong-quan',
    label: 'Tổng quan',
    route: '/admin',
    icon: AppSemanticIcons.dashboard,
  ),
  AdminBottomNavItem(
    id: 'nguoi-dung',
    label: 'Người dùng',
    route: '/admin/nguoi-dung',
    icon: LucideIcons.users,
  ),
  AdminBottomNavItem(
    id: 'kiem-duyet',
    label: 'Kiểm duyệt',
    route: '/admin/kiem-duyet',
    icon: LucideIcons.clipboardCheck,
  ),
  AdminBottomNavItem(
    id: 'ho-so-host',
    label: 'Hồ sơ',
    route: '/admin/ho-so-host',
    icon: AppSemanticIcons.hostApplications,
  ),
  AdminBottomNavItem(
    id: 'menu',
    label: 'Menu',
    icon: LucideIcons.menu,
    isMenuTrigger: true,
  ),
];

class AdminPortalScreen extends ConsumerStatefulWidget {
  const AdminPortalScreen({
    super.key,
    required this.activeTab,
  });

  final String activeTab;

  @override
  ConsumerState<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends ConsumerState<AdminPortalScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.activeTab;
  }

  @override
  void didUpdateWidget(covariant AdminPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTab != widget.activeTab) {
      _currentTab = widget.activeTab;
    }
  }

  void _selectTab(BuildContext context, String tabId, String route) {
    if (_currentTab != tabId) {
      setState(() {
        _currentTab = tabId;
      });
    }
    if (GoRouter.maybeOf(context) != null) {
      context.go(route);
    }
  }

  void _navigateExternalRoute(BuildContext context, String route) {
    if (GoRouter.maybeOf(context) != null) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final activeMeta = kAdminNavItems.firstWhere(
      (item) => item.id == _currentTab,
      orElse: () => kAdminNavItems.first,
    );
    final rawAdminName = user?.fullName.trim() ?? '';
    final adminDisplayName = rawAdminName.isNotEmpty ? rawAdminName : 'Admin';

    Widget buildSidebarContent({bool inDrawer = false}) {
      return Container(
        width: inDrawer ? math.min(284, width * 0.86) : 272,
        color: AdminStudioTokens.groupSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      _selectTab(context, 'tong-quan', '/admin');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AdminStudioTokens.obsidian,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: AppBrandIcon.minhThanhLogo(
                                size: 19,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'The Palm Villa',
                                  overflow: TextOverflow.ellipsis,
                                  style: AdminStudioTokens.cardTitle.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Admin Panel',
                                  style: AdminStudioTokens.metaCaption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (inDrawer)
                  AdminStudioCircleButton(
                    icon: LucideIcons.x,
                    tooltip: 'Đóng menu điều hướng',
                    onTap: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                children: kAdminNavItems.map((item) {
                  final selected = item.id == _currentTab;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AdminStudioTokens.pillRadius,
                        ),
                        onTap: () {
                          if (inDrawer) Navigator.of(context).pop();
                          _selectTab(context, item.id, item.route);
                        },
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AdminStudioTokens.obsidian
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AdminStudioTokens.pillRadius,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 17.5,
                                color: selected
                                    ? Colors.white
                                    : AdminStudioTokens.iconSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: AdminStudioTokens.pillText.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: selected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: selected
                                        ? Colors.white
                                        : AdminStudioTokens.inkSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            AdminStudioInnerCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AdminStudioAvatar(
                        name: adminDisplayName,
                        imageUrl: user?.avatarUrl,
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdminStudioTokens.cardTitle.copyWith(
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              user?.email ?? 'admin@vungtaustay.com',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdminStudioTokens.metaCaption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: _kPillOutlinedStyle,
                      onPressed: () {
                        if (inDrawer) Navigator.of(context).pop();
                        _navigateExternalRoute(context, '/');
                      },
                      child: const Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            AppSemanticIcons.home,
                            size: 15,
                            color: AdminStudioTokens.iconInk,
                          ),
                          Text('Về trang khách'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: _kPillOutlinedStyle,
                      onPressed: () async {
                        if (inDrawer) Navigator.of(context).pop();
                        await ref.read(authNotifierProvider.notifier).logout();
                        if (context.mounted) {
                          _navigateExternalRoute(context, '/dang-nhap');
                        }
                      },
                      child: const Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            AppSemanticIcons.logout,
                            size: 15,
                            color: AdminStudioTokens.iconInk,
                          ),
                          Text('Đăng xuất'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isOverview = _currentTab == 'tong-quan';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminStudioTokens.canvas,
      extendBody: !isDesktop,
      drawer: Drawer(
        width: math.min(292, width * 0.88),
        backgroundColor: AdminStudioTokens.groupSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        child: SafeArea(child: buildSidebarContent(inDrawer: true)),
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(context),
      body: SafeArea(
        bottom: isDesktop,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Container(
                decoration: const BoxDecoration(
                  color: AdminStudioTokens.groupSurface,
                  border: Border(
                    right: BorderSide(
                      color: AdminStudioTokens.groupBorder,
                      width: 1.2,
                    ),
                  ),
                ),
                child: buildSidebarContent(),
              ),
            Expanded(
              child: Column(
                children: [
                  AdminFrostedSurface(
                    sigma: AdminStudioTokens.headerBlurSigma,
                    fillColor: AdminStudioTokens.frostedHeaderFill,
                    padding: EdgeInsets.fromLTRB(
                      width < 380 ? 12 : 20,
                      10,
                      width < 380 ? 8 : 14,
                      8,
                    ),
                    child: Row(
                      children: [
                        if (!isDesktop) ...[
                          Semantics(
                            button: true,
                            label: 'Về Tổng quan Admin',
                            child: Tooltip(
                              message: 'Tổng quan Admin',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    _selectTab(context, 'tong-quan', '/admin'),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: AdminStudioTokens.obsidian,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: AppBrandIcon.minhThanhLogo(
                                          size: 19,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isOverview
                                    ? activeMeta.title
                                    : 'The Palm Villa · $adminDisplayName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminStudioTokens.headerEyebrow,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isOverview
                                    ? 'Chào, $adminDisplayName'
                                    : activeMeta.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminStudioTokens.headerGreeting,
                              ),
                            ],
                          ),
                        ),
                        const NotificationBell(),
                        if (!isDesktop)
                          AdminStudioCircleButton(
                            icon: LucideIcons.menu,
                            tooltip: 'Mở menu điều hướng',
                            visualSize: 36,
                            iconSize: 17,
                            onTap: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildActiveView(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isMenuTabActive = _currentTab == 'phan-quyen';
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showCompactCircleOnly = textScale > 1.45;

    return AdminFrostedSurface(
      key: const ValueKey('admin-bottom-nav-bar'),
      sigma: AdminStudioTokens.dockBlurSigma,
      fillColor: AdminStudioTokens.frostedDockFill,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AdminStudioTokens.dockRadius),
      ),
      border: const Border(
        top: BorderSide(color: AdminStudioTokens.frostedDockBorder, width: 1.0),
      ),
      boxShadow: AdminStudioTokens.dockShadow,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: kAdminBottomNavItems.map((item) {
                final isSelected = item.isMenuTrigger
                    ? isMenuTabActive
                    : _currentTab == item.id;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: item.isMenuTrigger
                        ? 'Mở menu điều hướng Admin'
                        : item.label,
                    child: GestureDetector(
                      key: ValueKey('admin-bottom-nav-${item.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (item.isMenuTrigger) {
                          _scaffoldKey.currentState?.openDrawer();
                        } else if (item.route != null) {
                          _selectTab(context, item.id, item.route!);
                        }
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 52,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AdminStudioTokens.obsidian
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  size: isSelected ? 18 : 19,
                                  color: isSelected
                                      ? Colors.white
                                      : AdminStudioTokens.iconSecondary,
                                ),
                              ),
                            ),
                            if (!showCompactCircleOnly) ...[
                              const SizedBox(height: 2),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: AdminStudioTokens.metaCaption.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AdminStudioTokens.inkPrimary
                                        : AdminStudioTokens.inkMuted,
                                  ),
                                ),
                              ),
                            ] else
                              Offstage(
                                child: Text(item.label),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView() {
    switch (_currentTab) {
      case 'nguoi-dung':
        return const _AdminUsersTab();
      case 'kiem-duyet':
        return const _AdminModerationTab();
      case 'ho-so-host':
        return const _AdminHostApplicationsTab();
      case 'phan-quyen':
        return const _AdminRolesTab();
      case 'tong-quan':
      default:
        return const _AdminOverviewTab();
    }
  }
}

// ── 1. TỔNG QUAN HỆ THỐNG (/admin) ──
class _AdminOverviewTab extends ConsumerStatefulWidget {
  const _AdminOverviewTab();

  @override
  ConsumerState<_AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends ConsumerState<_AdminOverviewTab> {
  AdminOverviewStats? _stats;
  bool _loading = true;
  String? _error;
  bool _isOffline = false;
  int _rangeDays = 30;
  String _group = 'day';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _isOffline = false;
    });
    try {
      final stats = await ref.read(adminRepositoryProvider).getOverviewStats(
            days: _rangeDays,
            group: _group,
          );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
        _isOffline = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stats = null;
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải tổng quan admin.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final cards = [
      (
        label: 'Người dùng',
        value: _loading ? '...' : '${stats?.users ?? 0}',
        icon: LucideIcons.users,
        route: '/admin/nguoi-dung',
      ),
      (
        label: 'Chờ duyệt',
        value: _loading ? '...' : '${stats?.pendingListings ?? 0}',
        icon: LucideIcons.clock,
        route: '/admin/kiem-duyet',
      ),
      (
        label: 'Doanh thu',
        value: _loading
            ? '...'
            : CurrencyFormatter.formatVnd(
                (stats?.grossRevenue ?? 0).round(),
                fallback: '0 ₫',
              ),
        icon: AppSemanticIcons.revenue,
        route: null,
      ),
      (
        label: 'Đơn đặt',
        value: _loading ? '...' : '${stats?.bookings ?? 0}',
        icon: AppSemanticIcons.bookings,
        route: null,
      ),
      (
        label: 'Chủ nhà',
        value: _loading ? '...' : '${stats?.hosts ?? 0}',
        icon: AppSemanticIcons.becomeHost,
        route: '/admin/ho-so-host',
      ),
      (
        label: 'Phòng hoạt động',
        value: _loading ? '...' : '${stats?.activeListings ?? 0}',
        icon: AppSemanticIcons.home,
        route: '/admin/kiem-duyet',
      ),
    ];

    final series = stats?.revenueSeries ?? const <AdminRevenuePoint>[];
    final maxRevenue = series.fold<double>(
      0,
      (prev, item) => item.grossRevenue > prev ? item.grossRevenue : prev,
    );

    return SingleChildScrollView(
      padding: _studioScrollPadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, filterConstraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final useSingleRow =
                      filterConstraints.maxWidth >= 560 && textScale <= 1.25;

                  final rangeBar = AdminStudioSegmentedBar<int>(
                    selectedValue: _rangeDays,
                    items: const [
                      AdminStudioSegmentItem(value: 7, label: '7 ngày'),
                      AdminStudioSegmentItem(value: 30, label: '30 ngày'),
                      AdminStudioSegmentItem(value: 90, label: '90 ngày'),
                    ],
                    onSelected: _loading
                        ? null
                        : (daysOption) {
                            if (_rangeDays == daysOption) return;
                            setState(() {
                              _rangeDays = daysOption;
                              _group = daysOption >= 90 ? 'month' : 'day';
                            });
                            _load();
                          },
                  );

                  final groupBar = AdminStudioSegmentedBar<String>(
                    selectedValue: _group,
                    items: const [
                      AdminStudioSegmentItem(
                        value: 'day',
                        label: 'Theo ngày',
                      ),
                      AdminStudioSegmentItem(
                        value: 'month',
                        label: 'Theo tháng',
                      ),
                    ],
                    onSelected: _loading
                        ? null
                        : (next) {
                            if (next == _group) return;
                            setState(() => _group = next);
                            _load();
                          },
                  );

                  if (useSingleRow) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: rangeBar),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: groupBar),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      rangeBar,
                      const SizedBox(height: 8),
                      groupBar,
                    ],
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _AdminErrorBanner(
                  message: _error!,
                  isOffline: _isOffline,
                  onRetry: _loading ? null : _load,
                ),
              ],
              if (!_loading &&
                  _error == null &&
                  stats != null &&
                  !stats.hasAnyActivity) ...[
                const SizedBox(height: 12),
                AdminStudioInnerCard(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AdminStudioTokens.softCircle,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: AdminStudioTokens.iconMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Chưa có phát sinh dữ liệu trong kỳ báo cáo này.',
                          style: AdminStudioTokens.bodyRegular,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AdminStudioGroupCard(
                title: 'Hoạt động hệ thống',
                trailing: AdminStudioCircleButton(
                  icon: LucideIcons.ellipsis,
                  tooltip: 'Làm mới số liệu hoạt động',
                  visualSize: 34,
                  iconSize: 15,
                  onTap: _loading ? null : _load,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final cols = constraints.maxWidth >= 860
                        ? 3
                        : (constraints.maxWidth >= 310 && textScale <= 1.28)
                            ? 2
                            : 1;
                    const gap = 10.0;
                    final itemWidth =
                        (constraints.maxWidth - (cols - 1) * gap) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: cards.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final card = entry.value;
                        return SizedBox(
                          width: itemWidth,
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: idx * 25),
                            child: AdminStudioKpiCard(
                              label: card.label,
                              value: card.value,
                              icon: card.icon,
                              onTap: card.route != null &&
                                      GoRouter.maybeOf(context) != null
                                  ? () => context.go(card.route!)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AdminStudioGroupCard(
                title: 'Biểu đồ doanh thu',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!_loading && stats != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AdminStudioTokens.pillRadius,
                          ),
                          boxShadow: AdminStudioTokens.cardShadow,
                        ),
                        child: Text(
                          'Chủ nhà nhận: ${CurrencyFormatter.formatVnd(stats.hostRevenue.round(), fallback: '0 ₫')}',
                          style: AdminStudioTokens.metaCaption.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AdminStudioTokens.inkPrimary,
                          ),
                        ),
                      ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AdminStudioTokens.obsidian,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          AppSemanticIcons.revenue,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminStudioTokens.obsidian,
                            ),
                          ),
                        ),
                      )
                    : _error != null
                        ? const AdminStudioInnerCard(
                            padding: EdgeInsets.symmetric(
                              vertical: 22,
                              horizontal: 16,
                            ),
                            child: Text(
                              'Không thể hiển thị biểu đồ doanh thu do lỗi tải số liệu.',
                              textAlign: TextAlign.center,
                              style: AdminStudioTokens.cardSubtitle,
                            ),
                          )
                        : series.isEmpty
                            ? const AdminStudioInnerCard(
                                padding: EdgeInsets.symmetric(
                                  vertical: 26,
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'Chưa có dữ liệu chuỗi doanh thu trong khoảng thời gian đã chọn.',
                                  textAlign: TextAlign.center,
                                  style: AdminStudioTokens.cardSubtitle,
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, chartConstraints) {
                                  final textScale =
                                      MediaQuery.textScalerOf(context).scale(1);
                                  final compactChart =
                                      chartConstraints.maxWidth < 460 ||
                                          textScale > 1.25;
                                  return Column(
                                    children: series.take(14).map((point) {
                                      final ratio = maxRevenue > 0
                                          ? (point.grossRevenue / maxRevenue)
                                              .clamp(0.05, 1.0)
                                          : 0.05;
                                      final amountLabel =
                                          '${CurrencyFormatter.formatVnd(point.grossRevenue.round(), fallback: '0 ₫')} (${point.bookingCount} đơn)';
                                      return AdminStudioInnerCard(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: compactChart
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    alignment: WrapAlignment
                                                        .spaceBetween,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            LucideIcons
                                                                .calendar,
                                                            size: 13,
                                                            color:
                                                                AdminStudioTokens
                                                                    .iconMuted,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            point.period,
                                                            style:
                                                                AdminStudioTokens
                                                                    .metaCaption,
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        amountLabel,
                                                        style: AdminStudioTokens
                                                            .pillText
                                                            .copyWith(
                                                          fontSize: 12.5,
                                                          color:
                                                              AdminStudioTokens
                                                                  .inkPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      AdminStudioTokens
                                                          .pillRadius,
                                                    ),
                                                    child: Container(
                                                      height: 7,
                                                      color: AdminStudioTokens
                                                          .softCircle,
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child:
                                                          FractionallySizedBox(
                                                        widthFactor: ratio,
                                                        child: Container(
                                                          height: 7,
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                AdminStudioTokens
                                                                    .obsidian,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              AdminStudioTokens
                                                                  .pillRadius,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                children: [
                                                  SizedBox(
                                                    width: 102,
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          LucideIcons.calendar,
                                                          size: 13,
                                                          color:
                                                              AdminStudioTokens
                                                                  .iconMuted,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            point.period,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                AdminStudioTokens
                                                                    .metaCaption,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        AdminStudioTokens
                                                            .pillRadius,
                                                      ),
                                                      child: Container(
                                                        height: 8,
                                                        color: AdminStudioTokens
                                                            .softCircle,
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child:
                                                            FractionallySizedBox(
                                                          widthFactor: ratio,
                                                          child: Container(
                                                            height: 8,
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  AdminStudioTokens
                                                                      .obsidian,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                AdminStudioTokens
                                                                    .pillRadius,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 156,
                                                    child: Text(
                                                      amountLabel,
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: AdminStudioTokens
                                                          .pillText
                                                          .copyWith(
                                                        fontSize: 12,
                                                        color: AdminStudioTokens
                                                            .inkPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2. QUẢN LÝ NGƯỜI DÙNG (/admin/nguoi-dung) ──
class _AdminUsersTab extends ConsumerStatefulWidget {
  const _AdminUsersTab();

  @override
  ConsumerState<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<_AdminUsersTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _debouncedSearch = '';
  String _status = 'all';
  String _roleFilter = 'all';
  int _page = 1;
  final int _limit = 20;
  int _total = 0;
  int _totalPages = 1;
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  String? _error;
  bool _isOffline = false;
  String? _actionUserId;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _debouncedSearch = value.trim();
        _page = 1;
      });
      _fetchUsers();
    });
  }

  Future<void> _fetchUsers({bool preserveError = false}) async {
    setState(() {
      _loading = true;
      if (!preserveError) {
        _error = null;
        _isOffline = false;
      }
    });
    try {
      final result =
          await ref.read(adminRepositoryProvider).getAdminUsersPaginated(
                page: _page,
                limit: _limit,
                search: _debouncedSearch,
                role: _roleFilter,
                status: _status,
              );
      if (!mounted) return;
      setState(() {
        _users = result.items;
        _page = result.page;
        _total = result.total;
        _totalPages = result.totalPages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải danh sách người dùng.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final userId = '${user['userId'] ?? user['id'] ?? ''}';
    if (userId.isEmpty) return;

    final currentActor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(currentActor)) {
      setState(() {
        _error =
            'Chỉ Quản trị viên (Admin) mới có quyền khóa hoặc mở khóa tài khoản.';
      });
      return;
    }
    if (currentActor != null && currentActor.id == userId) {
      setState(() {
        _error = 'Bạn không thể tự khóa tài khoản của chính mình.';
      });
      return;
    }

    final currentStatus = '${user['status'] ?? 'active'}'.toLowerCase();
    final isLocked = ['blocked', 'suspended', 'locked'].contains(currentStatus);
    final nextStatus = isLocked ? 'active' : 'suspended';
    final displayName =
        '${user['fullName'] ?? user['name'] ?? user['email'] ?? '#$userId'}';
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title:
            isLocked ? 'Xác nhận mở khóa tài khoản' : 'Xác nhận khóa tài khoản',
        subtitle: isLocked
            ? 'Kích hoạt lại tài khoản $displayName (#$userId)?'
            : 'Tạm khóa (suspended) tài khoản $displayName (#$userId)?',
        maxWidth: 460,
        actions: [
          OutlinedButton(
            style: _kPillOutlinedStyle,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: _kPillElevatedStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isLocked ? 'Xác nhận mở khóa' : 'Xác nhận khóa'),
          ),
        ],
        child: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: _multilineInputDecoration(
            hintText: isLocked
                ? 'Ghi chú mở khóa (tùy chọn)...'
                : 'Lý do khóa tài khoản (ví dụ: vi phạm chính sách)...',
          ),
        ),
      ),
    );
    reasonCtrl.dispose();

    if (confirmed != true) return;

    setState(() {
      _actionUserId = userId;
      _error = null;
      _isOffline = false;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateAdminUserStatus(userId, nextStatus);
      if (!mounted) return;
      AppToast.show(
        context,
        isLocked
            ? 'Đã kích hoạt lại tài khoản #$userId.'
            : 'Đã tạm khóa (suspended) tài khoản #$userId.',
        type: AppToastType.success,
      );
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      final status = AdminRepository.extractStatusCode(e);
      final msg = AdminRepository.extractErrorMessage(
        e,
        'Không thể cập nhật trạng thái người dùng.',
      );
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = msg;
      });
      if (status == 409) {
        await _fetchUsers(preserveError: true);
      }
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final userId = '${user['userId'] ?? user['id'] ?? ''}';
    if (userId.isEmpty) return;

    final currentActor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(currentActor)) {
      setState(() {
        _error =
            'Chỉ Quản trị viên (Admin) mới có quyền chỉnh sửa thông tin người dùng.';
      });
      return;
    }

    final nameCtrl = TextEditingController(
      text: '${user['fullName'] ?? user['name'] ?? ''}',
    );
    final phoneCtrl = TextEditingController(
      text: '${user['phone'] ?? ''}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Cập nhật người dùng #$userId',
        subtitle: '${user['email'] ?? ''}',
        maxWidth: 460,
        actions: [
          OutlinedButton(
            style: _kPillOutlinedStyle,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: _kPillElevatedStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lưu thay đổi'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: _multilineInputDecoration(labelText: 'Họ và tên'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: _multilineInputDecoration(labelText: 'Số điện thoại'),
            ),
          ],
        ),
      ),
    );

    final nextName = nameCtrl.text.trim();
    final nextPhone = phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();

    if (confirmed != true) return;

    setState(() {
      _actionUserId = userId;
      _error = null;
      _isOffline = false;
    });
    try {
      await ref.read(adminRepositoryProvider).updateAdminUser(userId, {
        if (nextName.isNotEmpty) 'fullName': nextName,
        'phone': nextPhone.isEmpty ? null : nextPhone,
      });
      if (!mounted) return;
      AppToast.show(
        context,
        'Đã cập nhật thông tin người dùng #$userId.',
        type: AppToastType.success,
      );
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể cập nhật thông tin người dùng.',
        );
      });
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canManageUsers = _isActorAdmin(actor);

    return SingleChildScrollView(
      padding: _studioScrollPadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canManageUsers)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: AdminStudioInnerCard(
                    warningHighlight: true,
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Chỉ Quản trị viên (Admin) mới có quyền chỉnh sửa hoặc khóa tài khoản người dùng.',
                      style: AdminStudioTokens.bodyRegular,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _AdminErrorBanner(
                    message: _error!,
                    isOffline: _isOffline,
                    onRetry: _loading ? null : _fetchUsers,
                  ),
                ),
              AdminStudioGroupCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: AdminStudioTokens.bodyRegular.copyWith(
                        color: AdminStudioTokens.inkPrimary,
                      ),
                      decoration: AdminStudioTokens.searchPillDecoration(
                        hintText: 'Tìm tên, email, SĐT...',
                        prefixIcon: LucideIcons.search,
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 15,
                                  color: AdminStudioTokens.iconMuted,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, filterConstraints) {
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(1);
                        final stackFilters =
                            filterConstraints.maxWidth < 290 || textScale > 1.3;

                        Widget buildPillDropdown({
                          required String value,
                          required List<DropdownMenuItem<String>> items,
                          required ValueChanged<String?> onChanged,
                        }) {
                          return Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AdminStudioTokens.pillRadius,
                              ),
                              boxShadow: AdminStudioTokens.cardShadow,
                            ),
                            alignment: Alignment.centerLeft,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: value,
                                isExpanded: true,
                                isDense: true,
                                icon: const Icon(
                                  LucideIcons.chevronDown,
                                  size: 14,
                                  color: AdminStudioTokens.iconMuted,
                                ),
                                style: AdminStudioTokens.pillText.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: AdminStudioTokens.inkPrimary,
                                ),
                                items: items,
                                onChanged: onChanged,
                              ),
                            ),
                          );
                        }

                        final roleDropdown = buildPillDropdown(
                          value: _roleFilter,
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Vai trò: Tất cả'),
                            ),
                            DropdownMenuItem(
                              value: 'guest',
                              child: Text('Guest'),
                            ),
                            DropdownMenuItem(
                              value: 'host',
                              child: Text('Host'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _roleFilter = value;
                              _page = 1;
                            });
                            _fetchUsers();
                          },
                        );

                        final statusDropdown = buildPillDropdown(
                          value: _status,
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Trạng thái: Tất cả'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Hoạt động'),
                            ),
                            DropdownMenuItem(
                              value: 'suspended',
                              child: Text('Tạm khóa'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Ngưng hoạt động'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _status = value;
                              _page = 1;
                            });
                            _fetchUsers();
                          },
                        );

                        if (stackFilters) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              roleDropdown,
                              const SizedBox(height: 8),
                              statusDropdown,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: roleDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: statusDropdown),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AdminStudioGroupCard(
                title: 'Danh sách tài khoản',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AdminStudioTokens.pillRadius,
                    ),
                  ),
                  child: Text(
                    '$_total người dùng',
                    style: AdminStudioTokens.metaCaption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AdminStudioTokens.inkPrimary,
                    ),
                  ),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminStudioTokens.obsidian,
                            ),
                          ),
                        ),
                      )
                    : _users.isEmpty
                        ? const AdminStudioInnerCard(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Không có người dùng phù hợp.',
                                style: AdminStudioTokens.cardSubtitle,
                              ),
                            ),
                          )
                        : Column(
                            children: _users.map((u) {
                              final userId = '${u['userId'] ?? u['id'] ?? ''}';
                              final name =
                                  '${u['fullName'] ?? u['name'] ?? u['username'] ?? 'User #$userId'}';
                              final avatarUrl =
                                  '${u['avatarUrl'] ?? u['avatar'] ?? ''}'
                                      .trim();
                              final rawEmail = '${u['email'] ?? ''}'.trim();
                              final email =
                                  rawEmail.isNotEmpty && rawEmail != '-'
                                      ? rawEmail
                                      : '';
                              final rawPhone = '${u['phone'] ?? ''}'.trim();
                              final hasPhone = rawPhone.isNotEmpty &&
                                  rawPhone != '-' &&
                                  rawPhone != 'null';
                              final contactLine = [
                                if (email.isNotEmpty) email,
                                if (hasPhone) rawPhone,
                              ].join(' · ');

                              final role =
                                  '${u['role'] ?? (u['roles'] is List && (u['roles'] as List).isNotEmpty ? (u['roles'] as List).first : 'guest')}';
                              final status =
                                  '${u['status'] ?? 'active'}'.toLowerCase();
                              final locked = [
                                'blocked',
                                'suspended',
                                'locked',
                              ].contains(status);

                              final userHeader = Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  AdminStudioAvatar(
                                    name: name,
                                    imageUrl: avatarUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AdminStudioTokens
                                                      .cardTitle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (locked)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AdminStudioTokens
                                                        .dangerTint,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      AdminStudioTokens
                                                          .pillRadius,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Khóa',
                                                    style: AdminStudioTokens
                                                        .metaCaption
                                                        .copyWith(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: AdminStudioTokens
                                                          .dangerInk,
                                                    ),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: AdminStudioTokens
                                                        .successInk,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          child: Text(
                                            role,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                AdminStudioTokens.cardSubtitle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final canActOnUser =
                                  canManageUsers && _actionUserId != userId;
                              final lockLabel = locked ? 'Mở khóa' : 'Khóa';
                              final actionButtons = Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Semantics(
                                    button: true,
                                    enabled: canActOnUser,
                                    label: 'Sửa',
                                    child: Tooltip(
                                      message: 'Sửa',
                                      child: OutlinedButton(
                                        key: ValueKey(
                                          'admin-user-edit-$userId',
                                        ),
                                        style: _kCompactIconActionStyle,
                                        onPressed: !canActOnUser
                                            ? null
                                            : () => _openEditUserDialog(u),
                                        child: const Icon(
                                          LucideIcons.pencil,
                                          size: 15.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    enabled: canActOnUser,
                                    label: lockLabel,
                                    child: Tooltip(
                                      message: lockLabel,
                                      child: OutlinedButton(
                                        key: ValueKey(
                                          'admin-user-lock-$userId',
                                        ),
                                        style: _kCompactIconActionStyle,
                                        onPressed: !canActOnUser
                                            ? null
                                            : () => _toggleUserStatus(u),
                                        child: Icon(
                                          locked
                                              ? LucideIcons.lockOpen
                                              : LucideIcons.lock,
                                          size: 15.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              return AdminStudioInnerCard(
                                key: ValueKey('admin-user-row-$userId'),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: LayoutBuilder(
                                  builder: (context, rowConstraints) {
                                    final textScale =
                                        MediaQuery.textScalerOf(context)
                                            .scale(1);
                                    final isCompactRow =
                                        rowConstraints.maxWidth < 340 ||
                                            textScale > 1.25;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isCompactRow) ...[
                                          userHeader,
                                          const SizedBox(height: 10),
                                          actionButtons,
                                        ] else
                                          Row(
                                            children: [
                                              Expanded(child: userHeader),
                                              const SizedBox(width: 10),
                                              actionButtons,
                                            ],
                                          ),
                                        if (contactLine.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.mail,
                                                size: 13,
                                                color:
                                                    AdminStudioTokens.iconMuted,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  contactLine,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AdminStudioTokens
                                                      .metaCaption,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
              ),
              const SizedBox(height: 14),
              _AdminPaginationBar(
                page: _page,
                totalPages: _totalPages,
                total: _total,
                unitLabel: 'người dùng',
                loading: _loading,
                onPrev: () {
                  setState(() => _page -= 1);
                  _fetchUsers();
                },
                onNext: () {
                  setState(() => _page += 1);
                  _fetchUsers();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 3. KIỂM DUYỆT BÀI ĐĂNG (/admin/kiem-duyet) ──
class _AdminModerationTab extends ConsumerStatefulWidget {
  const _AdminModerationTab();

  @override
  ConsumerState<_AdminModerationTab> createState() =>
      _AdminModerationTabState();
}

class _AdminModerationTabState extends ConsumerState<_AdminModerationTab> {
  List<Map<String, dynamic>> _listings = const [];
  int _page = 1;
  final int _limit = 20;
  int _total = 0;
  int _totalPages = 1;
  bool _loading = true;
  String? _processingId;
  bool _modalActionLoading = false;
  String? _error;
  bool _isOffline = false;
  final Set<String> _viewedListingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending({bool preserveError = false}) async {
    setState(() {
      _loading = true;
      if (!preserveError) {
        _error = null;
        _isOffline = false;
      }
    });
    try {
      final paginated =
          await ref.read(adminRepositoryProvider).getPendingListingsPaginated(
                page: _page,
                limit: _limit,
              );
      if (!mounted) return;
      setState(() {
        _listings = paginated.items;
        _page = paginated.page;
        _total = paginated.total;
        _totalPages = paginated.totalPages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải bài chờ duyệt.',
        );
        _loading = false;
      });
    }
  }

  String _extractCoverImage(Map<String, dynamic> listing) {
    final direct =
        listing['coverImageUrl'] ?? listing['imageUrl'] ?? listing['image_url'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    if (listing['images'] is List && (listing['images'] as List).isNotEmpty) {
      final first = (listing['images'] as List).first;
      if (first is Map) {
        return '${first['url'] ?? first['imageUrl'] ?? first['image_url'] ?? ''}';
      }
      if (first is String) return first;
    }
    return '';
  }

  Future<void> _viewDetail(String listingId) async {
    setState(() {
      _modalActionLoading = true;
      _error = null;
      _isOffline = false;
    });
    try {
      final detail = await ref
          .read(adminRepositoryProvider)
          .getAdminListingDetail(listingId);
      if (!mounted) return;
      setState(() {
        _viewedListingIds.add(listingId);
        _modalActionLoading = false;
      });
      await _showListingDetailDialog(listingId, detail);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không tải được chi tiết căn.',
        );
        _modalActionLoading = false;
      });
    }
  }

  Future<void> _handleApprove(String listingId) async {
    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(actor)) {
      setState(() {
        _error = 'Bạn không có quyền kiểm duyệt bài đăng (403).';
      });
      return;
    }

    if (!_viewedListingIds.contains(listingId)) {
      setState(() {
        _error = 'Vui lòng xem chi tiết căn trước khi duyệt.';
      });
      return;
    }
    if (_processingId == listingId || _modalActionLoading) return;

    setState(() {
      _processingId = listingId;
      _modalActionLoading = true;
      _error = null;
      _isOffline = false;
    });
    try {
      await ref.read(adminRepositoryProvider).approveListing(listingId);
      if (!mounted) return;
      AppToast.show(
        context,
        'Đã phê duyệt bài đăng #$listingId.',
        type: AppToastType.success,
      );
      await _fetchPending();
    } catch (e) {
      if (!mounted) return;
      final statusCode = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(e, 'Duyệt căn thất bại.');
      });
      if (statusCode == 409) {
        await _fetchPending(preserveError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingId = null;
          _modalActionLoading = false;
        });
      }
    }
  }

  Future<void> _openRejectDialog(Map<String, dynamic> listing) async {
    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(actor)) {
      setState(() {
        _error = 'Bạn không có quyền kiểm duyệt bài đăng (403).';
      });
      return;
    }

    final listingId = '${listing['listingId'] ?? listing['id'] ?? ''}';
    if (!_viewedListingIds.contains(listingId)) {
      setState(() {
        _error = 'Vui lòng xem chi tiết căn trước khi từ chối.';
      });
      return;
    }

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Từ chối căn',
        subtitle: 'Nhập lý do từ chối để host biết cần chỉnh sửa gì.',
        maxWidth: 480,
        actions: [
          OutlinedButton(
            style: _kPillOutlinedStyle,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: _kPillElevatedStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
        child: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          decoration: _multilineInputDecoration(
            hintText:
                'Ví dụ: Ảnh chưa rõ, thiếu thông tin địa chỉ, giá chưa hợp lệ...',
          ),
        ),
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true) return;
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }

    setState(() {
      _processingId = listingId;
      _modalActionLoading = true;
      _error = null;
      _isOffline = false;
    });
    try {
      await ref.read(adminRepositoryProvider).rejectListing(listingId, reason);
      if (!mounted) return;
      AppToast.show(
        context,
        'Đã từ chối bài đăng #$listingId.',
        type: AppToastType.info,
      );
      await _fetchPending();
    } catch (e) {
      if (!mounted) return;
      final statusCode = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Từ chối căn thất bại.',
        );
      });
      if (statusCode == 409) {
        await _fetchPending(preserveError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingId = null;
          _modalActionLoading = false;
        });
      }
    }
  }

  List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => '$e'.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  String _formatAiConfidence(dynamic raw) {
    if (raw == null) return '-';
    final value = double.tryParse('$raw');
    if (value == null) return '$raw';
    final pct = value <= 1.0 ? (value * 100).round() : value.round();
    return '$pct%';
  }

  Future<void> _showListingDetailDialog(
    String listingId,
    Map<String, dynamic> initialDetail,
  ) async {
    Map<String, dynamic> currentDetail = initialDetail;
    bool reanalyzingAll = false;
    String? reanalyzingImageId;
    String? modalFeedback;
    bool modalFeedbackIsError = false;
    final actor = ref.read(authNotifierProvider).valueOrNull;
    final canAnalyzeAi = _isActorAdmin(actor);
    final canModerate = _isActorAdmin(actor);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final host = currentDetail['host'] is Map
              ? Map<String, dynamic>.from(currentDetail['host'] as Map)
              : const <String, dynamic>{};
          final rules = currentDetail['rules'] is Map
              ? Map<String, dynamic>.from(currentDetail['rules'] as Map)
              : const <String, dynamic>{};
          final images = currentDetail['images'] is List
              ? (currentDetail['images'] as List)
              : const <dynamic>[];
          final amenities = currentDetail['amenities'] is List
              ? (currentDetail['amenities'] as List)
              : const <dynamic>[];

          Future<void> handleReanalyzeAll() async {
            if (!canAnalyzeAi) {
              setModalState(() {
                modalFeedback =
                    'Chỉ Quản trị viên (Admin) mới có quyền chạy lại phân tích AI.';
                modalFeedbackIsError = true;
              });
              return;
            }
            setModalState(() {
              reanalyzingAll = true;
              modalFeedback = null;
            });
            try {
              await ref
                  .read(adminRepositoryProvider)
                  .analyzeAllListingImages(listingId, force: true);
              final refreshed = await ref
                  .read(adminRepositoryProvider)
                  .getAdminListingDetail(listingId);
              setModalState(() {
                currentDetail = refreshed;
                reanalyzingAll = false;
                modalFeedback = 'Đã phân tích lại AI toàn bộ ảnh của căn.';
                modalFeedbackIsError = false;
              });
            } catch (e) {
              setModalState(() {
                reanalyzingAll = false;
                modalFeedback = AdminRepository.extractErrorMessage(
                  e,
                  'Dịch vụ phân tích ảnh AI hiện không khả dụng.',
                );
                modalFeedbackIsError = true;
              });
            }
          }

          Future<void> handleReanalyzeSingle(String imageId) async {
            if (imageId.isEmpty) return;
            if (!canAnalyzeAi) {
              setModalState(() {
                modalFeedback =
                    'Chỉ Quản trị viên (Admin) mới có quyền chạy lại phân tích AI.';
                modalFeedbackIsError = true;
              });
              return;
            }
            setModalState(() {
              reanalyzingImageId = imageId;
              modalFeedback = null;
            });
            try {
              await ref
                  .read(adminRepositoryProvider)
                  .reanalyzeListingImage(imageId);
              final refreshed = await ref
                  .read(adminRepositoryProvider)
                  .getAdminListingDetail(listingId);
              setModalState(() {
                currentDetail = refreshed;
                reanalyzingImageId = null;
                modalFeedback = 'Đã phân tích lại AI cho ảnh #$imageId.';
                modalFeedbackIsError = false;
              });
            } catch (e) {
              setModalState(() {
                reanalyzingImageId = null;
                modalFeedback = AdminRepository.extractErrorMessage(
                  e,
                  'Không thể phân tích lại AI cho ảnh #$imageId.',
                );
                modalFeedbackIsError = true;
              });
            }
          }

          final viewInsets = MediaQuery.viewInsetsOf(ctx);

          return Dialog(
            backgroundColor: AdminStudioTokens.groupSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AdminStudioTokens.modalRadius),
            ),
            insetPadding: EdgeInsets.fromLTRB(
              12,
              16,
              12,
              math.max(16, viewInsets.bottom + 12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currentDetail['title'] ?? 'Chi tiết bài đăng'}',
                                style: AdminStudioTokens.headerGreeting,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  currentDetail['addressLine'],
                                  currentDetail['ward'],
                                  currentDetail['district'],
                                  currentDetail['city'],
                                ]
                                    .where(
                                      (e) =>
                                          e != null && '$e'.trim().isNotEmpty,
                                    )
                                    .join(', '),
                                style: AdminStudioTokens.cardSubtitle,
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: _kPillOutlinedStyle,
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (modalFeedback != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: modalFeedbackIsError
                              ? AdminStudioTokens.dangerTint
                              : AdminStudioTokens.successTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          modalFeedback!,
                          style: AdminStudioTokens.bodyRegular.copyWith(
                            fontWeight: FontWeight.w500,
                            color: modalFeedbackIsError
                                ? AdminStudioTokens.dangerInk
                                : AdminStudioTokens.successInk,
                          ),
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, bodyConstraints) {
                          final infoWidth = bodyConstraints.maxWidth >= 780
                              ? (bodyConstraints.maxWidth - 14) / 2
                              : bodyConstraints.maxWidth;
                          final imageCardWidth = bodyConstraints.maxWidth >= 560
                              ? 260.0
                              : bodyConstraints.maxWidth;

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    SizedBox(
                                      width: infoWidth,
                                      child: AdminStudioInnerCard(
                                        padding: const EdgeInsets.all(15),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Thông tin host',
                                              style:
                                                  AdminStudioTokens.cardTitle,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Họ tên: ${host['fullName'] ?? 'Chưa có'}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                            Text(
                                              'Email: ${host['email'] ?? 'Chưa có'}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                            Text(
                                              'SĐT: ${host['phone'] ?? 'Chưa có'}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                            Text(
                                              'Xác minh host: ${host['isHostVerified'] == true ? 'Đã xác minh' : 'Chưa xác minh'}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: infoWidth,
                                      child: AdminStudioInnerCard(
                                        padding: const EdgeInsets.all(15),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Giá & sức chứa',
                                              style:
                                                  AdminStudioTokens.cardTitle,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Giá thường: ${CurrencyFormatter.formatVnd((double.tryParse('${currentDetail['basePrice'] ?? 0}') ?? 0).round(), fallback: '0 ₫')}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                            Text(
                                              'Giá cuối tuần: ${CurrencyFormatter.formatVnd((double.tryParse('${currentDetail['weekendPrice'] ?? 0}') ?? 0).round(), fallback: '0 ₫')}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                            Text(
                                              'Phí dọn dẹp: ${CurrencyFormatter.formatVnd((double.tryParse('${currentDetail['cleaningFee'] ?? 0}') ?? 0).round(), fallback: '0 ₫')}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                            Text(
                                              'Khách tối đa: ${currentDetail['maxGuests'] ?? 0} · Phòng ngủ: ${currentDetail['bedrooms'] ?? 0} · Giường: ${currentDetail['beds'] ?? 0} · Phòng tắm: ${currentDetail['bathrooms'] ?? 0}',
                                              style:
                                                  AdminStudioTokens.bodyRegular,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                AdminStudioInnerCard(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mô tả',
                                        style: AdminStudioTokens.cardTitle,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${currentDetail['description'] ?? 'Chưa có mô tả'}',
                                        style: AdminStudioTokens.bodyRegular,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Ảnh căn & AI Image Analysis',
                                      style: AdminStudioTokens.sectionTitle,
                                    ),
                                    OutlinedButton.icon(
                                      style: _kPillOutlinedStyle,
                                      onPressed: reanalyzingAll || !canAnalyzeAi
                                          ? null
                                          : handleReanalyzeAll,
                                      icon: const Icon(
                                        LucideIcons.refreshCw,
                                        size: 14,
                                        color: AdminStudioTokens.iconInk,
                                      ),
                                      label: Text(
                                        reanalyzingAll
                                            ? 'Đang phân tích AI...'
                                            : 'Phân tích lại AI toàn bộ ảnh',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (images.isEmpty)
                                  const Text(
                                    'Căn chưa có ảnh đính kèm.',
                                    style: AdminStudioTokens.cardSubtitle,
                                  )
                                else
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: images.map((rawImg) {
                                      final img = rawImg is Map
                                          ? Map<String, dynamic>.from(rawImg)
                                          : <String, dynamic>{'url': '$rawImg'};
                                      final url =
                                          '${img['url'] ?? img['imageUrl'] ?? img['image_url'] ?? ''}';
                                      final imageId =
                                          '${img['imageId'] ?? img['id'] ?? img['listingImageId'] ?? ''}';
                                      final aiStatus =
                                          '${img['aiAnalysisStatus'] ?? 'pending'}';
                                      final aiImageType =
                                          '${img['aiImageType'] ?? img['displayTitle'] ?? ''}';
                                      final aiConfidence = _formatAiConfidence(
                                        img['aiConfidence'],
                                      );
                                      final sceneTags = _parseStringList(
                                        img['aiSceneTags'],
                                      );
                                      final amenityTags = _parseStringList(
                                        img['aiAmenityTags'],
                                      );
                                      final warnings = _parseStringList(
                                        img['aiQualityWarnings'],
                                      );
                                      final aiError =
                                          '${img['aiErrorMessage'] ?? ''}'
                                              .trim();
                                      final allLabels = [
                                        ...sceneTags,
                                        ...amenityTags,
                                      ];

                                      return SizedBox(
                                        width: imageCardWidth,
                                        child: AdminStudioInnerCard(
                                          warningHighlight:
                                              warnings.isNotEmpty ||
                                                  aiError.isNotEmpty,
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (url.isNotEmpty)
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: AppImage(
                                                    imageUrl: url,
                                                    width: imageCardWidth - 24,
                                                    height: 140,
                                                  ),
                                                ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                alignment:
                                                    WrapAlignment.spaceBetween,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: aiStatus ==
                                                              'completed'
                                                          ? AdminStudioTokens
                                                              .successTint
                                                          : aiStatus == 'failed'
                                                              ? AdminStudioTokens
                                                                  .dangerTint
                                                              : AdminStudioTokens
                                                                  .softCircle,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        AdminStudioTokens
                                                            .pillRadius,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'AI: $aiStatus',
                                                      style: AdminStudioTokens
                                                          .metaCaption
                                                          .copyWith(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: AdminStudioTokens
                                                            .inkPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    'Độ tin cậy: $aiConfidence',
                                                    style: AdminStudioTokens
                                                        .metaCaption
                                                        .copyWith(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (aiImageType.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Phân loại: $aiImageType',
                                                  style: AdminStudioTokens
                                                      .metaCaption
                                                      .copyWith(
                                                    color: AdminStudioTokens
                                                        .inkPrimary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                              if (allLabels.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: allLabels
                                                      .take(6)
                                                      .map((tag) {
                                                    return Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AdminStudioTokens
                                                            .softCircle,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          AdminStudioTokens
                                                              .pillRadius,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        tag,
                                                        style: AdminStudioTokens
                                                            .metaCaption
                                                            .copyWith(
                                                          fontSize: 11,
                                                          color:
                                                              AdminStudioTokens
                                                                  .inkSecondary,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                              if (warnings.isNotEmpty ||
                                                  aiError.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: AdminStudioTokens
                                                        .warningTint,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      12,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    [
                                                      ...warnings,
                                                      if (aiError.isNotEmpty)
                                                        aiError,
                                                    ].join(' · '),
                                                    style: AdminStudioTokens
                                                        .metaCaption
                                                        .copyWith(
                                                      fontSize: 11,
                                                      color: AdminStudioTokens
                                                          .inkPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (imageId.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton.icon(
                                                    style:
                                                        _kCompactPillOutlinedStyle,
                                                    onPressed: reanalyzingImageId ==
                                                                imageId ||
                                                            reanalyzingAll ||
                                                            !canAnalyzeAi
                                                        ? null
                                                        : () =>
                                                            handleReanalyzeSingle(
                                                              imageId,
                                                            ),
                                                    icon: const Icon(
                                                      LucideIcons.refreshCw,
                                                      size: 13,
                                                      color: AdminStudioTokens
                                                          .iconInk,
                                                    ),
                                                    label: Text(
                                                      reanalyzingImageId ==
                                                              imageId
                                                          ? 'Đang phân tích...'
                                                          : 'Phân tích lại AI',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                if (amenities.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Tiện ích',
                                    style: AdminStudioTokens.cardTitle,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: amenities.map((a) {
                                      final label = a is Map
                                          ? '${a['name'] ?? a['code'] ?? ''}'
                                          : '$a';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            AdminStudioTokens.pillRadius,
                                          ),
                                          boxShadow:
                                              AdminStudioTokens.cardShadow,
                                        ),
                                        child: Text(
                                          label,
                                          style: AdminStudioTokens.metaCaption
                                              .copyWith(
                                            color: AdminStudioTokens.inkPrimary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                AdminStudioInnerCard(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Nội quy',
                                        style: AdminStudioTokens.cardTitle,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Nhận phòng: ${rules['checkInFrom'] ?? '14:00'} · Trả phòng: ${rules['checkOutBefore'] ?? '12:00'} · Hút thuốc: ${rules['smokingAllowed'] == true ? 'Cho phép' : 'Không'} · Thú cưng: ${rules['petsAllowed'] == true ? 'Cho phép' : 'Không'} · Tiệc: ${rules['partyAllowed'] == true ? 'Cho phép' : 'Không'}',
                                        style: AdminStudioTokens.bodyRegular,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _kPillOutlinedStyle,
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                        OutlinedButton(
                          style: _kPillOutlinedStyle,
                          onPressed: !canModerate
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await _openRejectDialog({
                                    ...currentDetail,
                                    'listingId': listingId,
                                  });
                                },
                          child: const Text('Từ chối căn này'),
                        ),
                        ElevatedButton(
                          style: _kPillElevatedStyle,
                          onPressed: !canModerate
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await _handleApprove(listingId);
                                },
                          child: const Text('Duyệt căn này'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canModerate = _isActorAdmin(actor);

    return SingleChildScrollView(
      padding: _studioScrollPadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canModerate)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AdminStudioInnerCard(
                    warningHighlight: true,
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Chỉ Quản trị viên (Admin) mới có quyền phê duyệt / từ chối bài đăng.',
                      style: AdminStudioTokens.bodyRegular,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminErrorBanner(
                    message: _error!,
                    isOffline: _isOffline,
                    onRetry: _loading ? null : _fetchPending,
                  ),
                ),
              AdminStudioGroupCard(
                title: 'Hàng đợi kiểm duyệt',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AdminStudioTokens.pillRadius,
                    ),
                  ),
                  child: Text(
                    _loading
                        ? 'Đang tải danh sách...'
                        : '$_total bài chờ duyệt',
                    style: AdminStudioTokens.metaCaption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AdminStudioTokens.inkPrimary,
                    ),
                  ),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminStudioTokens.obsidian,
                            ),
                          ),
                        ),
                      )
                    : _listings.isEmpty
                        ? const AdminStudioInnerCard(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Không có listing chờ duyệt.',
                                style: AdminStudioTokens.cardSubtitle,
                              ),
                            ),
                          )
                        : Column(
                            children: _listings.map((item) {
                              final listingId =
                                  '${item['listingId'] ?? item['id'] ?? ''}';
                              final cover = _extractCoverImage(item);
                              final address = [
                                item['addressLine'],
                                item['ward'],
                                item['district'],
                                item['city'],
                              ]
                                  .where(
                                    (e) => e != null && '$e'.trim().isNotEmpty,
                                  )
                                  .join(', ');
                              final price = double.tryParse(
                                    '${item['basePrice'] ?? 0}',
                                  ) ??
                                  0;
                              final hasViewed =
                                  _viewedListingIds.contains(listingId);

                              return AdminStudioInnerCard(
                                key:
                                    ValueKey('admin-moderation-row-$listingId'),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 10,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (cover.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: AppImage(
                                              imageUrl: cover,
                                              width: 92,
                                              height: 66,
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 92,
                                            height: 66,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color:
                                                  AdminStudioTokens.softCircle,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: const Text(
                                              'Chưa có ảnh',
                                              style:
                                                  AdminStudioTokens.metaCaption,
                                            ),
                                          ),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 320,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item['title'] ?? 'Chỗ nghỉ'}',
                                                style:
                                                    AdminStudioTokens.cardTitle,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item['propertyType'] ?? 'villa'}${hasViewed ? ' · Đã xem chi tiết' : ''}',
                                                style: AdminStudioTokens
                                                    .cardSubtitle,
                                              ),
                                              if (address.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      LucideIcons.mapPin,
                                                      size: 12.5,
                                                      color: AdminStudioTokens
                                                          .iconMuted,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        address,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: AdminStudioTokens
                                                            .metaCaption,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(
                                                CurrencyFormatter.formatVnd(
                                                  price.round(),
                                                  fallback: '0 ₫',
                                                ),
                                                style: AdminStudioTokens
                                                    .pillText
                                                    .copyWith(
                                                  fontSize: 13.5,
                                                  color: AdminStudioTokens
                                                      .inkPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton(
                                          style: _kCompactPillOutlinedStyle,
                                          onPressed: _modalActionLoading
                                              ? null
                                              : () => _viewDetail(listingId),
                                          child: const Text('Xem chi tiết'),
                                        ),
                                        ElevatedButton(
                                          style: _kCompactPillElevatedStyle,
                                          onPressed: !canModerate ||
                                                  _processingId == listingId
                                              ? null
                                              : () => _handleApprove(listingId),
                                          child: Text(
                                            _processingId == listingId
                                                ? 'Đang duyệt...'
                                                : 'Duyệt',
                                          ),
                                        ),
                                        OutlinedButton(
                                          style: _kCompactPillOutlinedStyle,
                                          onPressed: !canModerate ||
                                                  _processingId == listingId
                                              ? null
                                              : () => _openRejectDialog(item),
                                          child: const Text('Từ chối'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
              ),
              if (!_loading && (_listings.isNotEmpty || _totalPages > 1)) ...[
                const SizedBox(height: 14),
                _AdminPaginationBar(
                  page: _page,
                  totalPages: _totalPages,
                  total: _total,
                  unitLabel: 'bài chờ duyệt',
                  loading: _loading,
                  onPrev: () {
                    setState(() => _page -= 1);
                    _fetchPending();
                  },
                  onNext: () {
                    setState(() => _page += 1);
                    _fetchPending();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 4. HỒ SƠ ĐĂNG KÝ HOST (/admin/ho-so-host) ──
class _AdminHostApplicationsTab extends ConsumerStatefulWidget {
  const _AdminHostApplicationsTab();

  @override
  ConsumerState<_AdminHostApplicationsTab> createState() =>
      _AdminHostApplicationsTabState();
}

class _AdminHostApplicationsTabState
    extends ConsumerState<_AdminHostApplicationsTab> {
  String _status = 'pending';
  List<Map<String, dynamic>> _applications = const [];
  int _appPage = 1;
  int _appTotal = 0;
  int _appTotalPages = 1;
  String? _selectedId;
  bool _loadingList = true;
  bool _loadingDetail = false;
  final TextEditingController _rejectReasonCtrl = TextEditingController();
  String? _error;
  bool _isOffline = false;
  String? _message;

  // Legacy Verifications state
  String _verificationStatus = 'all';
  List<Map<String, dynamic>> _verifications = const [];
  int _verificationPage = 1;
  int _verificationTotal = 0;
  int _verificationTotalPages = 1;
  bool _loadingVerifications = true;
  String? _verificationError;
  bool _verificationOffline = false;
  String? _processingVerificationId;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
    _fetchVerifications();
  }

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchApplications({bool preserveError = false}) async {
    setState(() {
      _loadingList = true;
      if (!preserveError) {
        _error = null;
        _isOffline = false;
      }
    });
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .getAdminHostApplicationsPaginated(
            status: _status,
            page: _appPage,
            limit: 20,
          );
      if (!mounted) return;
      setState(() {
        _applications = result.items;
        _appPage = result.page;
        _appTotal = result.total;
        _appTotalPages = result.totalPages;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải danh sách hồ sơ host.',
        );
        _loadingList = false;
      });
    }
  }

  Future<void> _fetchVerifications({bool preserveError = false}) async {
    setState(() {
      _loadingVerifications = true;
      if (!preserveError) {
        _verificationError = null;
        _verificationOffline = false;
      }
    });
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .getAdminVerificationsPaginated(
            status: _verificationStatus,
            page: _verificationPage,
            limit: 20,
          );
      if (!mounted) return;
      setState(() {
        _verifications = result.items;
        _verificationPage = result.page;
        _verificationTotal = result.total;
        _verificationTotalPages = result.totalPages;
        _loadingVerifications = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifications = const [];
        _verificationOffline = AdminRepository.isOfflineError(e);
        _verificationError = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải danh sách Legacy Verifications.',
        );
        _loadingVerifications = false;
      });
    }
  }

  Future<void> _approveVerification(String verificationId) async {
    if (verificationId.isEmpty) return;
    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(actor)) {
      setState(() {
        _error = 'Chỉ Quản trị viên (Admin) mới có quyền duyệt xác minh (403).';
      });
      return;
    }

    setState(() {
      _processingVerificationId = verificationId;
      _error = null;
      _verificationError = null;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .approveHostVerification(verificationId);
      if (!mounted) return;
      setState(() => _message = 'Đã duyệt xác minh #$verificationId.');
      AppToast.show(
        context,
        'Đã duyệt xác minh #$verificationId.',
        type: AppToastType.success,
      );
      await _fetchVerifications();
    } catch (e) {
      if (!mounted) return;
      final status = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể duyệt xác minh.',
        );
      });
      if (status == 409) {
        await _fetchVerifications(preserveError: true);
      }
    } finally {
      if (mounted) setState(() => _processingVerificationId = null);
    }
  }

  Future<void> _rejectVerification(String verificationId) async {
    if (verificationId.isEmpty) return;
    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(actor)) {
      setState(() {
        _error =
            'Chỉ Quản trị viên (Admin) mới có quyền từ chối xác minh (403).';
      });
      return;
    }

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Từ chối xác minh #$verificationId',
        subtitle: 'Nhập lý do từ chối giấy tờ xác minh này.',
        maxWidth: 440,
        actions: [
          OutlinedButton(
            style: _kPillOutlinedStyle,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: _kPillElevatedStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Từ chối'),
          ),
        ],
        child: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: _multilineInputDecoration(
            hintText: 'Ví dụ: Ảnh giấy tờ bị mờ hoặc hết hạn...',
          ),
        ),
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true) return;
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối xác minh.');
      return;
    }

    setState(() {
      _processingVerificationId = verificationId;
      _error = null;
      _verificationError = null;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .rejectHostVerification(verificationId, reason);
      if (!mounted) return;
      setState(() => _message = 'Đã từ chối xác minh #$verificationId.');
      await _fetchVerifications();
    } catch (e) {
      if (!mounted) return;
      final status = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể từ chối xác minh.',
        );
      });
      if (status == 409) {
        await _fetchVerifications(preserveError: true);
      }
    } finally {
      if (mounted) setState(() => _processingVerificationId = null);
    }
  }

  Future<void> _openApplicationDetail(String applicationId) async {
    if (applicationId.isEmpty || _loadingDetail) return;
    setState(() {
      _selectedId = applicationId;
      _loadingDetail = true;
      _error = null;
      _isOffline = false;
      _message = null;
      _rejectReasonCtrl.clear();
    });
    try {
      final detail = await ref
          .read(adminRepositoryProvider)
          .getAdminHostApplicationDetail(applicationId);
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
      });
      await _showHostApplicationDetailDialog(applicationId, detail);
      if (mounted) {
        setState(() {
          _selectedId = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải chi tiết hồ sơ host.',
        );
        _selectedId = null;
        _loadingDetail = false;
      });
    }
  }

  Future<void> _showHostApplicationDetailDialog(
    String applicationId,
    Map<String, dynamic> initialDetail,
  ) async {
    final Map<String, dynamic> currentDetail = initialDetail;
    bool actionLoading = false;
    String? rejectReasonError;
    String? modalError;
    bool modalIsOffline = false;
    final actor = ref.read(authNotifierProvider).valueOrNull;
    final canManageHostApps = _isActorAdmin(actor);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final appId =
              '${currentDetail['applicationId'] ?? currentDetail['id'] ?? applicationId}';
          final documents = currentDetail['documents'] is List
              ? (currentDetail['documents'] as List)
              : const <dynamic>[];

          Future<void> handleApprove() async {
            if (appId.isEmpty) return;
            final latestActor = ref.read(authNotifierProvider).valueOrNull;
            if (!_isActorAdmin(latestActor)) {
              setModalState(() {
                modalError =
                    'Chỉ Quản trị viên (Admin) mới có quyền phê duyệt hồ sơ host (403).';
                modalIsOffline = false;
              });
              return;
            }

            setModalState(() {
              actionLoading = true;
              modalError = null;
              rejectReasonError = null;
              modalIsOffline = false;
            });
            try {
              await ref
                  .read(adminRepositoryProvider)
                  .approveHostApplication(appId);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (!mounted) return;
              final successMsg =
                  'Đã duyệt hồ sơ chủ nhà #$appId. Hồ sơ đã chuyển vào mục "Đã duyệt".';
              setState(() {
                _message = successMsg;
                _error = null;
                _isOffline = false;
              });
              AppToast.show(context, successMsg, type: AppToastType.success);
              await _fetchApplications();
            } catch (e) {
              final status = AdminRepository.extractStatusCode(e);
              final errMsg = AdminRepository.extractErrorMessage(
                e,
                'Không thể duyệt hồ sơ.',
              );
              final offline = AdminRepository.isOfflineError(e);
              if (ctx.mounted) {
                setModalState(() {
                  actionLoading = false;
                  modalError = errMsg;
                  modalIsOffline = offline;
                });
              }
              if (status == 409 && mounted) {
                await _fetchApplications(preserveError: true);
              }
            }
          }

          Future<void> handleReject() async {
            if (appId.isEmpty) return;
            final latestActor = ref.read(authNotifierProvider).valueOrNull;
            if (!_isActorAdmin(latestActor)) {
              setModalState(() {
                modalError =
                    'Chỉ Quản trị viên (Admin) mới có quyền từ chối hồ sơ host (403).';
                modalIsOffline = false;
              });
              return;
            }

            final reason = _rejectReasonCtrl.text.trim();
            if (reason.isEmpty) {
              setModalState(() {
                rejectReasonError = 'Vui lòng nhập lý do từ chối.';
              });
              return;
            }

            setModalState(() {
              actionLoading = true;
              modalError = null;
              rejectReasonError = null;
              modalIsOffline = false;
            });
            try {
              await ref
                  .read(adminRepositoryProvider)
                  .rejectHostApplication(appId, reason);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (!mounted) return;
              final infoMsg =
                  'Đã từ chối hồ sơ chủ nhà #$appId. Hồ sơ đã chuyển vào mục "Từ chối".';
              setState(() {
                _message = infoMsg;
                _error = null;
                _isOffline = false;
              });
              AppToast.show(context, infoMsg, type: AppToastType.info);
              await _fetchApplications();
            } catch (e) {
              final status = AdminRepository.extractStatusCode(e);
              final errMsg = AdminRepository.extractErrorMessage(
                e,
                'Không thể từ chối hồ sơ.',
              );
              final offline = AdminRepository.isOfflineError(e);
              if (ctx.mounted) {
                setModalState(() {
                  actionLoading = false;
                  modalError = errMsg;
                  modalIsOffline = offline;
                });
              }
              if (status == 409 && mounted) {
                await _fetchApplications(preserveError: true);
              }
            }
          }

          final viewInsets = MediaQuery.viewInsetsOf(ctx);
          final screenHeight = MediaQuery.sizeOf(ctx).height;
          final maxDialogHeight = math.min(
            780.0,
            math.max(240.0, screenHeight - viewInsets.bottom - 36),
          );

          return Dialog(
            key: const Key('admin_host_app_detail_dialog'),
            backgroundColor: AdminStudioTokens.groupSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AdminStudioTokens.modalRadius),
              side: const BorderSide(
                color: AdminStudioTokens.groupBorder,
                width: 1.2,
              ),
            ),
            insetPadding: EdgeInsets.fromLTRB(
              12,
              16,
              12,
              math.max(16, viewInsets.bottom + 12),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: maxDialogHeight,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (modalError != null) ...[
                      _AdminErrorBanner(
                        message: modalError!,
                        isOffline: modalIsOffline,
                      ),
                      const SizedBox(height: 12),
                    ],
                    AdminStudioInnerCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${currentDetail['contactName'] ?? (currentDetail['user'] is Map ? currentDetail['user']['name'] : null) ?? 'Hồ sơ host'}',
                                      style: AdminStudioTokens.headerGreeting,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildHostAppStatusBadge(
                                      currentDetail['status'],
                                    ),
                                  ],
                                ),
                              ),
                              AdminStudioCircleButton(
                                icon: LucideIcons.x,
                                tooltip: 'Đóng chi tiết',
                                circleColor: AdminStudioTokens.softCircle,
                                onTap: actionLoading
                                    ? null
                                    : () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'SĐT: ${currentDetail['phone'] ?? '-'} · Loại: ${currentDetail['profileType'] ?? 'individual'}',
                            style: AdminStudioTokens.cardSubtitle,
                          ),
                          if (currentDetail['idNumber'] != null ||
                              currentDetail['idNumberMasked'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Số định danh (KYC): ${AdminRepository.maskKycIdentifier('${currentDetail['idNumberMasked'] ?? currentDetail['idNumber'] ?? ''}')}',
                              style: AdminStudioTokens.cardSubtitle,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Địa chỉ kinh doanh: ${currentDetail['businessAddress'] ?? '-'}',
                            style: AdminStudioTokens.bodyRegular,
                          ),
                          if (currentDetail['note'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Ghi chú: ${currentDetail['note']}',
                              style: AdminStudioTokens.bodyRegular,
                            ),
                          ],
                          if (currentDetail['rejectReason'] != null &&
                              '${currentDetail['rejectReason']}'.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AdminStudioTokens.dangerTint,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Lý do từ chối trước đó: ${currentDetail['rejectReason']}',
                                style: AdminStudioTokens.bodyRegular.copyWith(
                                  color: AdminStudioTokens.dangerInk,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Giấy tờ xác minh (${documents.length})',
                        style: AdminStudioTokens.sectionTitle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (documents.isNotEmpty)
                      ...documents.map((rawDoc) {
                        final doc = rawDoc is Map
                            ? Map<String, dynamic>.from(rawDoc)
                            : const <String, dynamic>{};
                        final fileUrl =
                            '${doc['fileUrl'] ?? doc['proxyUrl'] ?? ''}';
                        final signedUrl = '${doc['signedUrl'] ?? ''}';
                        final previewUrl =
                            fileUrl.isNotEmpty ? fileUrl : signedUrl;
                        final mimeType = '${doc['mimeType'] ?? ''}';
                        return AdminStudioInnerCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${doc['documentType'] ?? 'cccd'} / ${doc['side'] ?? 'front'}',
                                style: AdminStudioTokens.cardTitle,
                              ),
                              const SizedBox(height: 8),
                              if (previewUrl.isNotEmpty &&
                                  mimeType != 'application/pdf')
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AppImage(
                                    imageUrl: previewUrl,
                                    height: 180,
                                    width: double.infinity,
                                  ),
                                ),
                              if (signedUrl.isNotEmpty ||
                                  previewUrl.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  style: _kPillOutlinedStyle,
                                  onPressed: () async {
                                    final target = signedUrl.isNotEmpty
                                        ? signedUrl
                                        : previewUrl;
                                    final resolvedTarget =
                                        target.startsWith('http')
                                            ? target
                                            : AppImage.resolveNetworkUrl(
                                                target,
                                              );
                                    final uri = Uri.tryParse(resolvedTarget);
                                    if (uri != null &&
                                        UrlSecurityValidator
                                            .isTrustedAdminDocumentUrl(
                                          resolvedTarget,
                                        )) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } else if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Liên kết tài liệu không thuộc nguồn tin cậy hoặc không an toàn.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Mở tài liệu'),
                                ),
                              ],
                            ],
                          ),
                        );
                      })
                    else
                      const AdminStudioInnerCard(
                        child: Text(
                          'Không có giấy tờ đính kèm.',
                          style: AdminStudioTokens.cardSubtitle,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (currentDetail['status'] == 'approved')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AdminStudioTokens.successTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.circleCheck,
                              color: AdminStudioTokens.successInk,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Hồ sơ này đã được phê duyệt thành công. Người dùng đã có quyền Host.',
                                style: AdminStudioTokens.bodyRegular.copyWith(
                                  color: AdminStudioTokens.successInk,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (currentDetail['status'] == 'rejected')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AdminStudioTokens.dangerTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.circleX,
                              color: AdminStudioTokens.dangerInk,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hồ sơ này đã bị từ chối.',
                                    style:
                                        AdminStudioTokens.bodyRegular.copyWith(
                                      color: AdminStudioTokens.dangerInk,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (currentDetail['rejectReason'] != null &&
                                      '${currentDetail['rejectReason']}'
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lý do từ chối: ${currentDetail['rejectReason']}',
                                      style: AdminStudioTokens.bodyRegular,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      AdminStudioInnerCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quyết định xét duyệt',
                              style: AdminStudioTokens.cardTitle,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const Key(
                                'admin_host_app_reject_reason_field',
                              ),
                              controller: _rejectReasonCtrl,
                              maxLines: 3,
                              onChanged: (_) {
                                if (rejectReasonError != null) {
                                  setModalState(
                                    () => rejectReasonError = null,
                                  );
                                }
                              },
                              decoration: _multilineInputDecoration(
                                hintText:
                                    'Nhập lý do nếu bạn muốn từ chối hồ sơ này...',
                                errorText: rejectReasonError,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  style: _kPillElevatedStyle,
                                  onPressed:
                                      !canManageHostApps || actionLoading
                                          ? null
                                          : handleApprove,
                                  child: Text(
                                    actionLoading
                                        ? 'Đang xử lý...'
                                        : 'Phê duyệt hồ sơ',
                                  ),
                                ),
                                OutlinedButton(
                                  key: const Key(
                                    'admin_host_app_reject_btn',
                                  ),
                                  style: _kPillOutlinedStyle,
                                  onPressed:
                                      !canManageHostApps || actionLoading
                                          ? null
                                          : handleReject,
                                  child: const Text('Từ chối'),
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
        },
      ),
    );
  }

  Widget _buildHostAppStatusBadge(dynamic rawStatus) {
    final status = '$rawStatus'.toLowerCase();
    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AdminStudioTokens.successTint,
          borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.circleCheck,
              size: 13.5,
              color: AdminStudioTokens.successInk,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Đã phê duyệt (Đã cấp quyền Host)',
                style: AdminStudioTokens.metaCaption.copyWith(
                  color: AdminStudioTokens.successInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'rejected') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AdminStudioTokens.dangerTint,
          borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.circleX,
              size: 13.5,
              color: AdminStudioTokens.dangerInk,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Đã từ chối',
                style: AdminStudioTokens.metaCaption.copyWith(
                  color: AdminStudioTokens.dangerInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminStudioTokens.warningTint,
        borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.clock,
            size: 13.5,
            color: AdminStudioTokens.warningInk,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Chờ phê duyệt',
              style: AdminStudioTokens.metaCaption.copyWith(
                color: AdminStudioTokens.warningInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label, IconData icon) {
    final isSelected = _status == value;
    return AdminStudioFilterPill(
      key: Key('admin_host_app_filter_$value'),
      label: label,
      icon: icon,
      selected: isSelected,
      onTap: () {
        if (_status == value) return;
        setState(() {
          _status = value;
          _appPage = 1;
          _selectedId = null;
        });
        _fetchApplications();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canManageHostApps = _isActorAdmin(actor);

    final listSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminStudioGroupCard(
          title: 'Hồ sơ đăng ký Host',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
            ),
            child: Text(
              '$_appTotal hồ sơ',
              style: AdminStudioTokens.metaCaption.copyWith(
                fontWeight: FontWeight.w500,
                color: AdminStudioTokens.inkPrimary,
              ),
            ),
          ),
          child: _loadingList
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminStudioTokens.obsidian,
                      ),
                    ),
                  ),
                )
              : _applications.isEmpty
                  ? AdminStudioInnerCard(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          _status == 'pending'
                              ? 'Không có hồ sơ nào đang chờ duyệt.'
                              : _status == 'approved'
                                  ? 'Chưa có hồ sơ nào đã duyệt.'
                                  : _status == 'rejected'
                                      ? 'Chưa có hồ sơ nào bị từ chối.'
                                      : 'Không có hồ sơ host phù hợp.',
                          style: AdminStudioTokens.cardSubtitle,
                        ),
                      ),
                    )
                  : Column(
                      children: _applications.map((app) {
                        final appId =
                            '${app['applicationId'] ?? app['id'] ?? ''}';
                        final user = app['user'] is Map
                            ? Map<String, dynamic>.from(app['user'] as Map)
                            : const <String, dynamic>{};
                        final name =
                            '${user['name'] ?? app['contactName'] ?? 'Host #$appId'}';
                        final avatarUrl =
                            '${user['avatarUrl'] ?? user['avatar'] ?? ''}'
                                .trim();
                        final rawEmail =
                            '${user['email'] ?? app['contactEmail'] ?? ''}'
                                .trim();
                        final rawPhone =
                            '${app['phone'] ?? user['phone'] ?? ''}'.trim();
                        final contactLine = [
                          if (rawEmail.isNotEmpty && rawEmail != '-') rawEmail,
                          if (rawPhone.isNotEmpty && rawPhone != '-') rawPhone,
                        ].join(' · ');
                        final status = '${app['status'] ?? 'pending'}';
                        final selected = appId == _selectedId;

                        return AdminStudioInnerCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          selected: selected,
                          onTap: _loadingDetail
                              ? null
                              : () => _openApplicationDetail(appId),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AdminStudioAvatar(
                                    name: name,
                                    imageUrl: avatarUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 11),
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 260),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: AdminStudioTokens.cardTitle,
                                          ),
                                          if (contactLine.isNotEmpty)
                                            Text(
                                              contactLine,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AdminStudioTokens
                                                  .cardSubtitle,
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                LucideIcons.fileText,
                                                size: 12.5,
                                                color:
                                                    AdminStudioTokens.iconMuted,
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  '${status == 'approved' ? 'Đã duyệt' : status == 'rejected' ? 'Đã từ chối' : 'Chờ duyệt'} · Giấy tờ: ${app['documentCount'] ?? 0}',
                                                  style: AdminStudioTokens
                                                      .metaCaption
                                                      .copyWith(
                                                    color: AdminStudioTokens
                                                        .inkSecondary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton(
                                style: _kCompactPillOutlinedStyle,
                                onPressed: _loadingDetail
                                    ? null
                                    : () => _openApplicationDetail(appId),
                                child: Text(
                                  _loadingDetail && selected
                                      ? 'Đang tải...'
                                      : 'Chi tiết',
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ),
        if (_appTotalPages > 1 || _applications.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AdminPaginationBar(
            page: _appPage,
            totalPages: _appTotalPages,
            total: _appTotal,
            unitLabel: 'hồ sơ',
            loading: _loadingList,
            onPrev: () {
              setState(() => _appPage -= 1);
              _fetchApplications();
            },
            onNext: () {
              setState(() => _appPage += 1);
              _fetchApplications();
            },
          ),
        ],
      ],
    );

    final verificationsSection = AdminStudioGroupCard(
      title: 'Bảng Legacy Verifications',
      trailing: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
          boxShadow: AdminStudioTokens.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _verificationStatus,
                isDense: true,
                icon: const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 14,
                    color: AdminStudioTokens.iconMuted,
                  ),
                ),
                style: AdminStudioTokens.pillText.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AdminStudioTokens.inkPrimary,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Chờ duyệt'),
                  ),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Đã duyệt'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Từ chối'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _verificationStatus = value;
                    _verificationPage = 1;
                  });
                  _fetchVerifications();
                },
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_verificationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminErrorBanner(
                message: _verificationError!,
                isOffline: _verificationOffline,
                onRetry: _loadingVerifications ? null : _fetchVerifications,
              ),
            ),
          if (_loadingVerifications)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdminStudioTokens.obsidian,
                  ),
                ),
              ),
            )
          else if (_verifications.isEmpty && _verificationError == null)
            const AdminStudioInnerCard(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Text(
                  'Không có bản ghi Legacy Verification nào.',
                  style: AdminStudioTokens.cardSubtitle,
                ),
              ),
            )
          else if (_verifications.isNotEmpty)
            Column(
              children: _verifications.map((v) {
                final verificationId =
                    '${v['verificationId'] ?? v['id'] ?? ''}';
                final hostName =
                    '${v['fullName'] ?? (v['user'] is Map ? v['user']['fullName'] : null) ?? 'Host #${v['userId'] ?? verificationId}'}';
                final vType =
                    '${v['verificationType'] ?? v['documentType'] ?? 'identity'}';
                final vStatus = '${v['status'] ?? 'pending'}';
                final rawIdNum =
                    '${v['idNumberMasked'] ?? v['idNumber'] ?? ''}'.trim();
                final maskedIdNum = rawIdNum.isNotEmpty
                    ? ' · Định danh: ${AdminRepository.maskKycIdentifier(rawIdNum)}'
                    : '';
                final isProcessing =
                    _processingVerificationId == verificationId;

                return AdminStudioInnerCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AdminStudioAvatar(name: hostName, size: 38),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$hostName (#$verificationId)',
                                  style: AdminStudioTokens.cardTitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Loại: ${vType == 'identity' ? 'Định danh (CCCD/CMND)' : vType} · Trạng thái: ${vStatus == 'approved' ? 'Đã duyệt' : vStatus == 'rejected' ? 'Đã từ chối' : 'Chờ duyệt'}$maskedIdNum',
                                  style: AdminStudioTokens.metaCaption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ElevatedButton(
                            style: _kCompactPillElevatedStyle,
                            onPressed: !canManageHostApps ||
                                    isProcessing ||
                                    vStatus == 'approved'
                                ? null
                                : () => _approveVerification(verificationId),
                            child: const Text('Duyệt xác minh'),
                          ),
                          OutlinedButton(
                            style: _kCompactPillOutlinedStyle,
                            onPressed: !canManageHostApps ||
                                    isProcessing ||
                                    vStatus == 'rejected'
                                ? null
                                : () => _rejectVerification(verificationId),
                            child: const Text('Từ chối'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (_verificationTotalPages > 1) ...[
            const SizedBox(height: 8),
            _AdminPaginationBar(
              page: _verificationPage,
              totalPages: _verificationTotalPages,
              total: _verificationTotal,
              unitLabel: 'bản ghi xác minh',
              loading: _loadingVerifications,
              onPrev: () {
                setState(() => _verificationPage -= 1);
                _fetchVerifications();
              },
              onNext: () {
                setState(() => _verificationPage += 1);
                _fetchVerifications();
              },
            ),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: _studioScrollPadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildStatusFilterChip(
                    'pending',
                    'Chờ duyệt',
                    LucideIcons.clock,
                  ),
                  _buildStatusFilterChip(
                    'approved',
                    'Đã duyệt',
                    LucideIcons.circleCheck,
                  ),
                  _buildStatusFilterChip(
                    'rejected',
                    'Từ chối',
                    LucideIcons.circleX,
                  ),
                  _buildStatusFilterChip(
                    'all',
                    'Tất cả',
                    LucideIcons.layers,
                  ),
                ],
              ),
              if (!canManageHostApps) ...[
                const SizedBox(height: 12),
                const AdminStudioInnerCard(
                  warningHighlight: true,
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Chỉ Quản trị viên (Admin) mới có quyền phê duyệt hoặc từ chối hồ sơ đăng ký Host.',
                    style: AdminStudioTokens.bodyRegular,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _AdminErrorBanner(
                  message: _error!,
                  isOffline: _isOffline,
                  onRetry: _loadingList ? null : _fetchApplications,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminStudioTokens.successTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _message!,
                    style: AdminStudioTokens.bodyRegular.copyWith(
                      color: AdminStudioTokens.successInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              listSection,
              const SizedBox(height: 16),
              verificationsSection,
            ],
          ),
        ),
      ),
    );
  }
}

// ── 5. PHÂN QUYỀN HỆ THỐNG (/admin/phan-quyen) ──
class _AdminRolesTab extends ConsumerStatefulWidget {
  const _AdminRolesTab();

  @override
  ConsumerState<_AdminRolesTab> createState() => _AdminRolesTabState();
}

class _AdminRolesTabState extends ConsumerState<_AdminRolesTab> {
  static const List<String> _supportedRoles = [
    'guest',
    'host',
    'admin',
  ];

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _debouncedSearch = '';
  String _roleFilter = 'all';
  int _page = 1;
  final int _limit = 50;
  int _total = 0;
  int _totalPages = 1;

  List<Map<String, dynamic>> _users = const [];
  final Map<String, String> _draftRoles = {};
  bool _loading = true;
  String? _error;
  bool _isOffline = false;
  String? _savingUserId;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _debouncedSearch = value.trim();
        _page = 1;
      });
      _fetchUsers();
    });
  }

  Future<void> _fetchUsers({bool preserveError = false}) async {
    setState(() {
      _loading = true;
      if (!preserveError) {
        _error = null;
        _isOffline = false;
      }
    });
    try {
      final paginated =
          await ref.read(adminRepositoryProvider).getAdminUsersPaginated(
                page: _page,
                limit: _limit,
                search: _debouncedSearch,
                role: _roleFilter,
              );
      if (!mounted) return;
      final list = paginated.items;
      final drafts = <String, String>{};
      for (final u in list) {
        final id = '${u['userId'] ?? u['id'] ?? ''}';
        final role =
            '${u['role'] ?? (u['roles'] is List && (u['roles'] as List).isNotEmpty ? (u['roles'] as List).first : 'guest')}';
        drafts[id] = _supportedRoles.contains(role) ? role : 'guest';
      }
      setState(() {
        _users = list;
        _page = paginated.page;
        _total = paginated.total;
        _totalPages = paginated.totalPages;
        _draftRoles
          ..clear()
          ..addAll(drafts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải phân quyền.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _saveRole(Map<String, dynamic> user) async {
    final userId = '${user['userId'] ?? user['id'] ?? ''}';
    final role = _draftRoles[userId];
    if (userId.isEmpty || role == null || !_supportedRoles.contains(role)) {
      return;
    }

    final actor = ref.read(authNotifierProvider).valueOrNull;
    final isActorAdmin = _isActorAdmin(actor);
    if (!isActorAdmin) {
      setState(() {
        _error = 'Chỉ Quản trị viên (Admin) mới có quyền thay đổi vai trò.';
      });
      return;
    }
    if (actor != null && actor.id == userId && role != 'admin') {
      setState(() {
        _error = 'Bạn không thể tự hạ quyền Admin của chính mình.';
      });
      return;
    }

    setState(() {
      _savingUserId = userId;
      _error = null;
      _isOffline = false;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateAdminUser(userId, {'role': role});
      if (!mounted) return;
      AppToast.show(
        context,
        'Đã cập nhật vai trò người dùng #$userId thành $role.',
        type: AppToastType.success,
      );
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      final status = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể cập nhật vai trò người dùng.',
        );
      });
      if (status == 409) {
        await _fetchUsers(preserveError: true);
      }
    } finally {
      if (mounted) setState(() => _savingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canManageRoles = _isActorAdmin(actor);

    return SingleChildScrollView(
      padding: _studioScrollPadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canManageRoles)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AdminStudioInnerCard(
                    warningHighlight: true,
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Tài khoản của bạn không có quyền Admin để thay đổi vai trò hệ thống.',
                      style: AdminStudioTokens.bodyRegular,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminErrorBanner(
                    message: _error!,
                    isOffline: _isOffline,
                    onRetry: _loading ? null : _fetchUsers,
                  ),
                ),
              AdminStudioGroupCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: AdminStudioTokens.bodyRegular.copyWith(
                        color: AdminStudioTokens.inkPrimary,
                      ),
                      decoration: AdminStudioTokens.searchPillDecoration(
                        hintText: 'Tìm tên, email phân quyền...',
                        prefixIcon: LucideIcons.search,
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 15,
                                  color: AdminStudioTokens.iconMuted,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final roleOption in const [
                          ('all', 'Tất cả'),
                          ('guest', 'Guest'),
                          ('host', 'Host'),
                          ('admin', 'Admin'),
                        ])
                          AdminStudioFilterPill(
                            label: roleOption.$2,
                            selected: _roleFilter == roleOption.$1,
                            onTap: _loading
                                ? null
                                : () {
                                    if (_roleFilter == roleOption.$1) return;
                                    setState(() {
                                      _roleFilter = roleOption.$1;
                                      _page = 1;
                                    });
                                    _fetchUsers();
                                  },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AdminStudioGroupCard(
                title: 'Phân quyền tài khoản',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AdminStudioTokens.pillRadius,
                    ),
                  ),
                  child: Text(
                    '$_total tài khoản',
                    style: AdminStudioTokens.metaCaption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AdminStudioTokens.inkPrimary,
                    ),
                  ),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminStudioTokens.obsidian,
                            ),
                          ),
                        ),
                      )
                    : _users.isEmpty
                        ? const AdminStudioInnerCard(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Không có người dùng.',
                                style: AdminStudioTokens.cardSubtitle,
                              ),
                            ),
                          )
                        : Column(
                            children: _users.map((u) {
                              final userId = '${u['userId'] ?? u['id'] ?? ''}';
                              final name =
                                  '${u['fullName'] ?? u['name'] ?? u['username'] ?? 'User #$userId'}';
                              final avatarUrl =
                                  '${u['avatarUrl'] ?? u['avatar'] ?? ''}'
                                      .trim();
                              final email = '${u['email'] ?? '-'}';
                              final rawRole =
                                  '${u['role'] ?? (u['roles'] is List && (u['roles'] as List).isNotEmpty ? (u['roles'] as List).first : 'guest')}';
                              final currentRole =
                                  _supportedRoles.contains(rawRole)
                                      ? rawRole
                                      : 'guest';
                              final draftRole =
                                  _draftRoles[userId] ?? currentRole;
                              final isChanged = draftRole != currentRole;

                              final userInfo = Row(
                                children: [
                                  AdminStudioAvatar(
                                    name: name,
                                    imageUrl: avatarUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AdminStudioTokens.cardTitle,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AdminStudioTokens.cardSubtitle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              Widget buildRoleControls({
                                required bool expandDropdown,
                              }) {
                                final dropdownPill = Container(
                                  width: expandDropdown ? null : 164,
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AdminStudioTokens.softCircle,
                                    borderRadius: BorderRadius.circular(
                                      AdminStudioTokens.pillRadius,
                                    ),
                                    border: isChanged
                                        ? Border.all(
                                            color: AdminStudioTokens.obsidian,
                                            width: 1.1,
                                          )
                                        : null,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        size: 14,
                                        color: AdminStudioTokens.iconMuted,
                                      ),
                                      style:
                                          AdminStudioTokens.pillText.copyWith(
                                        color: AdminStudioTokens.inkPrimary,
                                      ),
                                      value: _supportedRoles.contains(draftRole)
                                          ? draftRole
                                          : 'guest',
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'guest',
                                          child: Text(
                                            'Guest',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'host',
                                          child: Text(
                                            'Host',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'admin',
                                          child: Text(
                                            'Admin',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      onChanged: !canManageRoles
                                          ? null
                                          : (next) {
                                              if (next == null) return;
                                              setState(
                                                () =>
                                                    _draftRoles[userId] = next,
                                              );
                                            },
                                    ),
                                  ),
                                );

                                final saveButton = ElevatedButton(
                                  style: _kCompactPillElevatedStyle.copyWith(
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size(64, 40),
                                    ),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 15),
                                    ),
                                  ),
                                  onPressed: !canManageRoles ||
                                          !isChanged ||
                                          _savingUserId == userId
                                      ? null
                                      : () => _saveRole(u),
                                  child: Text(
                                    _savingUserId == userId ? 'Lưu...' : 'Lưu',
                                  ),
                                );

                                final cancelButton = OutlinedButton(
                                  style: _kCompactPillOutlinedStyle.copyWith(
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size(54, 40),
                                    ),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _draftRoles[userId] = currentRole;
                                    });
                                  },
                                  child: const Text('Hủy'),
                                );

                                return Row(
                                  mainAxisSize: expandDropdown
                                      ? MainAxisSize.max
                                      : MainAxisSize.min,
                                  children: [
                                    if (expandDropdown)
                                      Expanded(child: dropdownPill)
                                    else
                                      dropdownPill,
                                    const SizedBox(width: 8),
                                    saveButton,
                                    if (isChanged) ...[
                                      const SizedBox(width: 6),
                                      cancelButton,
                                    ],
                                  ],
                                );
                              }

                              return AdminStudioInnerCard(
                                key: ValueKey('admin-role-row-$userId'),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                selected: isChanged,
                                child: LayoutBuilder(
                                  builder: (context, rowConstraints) {
                                    final textScale =
                                        MediaQuery.textScalerOf(context)
                                            .scale(1);
                                    final isStackedRow =
                                        rowConstraints.maxWidth < 520 ||
                                            textScale > 1.25;
                                    if (isStackedRow) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          userInfo,
                                          const SizedBox(height: 10),
                                          buildRoleControls(
                                            expandDropdown: true,
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: userInfo),
                                        const SizedBox(width: 12),
                                        buildRoleControls(
                                          expandDropdown: false,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
              ),
              if (!_loading && (_users.isNotEmpty || _totalPages > 1)) ...[
                const SizedBox(height: 14),
                _AdminPaginationBar(
                  page: _page,
                  totalPages: _totalPages,
                  total: _total,
                  unitLabel: 'tài khoản',
                  loading: _loading,
                  onPrev: () {
                    setState(() => _page -= 1);
                    _fetchUsers();
                  },
                  onNext: () {
                    setState(() => _page += 1);
                    _fetchUsers();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
