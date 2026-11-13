import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Scoped Studio Minimalist tokens for the Host Portal shell & Overview
/// (soft porcelain canvas, frosted header/dock, borderless Bento cards,
/// and sleek SF Pro Display / SF Pro Text weights).
abstract final class HostStudioTokens {
  // ── Surfaces & Frosted Layers ──
  static const Color canvas = Color(0xFFF2F4F7);
  static const Color groupSurface = Color(0xFFF7F8FA);
  static const Color groupBorder = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFECEEF2);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color softCircle = Color(0xFFF3F4F7);

  static const Color frostedHeaderFill = Color(0xCCF2F4F7);
  static const Color frostedInnerHeaderFill = Color(0xD9FFFFFF);
  static const Color frostedDockFill = Color(0xCFffffff);
  static const Color frostedDockBorder = Color(0xE6FFFFFF);

  // ── Studio Monochrome Ink Palette ──
  static const Color obsidian = Color(0xFF141416);
  static const Color inkPrimary = Color(0xFF141416);
  static const Color inkSecondary = Color(0xFF525866);
  static const Color inkMuted = Color(0xFF7B818F);
  static const Color inkSubtle = Color(0xFF9AA0AC);

  static const Color iconInk = AppColors.iconStrong;
  static const Color iconSecondary = Color(0xFF525866);
  static const Color iconMuted = Color(0xFF858B98);

  // ── Radii & Blur Sigmas ──
  static const double groupRadius = 28.0;
  static const double cardRadius = 22.0;
  static const double dockRadius = 28.0;
  static const double pillRadius = 999.0;

  static const double dockBlurSigma = 24.0;
  static const double headerBlurSigma = 18.0;

  // ── Soft Ambient Shadows ──
  static const List<BoxShadow> groupShadow = [
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> dockShadow = [
    BoxShadow(
      color: Color(0x100F172A),
      blurRadius: 28,
      offset: Offset(0, -4),
    ),
  ];

  // ── Typography (Sleek SF Pro weights — zero chunky w800) ──
  static const TextStyle headerEyebrow = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: inkMuted,
    height: 1.25,
  );

  static const TextStyle headerTitle = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 19.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: inkPrimary,
    height: 1.22,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.28,
    color: inkPrimary,
    height: 1.3,
  );

  static const TextStyle kpiValue = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 25,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    color: inkPrimary,
    height: 1.15,
  );

  static const TextStyle kpiLabel = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.04,
    color: inkMuted,
    height: 1.34,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.22,
    color: inkPrimary,
    height: 1.34,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.04,
    color: inkSecondary,
    height: 1.4,
  );

  static const TextStyle metaCaption = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.02,
    color: inkMuted,
    height: 1.35,
  );

  static const TextStyle priceEmphasis = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.35,
    color: inkPrimary,
    height: 1.25,
  );

  static const TextStyle pillText = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.08,
  );
}

/// Real [BackdropFilter] frosted glass surface for Host header & bottom dock.
class HostFrostedSurface extends StatelessWidget {
  const HostFrostedSurface({
    super.key,
    required this.child,
    this.sigma = HostStudioTokens.dockBlurSigma,
    this.fillColor = HostStudioTokens.frostedDockFill,
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.boxShadow,
    this.padding,
  });

  final Widget child;
  final double sigma;
  final Color fillColor;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: borderRadius,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soft grouped Bento container with specular white rim and whisper shadow.
class HostStudioGroupCard extends StatelessWidget {
  const HostStudioGroupCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
  });

  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: HostStudioTokens.groupSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.groupRadius),
        border: Border.all(
          color: HostStudioTokens.groupBorder,
          width: 1.2,
        ),
        boxShadow: HostStudioTokens.groupShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: HostStudioTokens.sectionTitle,
                      ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Borderless pure-white Bento KPI card with thin metric icon, soft circular
/// `↗` affordance badge, Medium-weight figure, and Regular muted label.
class HostStudioKpiCard extends StatelessWidget {
  const HostStudioKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HostStudioTokens.cardRadius);
    return Semantics(
      button: onTap != null,
      container: true,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
            decoration: BoxDecoration(
              color: HostStudioTokens.cardSurface,
              borderRadius: radius,
              boxShadow: HostStudioTokens.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: HostStudioTokens.iconMuted,
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: HostStudioTokens.softCircle,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.arrowUpRight,
                          size: 13.5,
                          color: onTap != null
                              ? HostStudioTokens.iconInk
                              : HostStudioTokens.iconMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: HostStudioTokens.kpiValue,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.kpiLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Accessible 48x48 hit-target wrapping a crisp borderless circular icon button.
class HostStudioCircleButton extends StatelessWidget {
  const HostStudioCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDark = false,
    this.visualSize = 36,
    this.iconSize = 16,
    this.circleColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isDark;
  final double visualSize;
  final double iconSize;
  final Color? circleColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = circleColor ??
        (isDark ? HostStudioTokens.obsidian : HostStudioTokens.cardSurface);
    final fg = isDark
        ? Colors.white
        : (disabled ? HostStudioTokens.inkSubtle : HostStudioTokens.iconInk);

    return Semantics(
      button: true,
      enabled: !disabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: circleColor == null && !isDark
                      ? HostStudioTokens.cardShadow
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean circular initials badge for guest rows (uses Container + BoxShape.circle,
/// never CircleAvatar).
class HostStudioInitialsBadge extends StatelessWidget {
  const HostStudioInitialsBadge({
    super.key,
    required this.name,
    this.size = 34,
  });

  final String name;
  final double size;

  static String _computeInitials(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'KH';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'KH';
    if (parts.length == 1) {
      final word = parts.first;
      return word.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.first;
    final last = parts.last.characters.first;
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: HostStudioTokens.softCircle,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _computeInitials(name),
        maxLines: 1,
        style: HostStudioTokens.pillText.copyWith(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w500,
          color: HostStudioTokens.inkPrimary,
        ),
      ),
    );
  }
}
