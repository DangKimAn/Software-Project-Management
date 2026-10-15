import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/core/formatters/currency_formatter.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/shared/animations/fade_slide_in.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_dialog.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_image.dart';
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
    icon: LucideIcons.layoutGrid,
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
    icon: LucideIcons.fileText,
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

class AdminPortalScreen extends ConsumerWidget {
  const AdminPortalScreen({
    super.key,
    required this.activeTab,
  });

  final String activeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final activeMeta = kAdminNavItems.firstWhere(
      (item) => item.id == activeTab,
      orElse: () => kAdminNavItems.first,
    );

    Widget buildSidebarContent({bool inDrawer = false}) {
      return Container(
        width: 272,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => context.go('/admin'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'minh thanh villa',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (inDrawer)
                  GestureDetector(
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
              ],
            ),
            const SizedBox(height: 28),
            Expanded(
              child: ListView(
                children: kAdminNavItems.map((item) {
                  final selected = item.id == activeTab;
                  return InkWell(
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      context.go(item.route);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.surfaceWarmSand
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: selected
                                ? AppColors.textPrimary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: AppColors.iconStrong,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
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
                      onPressed: () => context.go('/'),
                      child: const Text('Về trang khách'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(authNotifierProvider.notifier).logout();
                        if (context.mounted) context.go('/dang-nhap');
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.logOut,
                            size: 15,
                            color: AppColors.iconStrong,
                          ),
                          SizedBox(width: 8),
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
      backgroundColor: Colors.white,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(child: buildSidebarContent(inDrawer: true)),
            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!isDesktop)
                          Builder(
                            builder: (ctx) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Scaffold.of(ctx).openDrawer(),
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Icon(
                                    LucideIcons.menu,
                                    size: 20,
                                    color: AppColors.iconStrong,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ADMIN CENTER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeMeta.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (width >= 640)
                                Text(
                                  activeMeta.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
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

  Widget _buildActiveView() {
    switch (activeTab) {
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
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
    final rangeLabel = '$_rangeDays ngày';
    final cards = [
      (
        label: 'Tổng người dùng',
        value: _loading ? '...' : '${stats?.users ?? 0}',
        sub: 'Tài khoản trên hệ thống',
        icon: LucideIcons.users,
        route: '/admin/nguoi-dung',
      ),
      (
        label: 'Bài chờ duyệt',
        value: _loading ? '...' : '${stats?.pendingListings ?? 0}',
        sub: 'Cần kiểm duyệt nội dung & ảnh AI',
        icon: LucideIcons.clipboard,
        route: '/admin/kiem-duyet',
      ),
      (
        label: 'Doanh thu ($rangeLabel)',
        value: _loading
            ? '...'
            : CurrencyFormatter.formatVnd(
                (stats?.grossRevenue ?? 0).round(),
                fallback: '0 ₫',
              ),
        sub: _loading
            ? '...'
            : 'Nền tảng: ${CurrencyFormatter.formatVnd((stats?.platformRevenue ?? 0).round(), fallback: '0 ₫')}',
        icon: LucideIcons.dollarSign,
        route: null,
      ),
      (
        label: 'Số đơn đặt ($rangeLabel)',
        value: _loading ? '...' : '${stats?.bookings ?? 0}',
        sub: 'Tổng lượt đặt phòng phát sinh',
        icon: LucideIcons.circleCheck,
        route: null,
      ),
      (
        label: 'Chủ nhà (Host)',
        value: _loading ? '...' : '${stats?.hosts ?? 0}',
        sub: _loading
            ? '...'
            : 'Hoạt động: ${stats?.activeHosts ?? 0} · Đã xác minh: ${stats?.verifiedHosts ?? 0}',
        icon: LucideIcons.users,
        route: '/admin/ho-so-host',
      ),
      (
        label: 'Phòng đang hoạt động',
        value: _loading ? '...' : '${stats?.activeListings ?? 0}',
        sub: _loading
            ? '...'
            : 'Tạo mới ($rangeLabel): ${stats?.listingsCreated ?? 0}',
        icon: LucideIcons.clipboard,
        route: '/admin/kiem-duyet',
      ),
    ];

    final series = stats?.revenueSeries ?? const <AdminRevenuePoint>[];
    final maxRevenue = series.fold<double>(
      0,
      (prev, item) => item.grossRevenue > prev ? item.grossRevenue : prev,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng quan hệ thống',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats != null && stats.from.isNotEmpty
                            ? 'Số liệu thực tế từ ${stats.from} đến ${stats.to}.'
                            : 'Số liệu thực tế trong $_rangeDays ngày gần nhất.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final daysOption in const [7, 30, 90])
                        ChoiceChip(
                          label: Text('$daysOption ngày'),
                          selected: _rangeDays == daysOption,
                          selectedColor: AppColors.surfaceWarmSand,
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
                      DropdownButton<String>(
                        value: _group,
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
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(
                          LucideIcons.refreshCw,
                          size: 15,
                          color: AppColors.iconStrong,
                        ),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 960
                      ? 3
                      : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                  final itemWidth =
                      (constraints.maxWidth - (cols - 1) * 16) / cols;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: cards.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final card = entry.value;
                      return SizedBox(
                        width: itemWidth,
                        child: FadeSlideIn(
                          delay: Duration(milliseconds: idx * 35),
                          child: InkWell(
                            onTap: card.route != null
                                ? () => context.go(card.route!)
                                : null,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.label,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          card.value,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          card.sub,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    card.icon,
                                    size: 22,
                                    color: AppColors.iconStrong,
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
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
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
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biểu đồ doanh thu',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Thống kê doanh thu gộp và số đơn đặt theo kỳ báo cáo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (series.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWarmSand,
                          borderRadius: BorderRadius.circular(14),
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
                      Column(
                        children: series.take(14).map((point) {
                          final ratio = maxRevenue > 0
                              ? (point.grossRevenue / maxRevenue)
                                  .clamp(0.04, 1.0)
                              : 0.04;
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
                                    borderRadius: BorderRadius.circular(999),
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
                                  width: 132,
                                  child: Text(
                                    '${CurrencyFormatter.formatVnd(point.grossRevenue.round(), fallback: '0 ₫')} (${point.bookingCount} đơn)',
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

  Future<void> _fetchUsers() async {
    setState(() {
      _loading = true;
      _error = null;
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
    if (currentActor != null && currentActor.id == userId) {
      setState(() {
        _error = 'Bạn không thể tự khóa tài khoản của chính mình.';
      });
      return;
    }

    final currentStatus = '${user['status'] ?? 'active'}'.toLowerCase();
    final isLocked = ['blocked', 'suspended', 'locked'].contains(currentStatus);
    // Backend DB schema enum uses 'suspended' for locked accounts
    final nextStatus = isLocked ? 'active' : 'suspended';

    setState(() {
      _actionUserId = userId;
      _error = null;
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
      final msg = AdminRepository.extractErrorMessage(
        e,
        'Không thể cập nhật trạng thái người dùng.',
      );
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final userId = '${user['userId'] ?? user['id'] ?? ''}';
    if (userId.isEmpty) return;
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
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

    if (confirmed != true) return;

    setState(() {
      _actionUserId = userId;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).updateAdminUser(userId, {
        if (nameCtrl.text.trim().isNotEmpty) 'fullName': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quản lý người dùng',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tìm kiếm, lọc theo vai trò/trạng thái, chỉnh sửa hoặc khóa/mở khóa tài khoản.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Tìm email, số điện thoại, tên...',
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 16,
                            color: AppColors.iconMuted,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _roleFilter,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Mọi vai trò'),
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
                    ),
                    DropdownButton<String>(
                      value: _status,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Mọi trạng thái'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active (Hoạt động)'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspended (Tạm khóa)'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
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
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _fetchUsers,
                      icon: const Icon(
                        LucideIcons.refreshCw,
                        size: 15,
                        color: AppColors.iconStrong,
                      ),
                      label: const Text('Tải lại'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _users.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text('Không có user phù hợp.'),
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
                              final email = '${u['email'] ?? '-'}';
                              final phone = '${u['phone'] ?? '-'}';
                              final role =
                                  '${u['role'] ?? (u['roles'] is List && (u['roles'] as List).isNotEmpty ? (u['roles'] as List).first : 'guest')}';
                              final status =
                                  '${u['status'] ?? 'active'}'.toLowerCase();
                              final locked = [
                                'blocked',
                                'suspended',
                                'locked',
                              ].contains(status);

                              return Padding(
                                key: ValueKey('admin-user-row-$userId'),
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 260,
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
                                          Text(
                                            'ID: $userId · $email · $phone',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        role,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: locked
                                            ? AppColors.errorSoft
                                            : AppColors.successSoft,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: locked
                                              ? AppColors.error
                                              : AppColors.success,
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton(
                                          onPressed: _actionUserId == userId
                                              ? null
                                              : () => _openEditUserDialog(u),
                                          child: const Text('Sửa'),
                                        ),
                                        OutlinedButton(
                                          onPressed: _actionUserId == userId
                                              ? null
                                              : () => _toggleUserStatus(u),
                                          child: Text(
                                            locked ? 'Mở khóa' : 'Khóa',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Trang $_page / $_totalPages · Tổng $_total người dùng',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _loading || _page <= 1
                            ? null
                            : () {
                                setState(() => _page -= 1);
                                _fetchUsers();
                              },
                        child: const Text('Trang trước'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _loading || _page >= _totalPages
                            ? null
                            : () {
                                setState(() => _page += 1);
                                _fetchUsers();
                              },
                        child: const Text('Trang sau'),
                      ),
                    ],
                  ),
                ],
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
  bool _loading = true;
  String? _processingId;
  bool _modalActionLoading = false;
  String? _error;
  final Set<String> _viewedListingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(adminRepositoryProvider)
          .getPendingListings(page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _listings = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
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
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không tải được chi tiết căn.',
        );
        _modalActionLoading = false;
      });
    }
  }

  Future<void> _handleApprove(String listingId) async {
    // Business rule from Source goc KiemDuyetBaiDang/index.jsx:
    // Admin MUST view listing detail before approving!
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
      setState(() {
        _error = AdminRepository.extractErrorMessage(e, 'Duyệt căn thất bại.');
      });
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
    final listingId = '${listing['listingId'] ?? listing['id'] ?? ''}';
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Từ chối căn',
        subtitle: 'Nhập lý do từ chối để host biết cần chỉnh sửa gì.',
        maxWidth: 480,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
        child: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Ví dụ: Ảnh chưa rõ, thiếu thông tin địa chỉ, giá chưa hợp lệ...',
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }

    setState(() {
      _processingId = listingId;
      _modalActionLoading = true;
      _error = null;
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
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Từ chối căn thất bại.',
        );
      });
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
                  'Không thể phân tích lại AI toàn bộ ảnh.',
                );
                modalFeedbackIsError = true;
              });
            }
          }

          Future<void> handleReanalyzeSingle(String imageId) async {
            if (imageId.isEmpty) return;
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

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
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
                          borderRadius: BorderRadius.circular(14),
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
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                Container(
                                  width: 380,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(16),
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
                                  width: 380,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(16),
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
                                  onPressed: reanalyzingAll
                                      ? null
                                      : handleReanalyzeAll,
                                  icon: const Icon(
                                    LucideIcons.sparkles,
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
                                      '${img['aiErrorMessage'] ?? ''}'.trim();
                                  final allLabels = [
                                    ...sceneTags,
                                    ...amenityTags,
                                  ];

                                  return Container(
                                    width: 260,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
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
                                                BorderRadius.circular(12),
                                            child: AppImage(
                                              imageUrl: url,
                                              width: 240,
                                              height: 140,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: aiStatus == 'completed'
                                                    ? AppColors.successSoft
                                                    : aiStatus == 'failed'
                                                        ? AppColors.errorSoft
                                                        : AppColors
                                                            .surfaceWarmSand,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'AI: $aiStatus',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Độ tin cậy: $aiConfidence',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textSecondary,
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
                                            children:
                                                allLabels.take(6).map((tag) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceMuted,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.warningSoft,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              [
                                                ...warnings,
                                                if (aiError.isNotEmpty) aiError,
                                              ].join(' · '),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (imageId.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: reanalyzingImageId ==
                                                          imageId ||
                                                      reanalyzingAll
                                                  ? null
                                                  : () => handleReanalyzeSingle(
                                                        imageId,
                                                      ),
                                              icon: const Icon(
                                                LucideIcons.refreshCw,
                                                size: 13,
                                                color: AppColors.iconStrong,
                                              ),
                                              label: Text(
                                                reanalyzingImageId == imageId
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
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: amenities.map((a) {
                                  final label = a is Map
                                      ? '${a['name'] ?? a['code'] ?? ''}'
                                      : '$a';
                                  return Chip(label: Text(label));
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
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kiểm duyệt bài đăng',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Duyệt hoặc từ chối các chỗ nghỉ host đã gửi lên.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _fetchPending,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                    label: Text(_loading ? 'Đang tải...' : 'Tải lại'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _listings.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(40),
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

                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (cover.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: AppImage(
                                              imageUrl: cover,
                                              width: 112,
                                              height: 76,
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 112,
                                            height: 76,
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
                                        const SizedBox(width: 12),
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
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                'ID: $listingId · ${item['propertyType'] ?? 'villa'}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              if (address.isNotEmpty)
                                                Text(
                                                  address,
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
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton(
                                          onPressed: _modalActionLoading
                                              ? null
                                              : () => _viewDetail(listingId),
                                          child: const Text('Xem chi tiết'),
                                        ),
                                        ElevatedButton(
                                          onPressed: _processingId == listingId
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
                                          onPressed: _processingId == listingId
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
  String? _selectedId;
  Map<String, dynamic>? _detail;
  bool _loadingList = true;
  bool _loadingDetail = false;
  bool _actionLoading = false;
  final TextEditingController _rejectReasonCtrl = TextEditingController();
  String? _error;
  String? _message;

  // Legacy Verifications state
  String _verificationStatus = 'all';
  List<Map<String, dynamic>> _verifications = const [];
  bool _loadingVerifications = true;
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

  Future<void> _fetchApplications() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(adminRepositoryProvider)
          .getAdminHostApplications(status: _status, page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _applications = items;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể tải danh sách hồ sơ host.',
        );
        _loadingList = false;
      });
    }
  }

  Future<void> _fetchVerifications() async {
    setState(() {
      _loadingVerifications = true;
    });
    try {
      final items =
          await ref.read(adminRepositoryProvider).getAdminVerifications(
                status: _verificationStatus,
                page: 1,
                limit: 50,
              );
      if (!mounted) return;
      setState(() {
        _verifications = items;
        _loadingVerifications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifications = const [];
        _loadingVerifications = false;
      });
    }
  }

  Future<void> _approveVerification(String verificationId) async {
    if (verificationId.isEmpty) return;
    setState(() {
      _processingVerificationId = verificationId;
      _error = null;
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
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể duyệt xác minh.',
        );
      });
    } finally {
      if (mounted) setState(() => _processingVerificationId = null);
    }
  }

  Future<void> _rejectVerification(String verificationId) async {
    if (verificationId.isEmpty) return;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Từ chối xác minh #$verificationId',
        subtitle: 'Nhập lý do từ chối giấy tờ xác minh này.',
        maxWidth: 440,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Từ chối'),
          ),
        ],
        child: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: Ảnh giấy tờ bị mờ hoặc hết hạn...',
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối xác minh.');
      return;
    }

    setState(() {
      _processingVerificationId = verificationId;
      _error = null;
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
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể từ chối xác minh.',
        );
      });
    } finally {
      if (mounted) setState(() => _processingVerificationId = null);
    }
  }

  Future<void> _fetchDetail(String applicationId) async {
    setState(() {
      _selectedId = applicationId;
      _loadingDetail = true;
      _error = null;
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
    setState(() {
      _actionLoading = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(adminRepositoryProvider).approveHostApplication(appId);
      if (!mounted) return;
      setState(() => _message = 'Đã duyệt hồ sơ chủ nhà.');
      AppToast.show(
        context,
        'Đã duyệt hồ sơ chủ nhà #$appId.',
        type: AppToastType.success,
      );
      await _fetchApplications();
      await _fetchDetail(appId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể duyệt hồ sơ.',
        );
      });
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _runReject() async {
    final appId = '${_detail?['applicationId'] ?? _detail?['id'] ?? ''}';
    if (appId.isEmpty) return;
    final reason = _rejectReasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }
    setState(() {
      _actionLoading = true;
      _error = null;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .rejectHostApplication(appId, reason);
      if (!mounted) return;
      setState(() => _message = 'Đã từ chối hồ sơ chủ nhà.');
      AppToast.show(
        context,
        'Đã từ chối hồ sơ chủ nhà #$appId.',
        type: AppToastType.info,
      );
      await _fetchApplications();
      await _fetchDetail(appId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể từ chối hồ sơ.',
        );
      });
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    final listSection = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: _loadingList
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : _applications.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('Không có hồ sơ host phù hợp.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _applications.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final app = _applications[index];
                    final appId = '${app['applicationId'] ?? app['id'] ?? ''}';
                    final user = app['user'] is Map
                        ? Map<String, dynamic>.from(app['user'] as Map)
                        : const <String, dynamic>{};
                    final name =
                        '${user['name'] ?? app['contactName'] ?? 'Host #$appId'}';
                    final email =
                        '${user['email'] ?? app['contactEmail'] ?? '-'}';
                    final phone = '${app['phone'] ?? user['phone'] ?? '-'}';
                    final status = '${app['status'] ?? 'pending'}';
                    final selected = appId == _selectedId;

                    return InkWell(
                      onTap: () => _fetchDetail(appId),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: selected
                            ? AppColors.surfaceWarmSand
                            : Colors.transparent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$email · $phone',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Trạng thái: $status · Giấy tờ: ${app['documentCount'] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _fetchDetail(appId),
                              child: const Text('Chi tiết'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );

    final detailSection = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                        Text(
                          '${_detail!['contactName'] ?? (_detail!['user'] is Map ? _detail!['user']['name'] : null) ?? 'Hồ sơ host'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SĐT: ${_detail!['phone'] ?? '-'} · Loại: ${_detail!['profileType'] ?? 'individual'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
                              borderRadius: BorderRadius.circular(12),
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
                            final signedUrl = '${doc['signedUrl'] ?? ''}';
                            final mimeType = '${doc['mimeType'] ?? ''}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(14),
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
                                  if (signedUrl.isNotEmpty &&
                                      mimeType != 'application/pdf')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AppImage(
                                        imageUrl: signedUrl,
                                        height: 180,
                                        width: double.infinity,
                                      ),
                                    ),
                                  if (signedUrl.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () async {
                                        final uri = Uri.tryParse(signedUrl);
                                        if (uri != null) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
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
                        const Divider(height: 24),
                        const Text(
                          'Quyết định xét duyệt',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _rejectReasonCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Nhập lý do nếu bạn muốn từ chối hồ sơ này...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _actionLoading ||
                                        _detail!['status'] == 'approved'
                                    ? null
                                    : _runApprove,
                                child: const Text('Phê duyệt hồ sơ'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _actionLoading ||
                                        _detail!['status'] == 'rejected'
                                    ? null
                                    : _runReject,
                                child: const Text('Từ chối'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
    );

    final verificationsSection = Container(
      padding: const EdgeInsets.all(20),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bảng Legacy Verifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Xác minh giấy tờ chủ nhà qua cổng /api/admin/verifications.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: _verificationStatus,
                    underline: const SizedBox.shrink(),
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
                      setState(() => _verificationStatus = value);
                      _fetchVerifications();
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
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
          if (_loadingVerifications)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_verifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Không có bản ghi Legacy Verification nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
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
                final isProcessing =
                    _processingVerificationId == verificationId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                            'Loại: $vType · Trạng thái: $vStatus',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: isProcessing || vStatus == 'approved'
                                ? null
                                : () => _approveVerification(verificationId),
                            child: const Text('Duyệt xác minh'),
                          ),
                          OutlinedButton(
                            onPressed: isProcessing || vStatus == 'rejected'
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
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hồ sơ đăng ký Host',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quản lý và xét duyệt các yêu cầu trở thành chủ nhà.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _status,
                        underline: const SizedBox.shrink(),
                        items: const [
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
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tất cả'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _status = value;
                            _selectedId = null;
                            _detail = null;
                          });
                          _fetchApplications();
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _fetchApplications,
                        icon: const Icon(
                          LucideIcons.refreshCw,
                          size: 15,
                          color: AppColors.iconStrong,
                        ),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              ],
              const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                detailSection,
              ],
              const SizedBox(height: 24),
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

  List<Map<String, dynamic>> _users = const [];
  final Map<String, String> _draftRoles = {};
  bool _loading = true;
  String? _error;
  String? _savingUserId;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(adminRepositoryProvider)
          .getAdminUsers(page: 1, limit: 100);
      if (!mounted) return;
      final drafts = <String, String>{};
      for (final u in list) {
        final id = '${u['userId'] ?? u['id'] ?? ''}';
        final role =
            '${u['role'] ?? (u['roles'] is List && (u['roles'] as List).isNotEmpty ? (u['roles'] as List).first : 'guest')}';
        drafts[id] = _supportedRoles.contains(role) ? role : 'guest';
      }
      setState(() {
        _users = list;
        _draftRoles
          ..clear()
          ..addAll(drafts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
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
    final isActorAdmin =
        actor == null || actor.role == 'admin' || actor.roles.contains('admin');
    if (!isActorAdmin) {
      setState(() {
        _error = 'Chỉ Quản trị viên (Admin) mới có quyền thay đổi vai trò.';
      });
      return;
    }

    setState(() {
      _savingUserId = userId;
      _error = null;
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
      setState(() {
        _error = AdminRepository.extractErrorMessage(
          e,
          'Không thể cập nhật vai trò người dùng.',
        );
      });
    } finally {
      if (mounted) setState(() => _savingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canManageRoles =
        actor == null || actor.role == 'admin' || actor.roles.contains('admin');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phân quyền hệ thống',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cấp hoặc thay đổi vai trò cho từng người dùng (Guest, Host, Moderator, Admin).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (!canManageRoles) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(14),
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
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _users.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('Không có user.')),
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

                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 260,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Hiện tại: $currentRole',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    DropdownButton<String>(
                                      value: _supportedRoles.contains(draftRole)
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
                                              if (next == null) return;
                                              setState(
                                                () =>
                                                    _draftRoles[userId] = next,
                                              );
                                            },
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton(
                                          onPressed: !canManageRoles ||
                                                  !isChanged ||
                                                  _savingUserId == userId
                                              ? null
                                              : () => _saveRole(u),
                                          child: Text(
                                            _savingUserId == userId
                                                ? 'Đang lưu...'
                                                : 'Lưu',
                                          ),
                                        ),
                                        if (isChanged) ...[
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () {
                                              setState(() {
                                                _draftRoles[userId] =
                                                    currentRole;
                                              });
                                            },
                                            child: const Text('Hủy'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
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
