import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';

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

/// Monochrome neutral stroke brand icons for The Palm Villa, Google, TikTok,
/// Threads, YouTube, Facebook, and Instagram.
class AppBrandIcon extends StatelessWidget {
  final _BrandType _type;
  final double size;
  final Color color;

  /// The Palm Villa architectural crest mark (`logo_mau.svg`) rendered in
  /// clean monochrome stroke.
  const AppBrandIcon.minhThanhLogo({
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
      case _BrandType.minhThanhLogo:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _MinhThanhLogoStrokePainter(color: color),
          ),
        );
    }
  }
}

enum _BrandType {
  minhThanhLogo,
  google,
  tiktok,
  threads,
  youtube,
  facebook,
  instagram,
}

class _YouTubeStrokePainter extends CustomPainter {
  final Color color;

  const _YouTubeStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
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

class _FacebookStrokePainter extends CustomPainter {
  final Color color;

  const _FacebookStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
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

class _InstagramStrokePainter extends CustomPainter {
  final Color color;

  const _InstagramStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
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

class _GoogleGStrokePainter extends CustomPainter {
  final Color color;

  const _GoogleGStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
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

class _TikTokStrokePainter extends CustomPainter {
  final Color color;

  const _TikTokStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
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

class _MinhThanhLogoStrokePainter extends CustomPainter {
  final Color color;

  const _MinhThanhLogoStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(1.75, size.width * 0.085);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Outer circular wave crest from `logo_mau.svg`
    final rect = Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84);
    canvas.drawArc(rect, -0.35 * math.pi, 1.55 * math.pi, false, paint);

    // Inner villa roof + pillars silhouette from `logo_mau.svg`
    final roof = Path()
      ..moveTo(w * 0.22, h * 0.54)
      ..lineTo(w * 0.50, h * 0.32)
      ..lineTo(w * 0.78, h * 0.54)
      ..moveTo(w * 0.32, h * 0.50)
      ..lineTo(w * 0.32, h * 0.76)
      ..moveTo(w * 0.50, h * 0.46)
      ..lineTo(w * 0.50, h * 0.78)
      ..moveTo(w * 0.68, h * 0.50)
      ..lineTo(w * 0.68, h * 0.76);
    canvas.drawPath(roof, paint);
  }

  @override
  bool shouldRepaint(covariant _MinhThanhLogoStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}
