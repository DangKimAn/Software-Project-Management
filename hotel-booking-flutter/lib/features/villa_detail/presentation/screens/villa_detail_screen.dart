import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/animations/animated_heart_button.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../reviews/presentation/widgets/review_list_widget.dart';
import '../../../search/presentation/widgets/booking_date_range_picker.dart';
import '../../../trips/presentation/view_models/trips_view_model.dart';
import '../../../villas/domain/entities/villa.dart';
import '../../../villas/presentation/widgets/property_card.dart';
import '../../../villas/presentation/widgets/property_image_carousel.dart';
import '../widgets/booking_action_bar.dart';
import '../widgets/daily_price_breakdown.dart';
import '../widgets/mobile_spec_summary.dart';
import '../widgets/property_faq_section.dart';
import '../widgets/villa_description_section.dart';

/// Complete port of `Source goc/frontend/src/views/pages/ListingDetail/ListingDetailPage.tsx`.
class VillaDetailScreen extends ConsumerStatefulWidget {
  final String villaId;

  const VillaDetailScreen({super.key, required this.villaId});

  @override
  ConsumerState<VillaDetailScreen> createState() => _VillaDetailScreenState();
}

class _VillaDetailScreenState extends ConsumerState<VillaDetailScreen> {
  BookingDate? _checkIn;
  BookingDate? _checkOut;
  int _guestsCount = 2;
  final TextEditingController _couponCtrl = TextEditingController();
  final TextEditingController _specialRequestsCtrl = TextEditingController();
  int _couponDiscountVnd = 0;
  String? _appliedCouponCode;
  String? _couponMessage;
  bool _isValidatingCoupon = false;
  bool _isSubmittingBooking = false;
  String? _recordedVillaId;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(villaFilterProvider);
    final today = BookingDate.todayVn();
    _checkIn = filter.checkIn ?? today.addDays(1);
    _checkOut = filter.checkOut ?? today.addDays(3);
    if (filter.effectiveGuests > 0) {
      _guestsCount = filter.effectiveGuests;
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  int _calculateNights() =>
      VillaDetailPricingCalculator.calculateNights(_checkIn, _checkOut);

  ({
    int nights,
    int weekendNights,
    int roomSubtotal,
    int extraGuestTotal,
    int cleaningFee,
    int serviceFee,
    int discount,
    int finalTotal,
  }) _calculatePricing(Villa villa) {
    return VillaDetailPricingCalculator.calculatePricing(
      villa: villa,
      checkIn: _checkIn,
      checkOut: _checkOut,
      guestsCount: _guestsCount,
      couponDiscountVnd: _couponDiscountVnd,
    );
  }

  Future<void> _applyCoupon(Villa villa) async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty || _checkIn == null || _checkOut == null) return;
    final pricing = _calculatePricing(villa);

    setState(() {
      _isValidatingCoupon = true;
      _couponMessage = null;
    });

    try {
      final res = await ref.read(bookingRepositoryProvider).validateCoupon(
            code: code,
            listingId: villa.id,
            checkInDate: _checkIn!.toIsoDate(),
            checkOutDate: _checkOut!.toIsoDate(),
            guestsCount: _guestsCount,
            subtotalAmount: pricing.roomSubtotal,
          );
      if (!mounted) return;
      setState(() {
        _isValidatingCoupon = false;
        if (res.valid && res.discountAmount > 0) {
          _couponDiscountVnd = res.discountAmount;
          _appliedCouponCode = res.code;
          _couponMessage = res.message;
        } else {
          _couponDiscountVnd = 0;
          _appliedCouponCode = null;
          _couponMessage = res.message ?? 'Mã giảm giá không hợp lệ';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingCoupon = false;
        _couponDiscountVnd = 0;
        _appliedCouponCode = null;
        _couponMessage = DioClient.handleError(e).message;
      });
    }
  }

