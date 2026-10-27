import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';

/// Interactive heart button with spring pop bounce animation.
///
/// Strictly follows Section 2 Icon Design Rules:
/// - No circular or box background container around the icon.
/// - Transparent 48x48 hit target.
/// - Neutral monochrome stroke icon directly on the surface; active state is indicated by a subtle underline indicator bar.
class AnimatedHeartButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onToggle;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const AnimatedHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 20,
    this.activeColor = AppColors.iconStrong,
    this.inactiveColor = AppColors.iconStrong,
  });

  @override
  State<AnimatedHeartButton> createState() => _AnimatedHeartButtonState();
}

class _AnimatedHeartButtonState extends State<AnimatedHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 0.90)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.90, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite && widget.isFavorite) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0.0);
      }
    }
  }

  void _handleTap() {
    if (widget.onToggle != null) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0.0);
      }
      widget.onToggle!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.heart,
          key: ValueKey<bool>(widget.isFavorite),
          size: widget.size,
          color: widget.isFavorite ? widget.activeColor : widget.inactiveColor,
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 160),
          width: widget.isFavorite ? 14 : 0,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.textStrong,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );

    return Semantics(
      selected: widget.isFavorite,
      child: IconButton(
        onPressed: widget.onToggle == null ? null : _handleTap,
        tooltip:
            widget.isFavorite ? 'Bỏ lưu khỏi yêu thích' : 'Lưu vào yêu thích',
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        ),
        icon: disableAnimations
            ? content
            : ScaleTransition(scale: _scaleAnimation, child: content),
      ),
    );
  }
}
