import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../shared/accessibility/app_accessibility.dart';
import '../../shared/animations/pressable_scale.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Model mô tả một lối đi điều hướng nhanh trên trang 404.
class NotFoundQuickDestination {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const NotFoundQuickDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

/// Huy hiệu hiển thị đường dẫn không tồn tại đã được làm sạch query/token.
class NotFoundPathBadge extends StatelessWidget {
  final String sanitizedPath;
  final String semanticPrefix;

  const NotFoundPathBadge({
    super.key,
    required this.sanitizedPath,
    required this.semanticPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$semanticPrefix: $sanitizedPath',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarmSand,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.unlink,
              size: 14,
              color: AppColors.iconMuted,
            ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                sanitizedPath,
                maxLines: textScale > 1.3 ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khu vực gợi ý các lối đi chính giúp người dùng tiếp tục hành trình khám phá.
class NotFoundDestinationSection extends StatelessWidget {
  final String sectionTitle;
  final List<NotFoundQuickDestination> destinations;
  final ValueChanged<String> onSelectRoute;

  const NotFoundDestinationSection({
    super.key,
    required this.sectionTitle,
    required this.destinations,
    required this.onSelectRoute,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Giải thuật bố cục thích ứng (Adaptive Grid/Stack Switching):
        // Chỉ hiển thị 3 cột ngang khi chiều rộng vùng chứa >= 460dp VÀ tỷ lệ
        // phóng chữ <= 1.2x; tự động chuyển sang danh sách dọc trên màn hình hẹp
        // hoặc khi bật chữ lớn trợ năng để triệt tiêu hoàn toàn lỗi tràn chữ.
        final useHorizontalGrid =
            constraints.maxWidth >= 460 && textScale <= 1.2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                sectionTitle,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (useHorizontalGrid)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: _NotFoundDestinationTile(
                          destination: destinations[i],
                          isCompactCard: true,
                          onTap: () => onSelectRoute(destinations[i].route),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.s8),
                    _NotFoundDestinationTile(
                      destination: destinations[i],
                      isCompactCard: false,
                      onTap: () => onSelectRoute(destinations[i].route),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Ô lối tắt điều hướng có phản hồi nhấn thu phóng, viền tiêu điểm bàn phím và vùng chạm chuẩn trợ năng.
class _NotFoundDestinationTile extends StatefulWidget {
  final NotFoundQuickDestination destination;
  final bool isCompactCard;
  final VoidCallback onTap;

  const _NotFoundDestinationTile({
    required this.destination,
    required this.isCompactCard,
    required this.onTap,
  });

  @override
  State<_NotFoundDestinationTile> createState() =>
      _NotFoundDestinationTileState();
}

class _NotFoundDestinationTileState extends State<_NotFoundDestinationTile> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _handleHoverHighlight(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _handleFocusHighlight(bool value) {
    if (_isFocused == value) return;
    setState(() => _isFocused = value);
    if (value && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final animDuration = AppAccessibility.effectiveDuration(
      context,
      const Duration(milliseconds: 160),
    );
    final isHighlighted = _isHovered || _isFocused;

    final cardDecoration = BoxDecoration(
      color: isHighlighted
          ? AppColors.surfaceWarmSand
          : AppColors.surfaceWarmSand.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadii.md),
      border: Border.all(
        color: _isFocused
            ? AppColors.borderFocus
            : (_isHovered ? AppColors.border : AppColors.borderSoft),
        width: _isFocused ? 2.0 : 1.0,
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: '${dest.title}, ${dest.subtitle}',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: _handleHoverHighlight,
        onShowFocusHighlight: _handleFocusHighlight,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: PressableScale(
          scaleDown: AppAccessibility.effectiveScale(
            context,
            normalScale: 0.98,
          ),
          duration: animDuration,
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppAccessibility.minTouchTargetSize,
              minHeight: AppAccessibility.minTouchTargetSize,
            ),
            child: ExcludeSemantics(
              child: AnimatedContainer(
                duration: animDuration,
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical:
                      widget.isCompactCard ? AppSpacing.s16 : AppSpacing.s12,
                ),
                decoration: cardDecoration,
                child: widget.isCompactCard
                    ? _buildCompactContent(dest)
                    : _buildRowContent(dest),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContent(NotFoundQuickDestination dest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(dest.icon, size: 18, color: AppColors.iconStrong),
            const Icon(
              LucideIcons.arrowUpRight,
              size: 15,
              color: AppColors.iconMuted,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dest.title,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dest.subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRowContent(NotFoundQuickDestination dest) {
    return Row(
      children: [
        Icon(dest.icon, size: 18, color: AppColors.iconStrong),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dest.title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dest.subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        const Icon(
          LucideIcons.chevronRight,
          size: 16,
          color: AppColors.iconMuted,
        ),
      ],
    );
  }
}
