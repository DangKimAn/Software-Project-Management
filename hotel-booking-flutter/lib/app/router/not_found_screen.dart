import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../shared/accessibility/app_accessibility.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/widgets/app_semantic_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'not_found_painters.dart';
import 'not_found_path_sanitizer.dart';
import 'not_found_widgets.dart';

export 'not_found_path_sanitizer.dart' show sanitizeNotFoundDisplayPath;

/// Màn hình 404 hiện đại theo ngôn ngữ Airbnb Luxury × Apple Studio Minimalist.
class NotFoundScreen extends StatelessWidget {
  final String? requestedLocation;

  const NotFoundScreen({
    super.key,
    this.requestedLocation,
  });

  /// Điều hướng tới đường dẫn `route` thông qua `GoRouter`, hoặc lùi về màn trước nếu chạy độc lập trong bài kiểm thử.
  void _navigateToRoute(BuildContext context, String route) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(route);
      return;
    }
    Navigator.maybeOf(context)?.maybePop();
  }

  /// Giải thuật quay lại an toàn cho nút hành động phụ: ưu tiên `router.pop()` nếu có lịch sử ngăn xếp, ngược lại đưa về `/tim-kiem`.
  void _handleSecondaryBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/tim-kiem');
      }
      return;
    }
    Navigator.maybeOf(context)?.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final copy = NotFoundLocalizedCopy.resolve(context);
    final l10n = copy.l10n;
    final sanitizedPath = sanitizeNotFoundDisplayPath(requestedLocation);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final reduceMotion = AppAccessibility.shouldReduceMotion(context);
    final isCompact = screenWidth < 360;
    final isWide = screenWidth >= 640;

    final outerPadding = EdgeInsets.symmetric(
      horizontal: isCompact
          ? AppSpacing.s12
          : (isWide ? AppSpacing.s32 : AppSpacing.s16),
      vertical: isWide ? AppSpacing.s32 : AppSpacing.s20,
    );
    final cardPadding = EdgeInsets.symmetric(
      horizontal: isCompact
          ? AppSpacing.s16
          : (isWide ? AppSpacing.s40 : AppSpacing.s24),
      vertical: isCompact
          ? AppSpacing.s24
          : (isWide ? AppSpacing.s40 : AppSpacing.s32),
    );
    final titleFontSize = isWide ? 28.0 : (isCompact ? 21.0 : 24.0);

    final destinations = <NotFoundQuickDestination>[
      NotFoundQuickDestination(
        icon: LucideIcons.bedDouble,
        title: l10n.navStays,
        subtitle: copy.staysSubtitle,
        route: '/tim-kiem',
      ),
      NotFoundQuickDestination(
        icon: LucideIcons.bookOpen,
        title: l10n.navBlog,
        subtitle: copy.blogSubtitle,
        route: '/cam-nang',
      ),
      NotFoundQuickDestination(
        icon: AppSemanticIcons.supportCenter,
        title: l10n.navContact,
        subtitle: copy.contactSubtitle,
        route: '/lien-he',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceWarmSand,
      body: NotFoundBackdropStage(
        child: SafeArea(
          child: FocusTraversalGroup(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: outerPadding,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: FadeSlideIn(
                          duration: AppAccessibility.effectiveDuration(
                            context,
                            const Duration(milliseconds: 220),
                          ),
                          beginOffset:
                              reduceMotion ? Offset.zero : const Offset(0, 14),
                          child: Container(
                            padding: cardPadding,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBase,
                              borderRadius: BorderRadius.circular(
                                isWide
                                    ? AppRadii.heroCardDesktop
                                    : AppRadii.card,
                              ),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NotFoundWayfindingEmblem(compact: isCompact),
                                const SizedBox(height: AppSpacing.s16),
                                _buildEyebrowBadge(copy.eyebrow),
                                const SizedBox(height: AppSpacing.s12),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    l10n.errorNotFoundTitle,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.display.copyWith(
                                      fontSize: titleFontSize,
                                      letterSpacing: -0.55,
                                      height: 1.24,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: Text(
                                    l10n.errorNotFoundMessage,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontSize: isCompact ? 14 : 15,
                                      color: AppColors.textMuted,
                                      height: 1.55,
                                    ),
                                  ),
                                ),
                                if (sanitizedPath != null) ...[
                                  const SizedBox(height: AppSpacing.s16),
                                  NotFoundPathBadge(
                                    sanitizedPath: sanitizedPath,
                                    semanticPrefix: copy.pathPrefix,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.s24),
                                _buildActionButtons(
                                  context,
                                  homeLabel: l10n.ctaBackHome,
                                  backLabel: l10n.ctaBack,
                                  textScale: textScale,
                                ),
                                const SizedBox(height: AppSpacing.s24),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.borderSoft,
                                ),
                                const SizedBox(height: AppSpacing.s20),
                                NotFoundDestinationSection(
                                  sectionTitle: copy.quickSectionTitle,
                                  destinations: destinations,
                                  onSelectRoute: (route) =>
                                      _navigateToRoute(context, route),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEyebrowBadge(String eyebrowText) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadii.roundedPill,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              eyebrowText,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: AppColors.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context, {
    required String homeLabel,
    required String backLabel,
    required double textScale,
  }) {
    final btnAnimDuration = AppAccessibility.effectiveDuration(
      context,
      const Duration(milliseconds: 180),
    );

    final primaryBtn = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FilledButton(
        key: const ValueKey('not-found-home-btn'),
        onPressed: () => _navigateToRoute(context, '/'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          animationDuration: btnAnimDuration,
          minimumSize: const Size(164, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: const StadiumBorder(),
          textStyle: AppTypography.buttonText,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return AppColors.primaryPressed;
            }
            return AppColors.primary;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: AppColors.borderFocus, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.house, size: 17, color: Colors.white),
            const SizedBox(width: AppSpacing.s8),
            Flexible(child: Text(homeLabel, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );

    final secondaryBtn = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton(
        key: const ValueKey('not-found-back-btn'),
        onPressed: () => _handleSecondaryBack(context),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceBase,
          foregroundColor: AppColors.textStrong,
          animationDuration: btnAnimDuration,
          minimumSize: const Size(140, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          shape: const StadiumBorder(),
          textStyle:
              AppTypography.buttonText.copyWith(color: AppColors.textStrong),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: AppColors.borderFocus, width: 2)
                : const BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.arrowLeft,
              size: 17,
              color: AppColors.iconStrong,
            ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(child: Text(backLabel, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Giải thuật xếp nút hành động thích ứng (Responsive Dual-CTA Layout):
        // Giữ 2 nút nằm ngang cân đối khi chiều rộng >= 380dp và cỡ chữ <= 1.25x;
        // chuyển sang xếp chồng toàn chiều rộng trên màn hình nhỏ hoặc chữ phóng đại.
        if (constraints.maxWidth < 380 || textScale > 1.25) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryBtn,
              const SizedBox(height: AppSpacing.s12),
              secondaryBtn,
            ],
          );
        }
        return Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          alignment: WrapAlignment.center,
          children: [primaryBtn, secondaryBtn],
        );
      },
    );
  }
}
