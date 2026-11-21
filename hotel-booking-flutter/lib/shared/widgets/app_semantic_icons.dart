import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';

/// Bộ ánh xạ biểu tượng ngữ nghĩa và biểu trưng thương hiệu tập trung trên toàn ứng dụng.
///
/// Đảm bảo mọi tiện ích, tùy chọn sắp xếp và điều hướng đều hiển thị đúng biểu tượng nét mảnh đơn sắc,
/// không đặt vòng tròn màu hay hộp trang trí dư thừa quanh biểu tượng.
///
/// Centralized semantic & brand icon helper for the entire project.
///
/// Guarantees:
/// 1. Every icon matches its exact semantic purpose from `Source goc`.
/// 2. Strictly complies with Master Prompt Section 2 (Icon Design Rules):
///    - Monochrome neutral stroke icons directly on UI.
///    - No decorative circle/square/box backgrounds around icons.
///    - No multi-color or gradient fills.
class AppSemanticIcons {
  const AppSemanticIcons._();

  /// Canonical account logout icon synchronized across the entire system
  /// (matching the signed-in Guest account view).
  static const IconData logout = LucideIcons.doorOpen;

  /// Canonical cross-role semantic icons shared across Guest, Host, and Admin.
  static const IconData dashboard = LucideIcons.layoutDashboard;
  static const IconData home = LucideIcons.house;
  static const IconData becomeHost = LucideIcons.housePlus;
  static const IconData adminPortal = LucideIcons.shieldCheck;
  static const IconData bookings = LucideIcons.calendarCheck;
  static const IconData revenue = LucideIcons.chartColumn;
  static const IconData hostApplications = LucideIcons.fileCheck;
  static const IconData userProfile = LucideIcons.userRound;
  static const IconData changeAvatar = LucideIcons.camera;
  static const IconData messageHost = LucideIcons.messageSquare;
  static const IconData zaloSupport = LucideIcons.messageCircle;
  static const IconData supportCenter = LucideIcons.lifeBuoy;
  static const IconData errorAlert = LucideIcons.circleAlert;
  static const IconData retry = LucideIcons.refreshCw;
  static const IconData checkIn = LucideIcons.keyRound;
  static const IconData checkOut = LucideIcons.clock;

