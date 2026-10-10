import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';

/// Interactive heart button with an Airbnb/Instagram spring pop bounce animation.
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
    this.size = 18,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.textStrong,
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
      duration: const Duration(milliseconds: 280),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite && widget.isFavorite) {
      _controller.forward(from: 0.0);
    }
  }

  void _handleTap() {
    if (widget.onToggle != null) {
      _controller.forward(from: 0.0);
      widget.onToggle!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isFavorite ? 'Bỏ lưu khỏi yêu thích' : 'Lưu vào yêu thích',
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _handleTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  widget.isFavorite ? LucideIcons.heart : LucideIcons.heart,
                  key: ValueKey<bool>(widget.isFavorite),
                  size: widget.size,
                  color: widget.isFavorite
                      ? widget.activeColor
                      : widget.inactiveColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
