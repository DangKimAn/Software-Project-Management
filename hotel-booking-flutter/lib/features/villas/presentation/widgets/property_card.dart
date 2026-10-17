import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/animations/animated_heart_button.dart';
import '../../../../shared/animations/pressable_scale.dart';
import '../../../../shared/widgets/price_display.dart';
import '../../../../shared/widgets/villa_badge.dart';
import '../../domain/entities/villa.dart';
import 'property_image_carousel.dart';
import 'property_specs_row.dart';

class PropertyCard extends StatelessWidget {
  final Villa villa;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

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

                // Price Display + "Còn trống" text (no pill/frame)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: PriceDisplay(
                        basePriceVnd: villa.basePriceVnd,
                        saturdayPriceVnd: villa.saturdayPriceVnd,
                      ),
                    ),
                    const Text(
                      'Còn trống',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0891B2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
