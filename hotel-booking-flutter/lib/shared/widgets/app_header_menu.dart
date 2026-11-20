// CONFLICT-RESOLVED: Tách menu điều hướng tài khoản trên thanh đầu trang thành app_header_menu.dart để giữ app_header.dart tinh gọn theo nguyên tắc đơn trách nhiệm.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/di/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
// CONFLICT-RESOLVED: Tích hợp đa ngôn ngữ động (`context.l10n`) từ `origin/develop` (`cbb008a`) vào menu tài khoản trên thanh đầu trang.
import '../../l10n/l10n.dart';
import 'app_dialog.dart';
import 'app_image.dart';
import 'app_notification_bell.dart';
import 'app_semantic_icons.dart';
import 'currency_language_selector.dart';

/// Nút mở trình đơn thả xuống ở góc phải thanh đầu trang, tự động phân nhánh danh mục điều hướng
/// theo kích thước màn hình (`isDesktop`) và vai trò người dùng (Khách vãng lai, Khách đã đăng nhập, Host, Admin).
class AppHeaderMenuButton extends ConsumerWidget {
  /// Thông tin người dùng đang đăng nhập (`null` nếu đang duyệt ở chế độ khách vãng lai).
  final User? authUser;

  /// Cho biết khung nhìn hiện tại có đạt điểm ngắt màn hình lớn để ẩn bớt các mục đã có trên thanh ngang hay không.
  final bool isDesktop;

  /// Đổi màu biểu tượng trình đơn sang trắng khi thanh đầu trang đang phủ nổi trên ảnh bìa tối.
  final bool isOverlayTop;

  /// Đường dẫn màn hình hiện tại để bảo toàn ngữ cảnh quay lại (`redirectTo`) khi mở màn hình Đăng nhập / Đăng ký.
  final String currentPath;

  /// Khởi tạo nút trình đơn điều hướng tài khoản trên thanh đầu trang.
  const AppHeaderMenuButton({
    super.key,
    required this.authUser,
    required this.isDesktop,
    required this.isOverlayTop,
    this.currentPath = '/',
  });

  String _buildAuthRouteWithRedirect(String basePath) {
    final trimmed = currentPath.trim();
    if (AuthNotifier.isSafeRedirectPath(trimmed)) {
      return Uri(
        path: basePath,
        queryParameters: <String, String>{'redirectTo': trimmed},
      ).toString();
    }
    return basePath;
  }

  /// Dựng `PopupMenuButton` vùng chạm tối thiểu `48dp` và điều phối chuyển trang hoặc đăng xuất an toàn.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = authUser;
    final activeLocale = ref.watch(localeProvider);
    final activeL10n = lookupAppLocalizations(Locale(activeLocale));
    final initial = (user != null && user.fullName.trim().isNotEmpty)
        ? user.fullName.trim().characters.first.toUpperCase()
        : 'U';

