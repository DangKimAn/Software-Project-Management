import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

// Exact Flutter equivalents of animations defined in `Source goc/frontend/src/index.css`
// and `LocationMapPicker.css` & `useScrollVisibility.ts`.

/// Hiệu ứng xuất hiện mượt cho lịch và hộp thoại (`220ms`, đường cong `Cubic(0.16, 1, 0.3, 1)`):
/// kết hợp mờ dần `0 -> 1`, trượt dọc nhẹ và phóng từ `0.97` lên `1.0`.
///
/// `@keyframes calFadeIn` (220ms cubic-bezier(0.16, 1, 0.3, 1)):
/// opacity 0 -> 1, translateY(-10px) -> 0, scale(0.97) -> 1.0
class CalFadeIn extends StatefulWidget {
  /// Phần tử giao diện con cần áp dụng hiệu ứng xuất hiện.
  final Widget child;

  /// Thời lượng chạy hoạt ảnh (mặc định `220ms`).
  final Duration duration;

  /// Khởi tạo hiệu ứng xuất hiện cho bảng lịch hoặc hộp thoại.
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
    final curved = _controller.drive(CurveTween(curve: _curve));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant CalFadeIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
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

/// Hiệu ứng bật mở nhanh cho popover tìm kiếm và thông báo nổi (`170ms`, neo tâm trên `topCenter`).
///
/// `@keyframes searchPopIn` (170ms cubic-bezier(0.16, 1, 0.3, 1)):
/// opacity 0 -> 1, translateY(-6px) -> 0, scale(0.98) -> 1.0, transform-origin: top center
class SearchPopIn extends StatefulWidget {
  /// Phần tử giao diện con bên trong popover hoặc toast.
  final Widget child;

  /// Thời lượng hoạt ảnh bật mở (mặc định `170ms`).
  final Duration duration;

  /// Khởi tạo hiệu ứng bật mở neo đỉnh trên.
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
    _curved = _controller.drive(CurveTween(curve: _curve));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant SearchPopIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
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

/// Bộ chuyển cảnh ngang mượt mà (`180ms`) mỗi khi người dùng lật sang tháng khác trên lịch.
///
/// `@keyframes monthIn` (180ms ease-out):
/// opacity 0 -> 1, translateX(10px) -> 0 on month change
class MonthInSwitcher extends StatelessWidget {
  /// Khóa định danh tháng (ví dụ `'2026-11'`) dùng để kích hoạt `AnimatedSwitcher` khi đổi tháng.
  final Object monthKey;

  /// Lưới lịch của tháng hiện tại.
  final Widget child;

  /// Khởi tạo bộ chuyển cảnh đổi tháng trên lịch.
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

/// Hộp giữ chỗ ghim vị trí trên bản đồ với kích thước chạm chuẩn `48x48dp` (tĩnh, không phát vầng sáng).
///
/// `@keyframes map-marker-pulse` (2000ms cubic-bezier(0.215, 0.61, 0.355, 1) infinite):
/// scale(0.5) opacity 1 -> scale(1.5) opacity 0
class MapMarkerPulse extends StatefulWidget {
  /// Biểu tượng ghim tùy chỉnh đặt ở tâm vùng đánh dấu.
  final Widget? child;

  /// Kích thước cạnh của hộp đánh dấu tính bằng dp.
  final double pulseSize;

  /// Màu sắc tham chiếu của điểm đánh dấu.
  final Color pulseColor;

  /// Khởi tạo điểm ghim bản đồ kích thước tối thiểu chuẩn trợ năng.
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

class _MapMarkerPulseState extends State<MapMarkerPulse> {
  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.pulseSize,
        height: widget.pulseSize,
        child: Center(child: widget.child ?? const Icon(LucideIcons.mapPin)),
      );
}

/// Bộ theo dõi trạng thái ẩn/hiện và ghim thanh điều hướng theo hướng cuộn có độ trễ chống rung (hysteresis).
///
/// Exact scroll visibility logic from `Source goc/frontend/src/hooks/useScrollVisibility.ts`
class ScrollVisibilityTracker {
  /// Ngưỡng quãng đường cuộn tối thiểu (px) để đổi trạng thái ẩn/hiện nhằm lọc nhiễu rung ngón tay.
  final double threshold;

  /// Vùng đỉnh trang luôn giữ thanh điều hướng hiển thị bất kể hướng cuộn.
  final double topOffset;

  /// Tỷ lệ chiều cao khung nhìn cộng thêm vào `topOffset` trước khi bắt đầu cho phép ẩn thanh điều hướng.
  final double hideStartRatio;

  /// Callback thông báo mỗi khi cặp trạng thái `(isVisible, isPinned)` thực sự thay đổi.
  final void Function(bool isVisible, bool isPinned)? onChanged;

  double _lastScrollY = 0;

  /// Cho biết thanh điều hướng hiện đang hiển thị hay đã thu gọn.
  bool isVisible = true;

  /// Cho biết người dùng đã cuộn qua mốc `320px` để kích hoạt chế độ thanh điều hướng thu gọn/ghim hay chưa.
  bool isPinnedByScroll = false;

