import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/theme/admin_studio_tokens.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Frosted glass bar with real [BackdropFilter] blur used exclusively in Admin
/// for the top studio header and bottom navigation dock.
class AdminFrostedSurface extends StatelessWidget {
  const AdminFrostedSurface({
    super.key,
    required this.child,
    this.sigma = AdminStudioTokens.dockBlurSigma,
    this.fillColor = AdminStudioTokens.frostedDockFill,
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

/// Outer rounded grouped container (matching "Content Generation Activity" and
/// "Top Creators" sections in the Studio template).
class AdminStudioGroupCard extends StatelessWidget {
  const AdminStudioGroupCard({
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
        color: AdminStudioTokens.groupSurface,
        borderRadius: BorderRadius.circular(AdminStudioTokens.groupRadius),
        border: Border.all(
          color: AdminStudioTokens.groupBorder,
          width: 1.2,
        ),
        boxShadow: AdminStudioTokens.groupShadow,
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
                        style: AdminStudioTokens.sectionTitle,
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

/// Pure white rounded inner card floating inside [AdminStudioGroupCard].
class AdminStudioInnerCard extends StatelessWidget {
  const AdminStudioInnerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.margin,
    this.selected = false,
    this.warningHighlight = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool selected;
  final bool warningHighlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AdminStudioTokens.cardRadius);
    final content = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminStudioTokens.cardSurface,
        borderRadius: radius,
        border: selected
            ? Border.all(color: AdminStudioTokens.obsidian, width: 1.2)
            : warningHighlight
                ? Border.all(color: AdminStudioTokens.warningInk, width: 1.0)
                : null,
        boxShadow: AdminStudioTokens.cardShadow,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: AdminStudioTokens.cardSurface,
              borderRadius: radius,
              border: selected
                  ? Border.all(color: AdminStudioTokens.obsidian, width: 1.2)
                  : warningHighlight
                      ? Border.all(
                          color: AdminStudioTokens.warningInk,
                          width: 1.0,
                        )
                      : null,
              boxShadow: AdminStudioTokens.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 2-column Bento KPI card matching the template's metric cards:
/// - Top row: subtle thin metric icon + soft borderless circular `↗` badge
/// - Middle: sleek Medium-weight SF Pro Display figure
/// - Bottom: Regular muted label
class AdminStudioKpiCard extends StatelessWidget {
  const AdminStudioKpiCard({
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
    final radius = BorderRadius.circular(AdminStudioTokens.cardRadius);
    return Semantics(
      button: onTap != null,
      container: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
            decoration: BoxDecoration(
              color: AdminStudioTokens.cardSurface,
              borderRadius: radius,
              boxShadow: AdminStudioTokens.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      icon,
                      size: 15.5,
                      color: AdminStudioTokens.iconMuted,
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: AdminStudioTokens.softCircle,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.arrowUpRight,
                          size: 13.5,
                          color: onTap != null
                              ? AdminStudioTokens.iconInk
                              : AdminStudioTokens.iconMuted,
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
                    style: AdminStudioTokens.kpiValue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminStudioTokens.kpiLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminStudioSegmentItem<T> {
  const AdminStudioSegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Symmetrical capsule segmented bar where each option occupies balanced equal
/// width inside a crisp white pill track.
class AdminStudioSegmentedBar<T> extends StatelessWidget {
  const AdminStudioSegmentedBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.expandSegments = true,
  });

  final List<AdminStudioSegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T>? onSelected;
  final bool expandSegments;

  @override
  Widget build(BuildContext context) {
    final pillRadius = BorderRadius.circular(AdminStudioTokens.pillRadius);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget buildSegment(AdminStudioSegmentItem<T> item) {
      final selected = item.value == selectedValue;
      return Semantics(
        button: true,
        selected: selected,
        enabled: onSelected != null,
        label: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: pillRadius,
            onTap: onSelected == null ? null : () => onSelected!(item.value),
            child: AnimatedContainer(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color:
                    selected ? AdminStudioTokens.obsidian : Colors.transparent,
                borderRadius: pillRadius,
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 13.5,
                        color: selected
                            ? Colors.white
                            : AdminStudioTokens.iconMuted,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      item.label,
                      maxLines: 1,
                      style: AdminStudioTokens.pillText.copyWith(
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : AdminStudioTokens.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AdminStudioTokens.cardSurface,
        borderRadius: pillRadius,
        boxShadow: AdminStudioTokens.cardShadow,
      ),
      child: Row(
        mainAxisSize: expandSegments ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            if (expandSegments)
              Expanded(child: buildSegment(items[i]))
            else
              buildSegment(items[i]),
          ],
        ],
      ),
    );
  }
}

/// Accessible 48x48 hit-target wrapping a crisp borderless circular icon button
/// (white circle or solid obsidian black circle, zero border).
class AdminStudioCircleButton extends StatelessWidget {
  const AdminStudioCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDark = false,
    this.visualSize = 36,
    this.iconSize = 15.5,
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
        (isDark ? AdminStudioTokens.obsidian : AdminStudioTokens.cardSurface);
    final fg = isDark
        ? Colors.white
        : (disabled ? AdminStudioTokens.inkSubtle : AdminStudioTokens.iconInk);

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
                  color: disabled ? bg.withValues(alpha: 0.55) : bg,
                  shape: BoxShape.circle,
                  boxShadow: isDark ? null : AdminStudioTokens.cardShadow,
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

/// Borderless circular avatar displaying either a network image or refined
/// monochrome initials (avoids `CircleAvatar` per static screen audit rules).
class AdminStudioAvatar extends StatelessWidget {
  const AdminStudioAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String _extractInitials(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return 'A';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts.first.characters.first.toUpperCase();
      final last = parts.last.characters.first.toUpperCase();
      return '$first$last';
    }
    return cleaned.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl?.trim() ?? '';
    if (trimmedUrl.isNotEmpty && trimmedUrl != 'null' && trimmedUrl != '-') {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: AppImage(
            imageUrl: trimmedUrl,
            width: size,
            height: size,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AdminStudioTokens.softCircle,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _extractInitials(name),
          maxLines: 1,
          style: AdminStudioTokens.pillText.copyWith(
            fontSize: size * 0.33,
            color: AdminStudioTokens.inkPrimary,
          ),
        ),
      ),
    );
  }
}

/// Borderless filter pill (obsidian active / crisp white inactive).
class AdminStudioFilterPill extends StatelessWidget {
  const AdminStudioFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.inactiveFill = AdminStudioTokens.cardSurface,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color inactiveFill;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AdminStudioTokens.obsidian : inactiveFill,
              borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
              boxShadow: selected ? null : AdminStudioTokens.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color:
                        selected ? Colors.white : AdminStudioTokens.iconMuted,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminStudioTokens.pillText.copyWith(
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
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
  }
}
