import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_header.dart';

/// Khung bố cục chuẩn Light Luxury cho toàn bộ các trang Hỗ trợ, Chính sách & Khám phá.
/// Đảm bảo không tràn bố cục (0px overflow) từ màn hình 320dp đến Desktop và chữ phóng to 2.0x.
class SupportPageShell extends StatelessWidget {
  final String currentPath;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget body;
  final String ctaTitle;
  final String ctaDescription;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const SupportPageShell({
    super.key,
    required this.currentPath,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.ctaTitle,
    required this.ctaDescription,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 960;
    final horizontalPad = screenWidth >= 640
        ? AppSpacing.xl
        : (screenWidth < 360 ? AppSpacing.sm : AppSpacing.md);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppTopHeader(currentPath: currentPath),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceBase,
                        border: Border(
                          bottom: BorderSide(color: AppColors.borderSoft),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        isDesktop ? AppSpacing.xxl : AppSpacing.lg,
                        horizontalPad,
                        isDesktop ? AppSpacing.xxl : AppSpacing.xl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/');
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textStrong,
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  icon: const Icon(
                                    LucideIcons.arrowLeft,
                                    size: 16,
                                    color: AppColors.iconStrong,
                                  ),
                                  label: Text(
                                    context.l10n.ctaBack,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                eyebrow.toUpperCase(),
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                title,
                                style: AppTypography.displayLarge.copyWith(
                                  fontSize: screenWidth < 360 ? 22 : 28,
                                  color: AppColors.textStrong,
                                  height: 1.24,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 760),
                                child: Text(
                                  subtitle,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            AppSpacing.xl,
                            horizontalPad,
                            AppSpacing.xxl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              body,
                              const SizedBox(height: AppSpacing.xxl),
                              _SupportBottomCtaBanner(
                                title: ctaTitle,
                                description: ctaDescription,
                                primaryLabel: primaryActionLabel,
                                onPrimaryTap: onPrimaryAction,
                                secondaryLabel: secondaryActionLabel,
                                onSecondaryTap: onSecondaryAction,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportBottomCtaBanner extends StatelessWidget {
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  const _SupportBottomCtaBanner({
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarmSand,
        borderRadius: AppRadii.roundedCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.sectionHeading.copyWith(
              fontSize: 19,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: onPrimaryTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: 12,
                  ),
                ),
                child: Text(primaryLabel),
              ),
              if (secondaryLabel != null && onSecondaryTap != null)
                OutlinedButton(
                  onPressed: onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textStrong,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: 12,
                    ),
                  ),
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
