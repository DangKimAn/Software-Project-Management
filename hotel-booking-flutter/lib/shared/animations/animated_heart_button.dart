import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';

/// Nút trái tim yêu thích tương tác có hiệu ứng nảy đàn hồi 3 pha và thanh gạch chân chỉ báo.
///
/// Interactive heart button with spring pop bounce animation.
///
/// Strictly follows Section 2 Icon Design Rules:
/// - No circular or box background container around the icon.
/// - Transparent 48x48 hit target.
/// - Neutral monochrome stroke icon directly on the surface; active state is indicated by a subtle underline indicator bar.
class AnimatedHeartButton extends StatefulWidget {
  /// Trạng thái căn villa/bất động sản hiện đã được lưu vào danh sách yêu thích hay chưa.
  final bool isFavorite;

  /// Hàm gọi lại khi người dùng chạm chuyển đổi trạng thái yêu thích (`null` để vô hiệu hóa).
  final VoidCallback? onToggle;

  /// Kích thước hiển thị của biểu tượng trái tim tính bằng dp.
  final double size;

  /// Màu biểu tượng khi đang ở trạng thái đã lưu yêu thích.
  final Color activeColor;

  /// Màu biểu tượng khi ở trạng thái chưa lưu yêu thích.
  final Color inactiveColor;

  /// Khởi tạo nút trái tim có vùng chạm trong suốt `48x48dp` và hiệu ứng nảy đàn hồi.
  const AnimatedHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 20,
    this.activeColor = AppColors.iconStrong,
    this.inactiveColor = AppColors.iconStrong,
  });

  /// Tạo trạng thái điều khiển bộ hoạt ảnh co giãn đàn hồi.
  @override
  State<AnimatedHeartButton> createState() => _AnimatedHeartButtonState();
}

/// Trạng thái nội bộ quản lý `AnimationController` và chuỗi nội suy `TweenSequence` của nút trái tim.
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

    // Giải thuật chuỗi nội suy đàn hồi 3 pha (3-stage spring pop TweenSequence):
    // Tổng thời lượng 220ms được chia theo trọng số [40, 30, 30]:
    // - Pha 1 (40%): Phóng đại nhanh từ 1.0 lên 1.35 theo đường cong giảm tốc easeOutCubic.
    // - Pha 2 (30%): Thu nhỏ vượt ngưỡng xuống 0.90 theo easeInOut để tạo quán tính nén lò xo.
    // - Pha 3 (30%): Phục hồi về kích thước chuẩn 1.0 với độ nảy nhẹ easeOutBack.
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

  /// Dừng hoạt ảnh ngay lập tức nếu hệ điều hành bật chế độ giảm chuyển động.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  /// Giải phóng bộ điều khiển hoạt ảnh khi widget bị gỡ khỏi cây giao diện.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Kích hoạt hiệu ứng nảy khi trạng thái `isFavorite` chuyển từ chưa lưu sang đã lưu từ bên ngoài.
  @override
  void didUpdateWidget(covariant AnimatedHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite && widget.isFavorite) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0.0);
      }
    }
  }

  /// Xử lý thao tác chạm: phát hoạt ảnh nảy từ đầu (nếu cho phép) và gọi callback `onToggle`.
  void _handleTap() {
    if (widget.onToggle != null) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0.0);
      }
      widget.onToggle!();
    }
  }

  /// Dựng biểu tượng trái tim không khung nền kèm thanh gạch chân động rộng `14dp` khi được chọn.
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
