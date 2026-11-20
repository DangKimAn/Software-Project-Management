import 'package:flutter/material.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_typography.dart';

/// Bộ token thiết kế phong cách Studio Minimalist dành riêng cho cổng Quản trị (bố cục thẻ Bento nổi trên nền sứ mờ, tách biệt hoàn toàn với token của Khách và Chủ nhà).
abstract final class AdminStudioTokens {
  // ── Surfaces & Frosted Layers ──
  /// Màu nền sứ lạnh giúp các thẻ trắng và khung kính mờ nổi bật rõ nét.
  static const Color canvas = Color(0xFFF2F4F7);

  /// Bề mặt khung gom nhóm bên ngoài cho từng phân khu chức năng.
  static const Color groupSurface = Color(0xFFF7F8FA);

  /// Màu phủ bán trong suốt khi kết hợp hiệu ứng làm mờ kính hoặc viền sáng trắng.
  static const Color groupGlassFill = Color(0xD9F8F9FB);

  /// Viền sáng trắng tạo hiệu ứng phản quang nhẹ cho khung nhóm Bento.
  static const Color groupBorder = Color(0xFFFFFFFF);

  /// Đường phân cách mảnh nhẹ giữa các bề mặt sáng mà không gây nặng nề.
  static const Color hairline = Color(0xFFECEEF2);

  /// Bề mặt thẻ con màu trắng tinh bên trong khung nhóm.
  static const Color cardSurface = Color(0xFFFFFFFF);

  /// Nền xám trung tính dịu cho huy hiệu tròn nhỏ, chữ viết tắt và ô nhập dạng viên thuốc.
  static const Color softCircle = Color(0xFFF3F4F7);

  /// Lớp phủ kính mờ cho thanh tiêu đề trên cùng và thanh điều hướng dưới đáy.
  static const Color frostedHeaderFill = Color(0xCCF2F4F7);
  static const Color frostedDockFill = Color(0xCFffffff);
  static const Color frostedDockBorder = Color(0xE6FFFFFF);

  // ── Studio Monochrome Ink Palette ──
  /// Màu mực đen tuyền chủ đạo cho nút chọn đang kích hoạt, con số KPI và nút hành động chính.
  static const Color obsidian = Color(0xFF141416);
  static const Color obsidianPressed = Color(0xFF27272A);

  /// Hệ phân cấp màu chữ tinh gọn có độ tương phản và khả năng đọc cao.
  static const Color inkPrimary = Color(0xFF141416);
  static const Color inkSecondary = Color(0xFF525866);
  static const Color inkMuted = Color(0xFF7B818F);
  static const Color inkSubtle = Color(0xFF9AA0AC);

  /// Hệ màu biểu tượng thanh mảnh theo mức độ ưu tiên thị giác.
  static const Color iconInk = Color(0xFF18181B);
  static const Color iconSecondary = Color(0xFF525866);
  static const Color iconMuted = Color(0xFF858B98);

  // ── Semantic Status (Soft Studio Tints) ──
  static const Color successInk = AppColors.success;
  static const Color successTint = Color(0xFFECFDF5);
  static const Color warningInk = AppColors.warning;
  static const Color warningTint = Color(0xFFFFFBEB);
  static const Color dangerInk = AppColors.error;
  static const Color dangerTint = Color(0xFFFFF1F2);

  // ── Radii ──
  static const double groupRadius = 28.0;
  static const double cardRadius = 22.0;
  static const double dockRadius = 30.0;
  static const double modalRadius = 30.0;
  static const double pillRadius = 999.0;

  // ── Blur Sigmas ──
  static const double dockBlurSigma = 24.0;
  static const double headerBlurSigma = 18.0;

  // ── Soft Ambient Shadows (Whisper-light, never heavy) ──
  static const List<BoxShadow> groupShadow = [
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> dockShadow = [
    BoxShadow(
      color: Color(0x100F172A),
      blurRadius: 28,
      offset: Offset(0, -4),
    ),
  ];

  // ── Typography (Sleek SF Pro weights — zero chunky w800) ──
  static const TextStyle headerEyebrow = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: inkMuted,
    height: 1.28,
  );

