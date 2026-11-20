import 'package:flutter/material.dart';

/// Lớp bọc tương tác thu nhỏ mượt mà khi nhấn giữ, tạo phản hồi xúc giác tự nhiên cho thẻ và nút.
///
/// A wrapper widget that scales down smoothly when pressed,
/// providing tactile spring feedback like iOS / Airbnb luxury cards.
class PressableScale extends StatefulWidget {
  /// Phần tử giao diện con nhận hiệu ứng thu phóng khi chạm.
  final Widget child;

  /// Hàm xử lý khi chạm nhả thành công; nếu `null`, widget dùng `Listener` thụ động không chặn cử chỉ con.
  final VoidCallback? onTap;

  /// Tỷ lệ thu nhỏ tối đa khi đang nhấn giữ (mặc định `0.97`).
  final double scaleDown;

  /// Thời lượng chuyển tiếp thu nhỏ và phục hồi kích thước.
  final Duration duration;

  /// Đường cong nội suy tốc độ thu phóng.
  final Curve curve;

  /// Khởi tạo lớp bọc phản hồi thu phóng khi nhấn.
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  });

  /// Tạo trạng thái điều khiển hoạt ảnh thu phóng theo sự kiện chạm.
  @override
  State<PressableScale> createState() => _PressableScaleState();
}

/// Trạng thái nội bộ điều phối `AnimationController` khi nhấn xuống, nhả tay hoặc hủy cử chỉ.
class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).chain(CurveTween(curve: widget.curve)).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    _scaleAnimation = _controller.drive(
        Tween<double>(begin: 1, end: widget.scaleDown)
            .chain(CurveTween(curve: widget.curve)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null && !MediaQuery.disableAnimationsOf(context)) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null && !MediaQuery.disableAnimationsOf(context)) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Giải thuật định tuyến sự kiện chạm hai chế độ:
    // - Khi có onTap: dùng GestureDetector ở chế độ opaque để bắt trọn vùng chạm và kích hoạt callback.
    // - Khi không có onTap: hạ xuống Listener cấp thấp lắng nghe pointer thô để tạo hiệu ứng lún
    //   mà không tranh chấp đấu trường cử chỉ (GestureArena) với các nút bấm bên trong child.
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (widget.onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: disableAnimations
            ? widget.child
            : AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
                child: widget.child,
              ),
      );
    }

    if (disableAnimations) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
