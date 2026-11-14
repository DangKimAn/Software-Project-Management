import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../app/theme/app_colors.dart';
import '../../core/date/booking_date.dart';
import '../../l10n/l10n.dart';

/// Tập hằng số trợ năng cốt lõi, bộ phát hiện giảm chuyển động và tiện ích chuẩn hóa thời lượng
/// tuân thủ chuẩn thiết kế và trợ năng toàn cục của ứng dụng.
///
/// Core accessibility constants, reduced-motion detectors, and WCAG 2.1 contrast utilities
/// compliant with FLUTTER_RULES.md Sections 4, 5, 6, 9.2, 11, and 13.
abstract final class AppAccessibility {
  /// Kích thước vùng chạm tương tác tối thiểu mặc định theo chuẩn thiết kế (`48x48dp`).
  ///
  /// Default minimum interactive touch target per The Palm design rules (48x48dp).
  static const double minTouchTargetSize = 48.0;

  /// Ngưỡng sàn vùng chạm tương tác tối thiểu tuyệt đối (`44x44dp`).
  ///
  /// Absolute minimum interactive touch target floor per FLUTTER_RULES.md Section 13 (44x44dp).
  static const double minAbsoluteTouchTargetSize = 44.0;

  /// Kiểm tra xem hiệu ứng chuyển động có cần tắt hoặc rút gọn theo cấu hình hệ điều hành hay không.
  ///
  /// Kết hợp kiểm tra cả `MediaQuery.maybeDisableAnimationsOf` lẫn cờ trợ năng cấp nền tảng
  /// `disableAnimations` và `reduceMotion` thông qua tham số `platformFeatures` (nếu truyền vào
  /// khi kiểm thử) hoặc `PlatformDispatcher` mặc định.
  ///
  /// Determines whether animations should be disabled or minimized.
  ///
  /// Checks both [MediaQuery.maybeDisableAnimationsOf] AND OS-level
  /// [AccessibilityFeatures.disableAnimations] / [AccessibilityFeatures.reduceMotion]
  /// (critical for iOS "Reduce Motion" per FLUTTER_RULES.md Section 13).
  static bool shouldReduceMotion(
    BuildContext context, {
    AccessibilityFeatures? platformFeatures,
  }) {
    // Giải thuật phát hiện chế độ giảm chuyển động đa tầng (MediaQuery + PlatformDispatcher):
    // Ưu tiên cờ ghi đè trong cây widget trước, sau đó kiểm tra cấu hình trợ năng cấp hệ điều hành.
    final mediaQueryDisable =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (mediaQueryDisable) {
      return true;
    }
    final features = platformFeatures ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  /// Trả về `Duration.zero` khi bật chế độ giảm chuyển động, ngược lại giữ nguyên `normalDuration`.
  ///
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

  /// Trả về tỷ lệ `1.0` (không co giãn đàn hồi) khi bật giảm chuyển động, ngược lại dùng `normalScale`.
  ///
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

/// Bộ tính độ chói tương đối (relative luminance) và tỷ số tương phản màu theo chuẩn WCAG 2.1.
///
/// WCAG 2.1 relative luminance and contrast ratio calculator for design token verification.
abstract final class AppContrast {
  /// Trộn màu tiền cảnh `foreground` (có thể bán trong suốt) đè lên màu nền đục `background`.
  ///
  /// Composites a potentially translucent [foreground] over an opaque [background].
  static Color compositeOver(Color foreground, Color background) {
    if (foreground.a >= 1.0) return foreground;
    return Color.alphaBlend(foreground, background);
  }

  /// Tính độ chói tương đối theo công thức chuẩn WCAG 2.1 trong miền `[0.0, 1.0]`.
  ///
  /// Computes WCAG 2.1 relative luminance in `[0.0, 1.0]`.
  static double relativeLuminance(Color color) {
    // Giải thuật tuyến tính hóa kênh màu sRGB và tính độ chói tương đối WCAG 2.1:
    // - Bước 1: Với mỗi kênh chuẩn hóa c thuộc [0, 1], nếu c <= 0.03928 thì chia tuyến tính cho 12.92;
    //   ngược lại áp dụng hàm mũ hiệu chỉnh gamma ((c + 0.055) / 1.055)^2.4.
    // - Bước 2: Tổ hợp tuyến tính theo độ nhạy phổ mắt người ITU-R BT.709:
    //   L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin.
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

  /// Tính tỷ số tương phản WCAG 2.1 `(L1 + 0.05) / (L2 + 0.05)` trong miền `[1.0, 21.0]`.
  ///
  /// Computes WCAG 2.1 contrast ratio `(L1 + 0.05) / (L2 + 0.05)` in `[1.0, 21.0]`.
  static double contrastRatio(Color foreground, Color background) {
    // Giải thuật tính tỷ số tương phản WCAG 2.1:
    // Trộn trước kênh alpha của tiền cảnh lên màu nền, sau đó lấy tỷ số giữa độ chói lớn hơn (L1)
    // và độ chói nhỏ hơn (L2) cộng bù 0.05 để tránh chia cho 0 và phản ánh ánh sáng tán xạ môi trường.
    final effectiveFg = compositeOver(foreground, background);
    final lum1 = relativeLuminance(effectiveFg);
    final lum2 = relativeLuminance(background);
    final brightest = math.max(lum1, lum2);
    final darkest = math.min(lum1, lum2);
    return (brightest + 0.05) / (darkest + 0.05);
  }

  /// Kiểm tra mức tuân thủ tương phản WCAG 2.1 cấp độ AA (`>= 4.5:1` chữ thường, `>= 3.0:1` chữ lớn).
  ///
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

  /// Kiểm tra mức tuân thủ tương phản WCAG 2.1 cấp độ AAA (`>= 7.0:1` chữ thường, `>= 4.5:1` chữ lớn).
  ///
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

  /// Đảm bảo màu chữ/biểu tượng đạt ngưỡng tương phản tối thiểu `minRatio` trên nền `background`.
  ///
  /// Nếu màu ưu tiên `preferred` không đủ tương phản, hàm tự động chọn giữa màu chữ đậm
  /// `AppColors.textStrong` và màu trắng sao cho tỷ số tương phản thực tế là cao nhất.
  ///
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

/// Nút biểu tượng tối giản đảm bảo vùng chạm trong suốt tối thiểu `48x48dp`, hỗ trợ đầy đủ
/// nhãn đọc màn hình TalkBack/VoiceOver và chú giải `Tooltip`.
///
/// Bare-icon interactive control with a guaranteed `>= 48x48dp` transparent hit area,
/// explicit TalkBack/VoiceOver [Semantics], and [Tooltip].
///
/// Enforces Rule 4 & FLUTTER_RULES.md Section 6:
/// - No circular/pill background fill, no halo, no blur, no shadow, no gradient.
/// - Monochrome neutral icon color (`#222222` or `#717171`, or `#FFFFFF` on dark/brand surface).
class AccessibleIconButton extends StatelessWidget {
  /// Dữ liệu biểu tượng hiển thị ở tâm vùng chạm.
  final IconData icon;

  /// Nhãn ngữ nghĩa bắt buộc cho trình đọc màn hình và `Tooltip`.
  final String semanticLabel;

  /// Gợi ý hành động bổ sung cho trình đọc màn hình.
  final String? semanticHint;

  /// Hàm xử lý khi người dùng chạm kích hoạt nút (`null` tương ứng trạng thái vô hiệu hóa).
  final VoidCallback? onPressed;

  /// Trạng thái đang được chọn (nếu nút đóng vai trò công tắc chuyển đổi).
  final bool? isSelected;

  /// Kích thước hiển thị của biểu tượng tính bằng dp.
  final double iconSize;

  /// Kích thước cạnh tối thiểu của vùng nhận chạm (luôn `>= 48dp`).
  final double hitSize;

  /// Màu sắc tùy chỉnh của biểu tượng; mặc định tự suy diễn theo trạng thái bật/tắt.
  final Color? iconColor;

  /// Nút quản lý tiêu điểm bàn phím tùy chọn.
  final FocusNode? focusNode;

  /// Khởi tạo nút biểu tượng chuẩn trợ năng với kiểm tra bất biến `hitSize >= 48dp`.
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

  /// Dựng cây ngữ nghĩa độc lập bọc ngoài `Tooltip`, `Focus` và hộp chạm trong suốt `48x48dp`.
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

/// Lớp bọc đồng bộ thứ tự duyệt tiêu điểm tất định cho cả trình đọc màn hình và bàn phím cứng.
///
/// Deterministic TalkBack / VoiceOver & keyboard traversal wrapper.
///
/// Combines [OrdinalSortKey] (screen reader swipe order) with [NumericFocusOrder]
/// (hardware keyboard Tab order) so traversal order is predictable across platforms.
class AccessibleTraversalItem extends StatelessWidget {
  /// Chỉ số thứ tự duyệt tăng dần dùng chung cho cả vuốt ngữ nghĩa và phím `Tab`.
  final double order;

  /// Phần tử giao diện con được gắn thứ tự duyệt.
  final Widget child;

  /// Nhãn ngữ nghĩa tùy chọn đọc lên khi phần tử nhận tiêu điểm.
  final String? semanticLabel;

  /// Gợi ý ngữ nghĩa bổ sung tùy chọn.
  final String? semanticHint;

  /// Đánh dấu phần tử là nút bấm trong cây ngữ nghĩa.
  final bool? button;

  /// Đánh dấu trạng thái đang chọn của phần tử.
  final bool? selected;

  /// Đánh dấu phần tử là tiêu đề phân mục để điều hướng nhanh bằng trình đọc màn hình.
  final bool? header;

  /// Có gom nhóm ngữ nghĩa thành một container độc lập hay không.
  final bool container;

  /// Khởi tạo phần tử điều hướng tiêu điểm có thứ tự tất định.
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

  /// Kết hợp `OrdinalSortKey` và `NumericFocusOrder` cùng giá trị `order`.
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

/// Phạm vi trợ năng chuyên dụng cho hộp thoại Modal và BottomSheet: cô lập vùng đọc màn hình,
/// khóa vòng lặp tiêu điểm bên trong hộp thoại và tự động hoàn trả tiêu điểm khi đóng.
///
/// Modal / BottomSheet accessibility scope enforcing FLUTTER_RULES.md Section 11.4:
/// - Confines screen reader route semantics (`scopesRoute: true`, `namesRoute: true`).
/// - Applies ordered focus traversal (`OrderedTraversalPolicy`) inside the modal.
/// - Restores focus to [restoreFocusNode] (or the previously focused control) when disposed.
/// - Respects [SafeArea] and keyboard `viewInsets.bottom`.
class AccessibleModalScope extends StatefulWidget {
  /// Tiêu đề định danh tuyến hộp thoại để trình đọc màn hình thông báo khi mở.
  final String modalTitle;

  /// Nội dung giao diện bên trong hộp thoại.
  final Widget child;

  /// Nút tiêu điểm cần khôi phục sau khi hộp thoại đóng (mặc định tự chụp tiêu điểm trước đó).
  final FocusNode? restoreFocusNode;

  /// Nút tiêu điểm nhận focus ngay khi hộp thoại vừa hiển thị xong khung hình đầu tiên.
  final FocusNode? initialFocusNode;

  /// Tự động cộng đệm dưới theo chiều cao bàn phím ảo `viewInsets.bottom`.
  final bool padForKeyboard;

  /// Khởi tạo phạm vi trợ năng cho Modal hoặc BottomSheet.
  const AccessibleModalScope({
    super.key,
    required this.modalTitle,
    required this.child,
    this.restoreFocusNode,
    this.initialFocusNode,
    this.padForKeyboard = true,
  });

  /// Tạo đối tượng trạng thái quản lý vòng đời thu nhận và khôi phục tiêu điểm.
  @override
  State<AccessibleModalScope> createState() => _AccessibleModalScopeState();
}

/// Trạng thái nội bộ lưu giữ nút tiêu điểm gốc trước khi mở hộp thoại và trả lại khi hủy.
class _AccessibleModalScopeState extends State<AccessibleModalScope> {
  FocusNode? _previousFocusNode;
  late final FocusScopeNode _modalScopeNode;

  @override
  void initState() {
    super.initState();
    // Giải thuật bắt giữ và chuyển giao tiêu điểm an toàn sau khung hình đầu tiên:
    // Ghi nhớ nút đang giữ focus ở màn hình nền, sau đó đợi post-frame callback để chuyển focus
    // vào initialFocusNode hoặc phạm vi hộp thoại mà không gây xung đột trong pha build.
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
    // Giải thuật hoàn trả tiêu điểm hậu hủy (post-dispose focus restoration):
    // Giải phóng FocusScope của hộp thoại trước rồi mới trả focus về nút kích hoạt ban đầu ở
    // khung hình kế tiếp nếu nút đó vẫn còn khả năng nhận focus trong cây giao diện.
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

/// Ô ngày lịch đặt phòng chuẩn trợ năng và bảo mật quyền riêng tư (không bao giờ lộ tên khách đặt),
/// đảm bảo vùng chạm tối thiểu `48x48dp` và hỗ trợ quy tắc nửa khoảng `[checkIn, checkOut)`.
///
/// Privacy-safe, accessible calendar day cell wrapper compliant with FLUTTER_RULES.md Section 9.2:
/// - Booked/unavailable days announce localized `dateBooked` (`"Ngày này đã kín"`)
///   and NEVER expose any guest/group name or reservation PII.
/// - Guarantees `>= 48x48dp` touch target.
class AccessibleCalendarDayCell extends StatelessWidget {
  /// Ngày lịch thuần túy không phụ thuộc múi giờ của ô hiện tại.
  final BookingDate date;

  /// Đánh dấu đêm nghỉ của ngày này đã có khách đặt kín.
  final bool isBooked;

  /// Đánh dấu ngày đã qua trong quá khứ (không cho phép chọn mới).
  final bool isPast;

  /// Đánh dấu ngày đang được chọn làm ngày nhận phòng (`checkIn`).
  final bool isSelectedStart;

  /// Đánh dấu ngày đang được chọn làm ngày trả phòng (`checkOut`).
  final bool isSelectedEnd;

  /// Đánh dấu ngày nằm giữa khoảng lưu trú đang chọn.
  final bool isInRange;

  /// Cho phép chọn ngày đã kín đêm làm mốc trả phòng hợp lệ theo quy ước nửa khoảng `[checkIn, checkOut)`.
  final bool isCheckoutCandidate;

  /// Hàm xử lý khi người dùng chạm chọn ô ngày hợp lệ.
  final VoidCallback? onTap;

  /// Giao diện con tùy chỉnh thay thế nhãn số ngày mặc định.
  final Widget? child;

  /// Khởi tạo ô ngày lịch có nhãn đọc màn hình an toàn quyền riêng tư.
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

  /// Tạo nhãn ngữ nghĩa đa ngôn ngữ an toàn thông tin cá nhân (PII-safe) cho một ô ngày trên lịch.
  ///
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
    // Giải thuật sinh nhãn ngữ nghĩa lịch đặt phòng bảo mật thông tin cá nhân (PII-safe):
    // - Nếu ngày đã kín phòng và KHÔNG phải là ứng viên trả phòng hợp lệ (isCheckoutCandidate == false),
    //   chỉ thông báo trạng thái chung "Ngày này đã kín", tuyệt đối không đọc tên đoàn hay mã đơn.
    // - Nếu là ứng viên trả phòng (ngày khách kế tiếp nhận phòng), vẫn cho phép đọc như ngày khả dụng
    //   hoặc ngày trả phòng đã chọn theo đúng mô hình nửa khoảng [checkIn, checkOut).
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

  /// Dựng ô ngày `48x48dp` với màu nền, gạch ngang và trạng thái tương tác đồng bộ ngữ nghĩa.
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