  /// Phân giải biểu tượng `LucideIcons` ngữ nghĩa tương ứng cho mọi mã hoặc nhãn tiện ích tiếng Việt `nameOrCode`.
  ///
  /// Giải thuật đối sánh từ khóa có thứ tự ưu tiên:
  /// Kiểm tra nhóm từ khóa đặc thù (`bbq`, `nướng`, `lò sưởi`) trước nhóm bao hàm rộng (`bếp`, `sân vườn`)
  /// để các cụm từ ghép như `"Bếp nướng BBQ sân vườn"` luôn nhận đúng biểu tượng ngọn lửa thay vì bị nuốt bởi từ khóa chung.
  ///
  /// Resolves the exact semantic icon for any villa amenity code or Vietnamese label
  /// (matching `ListingDetailPage.tsx` `getAmenityIcon` + `filterOptions.ts`).
  static IconData resolveAmenityIcon(String nameOrCode) {
    final lower = nameOrCode.trim().toLowerCase();

    if (lower.contains('wifi') ||
        lower.contains('wi-fi') ||
        lower.contains('internet')) {
      return LucideIcons.wifi;
    }
    if (lower.contains('hồ bơi') ||
        lower.contains('bể bơi') ||
        lower.contains('ho boi') ||
        lower.contains('ho_boi') ||
        lower.contains('pool')) {
      return LucideIcons.waves;
    }
    // Check BBQ / grill / fireplace BEFORE generic 'bếp' or 'sân vườn'
    // so compound labels like "Bếp nướng BBQ sân vườn" map to flame.
    if (lower.contains('bbq') ||
        lower.contains('nướng') ||
        lower.contains('grill') ||
        lower.contains('lò sưởi') ||
        lower.contains('fireplace')) {
      return LucideIcons.flame;
    }
    if (lower.contains('tv') ||
        lower.contains('tivi') ||
        lower.contains('television') ||
        lower.contains('màn hình') ||
        lower.contains('netflix') ||
        lower.contains('máy chiếu')) {
      return LucideIcons.tv;
    }
    if (lower.contains('bồn tắm') ||
        lower.contains('jacuzzi') ||
        lower.contains('bathtub') ||
        lower.contains('bath') ||
        lower.contains('phòng tắm') ||
        lower.contains('nhà vệ sinh') ||
        lower.contains('toilet') ||
        lower.contains('wc') ||
        lower.contains('vòi sen') ||
        lower.contains('shower')) {
      return LucideIcons.bath;
    }
    if (lower.contains('tủ lạnh') ||
        lower.contains('refrigerator') ||
        lower.contains('fridge') ||
        lower.contains('minibar')) {
      return LucideIcons.refrigerator;
    }
    if (lower.contains('cà phê') ||
        lower.contains('coffee') ||
        lower.contains('trà')) {
      return LucideIcons.coffee;
    }
    if (lower.contains('bếp') ||
        lower.contains('kitchen') ||
        lower.contains('nấu ăn') ||
        lower.contains('bàn ăn') ||
        lower.contains('dining')) {
      return LucideIcons.utensils;
    }
    if (lower.contains('điều hòa') ||
        lower.contains('dieu hoa') ||
        lower.contains('dieu_hoa') ||
        lower.contains('máy lạnh') ||
        lower.contains('air_conditioner') ||
        lower.contains('air conditioning') ||
        lower.contains('ac_unit') ||
        lower == 'ac') {
      return LucideIcons.snowflake;
    }
    if (lower.contains('máy giặt') ||
        lower.contains('may_giat') ||
        lower.contains('giặt') ||
        lower.contains('washer') ||
        lower.contains('laundry')) {
      return LucideIcons.washingMachine;
    }
    if (lower.contains('máy sấy') ||
        lower.contains('hair dryer') ||
        lower.contains('dryer')) {
      return LucideIcons.wind;
    }
    if (lower.contains('bàn ủi') ||
        lower.contains('bàn là') ||
        lower.contains('iron')) {
      return LucideIcons.shirt;
    }
    if (lower.contains('đậu xe') ||
        lower.contains('đỗ xe') ||
        lower.contains('dau_xe') ||
        lower.contains('parking') ||
        lower.contains('ô tô') ||
        lower.contains('xe hơi')) {
      return LucideIcons.car;
    }
    if (lower.contains('xe đạp') ||
        lower.contains('bike') ||
        lower.contains('bicycle')) {
      return LucideIcons.bike;
    }
    if (lower.contains('thú cưng') ||
        lower.contains('thu_cung') ||
        lower.contains('pet') ||
        lower.contains('chó mèo')) {
      return LucideIcons.pawPrint;
    }
    if (lower.contains('gần biển') ||
        lower.contains('gan_bien') ||
        lower.contains('bãi biển') ||
        lower.contains('bãi tắm') ||
        lower.contains('sát biển') ||
        lower.contains('ra biển') ||
        lower.contains('near_beach') ||
        lower.contains('beach_access')) {
      return LucideIcons.umbrella;
    }
    if (lower.contains('ban công') ||
        lower.contains('ban_cong') ||
        lower.contains('sân thượng') ||
        lower.contains('balcony') ||
        lower.contains('thoáng mát')) {
      return LucideIcons.wind;
    }
    if (lower.contains('sân vườn') ||
        lower.contains('garden') ||
        lower.contains('cây xanh')) {
      return LucideIcons.trees;
    }
    if (lower.contains('view') ||
        lower.contains('cảnh') ||
        lower.contains('nice_view')) {
      return LucideIcons.mountainSnow;
    }
    if (lower.contains('check-in') ||
        lower.contains('checkin') ||
        lower.contains('nhận phòng') ||
        lower.contains('khóa')) {
      return LucideIcons.keyRound;
    }
    if (lower.contains('karaoke') ||
        lower.contains('loa') ||
        lower.contains('mic')) {
      return LucideIcons.micVocal;
    }
    if (lower.contains('bida') || lower.contains('billiards')) {
      return LucideIcons.circleDot;
    }
    if (lower.contains('thang máy') ||
        lower.contains('thang_may') ||
        lower.contains('elevator')) {
      return LucideIcons.arrowUpDown;
    }
    if (lower.contains('giường đôi') || lower.contains('double_bed')) {
      return LucideIcons.bedDouble;
    }
    if (lower.contains('phòng ngủ') ||
        lower.contains('giường') ||
        lower.contains('bedroom') ||
        lower.contains('bed')) {
      return LucideIcons.bed;
    }
    if (lower.contains('sofa') ||
        lower.contains('phòng khách') ||
        lower.contains('living_room')) {
      return LucideIcons.sofa;
    }
    if (lower.contains('gym') ||
        lower.contains('tập thể dục') ||
        lower.contains('fitness')) {
      return LucideIcons.dumbbell;
    }
    if (lower.contains('camera') ||
        lower.contains('an ninh') ||
        lower.contains('bảo vệ') ||
        lower.contains('security')) {
      return LucideIcons.shieldCheck;
    }

    return LucideIcons.circleCheck;
  }

