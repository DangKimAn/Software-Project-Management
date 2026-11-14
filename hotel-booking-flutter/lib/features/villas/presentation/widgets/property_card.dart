import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/animations/animated_heart_button.dart';
import '../../../../shared/animations/pressable_scale.dart';
import '../../../../shared/widgets/price_display.dart';
import '../../../../shared/widgets/villa_badge.dart';
import '../../domain/entities/villa.dart';
import 'property_image_carousel.dart';
import 'property_specs_row.dart';

/// Thẻ hiển thị tóm tắt thông tin biệt thự theo phong cách tối giản sang trọng trên lưới tìm kiếm và trang chủ.
///
/// Bao gồm vòng quay ảnh tỷ lệ `4:3` tích hợp `Hero`, nút thả tim yêu thích, huy hiệu ưu tiên duy nhất,
/// điểm đánh giá, hàng thông số chuẩn thứ tự nghiệp vụ và khối hiển thị giá xác thực.
class PropertyCard extends StatelessWidget {
  /// Thực thể dữ liệu biệt thự cần hiển thị.
  final Villa villa;

  /// Hàm gọi lại khi người dùng chạm mở trang chi tiết biệt thự.
  final VoidCallback onTap;

  /// Cho biết biệt thự hiện tại có nằm trong danh sách yêu thích của người dùng hay không.
  final bool isFavorite;

  /// Hàm gọi lại khi người dùng bấm nút chuyển đổi trạng thái yêu thích.
  final VoidCallback? onFavoriteToggle;

  /// Khởi tạo thẻ biệt thự `PropertyCard`.
  const PropertyCard({
    super.key,
    required this.villa,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primaryBadge = villa.primaryBadge;

    return PressableScale(
      onTap: onTap,
      scaleDown: 0.98,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Carousel with Favorite Button
          Stack(
            children: [
              Hero(
                tag: 'villa_image_${villa.id}',
                child: PropertyImageCarousel(
                  imageUrls: villa.imageUrls,
                  aspectRatio: 4 / 3,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              ),

              // Top Right: Favorite heart button with pop animation
              Positioned(
                top: 10,
                right: 10,
                child: AnimatedHeartButton(
                  isFavorite: isFavorite,
                  onToggle: onFavoriteToggle,
                ),
              ),
            ],
          ),

          // Card Body Details (`StayCard.tsx` - Flat Minimal UI)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (primaryBadge != null) ...[
                  VillaBadge(badgeType: primaryBadge),
                  const SizedBox(height: 4),
                ],
                // Title + Address on left, Orange Star + Rating on right (no badge/frame)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            villa.name,
                            style: AppTypography.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.mapPin,
                                size: 13,
                                color: AppColors.iconMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  villa.address.isNotEmpty
                                      ? villa.address
                                      : villa.tagline,
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.star,
                          size: 14,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          villa.rating.toStringAsFixed(1),
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description / Tagline preview
                Text(
                  villa.tagline.isNotEmpty ? villa.tagline : villa.description,
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFF4B5563),
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Specifications Row in strict business order
                PropertySpecsRow(specs: villa.specs),

                const SizedBox(height: 12),

                // Giải thuật phân bố dòng giá và trạng thái thích ứng tỷ lệ phóng chữ (TextScaler):
                // Khi thẻ hẹp (< 260dp) hoặc phông chữ phóng to (scale >= 1.35), xếp dọc nhãn trạng thái
                // xuống dưới PriceDisplay để khối giá giữ trọn chiều rộng thẻ, tránh bị ép gãy nhiều dòng.
                LayoutBuilder(
                  builder: (context, priceConstraints) {
                    final scale = MediaQuery.textScalerOf(context).scale(1.0);
                    final stackVertically =
                        scale >= 1.35 || priceConstraints.maxWidth < 260;
                    final statusLabel = Text(
                      context.l10n.statusAvailable,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    );
                    if (stackVertically) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PriceDisplay(
                            basePriceVnd: villa.basePriceVnd,
                            saturdayPriceVnd: villa.saturdayPriceVnd,
                          ),
                          const SizedBox(height: 4),
                          statusLabel,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: PriceDisplay(
                            basePriceVnd: villa.basePriceVnd,
                            saturdayPriceVnd: villa.saturdayPriceVnd,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 0,
                          child: statusLabel,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
