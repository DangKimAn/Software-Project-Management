import 'package:flutter/widgets.dart';
import '../../../villas/domain/entities/villa.dart';

/// Tính toán chiều cao khung cuộn ngang cho dải thẻ biệt thự tương tự thích ứng theo `TextScaler` và cấu trúc thẻ.
///
/// Kết hợp chiều cao cố định của ảnh tỷ lệ `4:3` (`225px`) với phần thân chữ đã nhân hệ số phóng to
/// của hệ điều hành và khoản bù dòng `Wrap` cho hàng thông số, ngăn chặn triệt để lỗi tràn khung đáy.
// Giải thuật tính chiều cao linh hoạt cho dải thẻ biệt thự tương tự theo tỷ lệ phóng chữ (`TextScaler`):
// Giữ nguyên chiều cao ảnh tỷ lệ 4:3 (`300 * 3 / 4 = 225px`) và co giãn vùng văn bản + dòng thông số `Wrap`
// theo `MediaQuery.textScalerOf(context)` để ở `1.0x` đạt ~`372px` (hoặc cao hơn khi có huy hiệu/giá cuối tuần)
// và ở `1.3x–2.0x` mở rộng đủ chỗ cho `PropertyCard`, triệt tiêu hoàn toàn lỗi tràn đáy (Bottom Overflow).
double computeSimilarVillasCarouselHeight(
  BuildContext context,
  List<Villa> recs,
) {
  final textScaler = MediaQuery.textScalerOf(context);
  final scale = textScaler.scale(1.0).clamp(1.0, 2.5);
  const imageHeight = 225.0;
  final hasBadge = recs.any((v) => v.primaryBadge != null);
  final hasWeekendPrice = recs.any(
    (v) =>
        v.saturdayPriceVnd != null &&
        v.basePriceVnd != null &&
        v.saturdayPriceVnd! > v.basePriceVnd!,
  );
  final maxSpecItems = recs.fold<int>(0, (prev, v) {
    var count = 0;
    if (v.specs.bedrooms > 0) count++;
    if (v.specs.beds > 0) count++;
    if (v.specs.maxGuests > 0) count++;
    if (v.specs.bathrooms > 0) count++;
    if (v.specs.beachDistanceMeters != null &&
        v.specs.beachDistanceMeters! > 0) {
      count++;
    }
    return count > prev ? count : prev;
  });

  final baseTextPortion = 148.0 +
      (hasBadge ? 28.0 : 0.0) +
      (hasWeekendPrice ? 26.0 : 0.0) +
      (maxSpecItems >= 5 ? 26.0 : 0.0);
  final stackedStatusAllowance = scale >= 1.35 ? textScaler.scale(22.0) : 0.0;
  final extraWrapAllowance = scale > 1.0
      ? (scale - 1.0) *
          (54.0 * maxSpecItems.clamp(3, 5) + (hasWeekendPrice ? 36.0 : 16.0))
      : 0.0;

  return imageHeight +
      textScaler.scale(baseTextPortion) +
      stackedStatusAllowance +
      extraWrapAllowance;
}