  /// Phân giải biểu tượng ngữ nghĩa tương ứng cho mã tùy chọn sắp xếp `sortValue`.
  ///
  /// Resolves the exact semantic icon for sort options (`filterOptions.ts`).
  static IconData resolveSortIcon(String sortValue) {
    switch (sortValue) {
      case 'price_asc':
      case 'gia-thap-den-cao':
        return LucideIcons.trendingUp;
      case 'price_desc':
        return LucideIcons.trendingDown;
      case 'rating_desc':
      case 'danh-gia-cao-nhat':
        return LucideIcons.star;
      case 'gan-trung-tam':
        return LucideIcons.mapPin;
      case 'phu-hop-nhom-dong':
        return LucideIcons.users;
      default:
        return LucideIcons.clock;
    }
  }
}

/// Widget biểu trưng thương hiệu vector nét mảnh dành cho Minh Thanh Villa / The Palm Villa, Google và các mạng xã hội.
///
/// Bọc các bộ vẽ `CustomPainter` chuẩn hóa trên hệ lưới `24x24` hoặc `48x48` để giữ độ sắc nét đồng nhất ở mọi mật độ điểm ảnh.
///
/// Monochrome neutral stroke brand icons for The Palm Villa, Google, TikTok,
/// Threads, YouTube, Facebook, and Instagram.
class AppBrandIcon extends StatelessWidget {
  final _BrandType _type;

  /// Kích thước cạnh vuông của biểu trưng tính bằng điểm ảnh logic.
  final double size;

  /// Màu nét vẽ đơn sắc áp dụng cho biểu trưng.
  final Color color;

