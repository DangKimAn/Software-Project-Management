import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

/// Exact Flutter equivalents of animations defined in `Source goc/frontend/src/index.css`
/// and `LocationMapPicker.css` & `useScrollVisibility.ts`.

/// `@keyframes calFadeIn` (220ms cubic-bezier(0.16, 1, 0.3, 1)):
/// opacity 0 -> 1, translateY(-10px) -> 0, scale(0.97) -> 1.0
class CalFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const CalFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<CalFadeIn> createState() => _CalFadeInState();
}

class _CalFadeInState extends State<CalFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  static const Cubic _curve = Cubic(0.16, 1.0, 0.3, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: _curve);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}

/// `@keyframes searchPopIn` (170ms cubic-bezier(0.16, 1, 0.3, 1)):
/// opacity 0 -> 1, translateY(-6px) -> 0, scale(0.98) -> 1.0, transform-origin: top center
class SearchPopIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const SearchPopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 170),
  });

  @override
  State<SearchPopIn> createState() => _SearchPopInState();
}

class _SearchPopInState extends State<SearchPopIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  static const Cubic _curve = Cubic(0.16, 1.0, 0.3, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: _curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        final t = _curved.value;
        final dy = -6.0 * (1.0 - t);
        final scale = 0.98 + 0.02 * t;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// `@keyframes monthIn` (180ms ease-out):
/// opacity 0 -> 1, translateX(10px) -> 0 on month change
class MonthInSwitcher extends StatelessWidget {
  final Object monthKey;
  final Widget child;

  const MonthInSwitcher({
    super.key,
    required this.monthKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        if (disableAnimations) {
          return child;
        }
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.04, 0.0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<Object>(monthKey),
        child: child,
      ),
    );
  }
}

/// `@keyframes map-marker-pulse` (2000ms cubic-bezier(0.215, 0.61, 0.355, 1) infinite):
/// scale(0.5) opacity 1 -> scale(1.5) opacity 0
class MapMarkerPulse extends StatefulWidget {
  final Widget? child;
  final double pulseSize;
  final Color pulseColor;

  const MapMarkerPulse({
    super.key,
    this.child,
    double? size,
    double pulseSize = 48.0,
    this.pulseColor = const Color(0x4D222222),
  }) : pulseSize = size ?? pulseSize;

  @override
  State<MapMarkerPulse> createState() => _MapMarkerPulseState();
}

class _MapMarkerPulseState extends State<MapMarkerPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  static const Cubic _curve = Cubic(0.215, 0.61, 0.355, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _curved = CurvedAnimation(parent: _controller, curve: _curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.child ??
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Color(0xFF222222),
            shape: BoxShape.circle,
          ),
        );
    if (MediaQuery.disableAnimationsOf(context)) {
      return inner;
    }
    return SizedBox(
      width: widget.pulseSize,
      height: widget.pulseSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _curved,
            builder: (context, _) {
              final t = _curved.value;
              final scale = 0.5 + 1.0 * t;
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.pulseSize,
                    height: widget.pulseSize,
                    decoration: BoxDecoration(
                      color: widget.pulseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          inner,
        ],
      ),
    );
  }
}

/// Exact scroll visibility logic from `Source goc/frontend/src/hooks/useScrollVisibility.ts`
class ScrollVisibilityTracker {
  final double threshold;
  final double topOffset;
  final double hideStartRatio;
  final void Function(bool isVisible, bool isPinned)? onChanged;

  double _lastScrollY = 0;
  bool isVisible = true;
  bool isPinnedByScroll = false;

  ScrollVisibilityTracker({
    this.threshold = 12.0,
    this.topOffset = 64.0,
    this.hideStartRatio = 0.5,
    this.onChanged,
  });

  void onScroll(double currentScrollY, double viewportHeight) {
    if (update(currentScrollY, viewportHeight)) {
      onChanged?.call(isVisible, isPinnedByScroll);
    }
  }

  bool update(double currentScrollY, double viewportHeight) {
    final prevVisible = isVisible;
    final prevPinned = isPinnedByScroll;

    isPinnedByScroll = currentScrollY > 320.0;
    final hideStartOffset = topOffset + viewportHeight * hideStartRatio;

    if (currentScrollY <= topOffset || currentScrollY <= hideStartOffset) {
      isVisible = true;
      _lastScrollY = currentScrollY;
      return prevVisible != isVisible || prevPinned != isPinnedByScroll;
    }

    final delta = currentScrollY - _lastScrollY;
    if (delta.abs() < threshold) {
      return prevPinned != isPinnedByScroll;
    }

    isVisible = delta < 0;
    _lastScrollY = currentScrollY;
    return prevVisible != isVisible || prevPinned != isPinnedByScroll;
  }
}

/// Shared animated modal container (`--radius-modal: 24px`, `calFadeIn` entrance).
class AppModal extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final VoidCallback? onClose;

  const AppModal({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.maxWidth = 640,
    this.onClose,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? subtitle,
    required Widget child,
    List<Widget>? actions,
    double maxWidth = 640,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.scrim,
      builder: (ctx) => AppModal(
        title: title,
        subtitle: subtitle,
        maxWidth: maxWidth,
        actions: actions,
        onClose: () => Navigator.of(ctx).pop(),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: CalFadeIn(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: AppRadii.roundedModal,
              border: Border.all(color: AppColors.borderSoft),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null || onClose != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null)
                                Text(title!,
                                    style: AppTypography.sectionHeading),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: AppTypography.bodyMuted,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            onPressed: onClose,
                            tooltip: 'Đóng',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: const Icon(
                              LucideIcons.x,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  child,
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AppToastType { info, success, warning, error }

/// Shared animated toast notification (`SearchPopIn` entrance + semantic soft surface + neutral monochrome icon).
class AppToast extends StatelessWidget {
  final String message;
  final AppToastType type;
  final VoidCallback? onDismiss;

  const AppToast({
    super.key,
    required this.message,
    this.type = AppToastType.info,
    this.onDismiss,
  });

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        content: AppToast(
          message: message,
          type: type,
          onDismiss: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  Color _backgroundColor() {
    return AppColors.surfaceBase;
  }

  IconData _iconData() {
    switch (type) {
      case AppToastType.success:
        return LucideIcons.circleCheck;
      case AppToastType.warning:
        return LucideIcons.triangleAlert;
      case AppToastType.error:
        return LucideIcons.circleAlert;
      case AppToastType.info:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchPopIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _backgroundColor(),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            Icon(_iconData(), size: 18, color: AppColors.iconStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: AppColors.iconStrong,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
