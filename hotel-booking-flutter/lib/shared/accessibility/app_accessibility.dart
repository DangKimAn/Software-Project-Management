import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../app/theme/app_colors.dart';
import '../../core/date/booking_date.dart';
import '../../l10n/l10n.dart';

/// Core accessibility constants, reduced-motion detectors, and WCAG 2.1 contrast utilities
/// compliant with FLUTTER_RULES.md Sections 4, 5, 6, 9.2, 11, and 13.
abstract final class AppAccessibility {
  /// Default minimum interactive touch target per The Palm design rules (48x48dp).
  static const double minTouchTargetSize = 48.0;

  /// Absolute minimum interactive touch target floor per FLUTTER_RULES.md Section 13 (44x44dp).
  static const double minAbsoluteTouchTargetSize = 44.0;

  /// Determines whether animations should be disabled or minimized.
  ///
  /// Checks both [MediaQuery.maybeDisableAnimationsOf] AND OS-level
  /// [AccessibilityFeatures.disableAnimations] / [AccessibilityFeatures.reduceMotion]
  /// (critical for iOS "Reduce Motion" per FLUTTER_RULES.md Section 13).
  static bool shouldReduceMotion(
    BuildContext context, {
    AccessibilityFeatures? platformFeatures,
  }) {
    final mediaQueryDisable =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (mediaQueryDisable) {
      return true;
    }
    final features = platformFeatures ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  /// Returns [Duration.zero] when reduced motion is enabled, or [normalDuration] otherwise.
  static Duration effectiveDuration(
    BuildContext context,
    Duration normalDuration, {
    AccessibilityFeatures? platformFeatures,
  }) {
    if (shouldReduceMotion(context, platformFeatures: platformFeatures)) {
      return Duration.zero;
    }
    return normalDuration;
  }

  /// Returns `1.0` (no scale bounce) when reduced motion is enabled, or [normalScale] otherwise.
  static double effectiveScale(
    BuildContext context, {
    double normalScale = 0.98,
    AccessibilityFeatures? platformFeatures,
  }) {
    if (shouldReduceMotion(context, platformFeatures: platformFeatures)) {
      return 1.0;
    }
    return normalScale;
  }
}

/// WCAG 2.1 relative luminance and contrast ratio calculator for design token verification.
abstract final class AppContrast {
  /// Composites a potentially translucent [foreground] over an opaque [background].
  static Color compositeOver(Color foreground, Color background) {
    if (foreground.a >= 1.0) return foreground;
    return Color.alphaBlend(foreground, background);
  }

  /// Computes WCAG 2.1 relative luminance in `[0.0, 1.0]`.
  static double relativeLuminance(Color color) {
    double linearize(double channel) {
      return channel <= 0.03928
          ? channel / 12.92
          : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize(color.r);
    final g = linearize(color.g);
    final b = linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Computes WCAG 2.1 contrast ratio `(L1 + 0.05) / (L2 + 0.05)` in `[1.0, 21.0]`.
  static double contrastRatio(Color foreground, Color background) {
    final effectiveFg = compositeOver(foreground, background);
    final lum1 = relativeLuminance(effectiveFg);
    final lum2 = relativeLuminance(background);
    final brightest = math.max(lum1, lum2);
    final darkest = math.min(lum1, lum2);
    return (brightest + 0.05) / (darkest + 0.05);
  }

  /// Checks WCAG 2.1 Level AA compliance:
  /// - Normal text: `>= 4.5:1`
  /// - Large text (>= 18pt or >= 14pt bold) / UI components: `>= 3.0:1`
  static bool meetsWcagAA(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final threshold = isLargeText ? 3.0 : 4.5;
    return contrastRatio(foreground, background) >= threshold;
  }

  /// Checks WCAG 2.1 Level AAA compliance:
  /// - Normal text: `>= 7.0:1`
  /// - Large text: `>= 4.5:1`
  static bool meetsWcagAAA(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final threshold = isLargeText ? 4.5 : 7.0;
    return contrastRatio(foreground, background) >= threshold;
  }

  /// Returns [preferred] if it meets [minRatio] against [background]; otherwise
  /// falls back to `#222222` (`AppColors.textStrong`) or `#FFFFFF` depending on luminance.
  static Color ensureReadableForeground(
    Color preferred,
    Color background, {
    double minRatio = 4.5,
  }) {
    if (contrastRatio(preferred, background) >= minRatio) {
      return preferred;
    }
    final strongRatio = contrastRatio(AppColors.textStrong, background);
    final whiteRatio = contrastRatio(Colors.white, background);
    return strongRatio >= whiteRatio ? AppColors.textStrong : Colors.white;
  }
}

/// Bare-icon interactive control with a guaranteed `>= 48x48dp` transparent hit area,
/// explicit TalkBack/VoiceOver [Semantics], and [Tooltip].
///
/// Enforces Rule 4 & FLUTTER_RULES.md Section 6:
/// - No circular/pill background fill, no halo, no blur, no shadow, no gradient.
/// - Monochrome neutral icon color (`#222222` or `#717171`, or `#FFFFFF` on dark/brand surface).
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final String? semanticHint;
  final VoidCallback? onPressed;
  final bool? isSelected;
  final double iconSize;
  final double hitSize;
  final Color? iconColor;
  final FocusNode? focusNode;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.semanticHint,
    this.isSelected,
    this.iconSize = 20.0,
    this.hitSize = AppAccessibility.minTouchTargetSize,
    this.iconColor,
    this.focusNode,
  }) : assert(hitSize >= AppAccessibility.minTouchTargetSize);