  static const TextStyle headerGreeting = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 19.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: inkPrimary,
    height: 1.22,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.28,
    color: inkPrimary,
    height: 1.3,
  );

  static const TextStyle kpiValue = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.65,
    color: inkPrimary,
    height: 1.15,
  );

  static const TextStyle kpiLabel = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: inkMuted,
    height: 1.35,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppTypography.primaryFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.22,
    color: inkPrimary,
    height: 1.32,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.04,
    color: inkMuted,
    height: 1.35,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: inkSecondary,
    height: 1.44,
  );

  static const TextStyle metaCaption = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.02,
    color: inkMuted,
    height: 1.35,
  );

  static const TextStyle pillText = TextStyle(
    fontFamily: AppTypography.textFontFamily,
    fontFamilyFallback: AppTypography.fontFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.08,
  );

  // ── Studio Button Styles ──
  static final ButtonStyle primaryPillButton = ElevatedButton.styleFrom(
    backgroundColor: obsidian,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFE4E6EB),
    disabledForegroundColor: inkSubtle,
    elevation: 0,
    shadowColor: Colors.transparent,
    minimumSize: const Size(48, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    textStyle: pillText.copyWith(fontSize: 13),
    shape: const StadiumBorder(),
  );

  static final ButtonStyle compactPrimaryPillButton = ElevatedButton.styleFrom(
    backgroundColor: obsidian,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFE4E6EB),
    disabledForegroundColor: inkSubtle,
    elevation: 0,
    shadowColor: Colors.transparent,
    minimumSize: const Size(48, 38),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    textStyle: pillText,
    shape: const StadiumBorder(),
  );

  static final ButtonStyle secondaryPillButton = OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: inkPrimary,
    disabledForegroundColor: inkSubtle,
    elevation: 0,
    minimumSize: const Size(48, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    side: const BorderSide(color: hairline, width: 1),
    textStyle: pillText.copyWith(fontSize: 13),
    shape: const StadiumBorder(),
  );

  static final ButtonStyle compactSecondaryPillButton =
      OutlinedButton.styleFrom(
    backgroundColor: softCircle,
    foregroundColor: inkPrimary,
    disabledForegroundColor: inkSubtle,
    elevation: 0,
    minimumSize: const Size(48, 38),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    side: BorderSide.none,
    textStyle: pillText,
    shape: const StadiumBorder(),
  );

  static final ButtonStyle compactIconActionButton = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? softCircle.withValues(alpha: 0.6)
          : softCircle,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? inkSubtle : iconInk,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? inkSubtle : iconInk,
    ),
    overlayColor: WidgetStatePropertyAll(obsidian.withValues(alpha: 0.05)),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    minimumSize: const WidgetStatePropertyAll(Size(38, 38)),
    fixedSize: const WidgetStatePropertyAll(Size(38, 38)),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: const WidgetStatePropertyAll(CircleBorder()),
  );

  static final ButtonStyle circlePagerButton = OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: inkPrimary,
    disabledForegroundColor: inkSubtle,
    minimumSize: const Size(44, 44),
    padding: EdgeInsets.zero,
    side: BorderSide.none,
    shape: const CircleBorder(),
  );

  /// Tạo trang trí ô tìm kiếm bo tròn dạng viên thuốc dùng chung trên cổng Quản trị.
  static InputDecoration searchPillDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: cardSubtitle.copyWith(color: inkSubtle, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(
        prefixIcon,
        size: 16,
        color: iconMuted,
      ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: 40,
        minHeight: 40,
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pillRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pillRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pillRadius),
        borderSide: const BorderSide(color: obsidian, width: 1.1),
      ),
    );
  }

  /// Tạo trang trí ô nhập văn bản nhiều dòng (lý do từ chối, ghi chú kiểm duyệt) có viền báo lỗi rõ ràng.
  static InputDecoration multilineDecoration({
    String? hintText,
    String? labelText,
    String? errorText,
  }) {
    final borderRadius = BorderRadius.circular(20);
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      errorText: errorText,
      hintStyle: cardSubtitle.copyWith(color: inkSubtle, fontSize: 13),
      labelStyle: cardSubtitle.copyWith(fontSize: 13),
      errorStyle: metaCaption.copyWith(
        color: dangerInk,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: softCircle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: obsidian, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: dangerInk, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: dangerInk, width: 1.2),
      ),
    );
  }
}