  /// Khởi tạo bộ theo dõi trạng thái cuộn với ngưỡng lọc nhiễu `threshold` mặc định `12px`.
  ScrollVisibilityTracker({
    this.threshold = 12.0,
    this.topOffset = 64.0,
    this.hideStartRatio = 0.5,
    this.onChanged,
  });

  /// Xử lý sự kiện cuộn mới và chỉ phát `onChanged` khi trạng thái hiển thị hoặc ghim thay đổi.
  void onScroll(double currentScrollY, double viewportHeight) {
    if (update(currentScrollY, viewportHeight)) {
      onChanged?.call(isVisible, isPinnedByScroll);
    }
  }

  /// Cập nhật máy trạng thái ẩn/hiện theo vị trí cuộn dọc `currentScrollY` và chiều cao khung nhìn `viewportHeight`.
  ///
  /// Trả về `true` nếu `isVisible` hoặc `isPinnedByScroll` thay đổi so với lần cập nhật trước.
  bool update(double currentScrollY, double viewportHeight) {
    // Giải thuật theo dõi ẩn/hiện và ghim thanh điều hướng theo độ trễ cuộn (scroll hysteresis):
    // - Bước 1: Đánh dấu ghim thu gọn (isPinnedByScroll) khi vị trí cuộn vượt mốc cố định 320px.
    // - Bước 2: Tính ngưỡng bắt đầu cho phép ẩn hideStartOffset = topOffset + viewportHeight * hideStartRatio.
    //   Nếu người dùng vẫn đang ở vùng đầu trang (<= hideStartOffset), luôn cưỡng bức hiển thị (isVisible = true).
    // - Bước 3: Tính độ lệch cuộn delta = currentScrollY - _lastScrollY. Nếu |delta| < threshold (12px),
    //   giữ nguyên trạng thái ẩn/hiện hiện tại và KHÔNG cập nhật _lastScrollY để tích lũy quãng đường cuộn nhỏ.
    // - Bước 4: Khi |delta| >= threshold, cuộn lên (delta < 0) sẽ hiện thanh điều hướng, cuộn xuống (delta > 0)
    //   sẽ ẩn thanh điều hướng, đồng thời chốt lại mốc _lastScrollY mới.
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

/// Khung hộp thoại dùng chung bo góc `24px` kèm hiệu ứng xuất hiện `CalFadeIn` và nút đóng chuẩn `48x48dp`.
///
/// Shared animated modal container (`--radius-modal: 24px`, `calFadeIn` entrance).
class AppModal extends StatelessWidget {
  /// Tiêu đề chính hiển thị ở phần đầu hộp thoại.
  final String? title;

  /// Dòng mô tả phụ nằm ngay dưới tiêu đề chính.
  final String? subtitle;

  /// Nội dung chính hiển thị bên trong thân hộp thoại.
  final Widget child;

  /// Danh sách nút hành động căn phải ở chân hộp thoại.
  final List<Widget>? actions;

  /// Chiều rộng tối đa của hộp thoại trên màn hình lớn (mặc định `640dp`).
  final double maxWidth;

  /// Hàm xử lý khi bấm nút đóng ở góc trên bên phải.
  final VoidCallback? onClose;

  /// Khởi tạo khung hộp thoại dùng chung của ứng dụng.
  const AppModal({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.maxWidth = 640,
    this.onClose,
  });

  /// Hiển thị hộp thoại `AppModal` trên lớp phủ `Dialog` với nền mờ `AppColors.scrim`.
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: CalFadeIn(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor,
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
                    const SizedBox(height: 24),
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

/// Phân loại mức độ ngữ nghĩa của thông báo nổi `AppToast`.
enum AppToastType {
  /// Thông tin hướng dẫn hoặc phản hồi trung tính.
  info,

  /// Thông báo thao tác hoàn tất thành công.
  success,

  /// Cảnh báo tình huống cần người dùng lưu ý.
  warning,

  /// Thông báo lỗi thao tác hoặc sự cố kết nối.
  error,
}

/// Thanh thông báo nổi dùng chung kết hợp hiệu ứng `SearchPopIn`, nền phẳng và biểu tượng đơn sắc.
///
/// Shared animated toast notification (`SearchPopIn` entrance + semantic soft surface + neutral monochrome icon).
class AppToast extends StatelessWidget {
  /// Nội dung thông điệp hiển thị cho người dùng.
  final String message;

  /// Phân loại ngữ nghĩa quyết định biểu tượng đi kèm thông điệp.
  final AppToastType type;

  /// Hàm đóng nhanh thông báo nổi khi người dùng chạm nút tắt.
  final VoidCallback? onDismiss;

  /// Khởi tạo thông báo nổi `AppToast`.
  const AppToast({
    super.key,
    required this.message,
    this.type = AppToastType.info,
    this.onDismiss,
  });

  /// Hiển thị `AppToast` thông qua `ScaffoldMessenger` sau khi ẩn thanh thông báo cũ đang mở (nếu có).
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
                tooltip: 'Đóng',
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
