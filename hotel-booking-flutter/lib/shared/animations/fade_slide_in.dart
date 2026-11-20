import 'dart:async';
import 'package:flutter/material.dart';

/// Hiệu ứng xuất hiện kết hợp mờ dần và trượt nhẹ với bộ hẹn giờ trễ có thể hủy an toàn
/// cùng khả năng tự động bỏ qua chuyển động khi bật trợ năng giảm chuyển động.
///
/// Short entrance animation with cancellable delay and reduced-motion support.
class FadeSlideIn extends StatefulWidget {
  /// Phần tử giao diện con được bọc hiệu ứng xuất hiện.
  final Widget child;

  /// Độ trễ trước khi bắt đầu chạy hoạt ảnh (hữu ích khi xếp tầng danh sách thẻ).
  final Duration delay;

  /// Thời lượng thực thi chuyển động chính.
  final Duration duration;

  /// Độ lệch tọa độ pixel ban đầu trước khi trượt về `Offset.zero`.
  final Offset beginOffset;

  /// Đường cong gia tốc điều phối cả độ mờ và vị trí trượt.
  final Curve curve;

  /// Khởi tạo hiệu ứng xuất hiện mờ dần kèm trượt nhẹ.
  const FadeSlideIn(
      {super.key,
      required this.child,
      this.delay = Duration.zero,
      this.duration = const Duration(milliseconds: 220),
      this.beginOffset = const Offset(0, 24),
      this.curve = Curves.easeOutCubic});

  /// Tạo trạng thái điều phối bộ hẹn giờ trễ và `AnimationController`.
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

/// Trạng thái nội bộ quản lý vòng đời `Timer` có thể hủy và nội suy vị trí trượt.
class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  /// Khởi chạy hoặc đặt lại hoạt ảnh xuất hiện có xét đến cờ giảm chuyển động.
  void _start() {
    // Giải thuật kích hoạt hoạt ảnh trễ có thể hủy (cancellable staggered entrance):
    // Hủy Timer cũ trước khi đăng ký mới để tránh rò rỉ callback khi widget cập nhật hoặc hủy sớm;
    // nếu hệ thống yêu cầu tắt hoạt ảnh thì nhảy thẳng tới trạng thái đích (value = 1).
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
          // Giải thuật nội suy đồng thời độ mờ và dịch chuyển:
          // Ánh xạ tiến độ tuyến tính qua đường cong phi tuyến t, kẹp miền [0, 1] cho Opacity
          // để an toàn với các đường cong vượt biên, đồng thời suy giảm vector dịch chuyển theo (1 - t).
          final t = widget.curve.transform(_controller.value);
          return Opacity(
              opacity: t.clamp(0, 1),
              child: Transform.translate(
                  offset: widget.beginOffset * (1 - t), child: child));
        });
  }
}
