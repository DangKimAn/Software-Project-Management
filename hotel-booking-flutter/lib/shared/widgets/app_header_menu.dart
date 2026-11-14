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

  /// Khởi tạo nút trình đơn điều hướng tài khoản trên thanh đầu trang.
  const AppHeaderMenuButton({
    super.key,
    required this.authUser,
    required this.isDesktop,
    required this.isOverlayTop,
  });

  /// Dựng `PopupMenuButton` vùng chạm tối thiểu `48dp` và điều phối chuyển trang hoặc đăng xuất an toàn.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = authUser;
    return PopupMenuButton<String>(
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
            unawaited(context.push('/dang-nhap'));
            break;
          case 'register':
            unawaited(context.push('/dang-ky'));
            break;
          case 'profile':
            unawaited(context.push('/account/profile'));
            break;
          case 'trips':
            unawaited(context.push('/account/trips'));
            break;
          case 'wishlist':
            unawaited(context.push('/yeu-thich'));
            break;
          case 'messages':
            if (user != null && user.isAdmin) {
              unawaited(context.push('/admin/tin-nhan'));
            } else {
              unawaited(context.push('/messages'));
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
              unawaited(context.push('/chu-nha/cho-nghi'));
            } else {
              unawaited(context.push('/tro-thanh-host'));
            }
            break;
          case 'admin':
            unawaited(context.push('/admin'));
            break;
          case 'logout':
            ref.read(notificationsProvider.notifier).clearForLogout();
            await ref.read(authNotifierProvider.notifier).logout();
            if (context.mounted) {
              context.go('/');
            }
            break;
        }
      },
      itemBuilder: (context) => _buildMenuItems(ref, user),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 48,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Icon(
            LucideIcons.menu,
            size: 20,
            color: isOverlayTop ? Colors.white : AppColors.iconStrong,
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(WidgetRef ref, User? user) {
    final localeCurrencyLabel =
        '${ref.read(moneyFormatterProvider).l10n.settingsLanguage} • ${ref.read(effectiveCurrencyProvider).code} (${ref.read(effectiveCurrencyProvider).symbol})';

    final mobileNavItems = <PopupMenuEntry<String>>[
      if (!isDesktop) ...[
        const PopupMenuItem(
          value: 'home',
          child: _MenuItemRow(
            icon: AppSemanticIcons.home,
            label: 'Trang chủ',
          ),
        ),
        const PopupMenuItem(
          value: 'stays',
          child: _MenuItemRow(
            icon: LucideIcons.search,
            label: 'Nơi lưu trú',
          ),
        ),
        const PopupMenuItem(
          value: 'blog',
          child: _MenuItemRow(
            icon: LucideIcons.bookOpen,
            label: 'Blog',
          ),
        ),
        const PopupMenuItem(
          value: 'contact',
          child: _MenuItemRow(
            icon: LucideIcons.phone,
            label: 'Liên hệ',
          ),
        ),
        const PopupMenuDivider(),
      ],
    ];

    final commonAccountItems = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'wishlist',
        child: _MenuItemRow(
          icon: LucideIcons.heart,
          label: 'Danh sách yêu thích',
        ),
      ),
      const PopupMenuItem(
        value: 'trips',
        child: _MenuItemRow(
          icon: AppSemanticIcons.bookings,
          label: 'Chuyến đi',
        ),
      ),
      const PopupMenuItem(
        value: 'messages',
        child: _MenuItemRow(
          icon: AppSemanticIcons.messageHost,
          label: 'Tin nhắn',
        ),
      ),
      const PopupMenuItem(
        value: 'profile',
        child: _MenuItemRow(
          icon: AppSemanticIcons.userProfile,
          label: 'Hồ sơ',
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
        const PopupMenuItem(
          value: 'host',
          child: _MenuItemRow(
            icon: AppSemanticIcons.becomeHost,
            label: 'Trở thành host',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'login',
          child: _MenuItemRow(
            icon: LucideIcons.logIn,
            label: 'Đăng nhập',
            isBold: true,
          ),
        ),
        const PopupMenuItem(
          value: 'register',
          child: _MenuItemRow(
            icon: LucideIcons.userPlus,
            label: 'Đăng ký',
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
            label: user.isHost ? 'Khu vực host' : 'Trở thành host',
          ),
        ),
      if (user.isAdmin)
        const PopupMenuItem(
          value: 'admin',
          child: _MenuItemRow(
            icon: AppSemanticIcons.adminPortal,
            label: 'Khu vực admin',
            isBold: true,
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'logout',
        child: _MenuItemRow(
          icon: AppSemanticIcons.logout,
          label: 'Đăng xuất',
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
