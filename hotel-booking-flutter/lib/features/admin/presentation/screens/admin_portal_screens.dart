import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/core/formatters/currency_formatter.dart';
import 'package:hotel_booking_flutter/core/security/url_security_validator.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
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
    subtitle: 'Cập nhật vai trò người dùng (Guest, Host, Moderator, Admin).',
  ),
];

bool _isActorAdmin(User? actor) {
  if (actor == null) return false;
  if (actor.role.toLowerCase() == 'admin') return true;
  return actor.roles.any((r) => r.toLowerCase() == 'admin');
}

bool _isActorModeratorOrAdmin(User? actor) {
  if (actor == null) return false;
  if (_isActorAdmin(actor)) return true;
  if (actor.role.toLowerCase() == 'moderator') return true;
  return actor.roles.any((r) => r.toLowerCase() == 'moderator');
}

double _responsivePagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 380) return 12;
  if (width < 640) return 16;
  return 24;
}

final ButtonStyle _kPillOutlinedStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(48, 48),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  shape: const StadiumBorder(),
);

final ButtonStyle _kCirclePagerOutlinedStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(38, 38),
  padding: EdgeInsets.zero,
  shape: const CircleBorder(),
  side: const BorderSide(color: AppColors.border),
);

final ButtonStyle _kCompactPillOutlinedStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(48, 44),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  shape: const StadiumBorder(),
);

final ButtonStyle _kPillElevatedStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size(48, 48),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  shape: const StadiumBorder(),
);

