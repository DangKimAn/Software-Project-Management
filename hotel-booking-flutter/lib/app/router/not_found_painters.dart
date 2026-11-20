import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

/// Nền lưới kiến trúc tối giản phía sau thẻ 404 theo ngôn ngữ Light Luxury.
class NotFoundBackdropStage extends StatelessWidget {
  final Widget child;

  const NotFoundBackdropStage({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceWarmSand,
      child: CustomPaint(
        painter: const _ArchitecturalGridBackdropPainter(),
        child: child,
      ),
    );
  }
}

/// Biểu trưng la bàn định hướng kiến trúc ở đầu thẻ 404.
///
/// Đảm bảo icon đầu tiên trong cây widget luôn dùng `AppColors.iconMuted`
/// và đặt trong khung bo góc vuông mềm (không dùng vòng tròn màu bao quanh icon)
/// tuân thủ nghiêm ngặt `FLUTTER_RULES.md` Mục 6.
class NotFoundWayfindingEmblem extends StatelessWidget {
  final bool compact;

  const NotFoundWayfindingEmblem({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final outerSize = compact ? 80.0 : 92.0;
    final tileSize = compact ? 46.0 : 52.0;
    final iconSize = compact ? 22.0 : 24.0;

    return ExcludeSemantics(
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: CustomPaint(
          painter: const _WayfindingCompassDialPainter(),
          child: Center(
            child: Container(
              width: tileSize,
              height: tileSize,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarmSand,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Center(
                child: Icon(
                  LucideIcons.compass,
                  size: iconSize,
                  color: AppColors.iconMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Họa sĩ vẽ mặt chia độ la bàn cực bao quanh biểu trưng định hướng trang 404.
class _WayfindingCompassDialPainter extends CustomPainter {
  const _WayfindingCompassDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ mặt chia độ la bàn cực (Polar Coordinate Dial Geometry):
    // Chia vòng tròn ngoại tiếp thành 12 cung đều nhau (mỗi cung 30 độ = pi/6 rad).
    // Tại các góc chính Bắc/Đông/Nam/Tây (i % 3 == 0) vẽ vạch chia dài đậm hơn,
    // các góc phụ vẽ vạch mảnh và đánh dấu chấm Coral định vị hướng Bắc (12h).
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 2;

    final ringPaint = Paint()
      ..color = AppColors.borderSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, outerRadius, ringPaint);
    canvas.drawCircle(center, outerRadius * 0.78, ringPaint);

    final majorTickPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final minorTickPaint = Paint()
      ..color = AppColors.borderSoft
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + (i * math.pi / 6);
      final isCardinal = i % 3 == 0;
      if (i == 0) continue; // Nhường vị trí 12h cho điểm định vị Coral
      final tickLen = isCardinal ? 6.0 : 3.5;
      final p1 = Offset(
        center.dx + (outerRadius - tickLen) * math.cos(angle),
        center.dy + (outerRadius - tickLen) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, isCardinal ? majorTickPaint : minorTickPaint);
    }

    final northDotCenter = Offset(center.dx, center.dy - outerRadius);
    final northDotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(northDotCenter, 2.6, northDotPaint);
  }

  @override
  bool shouldRepaint(covariant _WayfindingCompassDialPainter oldDelegate) =>
      false;
}

/// Họa sĩ vẽ lưới tọa độ vòng tròn đồng tâm mảnh phía sau trang 404.
class _ArchitecturalGridBackdropPainter extends CustomPainter {
  const _ArchitecturalGridBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật dựng lưới tọa độ nền tinh tế (Viewport-Adaptive Hairline Grid):
    // Vẽ hai vòng đồng tâm lớn quanh tâm khung nhìn kết hợp đường trục mảnh,
    // tạo chiều sâu không gian trên màn hình rộng mà không gây nhiễu thị giác.
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    if (shortest <= 0) return;

    final linePaint = Paint()
      ..color = AppColors.borderSoft.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, shortest * 0.42, linePaint);
    canvas.drawCircle(center, shortest * 0.62, linePaint);

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchitecturalGridBackdropPainter oldDelegate) =>
      false;
}