  Future<void> _handleBookNow(Villa villa) async {
    if (_checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày nhận phòng và trả phòng.'),
        ),
      );
      return;
    }

    final nights = _calculateNights();
    if (nights < villa.minNights) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.villaDetailMinNightsRequired(villa.minNights),
          ),
        ),
      );
      return;
    }
    if (nights > villa.maxNights) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.villaDetailMaxNightsExceeded(villa.maxNights),
          ),
        ),
      );
      return;
    }

    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) {
      await ref.read(preferencesServiceProvider).setPendingBookingIntent({
        'listingId': villa.id,
        'checkInDate': _checkIn!.toIsoDate(),
        'checkOutDate': _checkOut!.toIsoDate(),
        'guestsCount': _guestsCount,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.villaDetailLoginToBook),
        ),
      );
      await context.push('/dang-nhap');
      return;
    }

    setState(() => _isSubmittingBooking = true);
    try {
      final booking = await ref.read(bookingRepositoryProvider).createBooking(
            listingId: villa.id,
            checkInDate: _checkIn!.toIsoDate(),
            checkOutDate: _checkOut!.toIsoDate(),
            guestsCount: _guestsCount,
            specialRequests: _specialRequestsCtrl.text.trim(),
            couponCode: _appliedCouponCode,
          );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      setState(() => _isSubmittingBooking = false);

      if (villa.instantBook ||
          booking.status == 'approved' ||
          booking.status == 'awaiting_payment') {
        await context.push('/thanh-toan/${booking.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.villaDetailBookingSuccess,
            ),
          ),
        );
        await context.push('/thanh-toan/${booking.id}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioClient.handleError(e).message)),
      );
    }
  }

  void _openFullscreenGallery(BuildContext context, Villa villa) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => FullscreenGalleryModal(villa: villa),
    );
  }

  @override
  Widget build(BuildContext context) {
    final villaAsync = ref.watch(villaDetailProvider(widget.villaId));
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.contains(widget.villaId);

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

        // Record in Recently Viewed once
        if (_recordedVillaId != villa.id) {
          _recordedVillaId = villa.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(recentlyViewedProvider.notifier).recordVilla(villa);
            }
          });
        }

        final checkIn = _checkIn ?? BookingDate.today().addDays(1);
        final checkOut = _checkOut ?? checkIn.addDays(2);
        final pricingParams = (
          villaId: villa.id,
          checkIn: checkIn,
          checkOut: checkOut,
        );
        final pricingAsync =
            ref.watch(villaNightlyPricingProvider(pricingParams));
        final recommendationsAsync =
            ref.watch(villaRecommendationsProvider(villa.id));
        final calc = _calculatePricing(villa);

        return Scaffold(
          backgroundColor: AppColors.surfaceBase,
          body: CustomScrollView(
            slivers: [
              // SliverAppBar with monochrome stroke icons directly on UI (no CircleAvatar around icons!)
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.surfaceBase,
                leading: Semantics(
                  button: true,
                  label: 'Quay lại',
                  child: InkWell(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          LucideIcons.arrowLeft,
                          size: 22,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Semantics(
                    button: true,
                    label: context.l10n.galleryViewAllPhotosSemantic,
                    child: InkWell(
                      onTap: () => _openFullscreenGallery(context, villa),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            LucideIcons.images,
                            size: 20,
                            color: AppColors.iconStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: context.l10n.ctaCopyLink,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: 'https://vungtaustay.vn/villa/${villa.id}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.villaDetailShareCopied),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            LucideIcons.share2,
                            size: 19,
                            color: AppColors.iconStrong,
                          ),
                        ),
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
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'villa_image_${villa.id}',
                        child: PropertyImageCarousel(
                          imageUrls: villa.imageUrls,
                          aspectRatio: 16 / 10,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openFullscreenGallery(context, villa),
                          icon: const Icon(
                            LucideIcons.grid2x2,
                            size: 15,
                            color: AppColors.iconStrong,
                          ),
                          label: Text(
                            context.l10n.villaDetailViewAllPhotos(villa.imageUrls.length),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Detail Body
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: FadeSlideIn(
                      duration: const Duration(milliseconds: 400),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Villa Title & Code
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(
                                    villa.name,
                                    style: AppTypography.displayMedium
                                        .copyWith(fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  villa.code,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Address & Rating Summary
                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.star,
                                        size: 16, color: AppColors.iconStrong),
                                    const SizedBox(width: 4),
                                    Text(
                                      villa.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${context.l10n.reviewsCount(villa.reviewCount)})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.mapPin,
                                        size: 16, color: AppColors.iconMuted),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        villa.address,
                                        style: AppTypography.bodyMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // 2-Tier Specification Summary (Rule 8.1)
                            MobileSpecSummary(specs: villa.specs),

                            _buildSectionDivider(),

                            // Host Card + Contact Host button (`HostMessagePage.tsx`)
                            _buildHostCard(context, villa),

                            _buildSectionDivider(),

                            // Description (with dynamic multi-language translation & original toggle)
                            VillaDescriptionSection(villa: villa),

                            _buildSectionDivider(),

                            // Amenities List
                            if (villa.amenities.isNotEmpty) ...[
                              Text(
                                context.l10n.villaDetailAmenitiesTitle,
                                style: AppTypography.sectionHeading
                                    .copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 14),
                              _buildAmenitiesGrid(context, villa.amenities),
                              _buildSectionDivider(),
                            ],

                            // Interactive Availability Calendar & Booking Configurator (`ListingDetailPage.tsx`)
                            _buildBookingConfiguratorCard(context, villa, calc),

                            // Nightly Price Breakdown loaded from Real API (Constrained Box Height <= 220, Rule 10)
                            pricingAsync.when(
                              data: (prices) {
                                if (prices.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: DailyPriceBreakdown(
                                    nightlyPrices: prices,
                                  ),
                                );
                              },
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            _buildSectionDivider(),

                            // House Rules & Cancellation Policy (`PoliciesCard`)
                            _buildPoliciesCard(villa),

                            _buildSectionDivider(),

                            // Reviews Section (Rule 7 & 8)
                            ReviewListWidget(
                              listingId: villa.id,
                              averageRating: villa.rating,
                              totalReviews: villa.reviewCount,
                            ),

                            _buildSectionDivider(),

                            // Nearby / Similar Recommendations (`GET /api/listings/:id/recommendations`)
                            recommendationsAsync.when(
                              data: (recs) {
                                if (recs.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.villaDetailSimilarTitle,
                                      style: AppTypography.sectionHeading
                                          .copyWith(fontSize: 18),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 360,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: recs.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 16),
                                        itemBuilder: (context, idx) {
                                          final rec = recs[idx];
                                          return SizedBox(
                                            width: 300,
                                            child: PropertyCard(
                                              villa: rec,
                                              isFavorite:
                                                  favorites.contains(rec.id),
                                              onFavoriteToggle: () {
                                                ref
                                                    .read(favoritesProvider
                                                        .notifier)
                                                    .toggleFavorite(rec.id);
                                              },
                                              onTap: () => context
                                                  .push('/villa/${rec.id}'),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    _buildSectionDivider(),
                                  ],
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            // FAQ Section (Rule 8.2)
                            const PropertyFaqSection(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Action Bar with SafeArea (Rule 10 & 12)
          bottomNavigationBar: BookingActionBar(
            villa: villa,
            totalCalculatedVnd: calc.finalTotal,
            selectedNights: calc.nights,
            onMessageHost: () =>
                context.push('/villa/${villa.id}/nhan-tin-host'),
            onBookNow:
                _isSubmittingBooking ? null : () => _handleBookNow(villa),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: AppLoading(
            message: context.l10n.loadingVillaDetail),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          message: DioClient.handleError(err).message,
          onRetry: () => ref.invalidate(villaDetailProvider(widget.villaId)),
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Divider(height: 1, thickness: 1, color: AppColors.borderSoft),
    );
  }

  Widget _buildHostCard(BuildContext context, Villa villa) {
    final rawName = villa.host?.fullName.trim() ?? '';
    final hostName =
        rawName.isNotEmpty ? rawName : context.l10n.hostDefaultName;
    final rawBio = villa.host?.bio?.trim() ?? '';
    final hostBio =
        rawBio.isNotEmpty ? rawBio : context.l10n.hostDefaultBio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.badgeCheck,
              size: 24,
              color: AppColors.iconStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.villaDetailHostPrefix(hostName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hostBio,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingConfiguratorCard(
    BuildContext context,
    Villa villa,
    ({
      int nights,
      int weekendNights,
      int roomSubtotal,
      int extraGuestTotal,
      int cleaningFee,
      int serviceFee,
      int discount,
      int finalTotal,
    }) calc,
  ) {
    final maxGuests = villa.specs.maxGuests > 0 ? villa.specs.maxGuests : 30;
    final formatter = ref.watch(moneyFormatterProvider);
    final totalResult = formatter.format(
      calc.finalTotal,
      context: MoneyDisplayContext.breakdown,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.l10n.villaDetailBookingCalendarTitle,
                style: AppTypography.sectionHeading.copyWith(fontSize: 18),
              ),
              Text(
                context.l10n.villaDetailStayNightsRange(
                    villa.minNights, villa.maxNights),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BookingDateRangePicker(
            initialCheckIn: _checkIn,
            initialCheckOut: _checkOut,
            bookedDatesIso: villa.bookedDatesIso,
            onRangeSelected: (range) {
              setState(() {
                _checkIn = range.$1;
                _checkOut = range.$2;
              });
            },
          ),
          const Divider(height: 28, color: AppColors.divider),

          // Guest Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.guestCount,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      villa.includedGuests > 0 &&
                              villa.includedGuests < maxGuests
                          ? context.l10n.villaDetailGuestCapacityInfo(
                              villa.includedGuests, maxGuests)
                          : context.l10n.villaDetailGuestCapacityMax(maxGuests),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GuestStepperButton(
                    icon: LucideIcons.minus,
                    enabled: _guestsCount > 1,
                    onTap: () => setState(() => _guestsCount--),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_guestsCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _GuestStepperButton(
                    icon: LucideIcons.plus,
                    enabled: _guestsCount < maxGuests,
                    onTap: () => setState(() => _guestsCount++),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Coupon input (`GET /api/coupons/validate`)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 14),
                  decoration: _compactFieldDecoration(
                    hintText: context.l10n.villaDetailPromoCodeHint,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _isValidatingCoupon ? null : () => _applyCoupon(villa),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(92, 46),
                  foregroundColor: AppColors.textStrong,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text(
                  _isValidatingCoupon
                      ? context.l10n.villaDetailPromoChecking
                      : context.l10n.villaDetailPromoApply,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          if (_appliedCouponCode != null && _couponDiscountVnd > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Đã áp dụng mã $_appliedCouponCode (${formatter.formatDiscount(_couponDiscountVnd)})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ] else if (_couponMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _couponMessage!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Special Requests
          TextField(
            controller: _specialRequestsCtrl,
            minLines: 1,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: _compactFieldDecoration(
              hintText: context.l10n.villaDetailSpecialRequestsHint,
            ),
          ),
          const SizedBox(height: 18),

          // Price Breakdown Summary (Flat Minimal - coherent single-column typography; FX-16 converts VND sum once)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PriceLine(
                label:
                    '${context.l10n.villaDetailRoomSubtotal(calc.nights)}${calc.weekendNights > 0 ? context.l10n.villaDetailWeekendNights(calc.weekendNights) : ''}',
                value: formatter
                    .format(
                      calc.roomSubtotal,
                      context: MoneyDisplayContext.breakdown,
                    )
                    .formatted,
              ),
              if (calc.extraGuestTotal > 0)
                _PriceLine(
                  label: context.l10n.villaDetailExtraGuestFee,
                  value: formatter
                      .format(
                        calc.extraGuestTotal,
                        context: MoneyDisplayContext.breakdown,
                      )
                      .formatted,
                ),
              if (calc.cleaningFee > 0)
                _PriceLine(
                  label: context.l10n.villaDetailCleaningFee,
                  value: formatter
                      .format(
                        calc.cleaningFee,
                        context: MoneyDisplayContext.breakdown,
                      )
                      .formatted,
                ),
              if (calc.serviceFee > 0)
                _PriceLine(
                  label: context.l10n.villaDetailServiceFee,
                  value: formatter
                      .format(
                        calc.serviceFee,
                        context: MoneyDisplayContext.breakdown,
                      )
                      .formatted,
                ),
              if (calc.discount > 0)
                _PriceLine(
                  label: context.l10n.villaDetailDiscountLabel(
                      _appliedCouponCode ?? ''),
                  value: formatter.formatDiscount(
                    calc.discount,
                    context: MoneyDisplayContext.breakdown,
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.borderSoft),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.villaDetailEstimatedTotal,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    totalResult.formatted,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                ],
              ),
              if (totalResult.isForeignDisplayed) ...[
                const SizedBox(height: 6),
                Text(
                  formatter.l10n.fxTotalPayableVnd(
                    formatter.formatExactVnd(calc.finalTotal, withCode: true),
                  ),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (formatter.isFallingBackToVnd) ...[
                const SizedBox(height: 6),
                Text(
                  formatter.l10n.fxRateUnavailableFallback,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesGrid(BuildContext context, List<String> amenities) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final int columns;
        if (constraints.maxWidth < 520 || textScale >= 1.35) {
          columns = 1;
        } else if (constraints.maxWidth >= 760) {
          columns = 3;
        } else {
          columns = 2;
        }

        final rows = <Widget>[];
        for (var i = 0; i < amenities.length; i += columns) {
          if (i > 0) {
            rows.add(const SizedBox(height: 14));
          }
          final rowChildren = <Widget>[];
          for (var col = 0; col < columns; col++) {
            if (col > 0) {
              rowChildren.add(const SizedBox(width: 16));
            }
            final idx = i + col;
            if (idx < amenities.length) {
              final item = amenities[idx];
              rowChildren.add(
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(
                            AppSemanticIcons.resolveAmenityIcon(item),
                            size: 20,
                            color: AppColors.iconStrong,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _resolveAmenityLabel(context, item),
                          style: AppTypography.bodyLarge.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }

  String _resolveAmenityLabel(BuildContext context, String item) {
    final lang = context.activeLanguageCode;
    if (lang == 'vi') return item;
    final lower = item.trim().toLowerCase();
    if (lower.contains('wifi') || lower.contains('wi-fi') || lower.contains('internet')) {
      return lang == 'ko' ? '초고속 와이파이' : 'High-speed Wi-Fi';
    }
    if (lower.contains('điều hòa') || lower.contains('máy lạnh') || lower.contains('air')) {
      return lang == 'ko' ? '각 방 에어컨' : 'Air conditioning in each room';
    }
    if (lower.contains('bếp') && (lower.contains('dụng cụ') || lower.contains('đầy đủ') || lower.contains('kitchen'))) {
      return lang == 'ko' ? '주방 조리도구 완비' : 'Fully equipped kitchen';
    }
    if (lower.contains('đỗ xe') || lower.contains('đậu xe') || lower.contains('parking')) {
      return lang == 'ko' ? '주차 공간' : 'Car parking space';
    }
    if (lower.contains('tv') || lower.contains('tivi')) {
      return lang == 'ko' ? '65인치 스마트 TV' : '65-inch Smart TV';
    }
    if (lower.contains('view biển') || lower.contains('biển') || lower.contains('ocean')) {
      return lang == 'ko' ? '오션뷰' : 'Direct sea view';
    }
    if (lower.contains('ban công') || lower.contains('balcony')) {
      return lang == 'ko' ? '발코니' : 'Airy balcony';
    }
    if (lower.contains('hồ bơi') || lower.contains('bể bơi') || lower.contains('pool')) {
      return lang == 'ko' ? '프라이빗 수영장' : 'Private pool';
    }
    if (lower.contains('bbq') || lower.contains('nướng')) {
      return lang == 'ko' ? 'BBQ 바비큐 그릴' : 'BBQ grill';
    }
    if (lower.contains('tủ lạnh') || lower.contains('fridge')) {
      return lang == 'ko' ? '냉장고' : 'Refrigerator';
    }
    if (lower.contains('máy giặt') || lower.contains('washer')) {
      return lang == 'ko' ? '세탁기' : 'Washing machine';
    }
    if (lower.contains('bồn tắm') || lower.contains('bathtub')) {
      return lang == 'ko' ? '욕조' : 'Bathtub';
    }
    return item;
  }

  String _resolveCancellationPolicy(BuildContext context, String policy) {
    final l10n = context.l10n;
    switch (policy.toLowerCase()) {
      case 'flexible':
        return l10n.villaDetailPolicyFlexible;
      case 'strict':
        return l10n.villaDetailPolicyStrict;
      case 'moderate':
      default:
        return l10n.villaDetailPolicyModerate;
    }
  }

  Widget _buildPoliciesCard(Villa villa) {
    final rules = villa.rules ?? const VillaRules();
    final policyItems = <Widget>[
      _PolicyItem(
        icon: AppSemanticIcons.checkIn,
        label: context.l10n.villaDetailCheckInTime(
            rules.checkInFrom, rules.checkInUntil),
      ),
      _PolicyItem(
        icon: AppSemanticIcons.checkOut,
        label: context.l10n.villaDetailCheckOutTime(rules.checkOutBefore),
      ),
      if (rules.quietHours != null)
        _PolicyItem(
          icon: LucideIcons.volumeX,
          label: context.l10n.villaDetailQuietHours(rules.quietHours!),
        ),
      _PolicyItem(
        icon: LucideIcons.pawPrint,
        label: rules.allowPets
            ? context.l10n.villaDetailPetsAllowed
            : context.l10n.villaDetailPetsNotAllowed,
      ),
      _PolicyItem(
        icon: LucideIcons.shieldCheck,
        label: _resolveCancellationPolicy(context, villa.cancellationPolicy),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.villaDetailPoliciesTitle,
          style: AppTypography.sectionHeading.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final int columns =
                (constraints.maxWidth < 640 || textScale >= 1.35) ? 1 : 2;
            final rows = <Widget>[];
            for (var i = 0; i < policyItems.length; i += columns) {
              if (i > 0) {
                rows.add(const SizedBox(height: 14));
              }
              final rowChildren = <Widget>[];
              for (var col = 0; col < columns; col++) {
                if (col > 0) {
                  rowChildren.add(const SizedBox(width: 20));
                }
                final idx = i + col;
                if (idx < policyItems.length) {
                  rowChildren.add(Expanded(child: policyItems[idx]));
                } else {
                  rowChildren.add(const Expanded(child: SizedBox.shrink()));
                }
              }
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowChildren,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          },
        ),
        if (rules.additionalRules.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final r in rules.additionalRules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $r',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }

  InputDecoration _compactFieldDecoration({required String hintText}) {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
    );
  }
}

class _GuestStepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _GuestStepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled ? AppColors.border : AppColors.borderSoft,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: enabled ? AppColors.iconStrong : AppColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;

  const _PriceLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PolicyItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 22,
          child: Center(
            child: Icon(icon, size: 20, color: AppColors.iconStrong),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class FullscreenGalleryModal extends StatefulWidget {
  final Villa villa;

  const FullscreenGalleryModal({super.key, required this.villa});

  @override
  State<FullscreenGalleryModal> createState() =>
      _FullscreenGalleryModalState();
}

class _FullscreenGalleryModalState extends State<FullscreenGalleryModal> {
  String _selectedType = 'all';

  @override
  Widget build(BuildContext context) {
    final images = widget.villa.images.isNotEmpty
        ? widget.villa.images
        : widget.villa.imageUrls
            .map((u) => VillaImage(imageId: u, url: u))
            .toList();

    final availableTypes = <String>{
      for (final img in images)
        if (img.type != null && img.type!.isNotEmpty) img.type!,
    };

    final filtered = _selectedType == 'all'
        ? images
        : images.where((i) => i.type == _selectedType).toList();

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.villa.name} (${context.l10n.galleryPhotoCount(filtered.length)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).closeButtonTooltip,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            LucideIcons.x,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (availableTypes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    ChoiceChip(
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      label: Text(
                        context.l10n.reviewsFilterAll,
                        style: TextStyle(
                          fontWeight: _selectedType == 'all'
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedType == 'all'
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: _selectedType == 'all',
                      onSelected: (_) => setState(() => _selectedType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    for (final t in availableTypes)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          label: Text(
                            VillaImage(imageId: '', url: '', type: t)
                                    .localizedType(context.l10n) ??
                                t,
                            style: TextStyle(
                              fontWeight: _selectedType == t
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _selectedType == t
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          selected: _selectedType == t,
                          onSelected: (_) => setState(() => _selectedType = t),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final img = filtered[index];
                  final spaceName = img.localizedType(context.l10n);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: AppImage(
                            url: img.url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      if (spaceName != null && spaceName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.gallerySpacePrefix(spaceName),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