InputDecoration _multilineInputDecoration({
  String? hintText,
  String? labelText,
  String? errorText,
}) {
  final borderRadius = BorderRadius.circular(20);
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    errorText: errorText,
    errorStyle: const TextStyle(
      color: AppColors.error,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1.4),
    ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOffline ? AppColors.surfaceBase : AppColors.errorSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOffline ? AppColors.warning : AppColors.error,
          ),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOffline ? LucideIcons.wifiOff : AppSemanticIcons.errorAlert,
                  size: 18,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOffline)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'Mất kết nối tới máy chủ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isOffline
                              ? AppColors.textPrimary
                              : AppColors.error,
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
                  size: 15,
                  color: AppColors.iconStrong,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          totalPages > 1
              ? 'Trang $page/$totalPages · $total $unitLabel'
              : 'Tổng $total $unitLabel',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (totalPages > 1)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                style: _kCirclePagerOutlinedStyle,
                onPressed: loading || page <= 1 ? null : onPrev,
                child: const Text('<'),
              ),
              OutlinedButton(
                style: _kCirclePagerOutlinedStyle,
                onPressed: loading || page >= totalPages ? null : onNext,
                child: const Text('>'),
              ),
            ],
          ),
      ],
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

    Widget buildSidebarContent({bool inDrawer = false}) {
      return Container(
        width: inDrawer ? math.min(272, width * 0.86) : 272,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      _selectTab(context, 'tong-quan', '/admin');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          AppBrandIcon.minhThanhLogo(
                            size: 26,
                            color: AppColors.iconStrong,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'The Palm Villa',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Admin Panel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
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
                  Semantics(
                    button: true,
                    label: 'Đóng menu điều hướng',
                    child: Tooltip(
                      message: 'Đóng menu',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(
                              LucideIcons.x,
                              size: 18,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: kAdminNavItems.map((item) {
                  final selected = item.id == _currentTab;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      _selectTab(context, item.id, item.route);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.surfaceBase
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: selected
                                ? AppColors.iconStrong
                                : AppColors.iconMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Admin',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? 'admin@vungtaustay.com',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
                            color: AppColors.iconStrong,
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
                            color: AppColors.iconStrong,
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Drawer(
        width: math.min(288, width * 0.88),
        backgroundColor: Colors.white,
        child: SafeArea(child: buildSidebarContent(inDrawer: true)),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: buildSidebarContent(),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 380 ? 12 : 20,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            activeMeta.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const NotificationBell(),
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
    final isMenuTabActive = _currentTab != 'nguoi-dung' &&
        _currentTab != 'kiem-duyet' &&
        _currentTab != 'ho-so-host';

    return Container(
      key: const ValueKey('admin-bottom-nav-bar'),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: kAdminBottomNavItems.map((item) {
              final isSelected =
                  item.isMenuTrigger ? isMenuTabActive : _currentTab == item.id;
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
                        minHeight: 48,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? AppColors.iconStrong
                                  : AppColors.iconMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: isSelected
                                    ? AppColors.textStrong
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 2,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
    final pagePad = _responsivePagePadding(context);
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
      padding: EdgeInsets.all(pagePad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final daysOption in const [7, 30, 90])
                        ChoiceChip(
                          label: Text(
                            '$daysOption ngày',
                            style: TextStyle(
                              fontWeight: _rangeDays == daysOption
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _rangeDays == daysOption
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          selected: _rangeDays == daysOption,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          selectedColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          onSelected: _loading
                              ? null
                              : (selected) {
                                  if (!selected || _rangeDays == daysOption) {
                                    return;
                                  }
                                  setState(() {
                                    _rangeDays = daysOption;
                                    _group = daysOption >= 90 ? 'month' : 'day';
                                  });
                                  _load();
                                },
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: DropdownButton<String>(
                          value: _group,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'day',
                              child: Text('Theo ngày'),
                            ),
                            DropdownMenuItem(
                              value: 'month',
                              child: Text('Theo tháng'),
                            ),
                          ],
                          onChanged: _loading
                              ? null
                              : (next) {
                                  if (next == null || next == _group) return;
                                  setState(() => _group = next);
                                  _load();
                                },
                        ),
                      ),
                      Tooltip(
                        message: 'Tải lại',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _loading ? null : _load,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.refreshCw,
                                  size: 14,
                                  color: AppColors.iconStrong,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Tải lại',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Chưa có phát sinh dữ liệu trong kỳ báo cáo này.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final cols = constraints.maxWidth >= 860
                      ? 3
                      : (constraints.maxWidth >= 340 && textScale <= 1.25)
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
                          child: InkWell(
                            onTap: card.route != null
                                ? () => context.go(card.route!)
                                : null,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          card.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        card.icon,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    card.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Biểu đồ doanh thu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!_loading && stats != null)
                          Text(
                            'Chủ nhà nhận: ${CurrencyFormatter.formatVnd(stats.hostRevenue.round(), fallback: '0 ₫')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Không thể hiển thị biểu đồ doanh thu do lỗi tải số liệu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else if (series.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Chưa có dữ liệu chuỗi doanh thu trong khoảng thời gian đã chọn.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
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
                                      .clamp(0.04, 1.0)
                                  : 0.04;
                              final amountLabel =
                                  '${CurrencyFormatter.formatVnd(point.grossRevenue.round(), fallback: '0 ₫')} (${point.bookingCount} đơn)';
                              if (compactChart) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            point.period,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            amountLabel,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: Container(
                                          height: 10,
                                          color: AppColors.surfaceMuted,
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: ratio,
                                            child: Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: AppColors.textPrimary,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 88,
                                      child: Text(
                                        point.period,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: Container(
                                          height: 12,
                                          color: AppColors.surfaceMuted,
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: ratio,
                                            child: Container(
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: AppColors.textPrimary,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 148,
                                      child: Text(
                                        amountLabel,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
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
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
              ),
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
    final pagePad = _responsivePagePadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canManageUsers) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Text(
                    'Chỉ Quản trị viên (Admin) mới có quyền chỉnh sửa hoặc khóa tài khoản người dùng.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _AdminErrorBanner(
                    message: _error!,
                    isOffline: _isOffline,
                    onRetry: _loading ? null : _fetchUsers,
                  ),
                ),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Tìm tên, email, SĐT...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.search,
                                size: 16,
                                color: AppColors.iconMuted,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
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
                                        color: AppColors.iconMuted,
                                      ),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Tải lại danh sách người dùng',
                          child: Tooltip(
                            message: 'Tải lại',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _loading ? null : _fetchUsers,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.refreshCw,
                                    size: 15,
                                    color: AppColors.iconStrong,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBase,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            alignment: Alignment.centerLeft,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: value,
                                isExpanded: true,
                                isDense: true,
                                icon: const Icon(
                                  LucideIcons.chevronDown,
                                  size: 15,
                                  color: AppColors.iconMuted,
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
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
                              value: 'moderator',
                              child: Text('Moderator'),
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
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _users.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(36),
                            child: Center(
                              child: Text('Không có người dùng phù hợp.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _users.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final u = _users[index];
                              final userId = '${u['userId'] ?? u['id'] ?? ''}';
                              final name =
                                  '${u['fullName'] ?? u['name'] ?? u['username'] ?? 'User #$userId'}';
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

                              final userInfo = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          role,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (locked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.errorSoft,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Khóa',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (contactLine.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      contactLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              );

                              final actionButtons = Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton(
                                    style: _kCompactPillOutlinedStyle,
                                    onPressed: !canManageUsers ||
                                            _actionUserId == userId
                                        ? null
                                        : () => _openEditUserDialog(u),
                                    child: const Text('Sửa'),
                                  ),
                                  OutlinedButton(
                                    style: _kCompactPillOutlinedStyle,
                                    onPressed: !canManageUsers ||
                                            _actionUserId == userId
                                        ? null
                                        : () => _toggleUserStatus(u),
                                    child: Text(
                                      locked ? 'Mở khóa' : 'Khóa',
                                    ),
                                  ),
                                ],
                              );

                              return Padding(
                                key: ValueKey('admin-user-row-$userId'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, rowConstraints) {
                                    final textScale =
                                        MediaQuery.textScalerOf(context)
                                            .scale(1);
                                    final isCompactRow =
                                        rowConstraints.maxWidth < 310 ||
                                            textScale > 1.25;
                                    if (isCompactRow) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          userInfo,
                                          const SizedBox(height: 8),
                                          actionButtons,
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: userInfo),
                                        const SizedBox(width: 8),
                                        actionButtons,
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
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
    if (!_isActorModeratorOrAdmin(actor)) {
      setState(() {
        _error = 'Bạn không có quyền kiểm duyệt bài đăng (403).';
      });
      return;
    }

    // Business rule from Source goc KiemDuyetBaiDang/index.jsx:
    // Moderator/Admin MUST view listing detail before approving or rejecting!
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
    if (!_isActorModeratorOrAdmin(actor)) {
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
    final canModerate = _isActorModeratorOrAdmin(actor);

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
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
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
                    const Divider(height: 24),
                    if (modalFeedback != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: modalFeedbackIsError
                              ? AppColors.errorSoft
                              : AppColors.successSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          modalFeedback!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: modalFeedbackIsError
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, bodyConstraints) {
                          final infoWidth = bodyConstraints.maxWidth >= 780
                              ? (bodyConstraints.maxWidth - 16) / 2
                              : bodyConstraints.maxWidth;
                          final imageCardWidth = bodyConstraints.maxWidth >= 560
                              ? 260.0
                              : bodyConstraints.maxWidth;

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    Container(
                                      width: infoWidth,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Thông tin host',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Họ tên: ${host['fullName'] ?? 'Chưa có'}',
                                          ),
                                          Text(
                                            'Email: ${host['email'] ?? 'Chưa có'}',
                                          ),
                                          Text(
                                            'SĐT: ${host['phone'] ?? 'Chưa có'}',
                                          ),
                                          Text(
                                            'Xác minh host: ${host['isHostVerified'] == true ? 'Đã xác minh' : 'Chưa xác minh'}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: infoWidth,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Giá & sức chứa',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Giá thường: ${CurrencyFormatter.formatVnd((double.tryParse('${currentDetail['basePrice'] ?? 0}') ?? 0).round(), fallback: '0 ₫')}',
                                          ),
                                          Text(
                                            'Giá cuối tuần: ${CurrencyFormatter.formatVnd((double.tryParse('${currentDetail['weekendPrice'] ?? 0}') ?? 0).round(), fallback: '0 ₫')}',
                                          ),
                                          Text(
                                            'Phí dọn dẹp: ${CurrencyFormatter.formatVnd((double.tryParse('${currentDetail['cleaningFee'] ?? 0}') ?? 0).round(), fallback: '0 ₫')}',
                                          ),
                                          Text(
                                            'Khách tối đa: ${currentDetail['maxGuests'] ?? 0} · Phòng ngủ: ${currentDetail['bedrooms'] ?? 0} · Giường: ${currentDetail['beds'] ?? 0} · Phòng tắm: ${currentDetail['bathrooms'] ?? 0}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Mô tả',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${currentDetail['description'] ?? 'Chưa có mô tả'}',
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: _kPillOutlinedStyle,
                                      onPressed: reanalyzingAll || !canAnalyzeAi
                                          ? null
                                          : handleReanalyzeAll,
                                      icon: const Icon(
                                        LucideIcons.refreshCw,
                                        size: 15,
                                        color: AppColors.iconStrong,
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
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
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

                                      return Container(
                                        width: imageCardWidth,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                            color: warnings.isNotEmpty ||
                                                    aiError.isNotEmpty
                                                ? AppColors.warning
                                                : AppColors.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (url.isNotEmpty)
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(18),
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
                                                        ? AppColors.successSoft
                                                        : aiStatus == 'failed'
                                                            ? AppColors
                                                                .errorSoft
                                                            : AppColors
                                                                .surfaceBase,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: Text(
                                                    'AI: $aiStatus',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'Độ tin cậy: $aiConfidence',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (aiImageType.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Phân loại: $aiImageType',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
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
                                                      color: AppColors
                                                          .surfaceMuted,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: const TextStyle(
                                                        fontSize: 11,
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
                                                  color: AppColors.surfaceBase,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  [
                                                    ...warnings,
                                                    if (aiError.isNotEmpty)
                                                      aiError,
                                                  ].join(' · '),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (imageId.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  style: _kPillOutlinedStyle,
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
                                                    color: AppColors.iconStrong,
                                                  ),
                                                  label: Text(
                                                    reanalyzingImageId ==
                                                            imageId
                                                        ? 'Đang phân tích...'
                                                        : 'Phân tích lại AI',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                if (amenities.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Tiện ích',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: amenities.map((a) {
                                      final label = a is Map
                                          ? '${a['name'] ?? a['code'] ?? ''}'
                                          : '$a';
                                      return Chip(
                                        shape: const StadiumBorder(),
                                        label: Text(label),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Text(
                                  'Nội quy',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Nhận phòng: ${rules['checkInFrom'] ?? '14:00'} · Trả phòng: ${rules['checkOutBefore'] ?? '12:00'} · Hút thuốc: ${rules['smokingAllowed'] == true ? 'Cho phép' : 'Không'} · Thú cưng: ${rules['petsAllowed'] == true ? 'Cho phép' : 'Không'} · Tiệc: ${rules['partyAllowed'] == true ? 'Cho phép' : 'Không'}',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),
                    Wrap(
                      spacing: 12,
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
    final canModerate = _isActorModeratorOrAdmin(actor);
    final pagePad = _responsivePagePadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _loading
                        ? 'Đang tải danh sách...'
                        : '$_total bài chờ duyệt',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: _kCompactPillOutlinedStyle,
                    onPressed: _loading ? null : _fetchPending,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 14,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Tải lại'),
                  ),
                ],
              ),
              if (!canModerate) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Text(
                    'Chỉ Admin hoặc Moderator mới có quyền phê duyệt / từ chối bài đăng.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _AdminErrorBanner(
                  message: _error!,
                  isOffline: _isOffline,
                  onRetry: _loading ? null : _fetchPending,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _listings.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(36),
                            child: Center(
                              child: Text('Không có listing chờ duyệt.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _listings.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _listings[index];
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

                              return Padding(
                                key:
                                    ValueKey('admin-moderation-row-$listingId'),
                                padding: const EdgeInsets.all(14),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
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
                                                BorderRadius.circular(14),
                                            child: AppImage(
                                              imageUrl: cover,
                                              width: 96,
                                              height: 68,
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 96,
                                            height: 68,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Text(
                                              'Chưa có ảnh',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 300,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item['title'] ?? 'Chỗ nghỉ'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                '${item['propertyType'] ?? 'villa'}${hasViewed ? ' · Đã xem chi tiết' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              if (address.isNotEmpty)
                                                Text(
                                                  address,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              Text(
                                                CurrencyFormatter.formatVnd(
                                                  price.round(),
                                                  fallback: '0 ₫',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
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
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(48, 40),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          onPressed: !canModerate ||
                                                  _processingId == listingId
                                              ? null
                                              : () => _handleApprove(
                                                    listingId,
                                                  ),
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
                            },
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
  Map<String, dynamic>? _detail;
  bool _loadingList = true;
  bool _loadingDetail = false;
  bool _actionLoading = false;
  final TextEditingController _rejectReasonCtrl = TextEditingController();
  String? _rejectReasonError;
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

  Future<void> _fetchDetail(String applicationId) async {
    setState(() {
      _selectedId = applicationId;
      _loadingDetail = true;
      _error = null;
      _rejectReasonError = null;
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
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải chi tiết hồ sơ host.',
        );
        _detail = null;
        _loadingDetail = false;
      });
    }
  }

  Future<void> _runApprove() async {
    final appId = '${_detail?['applicationId'] ?? _detail?['id'] ?? ''}';
    if (appId.isEmpty) return;

    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(actor)) {
      setState(() {
        _error =
            'Chỉ Quản trị viên (Admin) mới có quyền phê duyệt hồ sơ host (403).';
      });
      return;
    }

    setState(() {
      _actionLoading = true;
      _error = null;
      _rejectReasonError = null;
      _isOffline = false;
      _message = null;
    });
    try {
      await ref.read(adminRepositoryProvider).approveHostApplication(appId);
      if (!mounted) return;
      setState(() {
        _message = 'Đã duyệt hồ sơ chủ nhà #$appId. Hồ sơ đã chuyển vào mục "Đã duyệt".';
        if (_status == 'pending') {
          _selectedId = null;
          _detail = null;
        }
      });
      AppToast.show(
        context,
        'Đã duyệt hồ sơ chủ nhà #$appId. Hồ sơ đã chuyển vào mục "Đã duyệt".',
        type: AppToastType.success,
      );
      await _fetchApplications();
      if (_status != 'pending') {
        await _fetchDetail(appId);
      }
    } catch (e) {
      if (!mounted) return;
      final status = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể duyệt hồ sơ.',
        );
      });
      if (status == 409) {
        await _fetchApplications(preserveError: true);
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _runReject() async {
    final appId = '${_detail?['applicationId'] ?? _detail?['id'] ?? ''}';
    if (appId.isEmpty) return;

    final actor = ref.read(authNotifierProvider).valueOrNull;
    if (!_isActorAdmin(actor)) {
      setState(() {
        _error =
            'Chỉ Quản trị viên (Admin) mới có quyền từ chối hồ sơ host (403).';
      });
      return;
    }

    final reason = _rejectReasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _rejectReasonError = 'Vui lòng nhập lý do từ chối.');
      return;
    }
    setState(() {
      _actionLoading = true;
      _error = null;
      _rejectReasonError = null;
      _isOffline = false;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .rejectHostApplication(appId, reason);
      if (!mounted) return;
      setState(() {
        _message = 'Đã từ chối hồ sơ chủ nhà #$appId. Hồ sơ đã chuyển vào mục "Từ chối".';
        if (_status == 'pending') {
          _selectedId = null;
          _detail = null;
        }
      });
      AppToast.show(
        context,
        'Đã từ chối hồ sơ chủ nhà #$appId. Hồ sơ đã chuyển vào mục "Từ chối".',
        type: AppToastType.info,
      );
      await _fetchApplications();
      if (_status != 'pending') {
        await _fetchDetail(appId);
      }
    } catch (e) {
      if (!mounted) return;
      final status = AdminRepository.extractStatusCode(e);
      setState(() {
        _isOffline = AdminRepository.isOfflineError(e);
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể từ chối hồ sơ.',
        );
      });
      if (status == 409) {
        await _fetchApplications(preserveError: true);
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _buildHostAppStatusBadge(dynamic rawStatus) {
    final status = '$rawStatus'.toLowerCase();
    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.success),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleCheck, size: 14, color: AppColors.iconStrong),
            SizedBox(width: 6),
            Text(
              'Đã phê duyệt (Đã cấp quyền Host)',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
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
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.error),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleX, size: 14, color: AppColors.iconStrong),
            SizedBox(width: 6),
            Text(
              'Đã từ chối',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clock, size: 14, color: AppColors.iconStrong),
          SizedBox(width: 6),
          Text(
            'Chờ phê duyệt',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label, IconData icon) {
    final isSelected = _status == value;
    return InkWell(
      key: Key('admin_host_app_filter_$value'),
      onTap: () {
        if (_status == value) return;
        setState(() {
          _status = value;
          _appPage = 1;
          _selectedId = null;
          _detail = null;
        });
        _fetchApplications();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.iconMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canManageHostApps = _isActorAdmin(actor);
    final pagePad = _responsivePagePadding(context);

    final listSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: _loadingList
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _applications.isEmpty
                  ? Padding(
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
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _applications.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final app = _applications[index];
                        final appId =
                            '${app['applicationId'] ?? app['id'] ?? ''}';
                        final user = app['user'] is Map
                            ? Map<String, dynamic>.from(app['user'] as Map)
                            : const <String, dynamic>{};
                        final name =
                            '${user['name'] ?? app['contactName'] ?? 'Host #$appId'}';
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

                        return InkWell(
                          onTap: () => _fetchDetail(appId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            color: selected
                                ? AppColors.surfaceBase
                                : Colors.transparent,
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 280),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (contactLine.isNotEmpty)
                                        Text(
                                          contactLine,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${status == 'approved' ? 'Đã duyệt' : status == 'rejected' ? 'Đã từ chối' : 'Chờ duyệt'} · Giấy tờ: ${app['documentCount'] ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: _kCompactPillOutlinedStyle,
                                  onPressed: () => _fetchDetail(appId),
                                  child: const Text('Chi tiết'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

    final detailSection = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: _selectedId == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Chọn một hồ sơ từ danh sách để xem chi tiết thông tin và giấy tờ xác minh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : _loadingDetail
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _detail == null
                  ? const Text('Không thể tải chi tiết hồ sơ.')
                  : Column(
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
                                    '${_detail!['contactName'] ?? (_detail!['user'] is Map ? _detail!['user']['name'] : null) ?? 'Hồ sơ host'}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildHostAppStatusBadge(_detail!['status']),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Đóng chi tiết',
                              icon: const Icon(
                                LucideIcons.x,
                                size: 20,
                                color: AppColors.iconMuted,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedId = null;
                                  _detail = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'SĐT: ${_detail!['phone'] ?? '-'} · Loại: ${_detail!['profileType'] ?? 'individual'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_detail!['idNumber'] != null ||
                            _detail!['idNumberMasked'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Số định danh (KYC): ${AdminRepository.maskKycIdentifier('${_detail!['idNumberMasked'] ?? _detail!['idNumber'] ?? ''}')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Địa chỉ kinh doanh: ${_detail!['businessAddress'] ?? '-'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (_detail!['note'] != null) ...[
                          const SizedBox(height: 6),
                          Text('Ghi chú: ${_detail!['note']}'),
                        ],
                        if (_detail!['rejectReason'] != null &&
                            '${_detail!['rejectReason']}'.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Lý do từ chối trước đó: ${_detail!['rejectReason']}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                        const Divider(height: 24),
                        Text(
                          'Giấy tờ xác minh (${(_detail!['documents'] is List) ? (_detail!['documents'] as List).length : 0})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_detail!['documents'] is List &&
                            (_detail!['documents'] as List).isNotEmpty)
                          ...(_detail!['documents'] as List).map((rawDoc) {
                            final doc = rawDoc is Map
                                ? Map<String, dynamic>.from(rawDoc)
                                : const <String, dynamic>{};
                            final fileUrl = '${doc['fileUrl'] ?? doc['proxyUrl'] ?? ''}';
                            final signedUrl = '${doc['signedUrl'] ?? ''}';
                            final previewUrl = fileUrl.isNotEmpty ? fileUrl : signedUrl;
                            final mimeType = '${doc['mimeType'] ?? ''}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${doc['documentType'] ?? 'cccd'} / ${doc['side'] ?? 'front'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                  if (signedUrl.isNotEmpty || previewUrl.isNotEmpty) ...[
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
                                        final uri =
                                            Uri.tryParse(resolvedTarget);
                                        if (uri != null &&
                                            UrlSecurityValidator
                                                .isTrustedAdminDocumentUrl(
                                              resolvedTarget,
                                            )) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else if (context.mounted) {
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
                          const Text(
                            'Không có giấy tờ đính kèm.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        if (_detail!['status'] == 'approved') ...[
                          const Divider(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.successSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  LucideIcons.circleCheck,
                                  color: AppColors.iconStrong,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Hồ sơ này đã được phê duyệt thành công. Người dùng đã có quyền Host.',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_detail!['status'] == 'rejected') ...[
                          const Divider(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  LucideIcons.circleX,
                                  color: AppColors.iconStrong,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hồ sơ này đã bị từ chối.',
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (_detail!['rejectReason'] != null &&
                                          '${_detail!['rejectReason']}'
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lý do từ chối: ${_detail!['rejectReason']}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const Divider(height: 24),
                          const Text(
                            'Quyết định xét duyệt',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const Key('admin_host_app_reject_reason_field'),
                            controller: _rejectReasonCtrl,
                            maxLines: 3,
                            onChanged: (_) {
                              if (_rejectReasonError != null) {
                                setState(() => _rejectReasonError = null);
                              }
                            },
                            decoration: _multilineInputDecoration(
                              hintText:
                                  'Nhập lý do nếu bạn muốn từ chối hồ sơ này...',
                              errorText: _rejectReasonError,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                style: _kPillElevatedStyle,
                                onPressed: !canManageHostApps || _actionLoading
                                    ? null
                                    : _runApprove,
                                child: const Text('Phê duyệt hồ sơ'),
                              ),
                              OutlinedButton(
                                key: const Key('admin_host_app_reject_btn'),
                                style: _kPillOutlinedStyle,
                                onPressed: !canManageHostApps || _actionLoading
                                    ? null
                                    : _runReject,
                                child: const Text('Từ chối'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
    );

    final verificationsSection = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Bảng Legacy Verifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _verificationStatus,
                          isDense: true,
                          icon: const Icon(
                            LucideIcons.chevronDown,
                            size: 14,
                            color: AppColors.iconMuted,
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Tất cả'),
                            ),
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
                    ),
                  ),
                  OutlinedButton.icon(
                    style: _kCompactPillOutlinedStyle,
                    onPressed:
                        _loadingVerifications ? null : _fetchVerifications,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 14,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Tải lại'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_verificationError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminErrorBanner(
                message: _verificationError!,
                isOffline: _verificationOffline,
                onRetry: _loadingVerifications ? null : _fetchVerifications,
              ),
            ),
          ],
          if (_loadingVerifications)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_verifications.isEmpty && _verificationError == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Không có bản ghi Legacy Verification nào.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else if (_verifications.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _verifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final v = _verifications[index];
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

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$hostName (#$verificationId)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Loại: ${vType == 'identity' ? 'Định danh (CCCD/CMND)' : vType} · Trạng thái: ${vStatus == 'approved' ? 'Đã duyệt' : vStatus == 'rejected' ? 'Đã từ chối' : 'Chờ duyệt'}$maskedIdNum',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: const StadiumBorder(),
                            ),
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
              },
            ),
          if (_verificationTotalPages > 1) ...[
            const SizedBox(height: 12),
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
      padding: EdgeInsets.all(pagePad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusFilterChip('pending', 'Chờ duyệt', LucideIcons.clock),
                      _buildStatusFilterChip('approved', 'Đã duyệt', LucideIcons.circleCheck),
                      _buildStatusFilterChip('rejected', 'Từ chối', LucideIcons.circleX),
                      _buildStatusFilterChip('all', 'Tất cả', LucideIcons.layers),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: _kCompactPillOutlinedStyle,
                    onPressed: _fetchApplications,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 14,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Tải lại'),
                  ),
                ],
              ),
              if (!canManageHostApps) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Text(
                    'Chỉ Quản trị viên (Admin) mới có quyền phê duyệt hoặc từ chối hồ sơ đăng ký Host.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: listSection),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: detailSection),
                  ],
                )
              else ...[
                listSection,
                if (_selectedId != null) ...[
                  const SizedBox(height: 14),
                  detailSection,
                ],
              ],
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
    'moderator',
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
    final pagePad = _responsivePagePadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canManageRoles) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Text(
                    'Tài khoản của bạn không có quyền Admin để thay đổi vai trò hệ thống.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminErrorBanner(
                    message: _error!,
                    isOffline: _isOffline,
                    onRetry: _loading ? null : _fetchUsers,
                  ),
                ),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Tìm tên, email phân quyền...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.search,
                                size: 16,
                                color: AppColors.iconMuted,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
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
                                        color: AppColors.iconMuted,
                                      ),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Tải lại phân quyền',
                          child: Tooltip(
                            message: 'Tải lại',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _loading ? null : _fetchUsers,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.refreshCw,
                                    size: 15,
                                    color: AppColors.iconStrong,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final roleOption in const [
                          ('all', 'Tất cả'),
                          ('guest', 'Guest'),
                          ('host', 'Host'),
                          ('moderator', 'Moderator'),
                          ('admin', 'Admin'),
                        ])
                          ChoiceChip(
                            label: Text(
                              roleOption.$2,
                              style: TextStyle(
                                fontWeight: _roleFilter == roleOption.$1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _roleFilter == roleOption.$1
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: _roleFilter == roleOption.$1,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            selectedColor: AppColors.primary,
                            shape: const StadiumBorder(),
                            onSelected: _loading
                                ? null
                                : (selected) {
                                    if (!selected ||
                                        _roleFilter == roleOption.$1) {
                                      return;
                                    }
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
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _users.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(36),
                            child: Center(child: Text('Không có người dùng.')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _users.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final u = _users[index];
                              final userId = '${u['userId'] ?? u['id'] ?? ''}';
                              final name =
                                  '${u['fullName'] ?? u['name'] ?? u['username'] ?? 'User #$userId'}';
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

                              final userInfo = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              );

                              final roleControls = Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    height: 34,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBase,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isChanged
                                            ? AppColors.textPrimary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isDense: true,
                                          icon: const Icon(
                                            LucideIcons.chevronDown,
                                            size: 14,
                                            color: AppColors.iconMuted,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          value: _supportedRoles
                                                  .contains(draftRole)
                                              ? draftRole
                                              : 'guest',
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'guest',
                                              child: Text('Guest'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'host',
                                              child: Text('Host'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'moderator',
                                              child: Text('Moderator'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'admin',
                                              child: Text('Admin'),
                                            ),
                                          ],
                                          onChanged: !canManageRoles
                                              ? null
                                              : (next) {
                                                  if (next == null) {
                                                    return;
                                                  }
                                                  setState(
                                                    () => _draftRoles[userId] =
                                                        next,
                                                  );
                                                },
                                        ),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(48, 34),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: !canManageRoles ||
                                            !isChanged ||
                                            _savingUserId == userId
                                        ? null
                                        : () => _saveRole(u),
                                    child: Text(
                                      _savingUserId == userId
                                          ? 'Lưu...'
                                          : 'Lưu',
                                    ),
                                  ),
                                  if (isChanged)
                                    OutlinedButton(
                                      style: _kCompactPillOutlinedStyle,
                                      onPressed: () {
                                        setState(() {
                                          _draftRoles[userId] = currentRole;
                                        });
                                      },
                                      child: const Text('Hủy'),
                                    ),
                                ],
                              );

                              return Padding(
                                key: ValueKey('admin-role-row-$userId'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, rowConstraints) {
                                    final textScale =
                                        MediaQuery.textScalerOf(context)
                                            .scale(1);
                                    final isCompactRow =
                                        rowConstraints.maxWidth < 285 ||
                                            textScale > 1.25;
                                    if (isCompactRow) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          userInfo,
                                          const SizedBox(height: 8),
                                          roleControls,
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: userInfo),
                                        const SizedBox(width: 8),
                                        roleControls,
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
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