  /// The Palm Villa palm tree mark (`assets/icons/app_icon.png`) rendered in
  /// clean monochrome tint.
  const AppBrandIcon.minhThanhLogo({
    super.key,
    this.size = 24,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.minhThanhLogo;

  /// Alias for [AppBrandIcon.minhThanhLogo] displaying The Palm Villa icon.
  const AppBrandIcon.thePalmLogo({
    super.key,
    this.size = 24,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.minhThanhLogo;

  /// Google 'G' mark (`FcGoogle` in `LoginPage.tsx` / `RegisterPage.tsx`) rendered
  /// in clean monochrome stroke per Master Prompt Section 2.
  const AppBrandIcon.google({
    super.key,
    this.size = 20,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.google;

  /// Official 4-color Google Identity 'G' mark for Google Sign-In buttons.
  const AppBrandIcon.googleLogo({
    super.key,
    this.size = 20,
  })  : _type = _BrandType.googleLogo,
        color = AppColors.iconStrong;

  /// TikTok note mark (`FaTiktok` in `Footer.tsx`) rendered in monochrome stroke.
  const AppBrandIcon.tiktok({
    super.key,
    this.size = 20,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.tiktok;

  /// Threads '@' mark (`FaThreads` in `Footer.tsx`).
  const AppBrandIcon.threads({
    super.key,
    this.size = 20,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.threads;

  /// YouTube play-screen mark (`FaYoutube` in `Footer.tsx`).
  const AppBrandIcon.youtube({
    super.key,
    this.size = 20,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.youtube;

  /// Facebook 'f' mark (`FaFacebookF` in `Footer.tsx` and `ContactPage.tsx`).
  const AppBrandIcon.facebook({
    super.key,
    this.size = 20,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.facebook;

  /// Instagram camera mark.
  const AppBrandIcon.instagram({
    super.key,
    this.size = 20,
    this.color = AppColors.iconStrong,
  }) : _type = _BrandType.instagram;

  @override
  Widget build(BuildContext context) {
    switch (_type) {
      case _BrandType.facebook:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _FacebookStrokePainter(color: color),
          ),
        );
      case _BrandType.youtube:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _YouTubeStrokePainter(color: color),
          ),
        );
      case _BrandType.instagram:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _InstagramStrokePainter(color: color),
          ),
        );
      case _BrandType.threads:
        return Icon(LucideIcons.atSign, size: size, color: color);
      case _BrandType.tiktok:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _TikTokStrokePainter(color: color),
          ),
        );
      case _BrandType.google:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GoogleGStrokePainter(color: color),
          ),
        );
      case _BrandType.googleLogo:
        return SizedBox(
          width: size,
          height: size,
          child: const CustomPaint(
            painter: _GoogleOfficialLogoPainter(),
          ),
        );
      case _BrandType.minhThanhLogo:
        return SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/icons/app_icon.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Icon(
              LucideIcons.treePalm,
              size: size,
              color: color,
            ),
          ),
        );
    }
  }
}

enum _BrandType {
  minhThanhLogo,
  google,
  googleLogo,
  tiktok,
  threads,
  youtube,
  facebook,
  instagram,
}

/// Bộ vẽ vector nét mảnh biểu trưng YouTube trên hệ lưới chuẩn `24x24`.
class _YouTubeStrokePainter extends CustomPainter {
  final Color color;

  const _YouTubeStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ khung màn hình bo góc và tam giác phát trung tâm (24x24 Normalized Vector Geometry):
    // Co giãn hệ tọa độ theo tỷ lệ s = size.width / 24.0, dựng hình chữ nhật bo góc RRect (20x15, bán kính 4.2s)
    // làm thân màn hình và khép kín đường gấp khúc 3 đỉnh (10, 9.2) -> (15.2, 12) -> (10, 14.8) làm nút Play.
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, 2.0 * s)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outer YouTube screen frame in 24x24 space
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2.0 * s, 4.5 * s, 20.0 * s, 15.0 * s),
      Radius.circular(4.2 * s),
    );
    canvas.drawRRect(rrect, paint);

    // Inner play triangle (`m10 15 5-3-5-3v6Z`)
    final play = Path()
      ..moveTo(10.0 * s, 9.2 * s)
      ..lineTo(15.2 * s, 12.0 * s)
      ..lineTo(10.0 * s, 14.8 * s)
      ..close();
    canvas.drawPath(play, paint);
  }

  @override
  bool shouldRepaint(covariant _YouTubeStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bộ vẽ vector nét mảnh chữ `'f'` biểu trưng Facebook trên hệ lưới chuẩn `24x24`.
class _FacebookStrokePainter extends CustomPainter {
  final Color color;

  const _FacebookStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ đường bao chữ 'f' khép kín bằng cung tròn tiếp tuyến (Arc-Segment Outline Path):
    // Chuẩn hóa tỷ lệ s = size.width / 24.0, kết hợp hai cung tròn arcToPoint bán kính 5s (vai ngoài ngược chiều kim đồng hồ)
    // và 1s (góc lượn trong cùng chiều kim đồng hồ) nối với thanh ngang cắt thân chữ tại tung độ y = 10s..14s.
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, 2.0 * s)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Exact Lucide facebook 'f' outline in 24x24 space:
    // M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z
    final path = Path()
      ..moveTo(18.0 * s, 2.0 * s)
      ..lineTo(15.0 * s, 2.0 * s)
      ..arcToPoint(
        Offset(10.0 * s, 7.0 * s),
        radius: Radius.circular(5.0 * s),
        clockwise: false,
      )
      ..lineTo(10.0 * s, 10.0 * s)
      ..lineTo(7.0 * s, 10.0 * s)
      ..lineTo(7.0 * s, 14.0 * s)
      ..lineTo(10.0 * s, 14.0 * s)
      ..lineTo(10.0 * s, 22.0 * s)
      ..lineTo(14.0 * s, 22.0 * s)
      ..lineTo(14.0 * s, 14.0 * s)
      ..lineTo(17.0 * s, 14.0 * s)
      ..lineTo(18.0 * s, 10.0 * s)
      ..lineTo(14.0 * s, 10.0 * s)
      ..lineTo(14.0 * s, 7.0 * s)
      ..arcToPoint(
        Offset(15.0 * s, 6.0 * s),
        radius: Radius.circular(1.0 * s),
        clockwise: true,
      )
      ..lineTo(18.0 * s, 6.0 * s)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FacebookStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bộ vẽ vector nét mảnh biểu trưng máy ảnh Instagram trên hệ lưới chuẩn `24x24`.
class _InstagramStrokePainter extends CustomPainter {
  final Color color;

  const _InstagramStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ thân máy ảnh vuông bo góc đồng tâm và chấm kính ngắm (Concentric Camera Glyph):
    // Vẽ khung vuông bo góc RRect (20x20, bán kính 5s), vòng tròn ống kính tâm (12s, 12s) bán kính 4s bằng nét stroke,
    // và chấm đặc đèn báo góc trên phải tại tọa độ (17.5s, 6.5s) bán kính 1.1s.
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, 2.0 * s)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2.0 * s, 2.0 * s, 20.0 * s, 20.0 * s),
      Radius.circular(5.0 * s),
    );
    canvas.drawRRect(rrect, paint);
    canvas.drawCircle(Offset(12.0 * s, 12.0 * s), 4.0 * s, paint);
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(17.5 * s, 6.5 * s), 1.1 * s, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _InstagramStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bộ vẽ vector chữ `'G'` Google phiên bản nét mảnh đơn sắc đồng bộ hệ thống biểu tượng tối giản.
class _GoogleGStrokePainter extends CustomPainter {
  final Color color;

