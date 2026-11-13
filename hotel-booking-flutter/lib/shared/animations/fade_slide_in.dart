import 'dart:async';
import 'package:flutter/material.dart';

/// Short entrance animation with cancellable delay and reduced-motion support.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final Curve curve;
  const FadeSlideIn(
      {super.key,
      required this.child,
      this.delay = Duration.zero,
      this.duration = const Duration(milliseconds: 220),
      this.beginOffset = const Offset(0, 24),
      this.curve = Curves.easeOutCubic});
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  void _start() {
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(covariant FadeSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.delay != oldWidget.delay) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = widget.curve.transform(_controller.value);
          return Opacity(
              opacity: t.clamp(0, 1),
              child: Transform.translate(
                  offset: widget.beginOffset * (1 - t), child: child));
        });
  }
}