  @override
  Widget build(BuildContext context) {
    final effectiveHitSize = math.max(
      hitSize,
      AppAccessibility.minTouchTargetSize,
    );
    final effectiveColor = iconColor ??
        (onPressed != null ? AppColors.iconStrong : AppColors.iconMuted);

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      selected: isSelected,
      label: semanticLabel,
      hint: semanticHint,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: Focus(
          focusNode: focusNode,
          canRequestFocus: onPressed != null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: effectiveHitSize,
                minHeight: effectiveHitSize,
              ),
              child: SizedBox(
                width: effectiveHitSize,
                height: effectiveHitSize,
                child: Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: effectiveColor,
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

/// Deterministic TalkBack / VoiceOver & keyboard traversal wrapper.
///
/// Combines [OrdinalSortKey] (screen reader swipe order) with [NumericFocusOrder]
/// (hardware keyboard Tab order) so traversal order is predictable across platforms.
class AccessibleTraversalItem extends StatelessWidget {
  final double order;
  final Widget child;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? button;
  final bool? selected;
  final bool? header;
  final bool container;

  const AccessibleTraversalItem({
    super.key,
    required this.order,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    this.button,
    this.selected,
    this.header,
    this.container = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      sortKey: OrdinalSortKey(order),
      container: container,
      label: semanticLabel,
      hint: semanticHint,
      button: button,
      selected: selected,
      header: header,
      child: FocusTraversalOrder(
        order: NumericFocusOrder(order),
        child: child,
      ),
    );
  }
}

/// Modal / BottomSheet accessibility scope enforcing FLUTTER_RULES.md Section 11.4:
/// - Confines screen reader route semantics (`scopesRoute: true`, `namesRoute: true`).
/// - Applies ordered focus traversal (`OrderedTraversalPolicy`) inside the modal.
/// - Restores focus to [restoreFocusNode] (or the previously focused control) when disposed.
/// - Respects [SafeArea] and keyboard `viewInsets.bottom`.
class AccessibleModalScope extends StatefulWidget {
  final String modalTitle;
  final Widget child;
  final FocusNode? restoreFocusNode;
  final FocusNode? initialFocusNode;
  final bool padForKeyboard;

  const AccessibleModalScope({
    super.key,
    required this.modalTitle,
    required this.child,
    this.restoreFocusNode,
    this.initialFocusNode,
    this.padForKeyboard = true,
  });

  @override
  State<AccessibleModalScope> createState() => _AccessibleModalScopeState();
}

class _AccessibleModalScopeState extends State<AccessibleModalScope> {
  FocusNode? _previousFocusNode;
  late final FocusScopeNode _modalScopeNode;

  @override
  void initState() {
    super.initState();
    _previousFocusNode =
        widget.restoreFocusNode ?? FocusManager.instance.primaryFocus;
    _modalScopeNode = FocusScopeNode(debugLabel: 'AccessibleModalScope');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialFocusNode != null &&
          widget.initialFocusNode!.canRequestFocus) {
        widget.initialFocusNode!.requestFocus();
      } else {
        _modalScopeNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    final target = _previousFocusNode;
    _modalScopeNode.dispose();
    if (target != null && target.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (target.canRequestFocus) {
          target.requestFocus();
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        widget.padForKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.modalTitle,
      child: FocusScope(
        node: _modalScopeNode,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: SafeArea(
            child: AnimatedPadding(
              duration: AppAccessibility.effectiveDuration(
                context,
                const Duration(milliseconds: 180),
              ),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Privacy-safe, accessible calendar day cell wrapper compliant with FLUTTER_RULES.md Section 9.2:
/// - Booked/unavailable days announce localized `dateBooked` (`"Ngày này đã kín"`)
///   and NEVER expose any guest/group name or reservation PII.
/// - Guarantees `>= 48x48dp` touch target.
class AccessibleCalendarDayCell extends StatelessWidget {
  final BookingDate date;
  final bool isBooked;
  final bool isPast;
  final bool isSelectedStart;
  final bool isSelectedEnd;
  final bool isInRange;
  final bool isCheckoutCandidate;
  final VoidCallback? onTap;
  final Widget? child;

  const AccessibleCalendarDayCell({
    super.key,
    required this.date,
    this.isBooked = false,
    this.isPast = false,
    this.isSelectedStart = false,
    this.isSelectedEnd = false,
    this.isInRange = false,
    this.isCheckoutCandidate = false,
    this.onTap,
    this.child,
  });

  /// Builds a privacy-safe semantic label for a calendar day without any guest PII.
  static String buildSemanticLabel(
    BookingDate date, {
    required String localeCode,
    required bool isBooked,
    required bool isPast,
    required bool isSelectedStart,
    required bool isSelectedEnd,
    required bool isInRange,
    bool isCheckoutCandidate = false,
  }) {
    final l10n = LocaleFormatters.resolveL10n(localeCode);
    final formattedDate = LocaleFormatters.formatBookingDate(
      date,
      localeCode: localeCode,
    );
    if (isBooked && !isCheckoutCandidate) {
      return '$formattedDate, ${l10n.dateBooked}';
    }
    if (isSelectedStart) {
      return '$formattedDate, ${l10n.checkInDate}';
    }
    if (isSelectedEnd) {
      return '$formattedDate, ${l10n.checkOutDate}';
    }
    if (isInRange) {
      return '$formattedDate, ${l10n.statusAvailable}';
    }
    if (isPast) {
      return formattedDate;
    }
    return '$formattedDate, ${l10n.statusAvailable}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.activeLanguageCode;
    final canSelect = !isPast && (!isBooked || isCheckoutCandidate);
    final isSelected = isSelectedStart || isSelectedEnd;
    final label = buildSemanticLabel(
      date,
      localeCode: lang,
      isBooked: isBooked,
      isPast: isPast,
      isSelectedStart: isSelectedStart,
      isSelectedEnd: isSelectedEnd,
      isInRange: isInRange,
      isCheckoutCandidate: isCheckoutCandidate,
    );

    final bgColor = isSelected
        ? AppColors.primary
        : (isInRange ? AppColors.rangeBackground : Colors.transparent);
    final textColor = isSelected
        ? Colors.white
        : ((isBooked && !isCheckoutCandidate) || isPast
            ? AppColors.textMuted
            : AppColors.textStrong);

    return Semantics(
      button: true,
      enabled: canSelect && onTap != null,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canSelect ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppAccessibility.minTouchTargetSize,
            minHeight: AppAccessibility.minTouchTargetSize,
          ),
          child: Container(
            width: AppAccessibility.minTouchTargetSize,
            height: AppAccessibility.minTouchTargetSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              shape: isSelected ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isSelected
                  ? null
                  : (isInRange ? BorderRadius.circular(12) : null),
            ),
            child: child ??
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                    decoration: (isBooked && !isCheckoutCandidate)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