    return PopupMenuButton<String>(
      key: const Key('header_account_menu_button'),
      tooltip: 'Menu',
      offset: const Offset(0, 48),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'home':
            context.go('/');
            break;
          case 'login':
            unawaited(context.push(_buildAuthRouteWithRedirect('/dang-nhap')));
            break;
          case 'register':
            unawaited(context.push(_buildAuthRouteWithRedirect('/dang-ky')));
            break;
          case 'profile':
            context.go('/account/profile');
            break;
          case 'trips':
            context.go('/account/trips');
            break;
          case 'wishlist':
            unawaited(context.push('/yeu-thich'));
            break;
          case 'messages':
            if (user != null && user.isAdmin) {
              unawaited(context.push('/admin/tin-nhan'));
            } else {
              context.go('/messages');
            }
            break;
          case 'stays':
            unawaited(context.push('/tim-kiem'));
            break;
          case 'blog':
            unawaited(context.push('/cam-nang'));
            break;
          case 'contact':
            unawaited(context.push('/lien-he'));
            break;
          case 'language-currency':
            unawaited(showCurrencyLanguageBottomSheet(context));
            break;
          case 'host':
            if (user != null && user.isHost) {
              unawaited(context.push('/chu-nha'));
            } else {
              unawaited(context.push('/tro-thanh-host'));
            }
            break;
          case 'admin':
            unawaited(context.push('/admin'));
            break;
          case 'logout':
            // Giải thuật xác nhận hai bước trước khi hủy phiên đăng nhập (`TC-065`):
            // Hiển thị hộp thoại xác nhận rõ ràng trước khi xóa thông báo cục bộ, thu hồi Refresh Token và quay về Trang chủ.
            final confirmed = await AppDialog.show(
              context,
              title: activeL10n.settingsConfirmLogoutTitle,
              message: activeL10n.settingsConfirmLogout,
              confirmText: activeL10n.authLogout,
              cancelText: activeL10n.ctaCancel,
            );
            if (confirmed != true || !context.mounted) return;
            ref.read(notificationsProvider.notifier).clearForLogout();
            await ref.read(authNotifierProvider.notifier).logout();
            if (context.mounted) {
              context.go('/');
            }
            break;
        }
      },
      itemBuilder: (context) => _buildMenuItems(context, ref, user, activeL10n),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: user != null ? 10 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: user != null
              ? (isOverlayTop
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0xFFF8FAFC))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: user != null
              ? Border.all(
                  color: isOverlayTop
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFFE2E8F0),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.menu,
              size: 20,
              color: isOverlayTop ? Colors.white : AppColors.iconStrong,
            ),
            if (user != null) ...[
              const SizedBox(width: 8),
              Container(
                key: const Key('header_user_avatar_badge'),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                clipBehavior: Clip.antiAlias,
                child: (user.avatarUrl != null &&
                        user.avatarUrl!.trim().isNotEmpty)
                    ? AppImage(
                        url: user.avatarUrl!,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // CONFLICT-RESOLVED: Chuyển toàn bộ nhãn mục chọn trong `AppHeaderMenuButton` sang `AppLocalizations` từ `origin/develop` để hỗ trợ chuyển đổi VI/EN/KO thời gian thực.
  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context,
    WidgetRef ref,
    User? user,
    AppLocalizations l10n,
  ) {
    final localeCurrencyLabel =
        '${l10n.settingsLanguage} • ${ref.read(effectiveCurrencyProvider).code} (${ref.read(effectiveCurrencyProvider).symbol})';

    final mobileNavItems = <PopupMenuEntry<String>>[
      if (!isDesktop) ...[
        PopupMenuItem(
          value: 'home',
          child: _MenuItemRow(
            icon: AppSemanticIcons.home,
            label: l10n.navDiscover,
          ),
        ),
        PopupMenuItem(
          value: 'stays',
          child: _MenuItemRow(
            icon: LucideIcons.search,
            label: l10n.navStays,
          ),
        ),
        PopupMenuItem(
          value: 'blog',
          child: _MenuItemRow(
            icon: LucideIcons.bookOpen,
            label: l10n.navBlog,
          ),
        ),
        PopupMenuItem(
          value: 'contact',
          child: _MenuItemRow(
            icon: LucideIcons.phone,
            label: l10n.navContact,
          ),
        ),
        const PopupMenuDivider(),
      ],
    ];

    final commonAccountItems = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'wishlist',
        child: _MenuItemRow(
          icon: LucideIcons.heart,
          label: l10n.navFavorites,
        ),
      ),
      PopupMenuItem(
        value: 'trips',
        child: _MenuItemRow(
          icon: AppSemanticIcons.bookings,
          label: l10n.navTrips,
        ),
      ),
      PopupMenuItem(
        value: 'messages',
        child: _MenuItemRow(
          icon: AppSemanticIcons.messageHost,
          label: l10n.navMessages,
        ),
      ),
      PopupMenuItem(
        value: 'profile',
        child: _MenuItemRow(
          icon: AppSemanticIcons.userProfile,
          label: l10n.navAccount,
        ),
      ),
      PopupMenuItem(
        value: 'language-currency',
        child: _MenuItemRow(
          icon: LucideIcons.globe,
          label: localeCurrencyLabel,
        ),
      ),
    ];

    if (user == null) {
      return [
        ...mobileNavItems,
        ...commonAccountItems,
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'host',
          child: _MenuItemRow(
            icon: AppSemanticIcons.becomeHost,
            label: l10n.navBecomeHost,
          ),
        ),
        const PopupMenuDivider(),
        // CONFLICT-RESOLVED: Dùng đúng khóa bản địa hóa `authLoginTitle` và `authRegisterTitle` từ `AppLocalizations` đã sinh tự động.
        PopupMenuItem(
          value: 'login',
          child: _MenuItemRow(
            icon: LucideIcons.logIn,
            label: l10n.authLoginTitle,
            isBold: true,
          ),
        ),
        PopupMenuItem(
          value: 'register',
          child: _MenuItemRow(
            icon: LucideIcons.userPlus,
            label: l10n.authRegisterTitle,
          ),
        ),
      ];
    }

    return [
      PopupMenuItem(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      ...mobileNavItems,
      ...commonAccountItems,
      const PopupMenuDivider(),
      if (!user.isAdmin)
        PopupMenuItem(
          value: 'host',
          child: _MenuItemRow(
            icon: user.isHost
                ? AppSemanticIcons.home
                : AppSemanticIcons.becomeHost,
            label: user.isHost ? l10n.navHostPortal : l10n.navBecomeHost,
          ),
        ),
      if (user.isAdmin)
        PopupMenuItem(
          value: 'admin',
          child: _MenuItemRow(
            icon: AppSemanticIcons.adminPortal,
            label: l10n.navAdminPortal,
            isBold: true,
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'logout',
        child: _MenuItemRow(
          icon: AppSemanticIcons.logout,
          label: l10n.authLogout,
        ),
      ),
    ];
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBold;

  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: AppColors.iconStrong,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