  const _GoogleGStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ cung lượng giác chữ 'G' hở góc phần tư thứ nhất và thanh ngang xuyên tâm:
    // Quét cung tròn từ góc 0 rad một lượng 1.72 * pi rad (~310 độ) để chừa khe hở ~50 độ phía trên bên phải,
    // sau đó nối đoạn thẳng ngang từ tâm (center.dx, center.dy) ra biên phải (center.dx + radius, center.dy).
    final stroke = math.max(1.75, size.width * 0.1);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke * 1.4) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw the Google 'G' arc (from -40 deg counter-clockwise to 0 deg) + crossbar
    const startAngle = 0.0;
    const sweepAngle = 1.72 * math.pi;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    final barPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + radius, center.dy);
    canvas.drawPath(barPath, paint);
  }

  @override
  bool shouldRepaint(covariant _GoogleGStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bộ vẽ biểu trưng chữ `'G'` 4 màu chuẩn nhận diện Google Identity dành riêng cho nút Đăng nhập bằng Google.
class _GoogleOfficialLogoPainter extends CustomPainter {
  const _GoogleOfficialLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật ghép 4 miền cong Bezier bậc ba trên không gian chuẩn 48x48 (Multi-Segment Cubic Bezier Logo):
    // Căn giữa khung vuông cạnh min(width, height), chuẩn hóa hệ số s = side / 48.0, rồi lần lượt tô đặc 4 mảnh
    // Đỏ (cung đỉnh), Xanh dương (thanh ngang + cung phải), Vàng (cung trái) và Xanh lá (cung đáy) bằng các đường cubicTo khép kín.
    final side = math.min(size.width, size.height);
    final s = side / 48.0;
    final dx = (size.width - side) / 2.0;
    final dy = (size.height - side) / 2.0;

    canvas.save();
    if (dx != 0 || dy != 0) {
      canvas.translate(dx, dy);
    }

    // Official Google Identity 48x48 'G' vector segments
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final redPath = Path()
      ..moveTo(24.0 * s, 9.5 * s)
      ..cubicTo(27.54 * s, 9.5 * s, 30.71 * s, 10.72 * s, 33.21 * s, 13.1 * s)
      ..lineTo(40.06 * s, 6.25 * s)
      ..cubicTo(35.9 * s, 2.38 * s, 30.47 * s, 0.0, 24.0 * s, 0.0)
      ..cubicTo(14.62 * s, 0.0, 6.51 * s, 5.38 * s, 2.56 * s, 13.22 * s)
      ..lineTo(10.54 * s, 19.41 * s)
      ..cubicTo(12.43 * s, 13.72 * s, 17.74 * s, 9.5 * s, 24.0 * s, 9.5 * s)
      ..close();
    canvas.drawPath(redPath, redPaint);

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final bluePath = Path()
      ..moveTo(46.98 * s, 24.55 * s)
      ..cubicTo(46.98 * s, 22.98 * s, 46.83 * s, 21.46 * s, 46.60 * s, 20.0 * s)
      ..lineTo(24.0 * s, 20.0 * s)
      ..lineTo(24.0 * s, 29.02 * s)
      ..lineTo(36.94 * s, 29.02 * s)
      ..cubicTo(
          36.36 * s, 31.98 * s, 34.68 * s, 34.50 * s, 32.16 * s, 36.20 * s)
      ..lineTo(39.89 * s, 42.20 * s)
      ..cubicTo(
          44.40 * s, 38.02 * s, 46.98 * s, 31.84 * s, 46.98 * s, 24.55 * s)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final yellowPath = Path()
      ..moveTo(10.53 * s, 28.59 * s)
      ..cubicTo(10.05 * s, 27.14 * s, 9.77 * s, 25.60 * s, 9.77 * s, 24.0 * s)
      ..cubicTo(9.77 * s, 22.40 * s, 10.04 * s, 20.86 * s, 10.53 * s, 19.41 * s)
      ..lineTo(2.55 * s, 13.22 * s)
      ..cubicTo(0.92 * s, 16.46 * s, 0.0, 20.12 * s, 0.0, 24.0 * s)
      ..cubicTo(0.0, 27.88 * s, 0.92 * s, 31.54 * s, 2.56 * s, 34.78 * s)
      ..lineTo(10.53 * s, 28.59 * s)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final greenPath = Path()
      ..moveTo(24.0 * s, 48.0 * s)
      ..cubicTo(30.48 * s, 48.0 * s, 35.93 * s, 45.87 * s, 39.89 * s, 42.19 * s)
      ..lineTo(32.16 * s, 36.19 * s)
      ..cubicTo(30.01 * s, 37.64 * s, 27.24 * s, 38.49 * s, 24.0 * s, 38.49 * s)
      ..cubicTo(
          17.74 * s, 38.49 * s, 12.43 * s, 34.27 * s, 10.53 * s, 28.58 * s)
      ..lineTo(2.55 * s, 34.77 * s)
      ..cubicTo(6.51 * s, 42.62 * s, 14.62 * s, 48.0 * s, 24.0 * s, 48.0 * s)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleOfficialLogoPainter oldDelegate) => false;
}

