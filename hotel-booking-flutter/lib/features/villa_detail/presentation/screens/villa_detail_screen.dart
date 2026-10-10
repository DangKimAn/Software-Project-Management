import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../shared/animations/animated_heart_button.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../villas/presentation/widgets/property_image_carousel.dart';
import '../widgets/booking_action_bar.dart';
import '../widgets/daily_price_breakdown.dart';
import '../widgets/mobile_spec_summary.dart';
import '../widgets/property_faq_section.dart';
import '../../../reviews/presentation/widgets/review_list_widget.dart';

class VillaDetailScreen extends ConsumerWidget {
  final String villaId;

  const VillaDetailScreen({super.key, required this.villaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final villaAsync = ref.watch(villaDetailProvider(villaId));
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.contains(villaId);

    return villaAsync.when(
      data: (villa) {
        if (villa == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorView(
              title: 'Không tìm thấy biệt thự',
              message:
                  'Biệt thự bạn tìm kiếm không tồn tại hoặc đã ngừng phục vụ.',
            ),
          );
        }

        // Query real nightly pricing from backend API for the upcoming 7 nights
        final today = BookingDate.today();
        final pricingParams = (
          villaId: villa.id,
          checkIn: today,
          checkOut: today.addDays(7),
        );
        final pricingAsync =
            ref.watch(villaNightlyPricingProvider(pricingParams));

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Custom Silver AppBar with Carousel
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.surfaceBase,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft,
                          size: 20, color: AppColors.textStrong),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: IconButton(
                        icon: const Icon(LucideIcons.share2,
                            size: 18, color: AppColors.textStrong),
                        tooltip: 'Sao chép liên kết biệt thự',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                                text:
                                    'https://minhthanhvilla.com/villas/${villa.id}'),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Đã sao chép liên kết vào bộ nhớ tạm'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: AnimatedHeartButton(
                      isFavorite: isFav,
                      onToggle: () {
                        ref
                            .read(favoritesProvider.notifier)
                            .toggleFavorite(villa.id);
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'villa_image_${villa.id}',
                    child: PropertyImageCarousel(
                      imageUrls: villa.imageUrls,
                      aspectRatio: 16 / 10,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),

              // Detail Body with smooth staggered entrance animation
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Villa Title & Code
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                villa.name,
                                style: AppTypography.displayMedium
                                    .copyWith(fontSize: 22),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                villa.code,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Address with icon
                        Row(
                          children: [
                            const Icon(LucideIcons.mapPin,
                                size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                villa.address,
                                style: AppTypography.bodyMuted,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 2-Tier Specification Summary (Rule 8.1)
                        MobileSpecSummary(specs: villa.specs),

                        const SizedBox(height: 20),

                        // Description
                        Text('Giới thiệu biệt thự',
                            style: AppTypography.sectionHeading
                                .copyWith(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          villa.description,
                          style: AppTypography.bodyLarge.copyWith(height: 1.6),
                        ),

                        const SizedBox(height: 24),

                        // Amenities List
                        if (villa.amenities.isNotEmpty) ...[
                          Text('Tiện nghi có sẵn',
                              style: AppTypography.sectionHeading
                                  .copyWith(fontSize: 18)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: villa.amenities.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: AppColors.borderSoft),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.check,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(item, style: AppTypography.bodyMedium),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Nightly Price Breakdown loaded from Real API (Constrained Box Height <= 220, Rule 10)
                        pricingAsync.when(
                          data: (prices) {
                            if (prices.isEmpty) return const SizedBox.shrink();
                            return DailyPriceBreakdown(nightlyPrices: prices);
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 24),

                        // Reviews Section (Rule 7 & 8)
                        ReviewListWidget(
                          listingId: villa.id,
                          averageRating: villa.rating,
                          totalReviews: villa.reviewCount,
                        ),

                        const SizedBox(height: 24),

                        // FAQ Section (Rule 8.2)
                        const PropertyFaqSection(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Action Bar with SafeArea (Rule 10 & 12)
          bottomNavigationBar: BookingActionBar(villa: villa),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const AppLoading(
            message: 'Đang tải thông tin chi tiết biệt thự...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(villaDetailProvider(villaId)),
        ),
      ),
    );
  }
}
