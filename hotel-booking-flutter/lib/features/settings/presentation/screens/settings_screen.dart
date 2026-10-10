import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';

import 'package:go_router/go_router.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt & Tài khoản'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Account Profile Section
          _buildSectionHeader('Tài khoản'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: user != null
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.brandSoft,
                        backgroundImage:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? Text(
                                user.firstName.isNotEmpty
                                    ? user.firstName[0].toUpperCase()
                                    : 'U',
                                style: AppTypography.displayMedium.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: AppTypography.cardTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.isHost ? 'Chủ nhà' : 'Khách lưu trú',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.logOut,
                            color: AppColors.primary),
                        tooltip: 'Đăng xuất',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Đăng xuất'),
                              content: const Text(
                                  'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Đăng xuất'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .logout();
                          }
                        },
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.brandSoft,
                            child: Icon(LucideIcons.user,
                                color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Chưa đăng nhập',
                                    style: AppTypography.cardTitle),
                                Text(
                                  'Đăng nhập để xem kỳ nghỉ và đồng bộ yêu thích',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () => context.push('/login'),
                          child: const Text('Đăng nhập / Đăng ký'),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // Language section
          _buildSectionHeader('Ngôn ngữ / Language / 언어'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: [
                _buildLanguageTile(
                  title: 'Tiếng Việt',
                  subtitle: 'Mặc định',
                  isSelected: currentLocale == 'vi',
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLocale('vi'),
                ),
                const Divider(height: 1, color: AppColors.borderSoft),
                _buildLanguageTile(
                  title: 'English',
                  subtitle: 'International',
                  isSelected: currentLocale == 'en',
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLocale('en'),
                ),
                const Divider(height: 1, color: AppColors.borderSoft),
                _buildLanguageTile(
                  title: '한국어',
                  subtitle: 'Korean',
                  isSelected: currentLocale == 'ko',
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLocale('ko'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Environment & Technical Info
          _buildSectionHeader('Thông tin môi trường ứng dụng'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: [
                _buildInfoRow('Môi trường', AppConfig.environment.toUpperCase(),
                    isBadge: true),
                const SizedBox(height: 12),
                _buildInfoRow('Phiên bản', '1.0.0 (Build 1)'),
                const SizedBox(height: 12),
                _buildInfoRow('API Endpoint', AppConfig.apiBaseUrl),
                const SizedBox(height: 12),
                _buildInfoRow('Hotline', AppConfig.hotlineNumber),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Support & Contact
          _buildSectionHeader('Hỗ trợ trực tiếp'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(LucideIcons.phone, color: AppColors.primary),
                  title: const Text('Gọi tổng đài tư vấn'),
                  subtitle: const Text(AppConfig.hotlineNumber),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => ContactService.callHotline(),
                ),
                const Divider(height: 1, color: AppColors.borderSoft),
                ListTile(
                  leading: const Icon(LucideIcons.messageCircle,
                      color: AppColors.primary),
                  title: const Text('Nhắn tin qua Zalo OA'),
                  subtitle: const Text('Hỗ trợ khách hàng 24/7'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () {
                    ContactService.openZaloInquiry(
                      messageText:
                          'Xin chào Minh Thanh Villa, tôi cần hỗ trợ thông tin ứng dụng.',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