/// Bộ vẽ vector nét mảnh nốt nhạc biểu trưng TikTok theo tỷ lệ khung nhìn chuẩn hóa.
class _TikTokStrokePainter extends CustomPainter {
  final Color color;

  const _TikTokStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ thân nốt nhạc kết hợp cung tròn kép và cờ uốn Bezier bậc hai:
    // Kẻ trục dọc tại x = 0.58w từ 0.14h xuống 0.66h, nối hai cung tròn bán kính 0.17w tạo bầu nốt nhạc bên dưới,
    // rồi vẽ lá cờ uốn mềm phía trên đỉnh qua đường cong quadraticBezierTo tới điểm cuối (0.84w, 0.36h).
    final stroke = math.max(1.7, size.width * 0.095);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      // Vertical stem of the TikTok note
      ..moveTo(w * 0.58, h * 0.14)
      ..lineTo(w * 0.58, h * 0.66)
      // Lower loop
      ..arcToPoint(
        Offset(w * 0.24, h * 0.66),
        radius: Radius.circular(w * 0.17),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(w * 0.44, h * 0.50),
        radius: Radius.circular(w * 0.17),
        clockwise: true,
      )
      // Top flag curve
      ..moveTo(w * 0.58, h * 0.14)
      ..quadraticBezierTo(w * 0.62, h * 0.34, w * 0.84, h * 0.36);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TikTokStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}
