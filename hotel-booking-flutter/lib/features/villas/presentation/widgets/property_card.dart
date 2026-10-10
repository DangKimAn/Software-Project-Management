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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: AppRadii.roundedCard,
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [AppColors.shadowSoft],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel with Badges & Favorite Button
            Stack(
              children: [
                Hero(
                  tag: 'villa_image_${villa.id}',
                  child: PropertyImageCarousel(
                    imageUrls: villa.imageUrls,
                    aspectRatio: 4 / 3,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.card),
                    ),
                  ),
                ),

                // Top Left: At most 1 primary badge (priority order)
                if (primaryBadge != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: VillaBadge(badgeType: primaryBadge),
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

            // Card Body Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Rating Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          villa.name,
                          style: AppTypography.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.star,
                            size: 15,
                            color: AppColors.starAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            villa.rating.toStringAsFixed(1),
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Tagline / Address preview
                  Text(
                    villa.tagline,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Specifications Row in strict business order
                  PropertySpecsRow(specs: villa.specs),

                  const SizedBox(height: 14),

                  const Divider(color: AppColors.borderSoft, height: 1),

                  const SizedBox(height: 12),

                  // Price Display
                  PriceDisplay(
                    basePriceVnd: villa.basePriceVnd,
                    saturdayPriceVnd: villa.saturdayPriceVnd,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
